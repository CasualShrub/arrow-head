extends Node
class_name SusComponent

enum SusStage {LW, MD, HI}

@export_range(0.0, 1.0) var amount := 0.0:
	set(value):
		amount = clamp(value, 0.0, max_value)
@export_range(0.0, 1.0) var max_value := 1.0:
	set(value):
		if amount > value:
			amount = value
		max_value = value
@export var reduction_speed := 0.1
@export var incident_memory := 1.0
@export_range(0.0, 1.0) var medium_boundary := 0.70
@export_range(0.0, 1.0) var low_boundary := 0.35

signal incident_occured
signal alerted

@onready var _outline: AnimatedSprite3D = %Fill
@onready var _fill: AnimatedSprite3D = %Fill

var _last_incident: float

func get_stage() -> SusStage:
	var frac := amount / max_value
	if frac > medium_boundary:
		return SusStage.HI
	if frac > low_boundary:
		return SusStage.MD
	return SusStage.LW
	
func is_alert() -> bool:
	return amount == max_value

func _display_state() -> void:
	var frame := 1 if is_alert() else 0
	_outline.frame = frame
	_fill.frame = frame

func time_since_last_incident() -> float:
	return Time.get_ticks_msec() - _last_incident

func _stop_alert() -> void:
	amount -= 1

func baka(n: float) -> void:
	amount += n
	_last_incident = Time.get_ticks_msec()
	incident_occured.emit()
	if is_alert():
		alerted.emit()
	_display_state()

func _display_fill_percent(p: float) -> void:
	if not _fill: return
	if p == 0:
		if _outline.visible:
			_outline.hide()
		return
	elif not _outline.visible:
		_outline.show()
	var mat = _fill.material_override as ShaderMaterial
	mat.set_shader_parameter("fade_height", p)

func _on_fill_frame_changed() -> void:
	print("Frame changed")
	var mat = _fill.material_override as ShaderMaterial
	mat.set_shader_parameter("sprite_texture", _fill.sprite_frames.get_frame_texture(_fill.animation, _fill.frame))

func _physics_process(delta: float) -> void:
	if is_alert() and time_since_last_incident() > incident_memory:
		_stop_alert()
	amount -= reduction_speed * delta
	_display_fill_percent(amount / max_value)
