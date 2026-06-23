extends Node

signal move_direction_changed(direction: Vector2)
signal action_pressed

var _last_direction := Vector2.ZERO

func _poll_input(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != _last_direction:
		_last_direction = direction
		move_direction_changed.emit(direction)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		action_pressed.emit()
