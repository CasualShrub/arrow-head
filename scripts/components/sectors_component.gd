@tool
extends MeshInstance3D
class_name SectorsComponent

@export var sector_count := 4:
	set(value):
		if not mat: return
		mat.set_shader_parameter("sector_count", value)
		sector_count = value
		_handle_centering()
@export var centered := true:
	set(value):
		_handle_centering(value)
		centered = value
@export var radius := 0.5:
	set(value):
		scale.x = value * 2
		scale.y = value * 2
		radius = value
@export var relative_aim := false

signal changed

@onready var mat: ShaderMaterial = material_override

var _highlighted := -1:
	set(value):
		if not mat: return
		mat.set_shader_parameter("aimed_sector", value)
		_highlighted = value

var _stored := []

func get_sector_size() -> float:
	return TAU / sector_count

func get_sector_center(sector: int) -> float:
	var sector_size := get_sector_size()
	var center := sector_size * -sector
	#if centered:
	#	center -= sector_size / 2
	center = fposmod(center, TAU)
	return center

func get_sector_from_angle(angle: float) -> int:
	var sector_size := get_sector_size()

	angle = fposmod(angle, TAU)
	return int(floor(angle / sector_size))

func get_sector_from_position(pos: Vector3) -> int:
	var dir := pos - global_position
	dir.y = 0.0

	if dir.length() < 0.0001:
		return 0

	dir = dir.normalized()

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0

	forward = forward.normalized()
	right = right.normalized()

	var x := dir.dot(right)
	var z := dir.dot(forward)

	var angle := atan2(z, x)
	return get_sector_from_angle(angle)

func get_sector_from_movement(dir: Vector2) -> int:
	if dir == Vector2.ZERO: return 0
	if relative_aim:
		var v := global_position
		v.x += dir.x
		v.z += dir.y
		return get_sector_from_position(v)
	else:
		if dir.y < 0:
			return 0
		elif dir.y > 0:
			return 2
		else:
			if dir.x > 0:
				return 1
			elif dir.x < 0:
				return 3
			else:
				return -1

func _stored_is_ref(stored: Variant) -> bool:
	return stored is int

func store(sectors: Array[int], to_store: Variant) -> bool:
	if len(sectors) == 0: return false
	if len(sectors) == 1:
		var i := sectors[0]
		if _stored[i] != null: return false
		_stored[i] = to_store
	else:
		var largest := 0
		for i in sectors:
			largest = max(largest, i)
			if _stored[i] != null: return false
		for i in sectors:
			if i == largest:
				_stored[i] = to_store
			else:
				_stored[i] = largest
	changed.emit()
	return true

func get_stored() -> Array:
	return _stored

func get_stored_at(sector: int) -> Variant:
	var s = _stored[sector]
	if _stored_is_ref(s): s = _stored[s]
	return s

func occupied(sectors: Array[int]) -> bool:
	for i in sectors:
		if _stored[i] == null: return false
	return true

func full() -> bool:
	for s in _stored:
		if s == null: return false
	return true

func take_stored(sector: int) -> Variant:
	if _stored_is_ref(_stored[sector]):
		sector = _stored[sector]
	var slots = [sector]
	for i in range(sector_count):
		# store actual in last slot, so if passed break
		if i == sector:
			break
		if _stored[i] is int and _stored[i] == sector:
			slots.append(i)
	var s = get_stored_at(sector)
	for i in slots:
		_stored[i] = null
	changed.emit()
	return s

func clear_stored() -> void:
	_stored.clear()
	_setup_stored()
	changed.emit()

func get_highlighted() -> int:
	return _highlighted

func highlight_sector(sector: int = -1) -> void:
	_highlighted = sector

func _update_occupied_mask() -> void:
	if not mat: return
	var mask := 0
	for i in range(sector_count):
		if _stored[i]:
			mask += 1 << i
	mat.set_shader_parameter("occupied_mask", mask)

func _handle_centering(toggle: bool = centered) -> void:
	if toggle:
		_center()
	else:
		_decenter()

func _center() -> void:
	rotation.y = (PI + get_sector_size()) / 2
	
func _decenter() -> void:
	rotation.y = PI / 2

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
	_handle_centering()
	radius = radius
