extends Node3D

@export var player: Player

@export var height := 5.0
@export_group("lookahead")
@export var lookahead_smoothing := 6.0
@export var mouse_lookahead_distance := 0.25
@export var movement_lookahead_distance := 0.5
@export var max_mouse_distance := 5.0
@export var follow_speed := 10.0

var current_offset := Vector3.ZERO
var last_move_direction := Vector3.FORWARD

func _physics_process(delta: float) -> void:
	if not player: return
	var mouse_offset := player.get_mouse_world_position() - player.global_position
	mouse_offset.y = 0
	
	var strength := clampf(
		mouse_offset.length() / max_mouse_distance, 0.0, 1.0
	)
	strength *= strength
	
	var lookahead_offset := mouse_offset.normalized() * strength * mouse_lookahead_distance
	var movement_offset := player.velocity.normalized() * movement_lookahead_distance
	var height_offset := height * Vector3.UP
	
	var target_offset := lookahead_offset + movement_offset + height_offset
	global_position = global_position.lerp(player.global_position + target_offset, follow_speed * delta)
	
func _ready() -> void:
	if not player: player = %Player
