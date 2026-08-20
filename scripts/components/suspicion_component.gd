extends Node
class_name SuspicionComponent

enum SuspicionState {NONE, LOW, MEDIUM, HIGH}

signal suspicion_changed(stage: SuspicionState)
signal alerted()

var _last_incident: float
var state := SuspicionState.NONE:
	set(value):
		state = value
		suspicion_changed.emit(value)
		if is_alert(): alerted.emit()

func is_alert() -> bool:
	return state == SuspicionState.HIGH

func time_since_last_incident() -> float:
	return Time.get_ticks_msec() - _last_incident
