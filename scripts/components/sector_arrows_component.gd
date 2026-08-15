extends ArrowsComponent
class_name SectorArrowsComponent

@export var slot_count := 4

signal slot_occupied(slot: int, arrow: Arrow)
signal slot_cleared(slot: int)

signal firing_enabled(arrow: Arrow)
signal firing_disabled(arrow: Arrow)

var _embedded: Array[Arrow] = []
var _fireable: Dictionary[Arrow, bool] = {}

func _ready() -> void:
	_embedded.resize(slot_count)

func is_full() -> bool:
	for i in range(slot_count):
		if !is_slot_occupied(i): return false
	return true

func get_slots_of(arrow: Arrow) -> Array[int]:
	var slots := []
	for i in range(slot_count):
		if _embedded[i] == arrow:
			slots.append(arrow)
	return slots

func get_occupied() -> Array[bool]:
	var occupied := []
	occupied.resize(slot_count)
	for i in range(slot_count):
		occupied[i] = _embedded[i] != null
	return occupied

func is_slot_occupied(slot: int) -> bool:
	return _embedded[slot] != null

func get_embedded_in(slot: int) -> Arrow:
	return _embedded[slot]

func is_fireable(arrow: Arrow) -> bool:
	return _fireable.get(arrow, false)

func has_fireable() -> bool:
	for f in _fireable.values():
		if f: return true
	return false

func get_firing_next() -> Arrow:
	for a in _fireable.keys():
		if is_fireable(a): return a
	return null

func is_slot_fireable(slot: int) -> bool:
	return is_fireable(get_embedded_in(slot))

func enable_firing(arrow: Arrow) -> void:
	_fireable.set(arrow, true)
	firing_enabled.emit(arrow)

func disable_firing(arrow: Arrow) -> void:
	_fireable.set(arrow, false)
	firing_disabled.emit(arrow)

func fully_enable_firing() -> void:
	for arrow in _fireable.keys():
		enable_firing(arrow)

func _get_slot_size() -> float:
	return TAU / slot_count

func _get_slot_from_angle(angle: float) -> int:
	var slot_size := _get_slot_size()

	angle = fposmod(angle, TAU)
	return int(floor(angle / slot_size))

func _get_slot_from_offset(dir: Vector3) -> int:
	dir.y = 0.0
	if dir.length() < 0.0001:
		return 0
	dir = dir.normalized()

	var forward := -container.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var right := container.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var x := dir.dot(right)
	var z := dir.dot(forward)

	var angle := atan2(z, x)
	return _get_slot_from_angle(angle)

func has_arrow(arrow: Arrow) -> bool:
	return _fireable.has(arrow)

func _get_slots_to_occupy(arrow: Arrow) -> Array[int]:
	var offset := container.to_local(arrow.global_position)
	var collided_slot := _get_slot_from_offset(offset)
	return arrow.get_occupied_slots(collided_slot)

func _can_add_arrow(arrow: Arrow) -> bool:
	for slot in _get_slots_to_occupy(arrow):
		if is_slot_occupied(slot):
			return false
	return true

func _on_arrow_added(arrow: Arrow) -> void:
	for slot in _get_slots_to_occupy(arrow):
		_embedded[slot] = arrow
		disable_firing(arrow)
		slot_occupied.emit(slot, arrow)
		slot_occupied.emit(slot)

func _on_arrow_removed(arrow: Arrow) -> void:
	for i in range(slot_count):
		if _embedded[i] == arrow:
			_embedded[i] = null
			slot_cleared.emit(i)
	_fireable.erase(arrow)
