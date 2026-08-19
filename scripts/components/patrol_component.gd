extends Node
class_name PatrolComponent

@export var path: PatrolPath
@export var loop := false

func _init() -> void:
	assert(path, "PatrolComponent needs PatrolPath.")

func progress(distance: float) -> void:
	pass
