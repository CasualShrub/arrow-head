@icon("res://addons/at-icons/used/node/joypad.svg")
extends Node
class_name InputModeComponent

enum InputMode { KEYBOARD_MOUSE, CONTROLLER }

signal changed(mode: InputMode)

var _current_mode := InputMode.KEYBOARD_MOUSE

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		set_mode(InputMode.KEYBOARD_MOUSE)
	elif event is InputEventKey or event is InputEventMouseButton:
		set_mode(InputMode.KEYBOARD_MOUSE)

func is_using(mode: InputMode) -> bool:
	return _current_mode == mode

func is_keyboard_mouse() -> bool:
	return is_using(InputMode.KEYBOARD_MOUSE)

func is_controller() -> bool:
	return is_using(InputMode.CONTROLLER)

func get_mode() -> InputMode:
	return _current_mode

func set_mode(mode: InputMode) -> void:
	if _current_mode == mode: return
	_current_mode = mode
	changed.emit(mode)
