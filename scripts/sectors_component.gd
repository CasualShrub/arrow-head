@tool
extends MeshInstance3D
class_name SectorsComponent

@export var sector_count := 4:
	set(value):
		if not mat: return
		mat.set_shader_parameter("sector_count", value)
		sector_count = value
@export var centered := true:
	set(value):
		_handle_centering(value)
		centered = value
@export var radius := 1.0:
	set(value):
		scale.x = value
		scale.y = value
		radius = value

@onready var mat: ShaderMaterial = material_override

var _stored := []

func get_sector_size() -> float:
	return 2 * PI / sector_count

func get_sector_from_angle(angle: float) -> int:
	var sector_size := get_sector_size()
	if centered:
		angle += sector_size / 2
	if angle < 0:
		angle += 2 * PI
	elif angle >= 2 * PI:
		angle -= 2 * PI
	return floor(angle / sector_size)

func get_sector_from_position(pos: Vector3) -> int:
	var local_pos = to_local(pos)
	var angle := atan2(local_pos.x, -local_pos.z)
	return get_sector_from_angle(angle)

func _stored_is_ref(stored: Variant) -> bool:
	return stored is int and stored < sector_count

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
	_update_occupied_mask()
	return true

func get_stored() -> Array:
	return _stored

func get_stored_at(sector: int) -> Variant:
	var s = _stored[sector]
	if _stored_is_ref(s): s = _stored[s]
	return s
	
func occupied(sectors: Array[int]) -> bool:
	print("getting occupied",_stored)
	for i in sectors:
		if _stored[i] == null: return false
	return true

func full() -> bool:
	for s in _stored:
		if s == null: return false
	return true

func take_stored(sector: int) -> Variant:
	var s = get_stored_at(sector)
	if _stored_is_ref(s):
		sector = s
		s = get_stored_at(s)
	# other slots are 
	var slots = [sector]
	for i in range(sector_count):
		# store actual in last slot, so if passed break
		if i == sector:
			break
		if _stored[i] == sector:
			slots.append(i)
	for i in slots:
		_stored[i] = null
	_update_occupied_mask()
	return s

func clear_stored() -> void:
	for s in _stored:
		if s and s is not int:
			print("clearing", s)
			s.queue_free()
	_stored = []
	_setup_stored()

func highlight_sector(sector: int = -1) -> void:
	if not mat: return
	mat.set_shader_parameter("aimed_sector", sector)

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
	_stored.resize(sector_count)

func _ready() -> void:
	if not Engine.is_editor_hint():
		_setup_stored()
	_handle_centering()
