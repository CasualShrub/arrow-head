extends Node3D

@export var orbit_speed: float = 1.5

@onready var _pivot: Node3D = $Pivot


func _process(delta: float) -> void:
	_pivot.rotate_y(orbit_speed * delta)
