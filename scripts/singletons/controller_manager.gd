extends Node

signal changed
signal disconnected

const ACTIVITY_DEADZONE := 0.25
const DRAW_RUMBLE_START := 0.55
const RUMBLE_INTERVAL_MS := 35
const RELEASE_RELIEF_MS := 260
const WEB_HAPTICS := """
window.arrowheadHaptics = (() => {
 const generations = new Map();
 const actuator = id => {
  try {
   const pad = navigator.getGamepads?.()[id];
   return pad?.vibrationActuator || pad?.hapticActuators?.[0];
  } catch (_) { return null; }
 };
 return {
  play(id, weak, strong, duration, trigger) {
   const a = actuator(id);
   if (!a || document.hidden) return;
   const generation = (generations.get(id) || 0) + 1;
   generations.set(id, generation);
   const fallback = () => {
    if (generations.get(id) !== generation || document.hidden) return;
    try {
     const result = a.playEffect
      ? a.playEffect('dual-rumble', {duration, weakMagnitude: weak, strongMagnitude: strong})
      : a.pulse?.(Math.max(weak, strong), duration);
     Promise.resolve(result).catch(() => {});
    } catch (_) {}
   };
   if (trigger > 0 && a.effects?.includes('trigger-rumble')) {
    try {
     Promise.resolve(a.playEffect('trigger-rumble', {
      duration, weakMagnitude: weak, strongMagnitude: strong, leftTrigger: trigger, rightTrigger: trigger
     })).catch(fallback);
    } catch (_) { fallback(); }
   } else fallback();
  },
  stop(id) {
   generations.set(id, (generations.get(id) || 0) + 1);
   try { Promise.resolve(actuator(id)?.reset?.()).catch(() => {}); } catch (_) {}
  }
 };
})();
"""

var device := -1
var using_controller := false
var _web: JavaScriptObject
var _charging := false
var _next_pulse := 0
var _was_paused := false
var _last_joy_activity := -1000
var adaptive := preload("res://scripts/components/adaptive_trigger.gd").new()
var _trigger_preview_until := 0
var _attack_available := false
var _focused := true
var _release_until := 0
var _draw_rumbling := false
var _trigger_spent := false
var _kick_until := 0
var _release_started := -1
var _release_stage := -1
var _release_preview := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(adaptive)
	Input.joy_connection_changed.connect(_on_connection_changed)
	SettingsManager.changed.connect(_on_settings_changed)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		device = devices[0]
		using_controller = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_HAPTICS, true)
		_web = JavaScriptBridge.get_interface("arrowheadHaptics")

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_last_joy_activity = Time.get_ticks_msec()
		_use_controller(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > (0.15 if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else ACTIVITY_DEADZONE):
		_last_joy_activity = Time.get_ticks_msec()
		_use_controller(event.device)
	elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_use_mouse()
	elif event is InputEventMouseMotion and event.relative.length_squared() > 4.0 and Time.get_ticks_msec() - _last_joy_activity > 200:
		_use_mouse()

func _process(_delta: float) -> void:
	var now := _feedback_msec()
	var paused := get_tree().paused
	if paused and not _was_paused:
		stop_feedback()
	_was_paused = paused
	var previewing := _focused and now < _trigger_preview_until
	var pull := _trigger_pull()
	if pull <= InputComponent.TRIGGER_RESET_POINT:
		_trigger_spent = false
	if previewing:
		if not _trigger_spent and now >= _release_until and (pull >= InputComponent.TRIGGER_FIRE_POINT or is_equal_approx(pull, InputComponent.TRIGGER_FIRE_POINT)):
			_start_release(true)
	elif _trigger_preview_until > 0:
		stop_feedback()
	var armed := _focused and _attack_available and not paused and not _trigger_spent and now >= _release_until
	var preview_armed := previewing and not _trigger_spent and now >= _release_until
	if _focused and now < _kick_until and _is_dualsense():
		adaptive.kick(SettingsManager.trigger_resistance)
	else:
		adaptive.set_bow(SettingsManager.trigger_resistance if _is_dualsense() and (armed or preview_armed) else 0.0)
	var drawing := (armed and using_controller and (_charging or pull > DRAW_RUMBLE_START)) or preview_armed
	if drawing and pull > DRAW_RUMBLE_START:
		if _release_started >= 0:
			_release_started = -1
			_stop_rumble()
		_update_draw(pull, now, previewing)
	else:
		if _draw_rumbling:
			_stop_rumble()
			_next_pulse = 0
		_update_release(now)

func _feedback_msec() -> int:
	return Time.get_ticks_msec()

func _update_draw(pull: float, now: int, preview: bool) -> void:
	if SettingsManager.controller_vibration <= 0.0:
		return
	if now < _next_pulse:
		return
	var tension := clampf(inverse_lerp(DRAW_RUMBLE_START, InputComponent.TRIGGER_FIRE_POINT, pull), 0.0, 1.0)
	pulse(lerpf(0.18, 0.80, pow(tension, 1.4)), lerpf(0.10, 0.65, pow(tension, 1.15)), 0.07, 0.0, preview)
	_draw_rumbling = true
	_next_pulse = now + RUMBLE_INTERVAL_MS

func _start_release(preview := false) -> void:
	_charging = false
	_trigger_spent = _trigger_pull() > InputComponent.TRIGGER_RESET_POINT
	_release_started = _feedback_msec()
	_release_stage = -1
	_release_preview = preview
	_release_until = _release_started + RELEASE_RELIEF_MS
	_kick_until = _release_started + adaptive.KICK_MS if _trigger_spent and _is_dualsense() else 0
	adaptive.stop()
	if _kick_until > 0:
		adaptive.kick(SettingsManager.trigger_resistance)
	_stop_rumble()
	_update_release(_release_started)

func _update_release(now: int) -> void:
	if _release_started < 0:
		return
	var elapsed := now - _release_started
	if elapsed >= 320:
		_release_started = -1
		_stop_rumble()
		return
	var stage := 0 if elapsed < 120 else (1 if elapsed < 220 else 2)
	if stage == _release_stage:
		return
	_release_stage = stage
	var force := [Vector2.ONE, Vector2(0.95, 1.0), Vector2(0.55, 0.4)]
	var end_ms := [120, 220, 320]
	pulse(force[stage].x, force[stage].y, (end_ms[stage] - elapsed) / 1000.0, 1.0 if stage == 0 else 0.0, _release_preview)

func _trigger_pull() -> float:
	return clampf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), 0.0, 1.0) if device >= 0 else 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_focused = false
		stop_feedback()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true

func _use_controller(id: int) -> void:
	if device == id:
		if not using_controller:
			using_controller = true
			changed.emit()
		return
	var preview_until := _trigger_preview_until
	stop_feedback()
	device = id
	using_controller = true
	if _is_dualsense():
		_trigger_preview_until = preview_until
	changed.emit()

func _use_mouse() -> void:
	if not using_controller:
		return
	stop_feedback()
	using_controller = false
	changed.emit()

func _on_connection_changed(id: int, connected: bool) -> void:
	if connected:
		if device < 0:
			_use_controller(id)
	elif id == device:
		stop_feedback()
		device = -1
		using_controller = false
		changed.emit()
		disconnected.emit()

func set_charging(enabled: bool) -> void:
	if enabled == _charging:
		return
	if not enabled:
		stop_feedback()
	else:
		_charging = true
		if not _draw_rumbling:
			_next_pulse = 0

func set_attack_available(enabled: bool) -> void:
	if _attack_available == enabled:
		return
	_attack_available = enabled
	if not enabled:
		_charging = false
		if _release_started < 0:
			adaptive.stop()
		if _draw_rumbling:
			_stop_rumble()

func attack_released() -> void:
	_start_release()

func pulse(weak: float, strong: float, duration: float, trigger := 0.0, preview := false) -> void:
	if (not using_controller and not preview) or device < 0 or SettingsManager.controller_vibration <= 0.0:
		return
	var gain := SettingsManager.controller_vibration
	if _web:
		_web.play(device, weak * gain, strong * gain, duration * 1000.0, trigger * gain)
	else:
		Input.start_joy_vibration(device, weak * gain, strong * gain, duration)

func stop_feedback() -> void:
	_charging = false
	_trigger_preview_until = 0
	_trigger_spent = _trigger_pull() > InputComponent.TRIGGER_RESET_POINT
	_kick_until = 0
	_release_started = -1
	_next_pulse = 0
	adaptive.stop()
	_stop_rumble()

func _stop_rumble() -> void:
	_draw_rumbling = false
	if device < 0:
		return
	if _web:
		_web.stop(device)
	else:
		Input.stop_joy_vibration(device)

func _on_settings_changed() -> void:
	if SettingsManager.controller_vibration <= 0.0:
		_release_started = -1
		_stop_rumble()
	if SettingsManager.trigger_resistance <= 0.0:
		adaptive.stop()

func test_trigger() -> void:
	if adaptive.available:
		stop_feedback()
		_trigger_preview_until = _feedback_msec() + 3000
		_release_until = 0
		adaptive.set_bow(SettingsManager.trigger_resistance)

func _is_dualsense() -> bool:
	if device < 0 or device not in Input.get_connected_joypads():
		return false
	var info := Input.get_joy_info(device)
	if info.has("product_id"):
		var vendor: Variant = info.get("vendor_id", 0)
		var product: Variant = info.product_id
		var vendor_id := int(vendor)
		var product_id := int(product)
		return vendor_id == 0x054c and product_id in [0x0ce6, 0x0df2]
	var joy_name := Input.get_joy_name(device).to_lower()
	return "dualsense" in joy_name or "ps5" in joy_name or "0ce6" in joy_name or "0df2" in joy_name

func button_label(action: StringName) -> String:
	var joy_name := Input.get_joy_name(device).to_lower() if device >= 0 else ""
	var playstation := "sony" in joy_name or "dualsense" in joy_name or "ps5" in joy_name or "ps4" in joy_name or "wireless controller" in joy_name
	match action:
		&"ui_accept": return "Cross" if playstation else "A / South"
		&"ui_cancel": return "Circle" if playstation else "B / East"
		&"fire": return "R2 / R1" if playstation else "RT / RB"
		&"slow": return "L2 / L1" if playstation else "LT / LB"
		&"pause": return "Options" if playstation else "Start"
		&"restart": return "Triangle" if playstation else "Y / North"
	return String(action)
