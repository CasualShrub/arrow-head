extends Node
class_name PatrolComponent

@export var path: PatrolPath
@export var speed := 5.0

var _dist := 0.0

func has_path() -> bool:
	return path != null

func get_patrol_position() -> Vector3:
	if not has_path(): return Vector3.ZERO
	return path.get_position_at_distance_along(_dist)

func progress(distance: float) -> void:
	_dist += distance

func tick(delta: float) -> void:
	if not has_path(): return
	progress(speed * delta)
