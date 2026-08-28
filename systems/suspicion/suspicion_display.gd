extends Node3D
class_name SuspicionDisplay

signal state_changed(state: SuspicionComponent.SuspicionState)

func set_state(state: SuspicionComponent.SuspicionState) -> void:
	match state:
		SuspicionComponent.SuspicionState.NONE:
			pass
		SuspicionComponent.SuspicionState.LOW:
			pass
		SuspicionComponent.SuspicionState.MEDIUM:
			pass
		SuspicionComponent.SuspicionState.HIGH:
			pass
	state_changed.emit(state)
