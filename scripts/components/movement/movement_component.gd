extends Node
class_name MovementComponent

@export var target_speed := 1.0

var _parent: Arrow

func _spawn(_speed: float, dir: Vector3) -> Vector4:
	return Vector4(dir.x, dir.y, dir.z, target_speed)

func _tick(speed: float, dir: Vector3, _dt: float) -> Vector4:
	return Vector4(dir.x, dir.y, dir.z, speed)

func initialize(parent) -> void:
	_parent = parent
