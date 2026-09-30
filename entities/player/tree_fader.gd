extends Node
class_name TreeFader

@export var faded_transparency := 0.65
@export var fade_speed := 8.0
@export var target_height := 0.5

var _camera: Camera3D
var _fading: Dictionary = {}

func _ready() -> void:
	_camera = get_parent() as Camera3D

func _process(delta: float) -> void:
	var blocking := _find_blocking_trees()

	for tree in blocking:
		if not _fading.has(tree):
			_fading[tree] = 0.0

	var step := 1.0 - exp(-fade_speed * delta)
	for tree in _fading.keys():
		if not is_instance_valid(tree):
			_fading.erase(tree)
			continue
		var mesh := tree.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null:
			_fading.erase(tree)
			continue
		var goal := 0.0
		if blocking.has(tree):
			goal = faded_transparency
		var value: float = lerpf(_fading[tree], goal, step)
		if goal == 0.0 and value < 0.01:
			mesh.transparency = 0.0
			_fading.erase(tree)
			continue
		_fading[tree] = value
		mesh.transparency = value

func _find_blocking_trees() -> Array:
	var blocking: Array = []
	var trees := get_tree().get_nodes_in_group("fadeable")
	if trees.is_empty():
		return blocking

	var from := _camera.global_position
	for enemy in get_tree().get_nodes_in_group("tree_fade_targets"):
		var to: Vector3 = enemy.global_position + Vector3.UP * target_height
		for tree in trees:
			if blocking.has(tree):
				continue
			var mesh := tree.get_node_or_null("Mesh") as MeshInstance3D
			if mesh == null:
				continue
			var box := mesh.global_transform * mesh.get_aabb()
			if box.intersects_segment(from, to) != null:
				blocking.append(tree)
	return blocking
