@icon("res://addons/at-icons/used/node/joystick.svg")
extends Node
class_name VectorInputComponent

@export var left_action: StringName
@export var right_action: StringName
@export var up_action: StringName
@export var down_action: StringName

signal changed(vec: Vector2)

var _vec := Vector2.ZERO

func _ready() -> void:
	assert(left_action, "%s must have LeftAction." % get_path())
	assert(right_action, "%s must have RightAction." % get_path())
	assert(up_action, "%s must have UpAction." % get_path())
	assert(down_action, "%s must have DownAction." % get_path())

func _input(_event: InputEvent) -> void:
	var curr_vec := Input.get_vector(
		left_action,
		right_action,
		up_action,
		down_action
	)
	if curr_vec == _vec: return
	_vec = curr_vec
	changed.emit(curr_vec)

## Returns Vector2 with max length of 1.0.
func get_vector() -> Vector2:
	return _vec
