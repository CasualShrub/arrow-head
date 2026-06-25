extends Node
class_name InputComponent

var _fire_pressed := false
var _fire_released := false

func get_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func consume_fire_pressed() -> bool:
	if _fire_pressed:
		_fire_pressed = false
		return true
	return false
	
func consume_fire_released() -> bool:
	if _fire_released:
		_fire_released = false
		return true
	return false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		_fire_pressed = true
	elif event.is_action_released("fire"):
		_fire_released = true
