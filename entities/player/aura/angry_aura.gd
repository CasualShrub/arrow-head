extends Node3D
class_name AngryAura

@export var fade_time := 0.2

@onready var _arc: AnimatedSprite3D = %ArcA
@onready var _vignette: ColorRect = %VignetteRect

var _active := false
var _tween: Tween

func _ready() -> void:
	_arc.play(&"flicker")
	_set_alpha(0.0)
	hide()

func is_active() -> bool:
	return _active

func activate() -> void:
	if _active: return
	_active = true
	show()
	_fade_to(1.0)

func deactivate() -> void:
	if not _active: return
	_active = false
	_fade_to(0.0)

func deactivate_instantly() -> void:
	_active = false
	if _tween: _tween.kill()
	_set_alpha(0.0)
	hide()

func _fade_to(alpha: float) -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_alpha, _arc.modulate.a, alpha, fade_time)
	if alpha == 0.0:
		_tween.tween_callback(hide)

func _set_alpha(alpha: float) -> void:
	_arc.modulate.a = alpha
	(_vignette.material as ShaderMaterial).set_shader_parameter(&"intensity", alpha)
