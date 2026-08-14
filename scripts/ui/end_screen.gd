extends MenuOverlay
class_name EndScreen

# A menu overlay that also shows the run time and a piece of wobbling header
# art in place of the pause menu's title.

@export var min_angle := 4.0
@export var max_angle := 5.0
@export var rot_speed := 0.2
@export var base_angle := 0.0

@onready var _apple: TextureRect = %Apple
@onready var _time: Label = %Time

var _t := 0.0

func _show_time() -> void:
	var timer := get_node_or_null("../LevelTimer") as LevelTimer
	if timer:
		_time.text = "Time  " + LevelTimer.format_time(timer.get_elapsed())

func _process(delta: float) -> void:
	if not is_open():
		return
	_t += delta * rot_speed
	_apple.rotation_degrees = base_angle + sin(_t * max_angle) * min_angle
	_apple.scale = Vector2.ONE * (1.0 + sin(_t * 6.0) * 0.05)
