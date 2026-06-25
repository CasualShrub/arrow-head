extends Node3D

@export var player: Player

@export var height := 5.0
@export_group("lookahead")
@export var lookahead_smoothing := 6.0
@export var mouse_lookahead_distance := 0.25
@export var movement_lookahead_distance := 0.5
@export var max_mouse_distance := 5.0
@export var follow_speed := 10.0
@export_group("shake")
@export var sector_hit_trauma := 0.4
@export var trauma_decay := 1.5   
@export var max_shake_offset := 0.30

var current_offset := Vector3.ZERO
var last_move_direction := Vector3.FORWARD

var _base_pos := Vector3.ZERO
var _has_base := false
var _trauma := 0.0

var _is_focused := false
var _focused := Vector3()

func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func _on_player_hit(_arrow: Arrow, _sector: int) -> void:
	add_shake(sector_hit_trauma)

func focus(pos) -> void:
	_is_focused = true
	_focused = pos
	
func unfocus() -> void:
	_is_focused = false

func _physics_process(delta: float) -> void:
	if not player: return
	if _is_focused:
		global_position = _focused + height * Vector3.UP
		return
	var mouse_offset := player.get_mouse_world_position() - player.global_position
	mouse_offset.y = 0

	var strength := clampf(
		mouse_offset.length() / max_mouse_distance, 0.0, 1.0
	)
	strength *= strength

	var lookahead_offset := mouse_offset.normalized() * strength * mouse_lookahead_distance
	var movement_offset := player.velocity.normalized() * movement_lookahead_distance
	var height_offset := height * Vector3.UP

	var target := player.global_position + lookahead_offset + movement_offset + height_offset
	if not _has_base:
		_base_pos = global_position
		_has_base = true
	_base_pos = _base_pos.lerp(target, follow_speed * delta)

	var shake := 0.0
	if _trauma > 0.0:
		_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
		shake = _trauma * _trauma   # quadratic falloff feels punchier
	var jitter := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	global_position = _base_pos + jitter * shake * max_shake_offset

func _ready() -> void:
	if not player: player = %Player
	if player and not player.hit.is_connected(_on_player_hit):
		player.hit.connect(_on_player_hit)
