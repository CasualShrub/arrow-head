@tool
extends Area3D
class_name OutskirtFiller
#made this to  procedurally spawn stuff to fill the outside of our levels

@export var border_size := Vector2(38.59, 23.07):
	set(value):
		border_size = value
		_apply_border_size()
		_queue_rebuild()
@export var items: Array[PackedScene] = []:
	set(value):
		items = value
		_queue_rebuild()
@export var lay_flat := true:
	set(value):
		lay_flat = value
		_queue_rebuild()
@export var sprite_textures: Array[Texture2D] = []:
	set(value):
		sprite_textures = value
		_queue_rebuild()
@export var band_depth := 11.0:
	set(value):
		band_depth = value
		_queue_rebuild()
@export var spacing := 3.1:
	set(value):
		spacing = maxf(0.5, value)
		_queue_rebuild()
@export var position_jitter := 0.55:
	set(value):
		position_jitter = value
		_queue_rebuild()
@export var scale_min := 0.8:
	set(value):
		scale_min = value
		_queue_rebuild()
@export var scale_max := 1.15:
	set(value):
		scale_max = value
		_queue_rebuild()
@export var random_flip := true:
	set(value):
		random_flip = value
		_queue_rebuild()
@export var y_base := 0.05:
	set(value):
		y_base = value
		_queue_rebuild()
@export var y_slope := 0.015:
	set(value):
		y_slope = value
		_queue_rebuild()
@export var rng_seed := 67:
	set(value):
		rng_seed = value
		_queue_rebuild()

@export var is_circle := false:
	set(value):
		is_circle = value
		_queue_rebuild()

var _container: Node3D
var _last_border := Vector3.ZERO

func _ready() -> void:
	monitoring = false
	monitorable = false
	set_process(Engine.is_editor_hint())
	_apply_border_size()
	_rebuild()

func _process(_delta: float) -> void:
	var current_signature := _border_signature()
	if current_signature != _last_border:
		var border_shape := _get_border_shape()
		if border_shape != null:
			var box_shape := border_shape.shape as BoxShape3D
			border_size = Vector2(box_shape.size.x, box_shape.size.z)
		else:
			_rebuild()

func _queue_rebuild() -> void:
	if is_inside_tree():
		_rebuild()

func _get_border_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child
	return null

func _border_signature() -> Vector3:
	var border_shape := _get_border_shape()
	if border_shape == null:
		return Vector3.ZERO
	var box_shape := border_shape.shape as BoxShape3D
	return Vector3(box_shape.size.x, box_shape.size.z, border_shape.position.x + border_shape.position.z)

func _apply_border_size() -> void:
	var border_shape := _get_border_shape()
	if border_shape == null:
		return
	var box_shape := border_shape.shape as BoxShape3D
	box_shape.size = Vector3(border_size.x, box_shape.size.y, border_size.y)

func _grid_points(center: Vector2, half_width: float, half_depth: float, outer_width: float, outer_depth: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var grid_x := -outer_width
	while grid_x <= outer_width + 0.001:
		var grid_z := -outer_depth
		while grid_z <= outer_depth + 0.001:
			var offset_x := grid_x + rng.randf_range(-position_jitter, position_jitter)
			var offset_z := grid_z + rng.randf_range(-position_jitter, position_jitter)
			if absf(offset_x) > half_width or absf(offset_z) > half_depth:
				points.append(center + Vector2(offset_x, offset_z))
			grid_z += spacing
		grid_x += spacing
	return points

func _ring_points(center: Vector2, half_width: float, half_depth: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var ring_index := 0
	var ring_offset := spacing * 0.5
	while ring_offset <= band_depth + 0.001:
		var ring := _ellipse_polyline(half_width + ring_offset, half_depth + ring_offset, 256)
		var ring_length: float = ring[ring.size() - 1].z
		var count := maxi(3, roundi(ring_length / spacing))
		var step := ring_length / count
		var phase := step * (0.5 if ring_index % 2 == 1 else 0.0)
		var segment := 1
		for point_index in count:
			var target := phase + step * point_index
			while segment < ring.size() - 1 and ring[segment].z < target:
				segment += 1
			var from: Vector3 = ring[segment - 1]
			var to: Vector3 = ring[segment]
			var weight := (target - from.z) / maxf(to.z - from.z, 0.0001)
			var point := Vector2(from.x, from.y).lerp(Vector2(to.x, to.y), weight)
			point += Vector2(rng.randf_range(-position_jitter, position_jitter), rng.randf_range(-position_jitter, position_jitter))
			points.append(center + point)
		ring_offset += spacing
		ring_index += 1
	return points

func _ellipse_polyline(radius_x: float, radius_z: float, samples: int) -> Array[Vector3]:
	var polyline: Array[Vector3] = []
	var travelled := 0.0
	var previous := Vector2(radius_x, 0.0)
	for sample_index in samples + 1:
		var angle := TAU * sample_index / samples
		var current := Vector2(cos(angle) * radius_x, sin(angle) * radius_z)
		travelled += previous.distance_to(current)
		polyline.append(Vector3(current.x, current.y, travelled))
		previous = current
	return polyline

func _ensure_container() -> void:
	if is_instance_valid(_container):
		return
	for child in get_children():
		if child.name == "Scattered":
			_container = child
			return
	_container = Node3D.new()
	_container.name = "Scattered"
	add_child(_container)

func _rebuild() -> void:
	if not is_inside_tree() or items.is_empty():
		return
	var border_shape := _get_border_shape()
	if border_shape == null:
		return
	_last_border = _border_signature()

	var box_shape := border_shape.shape as BoxShape3D
	var center_x := border_shape.position.x
	var center_z := border_shape.position.z
	var half_width := box_shape.size.x * 0.5
	var half_depth := box_shape.size.z * 0.5
	var outer_width := half_width + band_depth
	var outer_depth := half_depth + band_depth

	_ensure_container()
	for child in _container.get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var center := Vector2(center_x, center_z)
	var spawn_points: Array[Vector2]
	if is_circle:
		spawn_points = _ring_points(center, half_width, half_depth, rng)
	else:
		spawn_points = _grid_points(center, half_width, half_depth, outer_width, outer_depth, rng)

	spawn_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)

	for point_index in spawn_points.size():
		var point := spawn_points[point_index]
		var item_scene: PackedScene = items[rng.randi() % items.size()]
		var instance := item_scene.instantiate() as Node3D
		_container.add_child(instance)
		if instance is Sprite3D and not sprite_textures.is_empty():
			(instance as Sprite3D).texture = sprite_textures[rng.randi() % sprite_textures.size()]
		var item_scale := rng.randf_range(scale_min, scale_max)
		var item_basis: Basis
		var item_y: float
		if lay_flat:
			var flipped_scale_x: float = -item_scale if (random_flip and rng.randf() < 0.5) else item_scale
			item_basis = Basis(Vector3(flipped_scale_x, 0, 0), Vector3(0, 0, item_scale), Vector3(0, -item_scale, 0))
			item_y = y_base + point.y * y_slope + float(point_index) * 0.0003
		else:
			item_basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(item_scale, item_scale, item_scale))
			item_y = y_base
		instance.transform = Transform3D(item_basis, Vector3(point.x, item_y, point.y))
