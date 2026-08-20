extends Node
class_name PatrolComponent

@export var path: PatrolPath
@export var speed := 5.0

var _dist := 0.0

func _init() -> void:
	assert(path, "%s needs PatrolPath." % get_path())

func get_patrol_position() -> Vector3:
	return path.get_position_at_distance_along(_dist)

func progress(distance: float) -> void:
	_dist += distance

func tick(delta: float) -> void:
	progress(speed * delta)
