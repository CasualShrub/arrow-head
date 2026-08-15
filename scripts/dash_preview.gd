extends Node3D
class_name DashPreview

@export var color := Color(0.2, 0.8, 1.0, 0.502)
@export var highlight_color := Color(1.0, 0.2, 0.2, 1.0)
@export var body_texture: Texture
@export var eyes_texture: Texture

@onready var _sprite: Sprite3D = $PreviewSprite
@onready var _eyes_sprite: Sprite3D = $PreviewSprite/PreviewEyes
@onready var _line: MeshInstance3D = $PreviewLine

signal enabled()
signal disabled()
signal position_changed(new_pos: Vector3)
signal target_added(target: HighlightComponent)
signal target_removed(target: HighlightComponent)

var _enabled := false
var _targets := Set.new()

func _ready() -> void:
	if body_texture:
		_sprite.texture = body_texture
	if eyes_texture:
		_eyes_sprite.texture = eyes_texture
	_sprite.modulate = color
	_line.material_override.color = color

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

func _position_sprite(pos: Vector3) -> void:
	_sprite.position = pos
	var dir = global_position.direction_to(pos)
	_sprite.look_at(pos + dir)

func set_preview_position(target: Vector3) -> void:
	if not is_enabled(): return
	_draw_line(global_position, target)
	_position_sprite(target)
	position_changed.emit(target)

func is_targeting(target: HighlightComponent) -> bool:
	return _targets.has(target)

func add_target(target: HighlightComponent) -> bool:
	if is_targeting(target): return false
	target.enable(highlight_color)
	_targets.add(target)
	target_added.emit(target)
	return true

func remove_target(target: HighlightComponent) -> bool:
	if not is_targeting(target): return false
	_targets.remove(target)
	target.disable()
	target_removed.emit(target)
	return true

func set_preview_targets(newTargets: Array[HighlightComponent]) -> void:
	for t in _targets:
		remove_target(t)
	
	for t in newTargets:
		add_target(t)
