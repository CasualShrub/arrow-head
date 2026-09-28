@tool
extends Area3D
class_name EntranceArea

@export var size := Vector3(3, 2.5, 2):
	set(value):
		size = value
		_apply_size()

func _ready() -> void:
	_apply_size()
	monitoring = false
	monitorable = false

func get_entry_direction() -> Vector3:
	var forward := -global_basis.z
	return Vector3(forward.x, 0, forward.z).normalized()

func _apply_size() -> void:
	var shape_node := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape_node and shape_node.shape is BoxShape3D:
		shape_node.shape.size = size
