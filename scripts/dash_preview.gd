extends Node3D
class_name DashPreview

@export var color := Color(0.2, 0.8, 1.0, 0.502)
@export var highlight_color := Color(1.0, 0.2, 0.2, 1.0)
@export var body_texture: Texture
@export var eyes_texture: Texture

@onready var _sprite: Sprite3D = $PreviewSprite
@onready var _eyes_sprite: Sprite3D = $PreviewSprite/PreviewEyes
@onready var _line: MeshInstance3D = $PreviewLine

const _ENEMY_LAYER := 1 << 3

var _targets: Array[HighlightComponent] = []

signal enabled()
signal disabled()
signal position_changed(new_pos: Vector3)

var _enabled := false

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
	_line.mesh.size.y = start.distance_to(end)
	_line.look_at(end, Vector3.UP)
	
func _position_sprite(pos: Vector3) -> void:
	_sprite.position = pos
	var dir = position.direction_to(pos)
	_sprite.look_at(pos + dir)

func update_preview_position(target: Vector3) -> void:
	if not is_enabled(): return
	_draw_line(global_position, target)
	_position_sprite(target)
	position_changed.emit(target)

func update_targets(newTargets: Array[HighlightComponent]) -> void:
	for h in _targets:
		if not h in _targets:
			h.disable()
			
	for h in newTargets:
		if not h in _targets:
			h.enable(highlight_color)
	_targets = newTargets

func _ready() -> void:
	if body_texture:
		_sprite.texture = body_texture
	if eyes_texture:
		_eyes_sprite.texture = eyes_texture
	_sprite.modulate = color
	_line.material_override.color = color
