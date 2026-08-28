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
#@onready var _pointer := $Pointer
@onready var mat: ShaderMaterial = _display.material_override

#highlighted means an arrow is occupying the slot
var _highlighted := 0:
	set(value):
		if not mat: return
		mat.set_shader_parameter("occupied_mask", value) #occupied_mask
		_highlighted = value

#primed means this arrow is ready to be consumed on the next dash
var _primed := -1:
	set(value):
		if not mat: return
		mat.set_shader_parameter("aimed_sector", value)
		_primed = value

func get_sector_size() -> float:
	return TAU / sector_count

func is_sector_highlighted(sector: int) -> bool:
	return (_highlighted >> sector) & 1

func highlight_sector(sector: int) -> void:
	if is_sector_highlighted(sector): return
	_highlighted |= 1 << sector
	sector_highlighted.emit(sector)

func unhighlight_sector(sector: int) -> void:
	if not is_sector_highlighted(sector): return
	_highlighted &= ~(1 << sector)
	sector_unhighlighted.emit(sector)

func set_primed(sector: int) -> void:
	_primed = sector

func clear_primed() -> void:
	_primed = -1

func clear() -> void:
	_highlighted = 0
	_primed = -1

#func _update_occupied_mask() -> void:
	#if not mat: return
	#var mask := 0
	#for i in range(sector_count):
		#if _stored[i]:
			#mask += 1 << i
	#mat.set_shader_parameter("occupied_mask", mask)

func _update_centering(toggle: bool = centered) -> void:
	if not _display: return
	if toggle:
		_display.rotation.y = (PI + get_sector_size()) / 2
	else:
		_display.rotation.y = PI / 2

func _ready() -> void:
	_update_centering()
	radius = radius
	if Engine.is_editor_hint(): return
	_highlighted = 0
	_primed = -1
	show()
