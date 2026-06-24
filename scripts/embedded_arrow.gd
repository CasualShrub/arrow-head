extends Node
class_name EmbeddedArrow

var _arrow: Arrow
var _sector: int
var _can_fire: bool

func toggle_firing(can_fire: bool) -> void:
	_can_fire = can_fire

func enable_firing() -> void:
	toggle_firing(true)

func is_firing_enabled() -> bool:
	return _can_fire

func get_sector() -> int:
	return _sector

func change_sector(sector: int) -> void:
	_sector = sector

func get_arrow() -> Arrow:
	return _arrow

func grab() -> Arrow:
	var a := _arrow
	_arrow = null
	queue_free()
	return a
	
func try_grab() -> Arrow:
	if not is_firing_enabled(): return null
	return grab()

func _exit_tree() -> void:
	print("exiting")
	if _arrow: _arrow.queue_free()

func _init(arrow: Arrow, sector: int) -> void:
	_arrow = arrow
	_sector = sector
	_can_fire = false
