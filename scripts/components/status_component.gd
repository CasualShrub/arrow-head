extends Node
class_name StatusComponent

signal statusAdded(Status)
signal statusRemoved(Status)
signal statusExpired(Status)

## Contains script -> instance.
var _active: Dictionary[Status, Status] = {}

func _ready():
	assert(
		get_parent() is Player,
		"StatusComponent must be the child of a Player"
	)

func _physics_process(delta: float) -> void:
	for status: Status in _active.values():
		status.tick(delta)
		if status.wantsExpire():
			remove_status(status)
			statusExpired.emit(status)

func has_status(status: Status) -> bool:
	return _active.has(_get_key(status))

func add_status(status_template: Status) -> void:
	if has_status(status_template): return
	var status := status_template.duplicate()
	_active.set(_get_key(status), status)
	status.apply(get_parent())
	statusAdded.emit(status)

func remove_status(status: Status) -> void:
	if not has_status(status): return
	_active.erase(_get_key(status))
	status.remove()
	statusRemoved.emit(status)

func _get_key(status: Status) -> Variant:
	return status.get_script()
