extends Resource
class_name ArrowPattern

@export var weight: float = 1.0
@export var recovery: float = 0.0
@export_group("lists")
@export var has_movement_pattern: bool = false
@export var movement_pattern: Dictionary[float, Vector2] = {}
@export var instances: Array[FiringInstance] = []
