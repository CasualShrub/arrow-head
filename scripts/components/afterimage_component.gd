extends Node
class_name AfterimageComponent

const MIX_SHADER = preload("res://shaders/mix.gdshader")

@export var affecting: Array[SpriteBase3D]
@export var container: Node3D

@export var is_enabled := true
@export var frame_rate := 1.0
@export var color := Color(1.0, 0.2, 0.2, 0.5)
@export var duration := 1.0

signal enabled()
signal disabled()
signal afterimage_created(sprite: Node3D)
signal afterimage_destroying(sprite: Node3D)

var _active: Array[Node3D] = []

var _to_next := 0.0

func _process(delta: float) -> void:
	if not is_enabled or not affecting or not container: return
	_to_next += delta * frame_rate
	print(_to_next)
	if _to_next >= 1.0:
		create_afterimages()
		_to_next -= 1.0

func enable() -> void:
	if is_enabled: return
	is_enabled = true
	enabled.emit()

func disable() -> void:
	if not is_enabled: return
	is_enabled = false
	disabled.emit()

func create_afterimages() -> Array[Node3D]:
	var afterimages: Array[Node3D] = []
	for s in affecting:
		afterimages.append(create_afterimage(s))
	return afterimages

func create_afterimage(base: SpriteBase3D) -> Node3D:
	var sprite := _duplicate_sprite(base)
	container.add_child(sprite)
	_active.append(sprite)
	afterimage_created.emit(sprite)
	return sprite

func _duplicate_sprite(base: SpriteBase3D) -> Node3D:
	var texture := _get_current_texture(base)
	
	var sprite := Sprite3D.new()
	sprite.pixel_size = base.pixel_size
	sprite.texture = texture
	sprite.render_priority = base.render_priority - 1
	sprite.global_transform = base.global_transform
	sprite.visible = base.visible
	
	var mat := ShaderMaterial.new()
	mat.render_priority = base.render_priority - 1
	mat.shader = MIX_SHADER
	mat.set_shader_parameter("albedo_texture", texture)
	mat.set_shader_parameter("strength", 1.0)
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("opacity", 1.0)
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(value: float):
			mat.set_shader_parameter("opacity", value),
		1.0,
		0.0,
		duration
	)
	
	tween.finished.connect(func():
		if is_instance_valid(sprite):
			afterimage_destroying.emit(sprite)
			_active.erase(sprite)
			sprite.queue_free()
	)

	sprite.material_override = mat
	
	return sprite

func _get_current_texture(sprite: SpriteBase3D) -> CompressedTexture2D:
	if sprite is Sprite3D: return sprite.texture
	elif sprite is AnimatedSprite3D:
		var animation := (sprite as AnimatedSprite3D).animation
		var frame := (sprite as AnimatedSprite3D).frame
		return sprite.sprite_frames.get_frame_texture(animation, frame)
	else:
		return null

func clear() -> void:
	for s in _active:
		if is_instance_valid(s): s.queue_free()
	_active = []
