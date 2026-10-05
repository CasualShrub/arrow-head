extends Status
class_name StatusSlow

@export_range(0.05, 1.0) var speed_multiplier := 0.5
@export var screen_effect: ScreenEffect = preload("res://systems/screen_effect/slow_vignette.tres")

var _effect_handle: ScreenEffectHandle

func _init() -> void:
	lifetime = 3.0

func apply(target: Player) -> void:
	super(target)
	target.speed_multiplier = speed_multiplier
	if screen_effect:
		_effect_handle = ScreenEffectManager.play(screen_effect)

func remove() -> void:
	if is_instance_valid(owner):
		owner.speed_multiplier = 1.0
	ScreenEffectManager.stop(_effect_handle)
	_effect_handle = null
