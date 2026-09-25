extends Control
class_name AppleSlider

signal value_changed(value: float)
signal drag_ended

@export var min_value := 0.0
@export var max_value := 1.0
@export var step := 0.01
@export var value: float:
	get:
		return _value
	set(v):
		if _assign(v):
			value_changed.emit(_value)

var _value := 1.0
var _dragging := false
var _grab_offset := 0.0
var _repeat_direction := 0
var _repeat_at := 0

@onready var _bar: TextureRect = $Bar
@onready var _knob: TextureButton = $Knob

func _ready() -> void:
	var mask := BitMap.new()
	mask.create_from_image_alpha(_knob.texture_normal.get_image())
	_knob.texture_click_mask = mask
	_knob.gui_input.connect(_on_knob_input)
	(_bar.material as ShaderMaterial).set_shader_parameter(&"seed", randf() * 100.0)
	_refresh()

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_set_from_x(event.position.x - _grab_offset)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		_end_drag()

func _gui_input(event: InputEvent) -> void:
	var direction := 0
	if event.is_action_pressed("ui_left", false, true):
		direction = -1
	elif event.is_action_pressed("ui_right", false, true):
		direction = 1
	if direction != 0:
		if _repeat_direction != direction:
			value += step * direction
			_repeat_direction = direction
			_repeat_at = Time.get_ticks_msec() + 350
		accept_event()

func _process(_delta: float) -> void:
	if _repeat_direction == 0:
		return
	var held := Input.is_action_pressed("ui_left" if _repeat_direction < 0 else "ui_right")
	if not has_focus() or not is_visible_in_tree() or not held:
		_repeat_direction = 0
		drag_ended.emit()
	elif Time.get_ticks_msec() >= _repeat_at:
		value += step * _repeat_direction
		_repeat_at = Time.get_ticks_msec() + 65

func set_value_no_signal(v: float) -> void:
	_assign(v)

func _on_knob_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_dragging = true
		_grab_offset = event.global_position.x - (_knob.get_global_transform() * Vector2(_knob.size.x * 0.5, 0.0)).x
		grab_focus()
		accept_event()
	else:
		_end_drag()

func _end_drag() -> void:
	if _dragging:
		_dragging = false
		drag_ended.emit()

func _set_from_x(global_x: float) -> void:
	var local_x := (_bar.get_global_transform().affine_inverse() * Vector2(global_x, 0.0)).x
	value = min_value + clampf(local_x / _bar.size.x, 0.0, 1.0) * (max_value - min_value)

func _assign(v: float) -> bool:
	v = clampf(v, min_value, max_value)
	if step > 0.0:
		v = clampf(min_value + roundf((v - min_value) / step) * step, min_value, max_value)
	if is_equal_approx(v, _value):
		return false
	_value = v
	_refresh()
	return true

func _refresh() -> void:
	if not is_node_ready():
		return
	var ratio := (_value - min_value) / (max_value - min_value)
	_knob.position.x = _bar.position.x + ratio * _bar.size.x - _knob.size.x * 0.5
	(_bar.material as ShaderMaterial).set_shader_parameter(&"fill_amount", ratio)
