extends Resource
class_name FiringInstance

@export_group("general")
@export var type: PackedScene = null
@export_range(0.0, 1.0) var probability: float = 1.0
@export_group("delay")
@export var starting_delay: float = 0.0
@export var max_starting_delay: float = 0.0
@export var instance_delay: float = 0.0
@export var max_instance_delay: float = 0.0
@export_group("volley")
@export var count: int = 1
@export var max_count: int = 0
@export_range(0.0, TAU) var spread: float = 0.0
@export_range(0.0, TAU) var max_spread := 0.0
@export_range(-PI, PI) var offset: float = 0.0
@export_range(-PI, PI) var max_offset: float = -PI
