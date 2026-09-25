@icon("res://addons/at-icons/used/node/push_button.svg")
extends Node
class_name InputComponent

@export var action_name: StringName
@export var trigger_fires_on_pull := false

const TRIGGER_FIRE_POINT := 0.95
const TRIGGER_RESET_POINT := 0.12

signal pressed()
signal released()

var _press_cached := false
var _release_cached := false
var _held := false
var _armed := true
var _trigger_active := false
var _trigger_spent := false
var _trigger_armed := true
var _trigger_device := -1
var _activation_cached := false
var _cancel_cached := false

func _ready() -> void:
	assert(action_name, "%s must have ActionName." % get_path())
	reset()

func _input(event: InputEvent) -> void:
	if not event.is_action(action_name):
		return
	if trigger_fires_on_pull and event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
		_update_trigger(event)
		return
	if _trigger_active:
		return
	var held := Input.is_action_pressed(action_name)
	if not _armed:
		_armed = not held
		return
	if held == _held:
		return
	_held = held
	if held:
		_press_cached = true
		pressed.emit()
	else:
		_release_cached = true
		released.emit()

func _update_trigger(event: InputEventJoypadMotion) -> void:
	_trigger_device = event.device
	var pull := event.axis_value
	if pull <= TRIGGER_RESET_POINT:
		if _trigger_active and not _trigger_spent:
			_cancel_cached = true
		_trigger_active = false
		_trigger_spent = false
		_trigger_armed = true
		if not Input.is_action_pressed(action_name):
			_armed = true
		return
	if _held:
		_trigger_armed = false
	if not _trigger_armed or _trigger_spent:
		return
	if not _trigger_active and pull >= InputMap.action_get_deadzone(action_name):
		_trigger_active = true
		_press_cached = true
		pressed.emit()
	if pull >= TRIGGER_FIRE_POINT or is_equal_approx(pull, TRIGGER_FIRE_POINT):
		_trigger_spent = true
		_activation_cached = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()

func reset() -> void:
	_press_cached = false
	_release_cached = false
	_held = false
	_armed = not Input.is_action_pressed(action_name) if action_name else true
	_activation_cached = false
	_cancel_cached = false
	_trigger_active = false
	_trigger_spent = false
	_trigger_armed = _armed
	if trigger_fires_on_pull:
		var devices := Input.get_connected_joypads()
		if _trigger_device >= 0 and _trigger_device not in devices:
			devices.append(_trigger_device)
		for id in devices:
			if Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_RESET_POINT:
				_trigger_armed = false

func consume_activated() -> bool:
	var activated := _activation_cached
	_activation_cached = false
	return activated

func consume_cancelled() -> bool:
	var cancelled := _cancel_cached
	_cancel_cached = false
	return cancelled

func is_slow_held() -> bool:
	return Input.is_action_pressed("slow")

func is_just_pressed() -> bool:
	return Input.is_action_just_pressed(action_name)

func is_just_released() ->  bool:
	return Input.is_action_just_released(action_name)

func is_pressed() -> bool:
	return Input.is_action_pressed(action_name)

func consume_pressed() -> bool:
	if _press_cached:
		_press_cached = false
		return true
	return false

func consume_released() -> bool:
	if _release_cached:
		_release_cached = false
		return true
	return false
