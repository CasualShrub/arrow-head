extends Node3D
class_name FallingLeaves

@export var textures: Array[Texture2D] = []
@export var spawn_interval := Vector2(0.7, 2.0)
@export var initial_count := 5
@export var speed_range := Vector2(1.0, 2.2)
@export var angle_range_degrees := Vector2(15.0, 65.0)
@export var height_range := Vector2(3.0, 7.0)
@export var fall_speed_range := Vector2(0.02, 0.1)
@export var pixel_size_range := Vector2(0.0003, 0.0006)
@export var spin_range := Vector2(-0.6, 0.6)
@export var tilt_range_degrees := Vector2(15.0, 40.0)
@export var flutter_range_degrees := Vector2(8.0, 25.0)
@export var wind_strength := 0.6
@export var wind_frequency := 0.35
@export var sway_amplitude := Vector2(0.1, 0.3)
@export var sway_frequency := Vector2(0.8, 2.0)
@export var alpha_range := Vector2(0.65, 0.95)
@export var max_leaves := 14
@export var spawn_margin := 0.8
@export var cull_distance := 10.0
@export var max_lifetime := 45.0

class Leaf:
	var sprite: Sprite3D
	var velocity: Vector3
	var spin: float
	var base_rotation: float
	var tilt: float
	var flutter: float
	var sway_amp: float
	var sway_freq: float
	var sway_phase: float
	var age := 0.0

var _leaves: Array[Leaf] = []
var _spawn_timer := 0.0
var _time := 0.0
var _initialized := false

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	if not _initialized:
		_initialized = true
		for i in initial_count:
			_spawn_leaf(camera, true)
		_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)
	_time += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)
		if _leaves.size() < max_leaves:
			_spawn_leaf(camera, false)
	_update_leaves(camera, delta)

func _view_half_extents(camera: Camera3D, height: float) -> Vector2:
	var distance := maxf(camera.global_position.y - height, 0.1)
	var half_height := tan(deg_to_rad(camera.fov) * 0.5) * distance
	var view_size := get_viewport().get_visible_rect().size
	return Vector2(half_height * view_size.x / view_size.y, half_height)

func _spawn_leaf(camera: Camera3D, inside_view: bool) -> void:
	if textures.is_empty():
		return
	var height := randf_range(height_range.x, height_range.y)
	var half := _view_half_extents(camera, height)
	var center := Vector2(camera.global_position.x, camera.global_position.z)
	var sprite := Sprite3D.new()
	sprite.texture = textures.pick_random()
	sprite.axis = Vector3.AXIS_Y
	sprite.pixel_size = randf_range(pixel_size_range.x, pixel_size_range.y)
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 100
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.modulate.a = randf_range(alpha_range.x, alpha_range.y)
	var ground_position: Vector2
	if inside_view:
		ground_position = center + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
	else:
		ground_position = _random_entry_point(center, half)
	add_child(sprite)
	sprite.global_position = Vector3(ground_position.x, height, ground_position.y)
	var leaf := Leaf.new()
	var angle := deg_to_rad(randf_range(angle_range_degrees.x, angle_range_degrees.y))
	var speed := randf_range(speed_range.x, speed_range.y)
	leaf.sprite = sprite
	leaf.velocity = Vector3(cos(angle) * speed, -randf_range(fall_speed_range.x, fall_speed_range.y), sin(angle) * speed)
	leaf.spin = randf_range(spin_range.x, spin_range.y)
	leaf.base_rotation = randf() * TAU
	leaf.tilt = deg_to_rad(randf_range(tilt_range_degrees.x, tilt_range_degrees.y))
	leaf.flutter = deg_to_rad(randf_range(flutter_range_degrees.x, flutter_range_degrees.y))
	leaf.sway_amp = randf_range(sway_amplitude.x, sway_amplitude.y)
	leaf.sway_freq = randf_range(sway_frequency.x, sway_frequency.y)
	leaf.sway_phase = randf() * TAU
	_leaves.append(leaf)

func _random_entry_point(center: Vector2, half: Vector2) -> Vector2:
	var top_length := 2.0 * half.x + spawn_margin
	var left_length := 2.0 * half.y + spawn_margin
	if randf() * (top_length + left_length) < top_length:
		return Vector2(center.x + randf_range(-half.x - spawn_margin, half.x), center.y - half.y - spawn_margin)
	return Vector2(center.x - half.x - spawn_margin, center.y + randf_range(-half.y - spawn_margin, half.y))

func _update_leaves(camera: Camera3D, delta: float) -> void:
	var center := Vector2(camera.global_position.x, camera.global_position.z)
	for i in range(_leaves.size() - 1, -1, -1):
		var leaf := _leaves[i]
		leaf.age += delta
		var position := leaf.sprite.global_position
		var planar_velocity := Vector2(leaf.velocity.x, leaf.velocity.z)
		var perpendicular := Vector2(-planar_velocity.y, planar_velocity.x).normalized()
		var sway := cos(leaf.age * leaf.sway_freq + leaf.sway_phase) * leaf.sway_amp * leaf.sway_freq
		var gust := sin(_time * wind_frequency * TAU + position.z * 0.3)
		var drift := planar_velocity + perpendicular * sway + Vector2(gust * wind_strength, 0.0)
		leaf.sprite.global_position = position + Vector3(drift.x, leaf.velocity.y, drift.y) * delta
		leaf.base_rotation += leaf.spin * delta
		var rock := sin(leaf.age * leaf.sway_freq + leaf.sway_phase + PI * 0.5)
		var flutter_x := sin(leaf.age * leaf.sway_freq * 1.3 + leaf.sway_phase)
		var flutter_z := cos(leaf.age * leaf.sway_freq * 0.9 + leaf.sway_phase)
		leaf.sprite.rotation = Vector3(flutter_x * leaf.flutter, leaf.base_rotation + rock * leaf.tilt + gust * 0.15, flutter_z * leaf.flutter)
		var half := _view_half_extents(camera, position.y)
		var offset := Vector2(position.x, position.z) - center
		var passed_view := offset.x > half.x + spawn_margin or offset.y > half.y + spawn_margin
		var left_behind := offset.length() > cull_distance + maxf(half.x, half.y)
		if passed_view or left_behind or leaf.age > max_lifetime:
			leaf.sprite.queue_free()
			_leaves.remove_at(i)
