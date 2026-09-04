@icon("res://addons/at-icons/used/node/push_button.svg")
extends Node
class_name InputComponent

@export var action_name: StringName

signal pressed()
signal released()

var _press_chached := false
var _release_cached := false

func _ready() -> void:
	assert(action_name, "%s must have ActionName." % get_path())

func _input(_event: InputEvent) -> void:
	if is_just_pressed():
		_press_chached = true
		pressed.emit()
	if is_just_released():
		_release_cached = true
		released.emit()

func is_slow_held() -> bool:
	return Input.is_action_pressed("slow")

func is_just_pressed() -> bool:
	return Input.is_action_just_pressed(action_name)

func is_just_released() ->  bool:
	return Input.is_action_just_released(action_name)

func is_pressed() -> bool:
	return Input.is_action_just_pressed(action_name)

func consume_pressed() -> bool:
	if _press_chached:
		_press_chached = false
		return true
	return false

func consume_released() -> bool:
	if _release_cached:
		_release_cached = false
		return true
	return false
