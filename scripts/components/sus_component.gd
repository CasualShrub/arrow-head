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
@export_range(0.0, 1.0) var medium_boundary := 0.65
@export_range(0.0, 1.0) var low_boundary := 0.35

signal incident_occured
signal alerted

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
	
func time_since_last_incident() -> float:
	return Time.get_ticks_msec() - _last_incident

func baka(n: float) -> void:
	amount += n
	_last_incident = Time.get_ticks_msec()
	incident_occured.emit()
	if is_alert():
		alerted.emit()

func _physics_process(delta: float) -> void:
	if is_alert() and time_since_last_incident() > incident_memory:
		amount -= 1
	amount -= reduction_speed * delta
