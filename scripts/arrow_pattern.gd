extends Resource
class_name ArrowPattern

@export var weight: float = 1.0
@export var recovery: float = 0.0
@export var uses_windup := false
@export_group("movement")
@export var has_movement_pattern: bool = false
@export var movement_pattern: Dictionary[float, Vector2] = {}
@export_group("lists")
@export var instances: Array[FiringInstance] = []
@export var tile_map_pattern: TileMapPattern
