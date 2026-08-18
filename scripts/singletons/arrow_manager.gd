extends Node

@export var pool_size := 500

var _pooled := 0
var _pool: Dictionary[PackedScene, Array] = {}

func make_arrow(
	scene: PackedScene,
	at: Vector3,
	velocity: Vector3,
	target_mask: int
) -> Arrow:
	var consumed = _consume_pool(scene)
	if consumed: return consumed
	var arrow := scene.instantiate() as Arrow
	if not arrow:
		push_error("Instantiated invalid scene ${0}.".format(scene))
	arrow.deactivated.connect(pool.bind(arrow))
	arrow.activate(at, velocity, target_mask)
	return arrow

func _destroy_arrow(arrow: Arrow) -> void:
	arrow.queue_free()

func _consume_pool(scene: PackedScene) -> Variant:
	var scene_pool = _pool[scene]
	if not scene_pool: return null
	return scene_pool.pop_front()

func pool(arrow: Arrow) -> void:
	if not _pool[arrow.scene]:
		_pool[arrow.scene] = []
	_pool[arrow.scene].append(arrow)
	_pooled += 1
	if _pooled > pool_size:
		var largest: Array
		var largest_len := 0
		for scene in _pool:
			var curr_len := len(_pool[scene])
			if curr_len > largest_len:
				largest = _pool[scene]
				largest_len = curr_len
		_destroy_arrow(largest.pop_back())
		_pooled -= 1
