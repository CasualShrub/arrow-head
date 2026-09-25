extends Node

signal status_changed

const WebBridge := preload("res://scripts/components/dualsense_web.gd")
const EXTENSION := "res://native/dualsense/dualsense.gdextension"
const KICK_MS := 260

enum Effect { OFF, BOW, KICK }

var status := "Adaptive triggers need macOS or a browser with WebHID."
var available := false
var _web: JavaScriptObject
var _native: RefCounted
var _strength := 0.0
var _effect := Effect.OFF
var _kick_until := 0
var _next_heartbeat := 0
var _next_status_check := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WebBridge.SOURCE, true)
		_web = JavaScriptBridge.get_interface("arrowheadTriggers")
	elif OS.get_name() == "macOS" and DisplayServer.get_name() != "headless":
		if FileAccess.file_exists("res://native/dualsense/build/libdualsense.dylib"):
			if not GDExtensionManager.is_extension_loaded(EXTENSION):
				GDExtensionManager.load_extension(EXTENSION)
			if ClassDB.class_exists(&"DualSenseBridge"):
				_native = ClassDB.instantiate(&"DualSenseBridge")
				_set_status("Looking for a DualSense...", false)
			else:
				_set_status("Could not load adaptive triggers. Rebuild the extension and restart.", false)
		else:
			_set_status("The macOS adaptive-trigger extension needs to be built.", false)

func _process(_delta: float) -> void:
	if _web:
		_set_status(String(_web.status), bool(_web.ready))
	elif _native and Time.get_ticks_msec() >= _next_status_check:
		_next_status_check = Time.get_ticks_msec() + 250
		var count: int = _native.controller_count()
		if count == 1 and not Input.get_connected_joypads().is_empty() and _native.output_ready():
			_set_status("Direct trigger vibration ready. Lightly hold L2, then pull R2 to 95%.", true)
		elif count == 0 or Input.get_connected_joypads().is_empty():
			_set_status("Connect a DualSense by USB or Bluetooth.", false)
		elif count == 1:
			_set_status("Trigger output failed. Reconnect the DualSense and restart the game.", false)
		else:
			_set_status("Connect one DualSense to use adaptive triggers.", false)
	if _effect == Effect.KICK and Time.get_ticks_msec() >= _kick_until:
		stop()
	elif _effect == Effect.BOW and Time.get_ticks_msec() >= _next_heartbeat:
		_send(_strength)

func _set_status(message: String, ready: bool) -> void:
	if status == message and available == ready:
		return
	if not ready:
		stop()
	status = message
	available = ready
	status_changed.emit()

func connect_device() -> void:
	if _web:
		_web.showConnect()

func set_bow(strength: float) -> void:
	_set_effect(strength, Effect.BOW)

func kick(strength: float) -> void:
	_set_effect(strength, Effect.KICK)

func _set_effect(strength: float, effect: Effect) -> void:
	var value := clampf(strength, 0.0, 1.0) if available else 0.0
	if value <= 0.0:
		effect = Effect.OFF
	if is_equal_approx(value, _strength) and effect == _effect:
		return
	_strength = value
	_effect = effect
	if effect == Effect.KICK:
		_kick_until = Time.get_ticks_msec() + KICK_MS
	_send(value)

func stop() -> void:
	set_bow(0.0)

func _send(value: float) -> void:
	_next_heartbeat = Time.get_ticks_msec() + 200
	if _web:
		if _effect == Effect.KICK:
			_web.kick(value)
		else:
			_web.bow(value)
	elif _native:
		var result: int = _native.kick(value) if _effect == Effect.KICK else _native.bow(value)
		if result != 0:
			_set_status("Trigger output failed. Reconnect the DualSense and restart the game.", false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stop()
	elif what == NOTIFICATION_EXIT_TREE:
		stop()
		if _web:
			_web.shutdown()
		_native = null
