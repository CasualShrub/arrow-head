extends AnimatedSprite3D
class_name PlayerEyes

enum EyeDirection {
	Hidden,
	Centered,
	North,
	NorthEast,
	East,
	SouthEast,
	South,
	SouthWest,
	West,
	NorthWest,
}

const STATE_MAP: Dictionary[EyeDirection, int] = {
	EyeDirection.Hidden: -1,
	EyeDirection.Centered: 0,
	EyeDirection.North: -1,
	EyeDirection.NorthEast: -1,
	EyeDirection.East: 1,
	EyeDirection.SouthEast: 2,
	EyeDirection.South: 3,
	EyeDirection.SouthWest: 4,
	EyeDirection.West: 5,
	EyeDirection.NorthWest: -1,
}

@export var deadzone := -1.0

signal state_changed(state: StringName)
signal direction_changed(direction: EyeDirection)

var _dir := EyeDirection.Hidden

func _ready() -> void:
	STATE_MAP.make_read_only()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		var dir := get_eyes_direction()
		if visible:
			if dir == EyeDirection.Hidden:
				set_eyes_direction(EyeDirection.Centered)
		else:
			if dir != EyeDirection.Hidden:
				set_eyes_direction(EyeDirection.Hidden)

func get_eyes_states() -> Array[StringName]:
	return sprite_frames.get_animation_names()

func has_state(state: StringName) -> bool:
	return sprite_frames.has_animation(state)

func get_eyes_state() -> StringName:
	return animation

func set_eyes_state(state: StringName):
	if animation == state: return
	assert(has_state(state), "Eyes do not have state {state}")
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
	var rot_direction := get_direction_from_rotaion(rot)
	set_eyes_direction(rot_direction)

func make_eyes_look_at(point: Vector3) -> void:
	var point_offset := to_local(point)
	if deadzone > 0.0:
		var point_offset_len_sq := position.distance_squared_to(point_offset)
		var deadzone_sq = deadzone * deadzone
		if point_offset_len_sq < deadzone_sq:
			set_eyes_direction(EyeDirection.Centered)
			return
	var rot := atan2(point_offset.z, point_offset.x)
	set_eyes_rotation(rot)

static func get_direction_from_rotaion(rot: float) -> EyeDirection:
	var deg := rad_to_deg(rot)
	if deg > -22.5 and deg <= 22.5:
		return EyeDirection.East
	elif deg > 22.5 and deg <= 67.5:
		return EyeDirection.SouthEast
	elif deg > 67.5 and deg <= 112.5:
		return EyeDirection.South
	elif deg > 112.5 and deg <= 157.5:
		return EyeDirection.SouthWest
	elif deg > 157.5 or deg <= -157.5:
		return EyeDirection.West
	elif deg > -157.5 and deg <= -112.5:
		return EyeDirection.NorthWest
	elif deg > -112.5 and deg <= -67.5:
		return EyeDirection.North
	else:
		return EyeDirection.NorthEast
