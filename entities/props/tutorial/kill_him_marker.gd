extends Node3D

@export var target: Enemy
@export var circle_frames: Array[Texture2D] = []
@export var circle_frame_time := 0.12
@export var arrow_bob_distance := 0.25
@export var arrow_step_time := 0.25

@onready var _circle: Sprite3D = $Circle
@onready var _arrows: Node3D = $Arrows

var _player: Player
var _shown := false
var _done := false
var _frame := 0
var _frame_timer := 0.0
var _time := 0.0
var _arrow_sprites: Array[Sprite3D] = []
var _arrow_base_z: Array[float] = []

func _ready() -> void:
	_collect_arrows()
	visible = false
	if target:
		target.health.died.connect(_on_target_died)

func _process(delta: float) -> void:
	_track_player()
	if not visible:
		return
	_animate_circle(delta)
	_animate_arrows(delta)

func _collect_arrows() -> void:
	for pivot in _arrows.get_children():
		for child in pivot.get_children():
			if child is Sprite3D:
				_arrow_sprites.append(child)
				_arrow_base_z.append(child.position.z)

func _track_player() -> void:
	var player := GameManager.player
	if player == _player:
		return
	if _player and is_instance_valid(_player):
		_player.arrows.filled.disconnect(_on_filled)
		_player.arrows.emptied.disconnect(_on_emptied)
	_player = player
	if not _player:
		return
	_player.arrows.filled.connect(_on_filled)
	_player.arrows.emptied.connect(_on_emptied)
	if _player.arrows.is_full():
		_on_filled()

func _animate_circle(delta: float) -> void:
	if circle_frames.is_empty():
		return
	_frame_timer += delta
	if _frame_timer < circle_frame_time:
		return
	_frame_timer = 0.0
	_frame = (_frame + 1) % circle_frames.size()
	_circle.texture = circle_frames[_frame]

func _animate_arrows(delta: float) -> void:
	_time += delta
	var offset := 0.0
	if int(_time / arrow_step_time) % 2 == 1:
		offset = arrow_bob_distance
	for i in range(_arrow_sprites.size()):
		_arrow_sprites[i].position.z = _arrow_base_z[i] - offset

func show_marker() -> void:
	if _shown or _done:
		return
	_shown = true
	_time = 0.0
	visible = true

func hide_marker() -> void:
	if not _shown:
		return
	_shown = false
	visible = false

func _on_filled() -> void:
	show_marker()

func _on_emptied() -> void:
	hide_marker()

func _on_target_died() -> void:
	_done = true
	hide_marker()
