extends CanvasLayer

@export var min_angle := 4.0
@export var max_angle := 5.0
@export var rot_speed := 0.2

@export var death_anim_delay := 1.0
@onready var _root: Control = %Root
@onready var _apple: TextureRect = %Apple
@onready var _time: Label = %Time
var _t := 0.0

func _ready() -> void:
	_root.visible = false

func _on_encounter_ended(won: bool) -> void:
	if won:
		return
	var timer := get_node_or_null("../LevelTimer") as LevelTimer
	if timer:
		_time.text = "Time  " + LevelTimer.format_time(timer.get_elapsed())
	await get_tree().create_timer(death_anim_delay).timeout
	_root.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_t += delta * rot_speed
	_apple.rotation_degrees = sin(_t * max_angle) * min_angle
	var s = 1.0 + sin(_t * 6.0) * 0.05
	_apple.scale = Vector2.ONE * s
