extends Node

@export var pool_size := 500

var _pool: Dictionary[PackedScene, Array] = {}

func _consume_pool(scene: PackedScene) -> Variant:
	var scene_pool = _pool[scene]
	if not scene_pool: return null
	return scene_pool.pop_front()

func pool(arrow: Arrow) -> void:
	pass

func make_arrow(scene: PackedScene) -> Variant:
	var pooled = _consume_pool(scene)
	if not pooled:
		return
	return scene.instantiate()
