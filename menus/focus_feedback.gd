extends Node
class_name FocusFeedback

var _control: Control
var _base_scale: Vector2
var _factor := 1.08
var _hovered := false
var _tween: Tween
var _companions: Array[Control] = []
var _companion_scales: Array[Vector2] = []

static func attach(control: Control, factor := 1.08, companions: Array[Control] = []) -> void:
	if control.has_node("FocusFeedback"):
		return
	var feedback := FocusFeedback.new()
	feedback.name = "FocusFeedback"
	feedback._factor = factor
	feedback._companions = companions
	control.add_child(feedback)

func _ready() -> void:
	_control = get_parent() as Control
	_base_scale = _control.scale
	for companion in _companions:
		_companion_scales.append(companion.scale)
		companion.position += (companion.pivot_offset - companion.size * 0.5) * (Vector2.ONE - companion.scale)
		companion.pivot_offset = companion.size * 0.5
	_control.position += (_control.pivot_offset - _control.size * 0.5) * (Vector2.ONE - _base_scale)
	_control.pivot_offset = _control.size * 0.5
	_control.resized.connect(func(): _control.pivot_offset = _control.size * 0.5)
	_control.focus_entered.connect(_refresh)
	_control.focus_exited.connect(_refresh)
	_control.mouse_entered.connect(func(): _hovered = true; _refresh())
	_control.mouse_exited.connect(func(): _hovered = false; _refresh())
	_control.visibility_changed.connect(_refresh)
	ControllerManager.changed.connect(_refresh)
	if _control is TextureButton and _control.texture_hover:
		_control.texture_focused = _control.texture_hover

func _refresh() -> void:
	if _tween:
		_tween.kill()
	var active := _control.is_visible_in_tree() and (_control.has_focus() or (_hovered and not ControllerManager.using_controller))
	_tween = create_tween().set_ignore_time_scale()
	_tween.tween_property(_control, "scale", _base_scale * (_factor if active else 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in _companions.size():
		_tween.parallel().tween_property(_companions[i], "scale", _companion_scales[i] * (_factor if active else 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
