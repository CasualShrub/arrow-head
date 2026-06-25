extends CanvasLayer

@export var min_angle := 4.0
@export var max_angle := 5.0
@export var rot_speed := 0.2

@onready var _root: Control = %Root
@onready var _apple: TextureRect = %Apple
var _t := 0.0

var _next_scene = "res://scenes/levels/level_1.tscn"

func _ready() -> void:
	_root.visible = false

func _on_encounter_cleared(won: bool, next_scene: String) -> void:
	_root.visible = true
	_next_scene = next_scene

func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		get_tree().change_scene_to_file(_next_scene)

func _process(delta: float) -> void:
	_t += delta * rot_speed
	_apple.rotation_degrees = sin(_t * max_angle) * min_angle
	var s = 1.0 + sin(_t * 6.0) * 0.05
	_apple.scale = Vector2.ONE * s
