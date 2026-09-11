extends TextureRect

const POSES := {
	&"top": {
		&"front": preload("res://menus/main_menu/apple_assets/top_front.PNG"),
		&"mid": preload("res://menus/main_menu/apple_assets/top_mid.PNG"),
		&"side": preload("res://menus/main_menu/apple_assets/top_side.PNG"),
	},
	&"middle": {
		&"front": preload("res://menus/main_menu/apple_assets/middle_front.PNG"),
		&"mid": preload("res://menus/main_menu/apple_assets/middle_mid.PNG"),
		&"side": preload("res://menus/main_menu/apple_assets/middle_side.PNG"),
	},
	&"down": {
		&"front": preload("res://menus/main_menu/apple_assets/down_front.PNG"),
		&"mid": preload("res://menus/main_menu/apple_assets/down_mid.PNG"),
		&"side": preload("res://menus/main_menu/apple_assets/down_side.PNG"),
	},
}

const EYES := {
	&"top": {
		&"front": preload("res://menus/main_menu/apple_assets/top_front_eyes.PNG"),
		&"mid": preload("res://menus/main_menu/apple_assets/top_mid_eyes.PNG"),
		&"side": preload("res://menus/main_menu/apple_assets/top_side_eyes.PNG"),
	},
	&"middle": {
		&"front": preload("res://menus/main_menu/apple_assets/middle_front_eyes.PNG"),
		&"mid": preload("res://menus/main_menu/apple_assets/middle_mid_eyes.PNG"),
		&"side": preload("res://menus/main_menu/apple_assets/middle_side_eyes.PNG"),
	},
	&"down": {
		&"front": preload("res://menus/main_menu/apple_assets/down_front_eyes.PNG"),
		&"mid": preload("res://menus/main_menu/apple_assets/down_mid_eyes.PNG"),
		&"side": preload("res://menus/main_menu/apple_assets/down_side_eyes.PNG"),
	},
}

const BLINK := [
	preload("res://menus/main_menu/apple_assets/middle_front_BLINK_1.PNG"),
	preload("res://menus/main_menu/apple_assets/middle_front_BLINK_2.PNG"),
	preload("res://menus/main_menu/apple_assets/middle_front_BLINK_3.PNG"),
]

@export var horizontal_deadzone: float = 0.22
@export var horizontal_side: float = 0.6
@export var vertical_split: float = 0.33
@export_group("Blink")
@export var blink_min_delay: float = 2.5
@export var blink_max_delay: float = 6.0
@export var blink_frame_time: float = 0.045

@onready var _eyes: TextureRect = $Eyes

var look_enabled: bool = true
var _mouse_in_window: bool = true
var _row: StringName = &"middle"
var _pose: StringName = &"front"
var _blinking: bool = false
var _blink_delay: float = 0.0
var _blink_tween: Tween

func _ready() -> void:
	_blink_delay = randf_range(blink_min_delay, blink_max_delay)
	_apply(&"middle", &"front", false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in_window = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in_window = false

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	if not look_enabled:
		_apply(&"middle", &"front", false)
		return

	var row: StringName = &"middle"
	var pose: StringName = &"front"
	var flip := false

	if _mouse_in_window:
		var viewport := get_viewport()
		var rect := viewport.get_visible_rect()
		var mouse := viewport.get_mouse_position()
		if rect.has_point(mouse):
			var center := global_position + size * 0.5
			var half_size := rect.size * 0.5
			var h_offset: float = clampf((mouse.x - center.x) / half_size.x, -1.0, 1.0)
			var v_offset: float = clampf((mouse.y - center.y) / half_size.y, -1.0, 1.0)

			if v_offset < -vertical_split:
				row = &"top"
			elif v_offset > vertical_split:
				row = &"down"

			var horizontal_distance := absf(h_offset)
			if horizontal_distance > horizontal_side:
				pose = &"side"
				flip = h_offset > 0.0
			elif horizontal_distance > horizontal_deadzone:
				pose = &"mid"
				flip = h_offset > 0.0

	_apply(row, pose, flip)
	_update_blink(delta)

func _apply(row: StringName, pose: StringName, flip: bool) -> void:
	_row = row
	_pose = pose
	texture = POSES[row][pose]
	flip_h = flip
	if not _blinking:
		_eyes.texture = EYES[row][pose]
	_eyes.flip_h = flip

func _update_blink(delta: float) -> void:
	var idle_front := _row == &"middle" and _pose == &"front"
	if _blinking:
		if not idle_front:
			_stop_blink()
		return
	if not idle_front:
		return
	_blink_delay -= delta
	if _blink_delay <= 0.0:
		_start_blink()

func _start_blink() -> void:
	_blinking = true
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween()
	for frame in BLINK:
		_blink_tween.tween_callback(func() -> void: _eyes.texture = frame)
		_blink_tween.tween_interval(blink_frame_time)
	_blink_tween.tween_callback(_stop_blink)

func _stop_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_blinking = false
	_blink_delay = randf_range(blink_min_delay, blink_max_delay)
	_eyes.texture = EYES[_row][_pose]
