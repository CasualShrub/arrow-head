extends Camera3D
class_name PlayerCamera

@export var height := 5.0:
	set(value):
		height = value
		position.y = height
@export_group("lookahead")
@export var max_lookahead_offset := 5.0
@export var lookahead_strength := 0.25
@export var lookahead_smoothing := 6.0
@export_group("shake")
@export var sector_hit_trauma := 0.4
@export var trauma_decay := 1.5   
@export var max_shake_offset := 0.30

signal shaken(strength: float)

var _current_lookahead := Vector3.ZERO
var _target_lookahead := Vector3.ZERO

func _process(delta: float) -> void:
	_current_lookahead = _current_lookahead.lerp(
		_target_lookahead,
		1.0 - exp(-lookahead_smoothing * delta)
	)
	
	position = Vector3(
		_current_lookahead.x,
		height,
		_current_lookahead.z
	)
	#var shake := 0.0
	#if _trauma > 0.0:
		#_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
		#shake = _trauma * _trauma   # quadratic falloff feels punchier
	#var jitter := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	#global_position = _base_pos + jitter * shake * max_shake_offset

func set_lookahead(offset: Vector3) -> void:
	offset.y = 0.0
	if offset.length_squared() > max_lookahead_offset * max_lookahead_offset:
		offset = offset.normalized() * max_lookahead_offset
	_target_lookahead = offset

func shake() -> void:
	shaken.emit()

func get_mouse_position() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := project_ray_origin(mouse)
	var dir := project_ray_normal(mouse)

	if abs(dir.y) < 0.001:
		return Vector3.ZERO

	var distance := -origin.y / dir.y
	return origin + dir * distance
	
	# more general
	#var mouse = get_viewport().get_mouse_position()
#
	#var origin = project_ray_origin(mouse)
	#var dir = project_ray_normal(mouse)
#
	#var query = PhysicsRayQueryParameters3D.new()
	#query.from = origin
	#query.to = origin + dir * 2000.0
	#query.collision_mask = collision_mask
#
	#var result = get_world_3d().direct_space_state.intersect_ray(query)
#
	#if result.is_empty():
		#return Vector3.ZERO
#
	#return result.position as Vector3
	
