extends Node3D

@export var idle_color: Color = Color(0.55, 0.55, 0.55, 1.0)
@export var lit_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var fade_speed: float = 12.0

@onready var _keys: Dictionary[StringName, Sprite3D] = {
	&"move_up": $W,
	&"move_left": $A,
	&"move_down": $S,
	&"move_right": $D,
}

func _ready() -> void:
	for sprite: Sprite3D in _keys.values():
		sprite.modulate = idle_color


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-fade_speed * delta)
	for action: StringName in _keys:
		var sprite := _keys[action]
		var target := lit_color if Input.is_action_pressed(action) else idle_color
		sprite.modulate = sprite.modulate.lerp(target, weight)
