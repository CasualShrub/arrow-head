extends Status
class_name StatusFreeze

@export var warn_time := 0.6
@export var blink_rate := 12.0

func _init() -> void:
	lifetime = 2.0

func apply(target: Player) -> void:
	#_sprite.modulate = Color(0.6, 0.85, 1)
	pass
