extends Node
class_name PatrolComponent

@export var path: PatrolPath
@export var speed := 5.0

func _init() -> void:
	assert(path, "PatrolComponent needs PatrolPath.")

func progress(distance: float) -> void:
	pass
