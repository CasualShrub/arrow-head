extends Node3D
class_name DashPreviewComponent

@export var color := Color(0.2, 0.8, 1.0, 0.502)
@export var highlight_color := Color(1.0, 0.2, 0.2, 1.0)
@export var width := 0.4
@export var cast_offset := 0.4

@onready var _dash_cast: RayCast3D = %DashCast
@onready var _sprite: Sprite3D = %PreviewSprite
@onready var _line: MeshInstance3D = %PreviewLine

@onready var _sprite_basis := _sprite.global_basis

const _ENEMY_LAYER := 1 << 3

var _highlighted: Array[Enemy] = []

func _update_sprite(pos: Vector3) -> void:
	_sprite.global_basis = _sprite_basis
	_sprite.global_position = pos

func _update_line(start: Vector3, end: Vector3) -> void:
	var direction = end - start
	var distance = direction.length()
	
	_line.global_position = start + direction / 2
	_line.mesh.size.y = distance
	_line.look_at(end, Vector3.UP)

func _update_highlight(new_targets: Array[Enemy]) -> void:
	for enemy in _highlighted:
		if not enemy in new_targets:
			enemy.highlight_off()
	
	for enemy in new_targets:
		if not enemy in _highlighted:
			enemy.highlight_on(highlight_color)
	_highlighted = new_targets

func get_enemies_in_path(start: Vector3, end: Vector3) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var seen := {}

	var shape = SphereShape3D.new()
	shape.radius = width

	var distance = start.distance_to(end)
	var steps = ceil(distance / 0.5)

	var space = get_world_3d().direct_space_state

	for i in range(steps + 1):
		var pos = start.lerp(end, float(i) / steps)

		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), pos)
		query.collision_mask = _ENEMY_LAYER

		for hit in space.intersect_shape(query):
			var enemy = hit.collider

			if enemy is Enemy and not seen.has(enemy):
				seen[enemy] = true
				result.append(enemy)
	return result

func get_end(target: Vector3) -> Vector3:
	var world_dir := global_position.direction_to(target)
	var dist := global_position.distance_to(target) + cast_offset
	_dash_cast.target_position = to_local(global_position + world_dir * dist)
	_dash_cast.force_raycast_update()
	if _dash_cast.is_colliding():
		var new_target := _dash_cast.get_collision_point()
		var new_dist := global_position.distance_to(new_target)
		new_dist -= cast_offset
		return global_position + global_position.direction_to(new_target) * new_dist
	else:
		return target

func update(start: Vector3, end: Vector3) -> void:
	end = get_end(end)
	_update_line(start, end)
	_update_sprite(end)
	var found := get_enemies_in_path(start, end)
	_update_highlight(found)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_highlight([])

func _ready() -> void:
	hide()
	_sprite.modulate = color
	_line.material_override.color = color
