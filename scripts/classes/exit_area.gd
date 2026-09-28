@tool
extends Area3D
class_name ExitArea

signal player_entered()
signal locked_changed(is_locked: bool)

@export var size := Vector3(3, 2.5, 2):
	set(value):
		size = value
		_apply_size()

var _locked := true

func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint(): return
	body_entered.connect(_on_body_entered)

func is_locked() -> bool:
	return _locked

func lock() -> void:
	if _locked: return
	_locked = true
	locked_changed.emit(true)

func unlock() -> void:
	if not _locked: return
	_locked = false
	locked_changed.emit(false)
	for body in get_overlapping_bodies():
		if body is Player:
			player_entered.emit()
			return

func get_exit_direction() -> Vector3:
	var forward := -global_basis.z
	return Vector3(forward.x, 0, forward.z).normalized()

func _on_body_entered(body: Node3D) -> void:
	if _locked: return
	if body is Player:
		player_entered.emit()

func _apply_size() -> void:
	var shape_node := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape_node and shape_node.shape is BoxShape3D:
		shape_node.shape.size = size
