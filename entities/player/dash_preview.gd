extends Node3D
class_name DashPreview

@export var color := Color(0.2, 0.8, 1.0, 0.502)
@export var highlight_color := Color(1.0, 0.2, 0.2, 1.0)
@export var max_range := 5.0:
	set(value):
		max_range = value
		_update_max_range()
@export var body_texture: Texture
@export var eyes_texture: Texture

@onready var _sprite: Sprite3D = %PreviewSprite
@onready var _eyes_sprite: Sprite3D = %PreviewEyes
@onready var _line: MeshInstance3D = %PreviewLine
@onready var _range: MeshInstance3D = %Range

signal enabled()
signal disabled()
signal position_changed(new_pos: Vector3)
signal target_added(target: TargetArea)
signal target_removed(target: TargetArea)

var _targets := Set.new()

@onready var _enabled := visible

func _ready() -> void:
	if body_texture:
		_sprite.texture = body_texture
	if eyes_texture:
		_eyes_sprite.texture = eyes_texture
	_sprite.modulate = color
	_line.material_override.albedo_color = color
	_update_max_range()

func is_enabled() -> bool:
	return _enabled

func enable() -> void:
	if is_enabled(): return
	_enabled = true
	show()
	enabled.emit()
	
func disable() -> void:
	if not is_enabled(): return
	_enabled = false
	hide()
	disabled.emit()

func _draw_line(start: Vector3, end: Vector3) -> void:
	_line.global_position = start.lerp(end, 0.5)
	_line.look_at(end, Vector3.UP)
	
	var mesh := _line.mesh as PlaneMesh
	mesh.size.y = start.distance_to(end)

func _position_sprite(at: Vector3) -> void:
	_sprite.global_position = at

func set_preview_position(target: Vector3) -> void:
	if not is_enabled(): return
	_draw_line(global_position, target)
	_position_sprite(target)
	position_changed.emit(target)

func is_targeting(target: TargetArea) -> bool:
	return _targets.has(target)

func add_target(target: TargetArea) -> bool:
	if is_targeting(target): return false
	target.mark_targeted()
	_targets.add(target)
	target_added.emit(target)
	return true

func remove_target(target: TargetArea) -> bool:
	if not is_targeting(target): return false
	_targets.remove(target)
	target.mark_untargeted()
	target_removed.emit(target)
	return true

func set_preview_targets(newTargets: Array[TargetArea]) -> void:
	for t in _targets.to_array():
		remove_target(t)
	
	for t in newTargets:
		add_target(t)

func _update_max_range() -> void:
	if not _range: return
	_range.scale = Vector3(max_range, 1, max_range)
