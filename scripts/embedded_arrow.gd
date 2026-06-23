extends Node
class_name EmbeddedArrow

var _arrow: Arrow
var _sector := 0
var _can_fire := false

func toggle_firing(can_fire: bool) -> void:
	_can_fire = can_fire
	
func is_firing_enabled() -> bool:
	return _can_fire
	
func get_sector() -> bool:
	return _sector
	
func change_sector(sector: int) -> void:
	_sector = sector
	
func get_arrow() -> Arrow:
	return _arrow

func grab() -> Arrow:
	queue_free()
	return get_arrow()

func _init(arrow: Arrow, sector: int) -> void:
	_arrow = arrow
	_sector = sector
