extends Camera3D
class_name PlayerCamera

@export var height := 5.0:
	set(value):
		position = position + Vector3(0, height, 0)
		height = value
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

signal shaken(amount: float)

var current_offset := Vector3.ZERO
var last_move_direction := Vector3.FORWARD

var _last_pos := Vector3.ZERO

var _trauma := 0.0


func _ready() -> void:
	_last_pos = global_position

func _physics_process(delta: float) -> void:
	var mouse_pos := get_mouse_position()
	mouse_pos.y = 0
	
	var p := get_parent_node_3d()
	var mouse_offset := p.to_local(global_position)

	var strength := clampf(
		mouse_offset.length() / max_mouse_distance, 0.0, 1.0
	)
	strength *= strength

	var lookahead_offset := mouse_offset.normalized() * strength * mouse_lookahead_distance
	#var movement_offset := player.velocity.normalized() * movement_lookahead_distance
	var height_offset := height * Vector3.UP

	var target := global_position + lookahead_offset + height_offset# + movement_offset
	global_position = _last_pos.lerp(target, follow_speed * delta)

	#var shake := 0.0
	#if _trauma > 0.0:
		#_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
		#shake = _trauma * _trauma   # quadratic falloff feels punchier
	#var jitter := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	#global_position = _base_pos + jitter * shake * max_shake_offset
	_last_pos = global_position

func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func _on_player_hit(_arrow: Arrow, _sector: int) -> void:
	add_shake(sector_hit_trauma)

func shake() -> void:
	shaken.emit()

func get_mouse_position(collision_mask: int = 1 << 4) -> Vector3:
	var mouse = get_viewport().get_mouse_position()

	var origin = project_ray_origin(mouse)
	var dir = project_ray_normal(mouse)

	var query = PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + dir * 2000.0
	query.collision_mask = collision_mask

	var result = get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return Vector3.ZERO

	return result.position as Vector3
