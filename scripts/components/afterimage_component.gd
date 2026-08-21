extends Node
class_name AfterimageComponent

@export var affecting: SpriteBase3D
@export var container: Node3D

@export var is_enabled := true
@export var frame_rate := 1.0
@export var color: Color
@export var duration := 1.0

signal enabled()
signal disabled()
signal afterimage_created(sprite: Sprite3D)
signal afterimage_destroying(sprite: Sprite3D)

var _active: Array[Sprite3D] = []

var _to_next := 0.0

func _process(delta: float) -> void:
	if not is_enabled or not affecting or not container: return
	_to_next += delta * frame_rate
	print(_to_next)
	if _to_next >= 1.0:
		create_afterimage()
		_to_next -= 1.0

func enable() -> void:
	if is_enabled: return
	is_enabled = true
	enabled.emit()

func disable() -> void:
	if not is_enabled: return
	is_enabled = false
	disabled.emit()

func create_afterimage() -> Sprite3D:
	var sprite := _duplicate_sprite()
	sprite.modulate = color
	container.add_child(sprite)
	_active.append(sprite)
	afterimage_created.emit(sprite)
	get_tree().create_timer(duration).timeout.connect(
		func():
			if not is_instance_valid(sprite): return
			afterimage_destroying.emit(sprite)
			_active.erase(sprite)
			sprite.queue_free()
	)
	return sprite

func _duplicate_sprite() -> Sprite3D:
	var sprite: Sprite3D
	if affecting is AnimatedSprite3D:
		var ani := affecting as AnimatedSprite3D
		sprite = Sprite3D.new()
		var animation := ani.animation
		var frame := ani.frame
		var tex := ani.sprite_frames.get_frame_texture(animation, frame)
		sprite.texture = tex
		sprite.global_transform = affecting.global_transform
		sprite.pixel_size = affecting.pixel_size
	elif affecting is Sprite3D:
		sprite = affecting.duplicate()
	return sprite

func clear() -> void:
	for s in _active:
		if is_instance_valid(s): s.queue_free()
	_active = []
