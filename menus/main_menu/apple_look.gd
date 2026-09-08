extends TextureRect

const POSES := {
	&"top": {
		&"front": preload("res://menus/main_menu/top_front.PNG"),
		&"mid": preload("res://menus/main_menu/top_mid.PNG"),
		&"side": preload("res://menus/main_menu/top_side.PNG"),
	},
	&"middle": {
		&"front": preload("res://menus/main_menu/middle_front.PNG"),
		&"mid": preload("res://menus/main_menu/middle_mid.PNG"),
		&"side": preload("res://menus/main_menu/middle_side.PNG"),
	},
	&"down": {
		&"front": preload("res://menus/main_menu/down_front.PNG"),
		&"mid": preload("res://menus/main_menu/down_mid.PNG"),
		&"side": preload("res://menus/main_menu/down_side.PNG"),
	},
}

const EYES := {
	&"top": {
		&"front": preload("res://menus/main_menu/top_front_eyes.PNG"),
		&"mid": preload("res://menus/main_menu/top_mid_eyes.PNG"),
		&"side": preload("res://menus/main_menu/top_side_eyes.PNG"),
	},
	&"middle": {
		&"front": preload("res://menus/main_menu/middle_front_eyes.PNG"),
		&"mid": preload("res://menus/main_menu/middle_mid_eyes.PNG"),
		&"side": preload("res://menus/main_menu/middle_side_eyes.PNG"),
	},
	&"down": {
		&"front": preload("res://menus/main_menu/down_front_eyes.PNG"),
		&"mid": preload("res://menus/main_menu/down_mid_eyes.PNG"),
		&"side": preload("res://menus/main_menu/down_side_eyes.PNG"),
	},
}

@export var horizontal_deadzone: float = 0.22
@export var horizontal_side: float = 0.6
@export var vertical_split: float = 0.33

@onready var _eyes: TextureRect = $Eyes

var _mouse_in_window: bool = true

func _ready() -> void:
	_apply(&"middle", &"front", false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in_window = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in_window = false
		_apply(&"middle", &"front", false) #default asset if no mouse

func _process(_delta: float) -> void:
	if not _mouse_in_window or not is_visible_in_tree():
		return
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var mouse := viewport.get_mouse_position()
	if not rect.has_point(mouse):
		_apply(&"middle", &"front", false)
		return

	var center := global_position + size * 0.5
	var half_size := rect.size * 0.5
	var h_offset: float = clampf((mouse.x - center.x) / half_size.x, -1.0, 1.0)
	var v_offset: float = clampf((mouse.y - center.y) / half_size.y, -1.0, 1.0)

	var row := &"middle"
	if v_offset < -vertical_split:
		row = &"top"
	elif v_offset > vertical_split:
		row = &"down"

	var pose := &"front"
	var flip := false
	var horizontal_distance := absf(h_offset)
	if horizontal_distance > horizontal_side:
		pose = &"side"
		flip = h_offset > 0.0
	elif horizontal_distance > horizontal_deadzone:
		pose = &"mid"
		flip = h_offset > 0.0

	_apply(row, pose, flip)

func _apply(row: StringName, pose: StringName, flip: bool) -> void:
	texture = POSES[row][pose]
	flip_h = flip
	_eyes.texture = EYES[row][pose]
	_eyes.flip_h = flip
