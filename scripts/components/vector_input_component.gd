extends Node
class_name VectorInputComponent

@export var left_action: StringName
@export var right_action: StringName
@export var up_action: StringName
@export var down_action: StringName

signal changed(vec: Vector2)

var _vec := Vector2.ZERO

func _init() -> void:
	assert(left_action, "VectorInputComponent must have LeftAction.")
	assert(right_action, "VectorInputComponent must have RightAction.")
	assert(up_action, "VectorInputComponent must have UpAction.")
	assert(down_action, "VectorInputComponent must have DownAction.")

func _input(_event: InputEvent) -> void:
	var curr_vec := Input.get_vector(left_action, right_action, up_action, down_action)
	if curr_vec == _vec: return
	_vec = curr_vec
	changed.emit(curr_vec)

func get_vector() -> Vector2:
	return _vec
