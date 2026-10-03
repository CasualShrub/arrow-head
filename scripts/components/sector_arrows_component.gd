extends ArrowsComponent
class_name SectorArrowsComponent

enum SlotState { EMPTY, OCCUPIED, USABLE, DISABLED }

@export var slot_count := 4
@export var centered := true

var slot_size: float:
	get():
		return TAU / slot_count

signal arrow_embedded(slot: int, arrow: Arrow)
signal slot_cleared(slot: int)

signal slot_state_changed(slot: int, state: SlotState)

signal firing_enabled(arrow: Arrow)
signal firing_disabled(arrow: Arrow)

signal filled()
signal emptied()

var slots: Array[SlotState] = []
var embedded: Array[Arrow] = []

func _ready() -> void:
	slots.resize(slot_count)
	embedded.resize(slot_count)
	if not filled.is_connected(_on_filled): filled.connect(_on_filled)
	if not emptied.is_connected(_on_emptied): emptied.connect(_on_emptied)

func get_state(slot: int) -> SlotState:
	return slots[slot]

func set_state(slot: int, state: SlotState) -> void:
	slots[slot] = state
	slot_state_changed.emit(slot, state)

func get_slots_with_state(state: SlotState) -> Array[int]:
	var found: Array[int] = []
	for slot in range(slot_count):
		if get_state(slot) == state:
			found.append(slot)
	return found

func is_full() -> bool:
	for i in range(slot_count):
		if get_state(i) == SlotState.EMPTY: return false
	return true

func get_embedded_arrow(slot: int) -> Arrow:
	return embedded[slot]

func get_embedded_slots(arrow: Arrow) -> Array[int]:
	var found: Array[int] = []
	for slot in range(slot_count):
		if get_embedded_arrow(slot) == arrow:
			found.append(slot)
	return found

func is_arrow_embedded(arrow: Arrow) -> bool:
	return embedded.has(arrow)

func can_use() -> bool:
	for slot in range(slot_count):
		if get_state(slot) == SlotState.USABLE: return true
	return false

func get_using_next() -> Arrow:
	var usable := get_slots_with_state(SlotState.USABLE)
	if usable.is_empty(): return null
	return get_embedded_arrow(usable.front())

func enable_use(arrow: Arrow) -> void:
	for slot in get_embedded_slots(arrow):
		set_state(slot, SlotState.USABLE)
	firing_enabled.emit(arrow)

func disable_use(arrow: Arrow) -> void:
	for slot in get_embedded_slots(arrow):
		set_state(slot, SlotState.OCCUPIED)
	firing_disabled.emit(arrow)

func _embed_in_slot(arrow: Arrow, slot: int) -> void:
	embedded[slot] = arrow
	set_state(slot, SlotState.OCCUPIED)
	arrow_embedded.emit(arrow, slot)
	print("arrow embedded in slot ", slot)

func _remove_from_slots(arrow: Arrow, toState: SlotState) -> void:
	for slot in get_embedded_slots(arrow):
		set_state(slot, toState)
		embedded[slot] = null
		slot_cleared.emit(slot)

func _get_slot_from_angle(angle: float) -> int:
	angle -= PI / 2 if not centered else 3 * PI / 4
	angle = fposmod(-angle, TAU)
	return int(floor(angle / slot_size))

func get_angle_from_slot(slot: int) -> float:
	var angle := -slot * slot_size
	angle += PI / 2 if not centered else 3 * PI / 4
	return angle + slot_size / 2

func _get_slot_from_offset(dir: Vector3) -> int:
	dir.y = 0.0
	if dir.is_zero_approx(): return 0
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

func _get_slots_to_occupy(arrow: Arrow) -> Array[int]:
	var offset := arrow.global_position - container.global_position
	var collided_slot := _get_slot_from_offset(offset)
	return arrow.get_occupied_slots(collided_slot)

func _can_add_arrow(arrow: Arrow) -> bool:
	for slot in _get_slots_to_occupy(arrow):
		if get_state(slot) != SlotState.EMPTY:
			return false
	return true

func _on_arrow_added(arrow: Arrow) -> void:
	for slot in _get_slots_to_occupy(arrow):
		_embed_in_slot(arrow, slot)
	if is_full():
		filled.emit()

func _on_arrow_removed(arrow: Arrow) -> void:
	_remove_from_slots(arrow, SlotState.DISABLED)
	if is_empty():
		emptied.emit()

func _on_filled() -> void:
	for arrow in embedded:
		enable_use(arrow)

func _on_emptied() -> void:
	for slot in range(slot_count):
		set_state(slot, SlotState.EMPTY)
