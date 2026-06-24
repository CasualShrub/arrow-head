extends Node
class_name MovementComponent

@export var speed := 1.0

var _parent: Arrow

func _spawn(vel: Vector3) -> Vector3:
	return vel

func _tick(vel: Vector3, _dt: float) -> Vector3:
	return vel.normalized() * speed

func initialize(parent) -> void:
	_parent = parent
