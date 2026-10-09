extends Resource
class_name Status

@export var lifetime := -1.0

var owner: Player

var _elapsed := 0.0

func apply(target: Player) -> void:
	owner = target
	_elapsed = 0.0

func remove() -> void:
	pass

func refresh() -> void:
	_elapsed = 0.0

func wants_expire() -> bool:
	return lifetime >= 0.0 and _elapsed >= lifetime

func advance(delta: float) -> void:
	_elapsed += delta
	tick(delta)

func tick(_delta: float) -> void:
	pass
