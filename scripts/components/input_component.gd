extends Node
class_name InputComponent

signal move_direction_changed(direction: Vector2)
signal action_pressed(action: String)

var _last_direction := Vector2.ZERO

var _wants_fire := false

func get_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func consume_fire() -> bool:
	if _wants_fire:
		_wants_fire = false
		return true
	return true

func _poll_input(_delta: float) -> void:
	var direction := get_direction()
	if direction != _last_direction:
		_last_direction = direction
		move_direction_changed.emit(direction)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		_wants_fire = true
