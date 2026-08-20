extends AnimatedSprite3D
class_name PlayerEyes

enum EyeDirection {
	HIDDEN,
	CENTERED,
	NORTH,
	NORTH_EAST,
	EAST,
	SOUTH_EAST,
	SOUTH,
	SOUTH_WEST,
	WEST,
	NORTH_WEST,
}

const STATE_MAP: Dictionary[EyeDirection, int] = {
	EyeDirection.HIDDEN: -1,
	EyeDirection.CENTERED: 0,
	EyeDirection.NORTH: -1,
	EyeDirection.NORTH_EAST: -1,
	EyeDirection.EAST: 1,
	EyeDirection.SOUTH_EAST: 2,
	EyeDirection.SOUTH: 3,
	EyeDirection.SOUTH_WEST: 4,
	EyeDirection.WEST: 5,
	EyeDirection.NORTH_WEST: -1,
}

@export var deadzone := -1.0

signal state_changed(state: StringName)
signal direction_changed(direction: EyeDirection)

var _dir := EyeDirection.HIDDEN

func _ready() -> void:
	STATE_MAP.make_read_only()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		var dir := get_eyes_direction()
		if visible:
			if dir == EyeDirection.HIDDEN:
				set_eyes_direction(EyeDirection.CENTERED)
		else:
			if dir != EyeDirection.HIDDEN:
				set_eyes_direction(EyeDirection.HIDDEN)

func get_eyes_states() -> Array[StringName]:
	return sprite_frames.get_animation_names()

func has_state(state: StringName) -> bool:
	return sprite_frames.has_animation(state)

func get_eyes_state() -> StringName:
	return animation

func set_eyes_state(state: StringName) -> void:
	if animation == state: return
	assert(has_state(state), "%s does not have state %s." % [get_path(), state])
	animation = state
	state_changed.emit(state)

func get_eyes_direction() -> EyeDirection:
	return _dir

func _get_frame_from_direction(dir: EyeDirection) -> int:
	return STATE_MAP.get(dir, -1)

func set_eyes_direction(dir: EyeDirection) -> void:
	var target_frame :=_get_frame_from_direction(dir)
	if target_frame == frame: return
	_dir = dir
	if target_frame == -1:
		if visible: hide()
	else:
		if not visible: show()
		frame = target_frame
	direction_changed.emit(dir)

func set_eyes_rotation(rot: float) -> void:
	var rot_direction := get_direction_from_rotation(rot)
	set_eyes_direction(rot_direction)

func make_eyes_look_at(target: Vector3) -> void:
	var target_offset := target - global_position
	target_offset.y = 0
	if deadzone > 0.0:
		var target_offset_len_sq := position.distance_squared_to(target_offset)
		var deadzone_sq = deadzone * deadzone
		if target_offset_len_sq < deadzone_sq:
			set_eyes_direction(EyeDirection.CENTERED)
			return
	var rot := atan2(target_offset.z, target_offset.x)
	
	set_eyes_rotation(rot)

static func get_direction_from_rotation(rot: float) -> EyeDirection:
	var deg := rad_to_deg(rot)
	if deg > -22.5 and deg <= 22.5:
		return EyeDirection.EAST
	elif deg > 22.5 and deg <= 67.5:
		return EyeDirection.SOUTH_EAST
	elif deg > 67.5 and deg <= 112.5:
		return EyeDirection.SOUTH
	elif deg > 112.5 and deg <= 157.5:
		return EyeDirection.SOUTH_WEST
	elif deg > 157.5 or deg <= -157.5:
		return EyeDirection.WEST
	elif deg > -157.5 and deg <= -112.5:
		return EyeDirection.NORTH_WEST
	elif deg > -112.5 and deg <= -67.5:
		return EyeDirection.NORTH
	else:
		return EyeDirection.NORTH_EAST
