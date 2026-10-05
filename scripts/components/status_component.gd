@icon("res://addons/at-icons/used/node/fire.svg")
extends Node
class_name StatusComponent

signal statusAdded(Status)
signal statusRemoved(Status)
signal statusExpired(Status)

## Contains script -> instance.
var _active: Dictionary[Script, Status] = {}

func _ready():
	assert(
		get_parent() is Player,
		"StatusComponent must be the child of a Player"
	)

func _physics_process(delta: float) -> void:
	for status: Status in _active.values():
		status.advance(delta)
		if status.wants_expire():
			remove_status(status)
			statusExpired.emit(status)

func has_status(status: Status) -> bool:
	return _active.has(_get_key(status))

func clear() -> void:
	for status: Status in _active.values():
		remove_status(status)

func add_status(status_template: Status) -> void:
	if has_status(status_template):
		_active[_get_key(status_template)].refresh()
		return
	var status := status_template.duplicate()
	_active.set(_get_key(status), status)
	status.apply(get_parent())
	statusAdded.emit(status)

func remove_status(status: Status) -> void:
	if not has_status(status): return
	var key := _get_key(status)
	var active: Status = _active[key]
	_active.erase(key)
	active.remove()
	statusRemoved.emit(active)

func _get_key(status: Status) -> Script:
	return status.get_script()
