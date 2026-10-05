@tool
@icon("res://addons/at-icons/used/node3d/checkerboard_circle.svg")
extends Node3D
class_name Sectors

enum SectorState {NONE, HIGHLIGHTED, USABLE, DISABLED}

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
		scale.z = value * 2
		radius = value
@export var inner_radius: float:
	get():
		if not mat: return 0.0
		return mat.get_shader_parameter("inner_radius")
	set(value):
		if not mat: return
		mat.set_shader_parameter("inner_radius", value)

signal sector_state_changed(sector: int, state: SectorState)

@onready var _display := $Display
#@onready var _pointer := $Pointer
@onready var mat: ShaderMaterial = _display.material_override

var sector_size: float:
	get():
		return TAU / sector_count

## arrow is occupying the slot
var _highlighted := 0:
	set(value):
		if not mat: return
		mat.set_shader_parameter("occupied_mask", value) #occupied_mask
		_highlighted = value
## slot is ready to be consumed
var _usable := 0:
	set(value):
		if not mat: return
		mat.set_shader_parameter("usable_mask", value)
		_usable = value
## slot cannot be interacted with
var _disabled := 0:
	set(value):
		if not mat: return
		mat.set_shader_parameter("disabled_mask", value)
		_disabled = value

func _ready() -> void:
	mat = mat.duplicate()
	_display.material_override = mat
	_highlighted = 0
	_usable = 0
	_disabled = 0
	mat.set_shader_parameter("sector_count", sector_count)
	_update_centering()
	if Engine.is_editor_hint(): return
	DarkenManager.register_highlighted(self)
	ScreenShaderManager.register_unfiltered(self)
	show()

func get_state(sector: int) -> SectorState:
	if (_highlighted >> sector) & 1:
		return SectorState.HIGHLIGHTED
	elif (_usable >> sector) & 1:
		return SectorState.USABLE
	elif (_disabled >> sector) & 1:
		return SectorState.DISABLED
	else:
		return SectorState.NONE

func set_state(sector: int, state: SectorState) -> void:
	var bit := 1 << sector
	if state == SectorState.HIGHLIGHTED:
		if _highlighted & bit: return
		print("state highlighted")
		_highlighted |= bit
	else:
		_highlighted &= ~bit
	if state == SectorState.USABLE:
		if _usable & bit: return
		print("state usable")
		_usable |= bit
	else:
		_usable &= ~bit
	if state == SectorState.DISABLED:
		if _disabled & bit: return
		print("state disabled")
		_disabled |= bit
	else:
		_disabled &= ~bit
	sector_state_changed.emit(sector, state)

#func _update_occupied_mask() -> void:
	#if not mat: return
	#var mask := 0
	#for i in range(sector_count):
		#if _stored[i]:
			#mask += 1 << i
	#mat.set_shader_parameter("occupied_mask", mask)

func clear() -> void:
	for sector in range(sector_count):
		set_state(sector, SectorState.NONE)

func _update_centering(toggle: bool = centered) -> void:
	if not _display: return
	if toggle:
		_display.rotation.y = TAU + sector_size / 2
	else:
		_display.rotation.y = TAU
