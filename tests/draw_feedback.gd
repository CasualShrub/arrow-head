extends Node

class TriggerProbe extends "res://scripts/components/adaptive_trigger.gd":
	func _ready() -> void:
		available = true
	func _process(_delta: float) -> void:
		pass
	func _send(_value: float) -> void:
		pass

class FeedbackProbe extends "res://scripts/singletons/controller_manager.gd":
	var pull := 0.0
	var now := 1000
	var pulses: Array[Vector2] = []
	var durations: Array[float] = []
	var stops := 0
	func _ready() -> void:
		adaptive.free()
		adaptive = TriggerProbe.new()
		add_child(adaptive)
		device = 0
		using_controller = true
		set_process(false)
		set_process_input(false)
	func _is_dualsense() -> bool:
		return device >= 0
	func _trigger_pull() -> float:
		return pull
	func _feedback_msec() -> int:
		return now
	func pulse(weak: float, strong: float, duration: float, _trigger := 0.0, _preview := false) -> void:
		if SettingsManager.controller_vibration > 0.0:
			pulses.append(Vector2(weak, strong))
			durations.append(duration)
	func _stop_rumble() -> void:
		_draw_rumbling = false
		stops += 1
	func advance(milliseconds: int) -> void:
		now += milliseconds
		_process(0)

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SoundManager.stop_music()
	var feedback := FeedbackProbe.new()
	add_child(feedback)
	var resistance: float = SettingsManager.trigger_resistance
	var vibration: float = SettingsManager.controller_vibration
	SettingsManager.trigger_resistance = 1.0
	SettingsManager.controller_vibration = 1.0

	feedback.advance(0)
	check(feedback.adaptive._strength == 0.0, "Empty attack applies resistance")
	feedback.set_attack_available(true)
	feedback.advance(0)
	check(feedback.adaptive._strength == 1.0 and not feedback._charging, "Resistance was not armed before the pull")
	check(feedback.pulses.is_empty(), "Idle attack should not rumble")
	feedback.using_controller = false
	feedback._use_controller(0)
	check(feedback.adaptive._strength == 1.0, "First R2 input unloaded the prepared resistance")

	feedback.pull = 0.5
	feedback.advance(0)
	check(feedback.pulses.is_empty(), "Rumble starts before the draw threshold")
	feedback.pull = 0.6
	feedback.advance(0)
	check(feedback.pulses.size() == 1 and not feedback._charging, "Draw feedback waits for the slowed physics tick")
	var onset: Vector2 = feedback.pulses.back()
	Engine.time_scale = 0.1
	feedback.pull = 0.8
	feedback.advance(40)
	var middle: Vector2 = feedback.pulses.back()
	check(middle.x > onset.x and middle.y > onset.y, "Rumble does not grow with trigger travel")
	feedback.pull = 0.95
	feedback.set_charging(true)
	feedback.attack_released()
	feedback.advance(0)
	check(feedback.adaptive._effect == feedback.adaptive.Effect.KICK, "Shot does not actively pulse R2")
	check(feedback.pulses.back() == Vector2.ONE and is_equal_approx(feedback.durations.back(), 0.12), "Shot has no sustained full-strength body recoil")
	var stops := feedback.stops
	feedback.set_attack_available(false)
	check(feedback.stops == stops and feedback.adaptive._effect == feedback.adaptive.Effect.KICK, "Last charge cut off the trigger kick")
	feedback.advance(55)
	check(feedback.pulses.back() == Vector2.ONE, "Body recoil lost its initial impact too early")
	check(feedback.adaptive._effect == feedback.adaptive.Effect.KICK, "R2 kick stopped too early")
	feedback.advance(75)
	check(feedback.pulses.back() == Vector2(0.95, 1.0), "Recoil lost its heavy follow-through")
	check(feedback.adaptive._effect == feedback.adaptive.Effect.KICK, "Trigger pulsation ended too early")
	feedback.advance(100)
	check(feedback.pulses.back() == Vector2(0.55, 0.4), "Recoil tail is missing")
	feedback.advance(30)
	check(feedback.adaptive._strength == 0.0, "Trigger kick exceeded 260 ms")
	feedback.advance(70)
	check(feedback._release_started < 0 and feedback.stops > stops, "Recoil did not end during slow motion")
	feedback.set_attack_available(true)
	feedback.advance(0)
	check(feedback.adaptive._strength == 0.0 and not feedback._draw_rumbling, "Holding R2 rearmed resistance after a shot")
	feedback.pull = 0.85
	feedback.advance(40)
	check(feedback.adaptive._strength == 0.0, "Threshold jitter rearmed the trigger")
	feedback.pull = 0.0
	feedback.advance(0)
	check(feedback.adaptive._strength == 1.0, "Releasing R2 did not rearm the next shot")

	feedback.pull = 0.95
	feedback.attack_released()
	feedback.advance(265)
	feedback.pull = 0.0
	feedback.advance(0)
	feedback.pull = 0.8
	feedback.set_charging(true)
	feedback.advance(0)
	check(feedback._release_started < 0 and feedback._draw_rumbling, "Quick new draw did not replace the old tail")
	stops = feedback.stops
	feedback.advance(100)
	check(feedback._draw_rumbling and feedback.stops == stops, "Old recoil completion stopped the new draw")
	get_tree().paused = true
	feedback.advance(0)
	check(feedback.adaptive._strength == 0.0 and not feedback._draw_rumbling, "Pause left feedback active")
	get_tree().paused = false
	feedback.pull = 0.0
	feedback.advance(0)
	feedback.pull = 0.95
	feedback.attack_released()
	feedback._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var count := feedback.pulses.size()
	feedback.advance(60)
	check(feedback.adaptive._strength == 0.0 and feedback.pulses.size() == count, "Focus loss allowed deferred recoil")
	feedback._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	feedback.set_attack_available(false)
	feedback.pull = 0.0
	feedback.advance(0)

	feedback.test_trigger()
	check(feedback.adaptive._strength == 1.0, "Settings test did not preload resistance")
	feedback.pull = 0.8
	feedback.advance(0)
	check(feedback._draw_rumbling, "Settings test omits draw tension")
	feedback.pull = 0.0
	feedback.advance(40)
	check(feedback._release_started < 0 and not feedback._draw_rumbling, "Aborted preview pull fired a shot")
	feedback.pull = 0.94
	feedback.advance(0)
	check(feedback.adaptive._effect == feedback.adaptive.Effect.BOW and feedback._release_started < 0, "Settings preview fired below 95 percent")
	feedback.pull = 0.95
	feedback.advance(0)
	check(feedback.adaptive._effect == feedback.adaptive.Effect.KICK and feedback.pulses.back() == Vector2.ONE, "Settings test omits the threshold kick")
	feedback.advance(330)
	count = feedback.pulses.size()
	feedback.pull = 0.85
	feedback.advance(40)
	feedback.pull = 1.0
	feedback.advance(200)
	check(feedback.pulses.size() == count and feedback.adaptive._strength == 0.0, "Held preview repeated the shot")
	feedback.pull = 0.0
	feedback.advance(0)
	feedback.pull = 0.95
	feedback.advance(0)
	check(feedback.adaptive._effect == feedback.adaptive.Effect.KICK, "Settings test cannot fire a second deliberate pull")
	feedback.now = feedback._trigger_preview_until + 1
	feedback.advance(0)
	check(feedback.adaptive._strength == 0.0 and not feedback._draw_rumbling, "Settings test left feedback running")

	feedback.set_attack_available(true)
	feedback.pull = 0.0
	SettingsManager.controller_vibration = 0.0
	feedback._on_settings_changed()
	count = feedback.pulses.size()
	feedback.advance(0)
	check(feedback.pulses.size() == count and feedback.adaptive._strength == 1.0, "Vibration off also disabled trigger resistance")
	feedback.pull = 0.95
	feedback.attack_released()
	check(feedback.adaptive._effect == feedback.adaptive.Effect.KICK and feedback.pulses.size() == count, "Body vibration off disabled the trigger kick")
	SettingsManager.controller_vibration = 1.0
	SettingsManager.trigger_resistance = 0.0
	feedback._on_settings_changed()
	feedback.pull = 0.0
	feedback.advance(300)
	feedback.pull = 0.8
	feedback.advance(40)
	check(feedback._draw_rumbling and feedback.adaptive._strength == 0.0, "Resistance off disabled ordinary rumble")
	feedback.attack_released()
	check(feedback.adaptive._strength == 0.0 and feedback.pulses.back() == Vector2.ONE, "Resistance off changed body recoil")
	feedback.stop_feedback()
	count = feedback.pulses.size()
	feedback.pull = 0.0
	feedback.advance(1000)
	check(feedback.pulses.size() == count, "Cancelled recoil restarted after a frame stall")
	SettingsManager.trigger_resistance = 1.0
	feedback.advance(0)
	feedback._on_connection_changed(0, false)
	feedback.advance(0)
	check(feedback.adaptive._strength == 0.0, "Disconnect re-armed resistance")

	Engine.time_scale = 1.0
	SettingsManager.trigger_resistance = resistance
	SettingsManager.controller_vibration = vibration
	feedback.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS: bow preloading, threshold kick/recoil, held-trigger latch, slow motion, last charge, redraw, cancellation, independent gains and settings preview")
	else:
		for message in failures:
			push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)
