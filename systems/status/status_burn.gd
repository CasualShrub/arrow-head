extends Status
class_name StatusBurn

@export var spin_speed := 24.0
@export var drift_speed := 7.2
@export var redrift := 0.14

var spin_dir := -1

func _init() -> void:
	lifetime = 2.5

func apply(target: Player) -> void:
	#_sprite.modulate = Color(1, 0.5, 0.2)
	pass

func tick(delta: float) -> void:
	_spin(delta)

func _spin(delta: float) -> void:
	#_face_dir(global_position + get_facing().rotated(Vector3.UP, spin_speed * spin_dir * delta))
	pass
