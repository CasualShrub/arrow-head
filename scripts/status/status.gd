extends Resource
class_name Status

@export var lifetime := -1.0

var owner: Player

var _applied_at: float
var _expires_at: float

func apply(target: Player) -> void:
	owner = target
	
	_applied_at = Time.get_ticks_msec()
	_expires_at = _applied_at + lifetime

func remove() -> void:
	pass
	
func wants_expire() -> bool:
	return lifetime >= 0.0 and Time.get_ticks_msec() >= _expires_at
	
func tick(delta: float) -> void:
	pass
