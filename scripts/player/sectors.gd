@tool
extends Node3D
class_name Sectors

@export var sector_count := 4:
	set(value):
		if not mat: return
		mat.set_shader_parameter("sector_count", value)
		sector_count = value
		_update_centering()
@export var centered := true:
	set(value):
		_update_centering(value)
		centered = value
@export var radius := 0.5:
	set(value):
		scale.x = value * 2
		scale.y = value * 2
		radius = value

signal sector_highlighted(sector: int)
signal sector_unhighlighted(sector: int)

@onready var _display := $Display
@onready var _pointer := $Pointer
@onready var mat: ShaderMaterial = _display.material_override

var _highlighted := -1:
	set(value):
		if not mat: return
		mat.set_shader_parameter("aimed_sector", value)
		_highlighted = value

var _stored := []

func get_sector_size() -> float:
	return TAU / sector_count

func is_sector_highlighted(sector: int) -> bool:
	return (_highlighted >> sector) & 1

func highlight_sector(sector: int) -> void:
	if is_sector_highlighted(sector): return
	_highlighted += 1 << sector
	sector_highlighted.emit(sector)

func unhighlight_sector(sector: int) -> void:
	if not is_sector_highlighted(sector): return
	_highlighted -= 1 << sector
	sector_unhighlighted.emit(sector)

func _update_occupied_mask() -> void:
	if not mat: return
	var mask := 0
	for i in range(sector_count):
		if _stored[i]:
			mask += 1 << i
	mat.set_shader_parameter("occupied_mask", mask)

func _update_centering(toggle: bool = centered) -> void:
	if toggle:
		_display.rotation.y = (PI + get_sector_size()) / 2
	else:
		_display.rotation.y = PI / 2

func _setup_stored() -> void:
	_stored = []
	_stored.resize(sector_count)
	for i in range(sector_count):
		_stored[i] = null

func _on_changed() -> void:
	_update_occupied_mask()

func _ready() -> void:
	if not Engine.is_editor_hint():
		_setup_stored()
		show()
	_update_centering()
	radius = radius
