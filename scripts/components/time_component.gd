@icon("res://addons/at-icons/used/node/hourglass.svg")
extends Node
class_name TimeComponent

@export_category("bar")
@export var bar: BarComponent
@export var activation_cost := 0.0
@export var tick_regen := 0.075
@export var tick_consumption := 0.1

@export_category("slow")
@export var slow_scale := 0.1
@export var normal_scale := 1.0
@export var transition_speed := 5.0

signal slowed()
signal resumed()

var _active := false
var _target_scale := 1.0

func _process(delta: float) -> void:
	# do not slow down the slower
	var real_delta := delta / Engine.time_scale
	
	if Engine.time_scale != _target_scale:
		Engine.time_scale = move_toward(
			Engine.time_scale,
			_target_scale,
			transition_speed * real_delta
		)
	
	if is_slowed():
		var cons := tick_consumption * real_delta
		if not bar.try_consume(cons):
			resume()
	else:
		if not bar.is_full():
			var reg = tick_regen * real_delta
			bar.regenerate(reg)

func is_slowed() -> bool: return _active

func slow() -> bool:
	if is_slowed() or (
		activation_cost > 0.0
		and not bar.try_consume(activation_cost)
	): return false
	_active = true
	_target_scale = slow_scale
	DarkenManager.set_darken(0.8, 1.0 / transition_speed)
	slowed.emit()
	return true

func resume() -> bool:
	if not is_slowed(): return false
	_active = false
	_target_scale = normal_scale
	DarkenManager.set_darken(0.0, 1.0 / transition_speed)
	resumed.emit()
	return true
