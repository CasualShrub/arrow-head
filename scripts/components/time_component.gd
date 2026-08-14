extends Node
class_name TimeComponent

@export_category("bar")
@export var max_bar := 1.0
@export var activation_cost := 0.0
@export var tick_regen := 0.05
@export var tick_consumption := 0.1

@export_category("slow")
@export var slow_scale := 0.2
@export var normal_scale := 1.0
@export var transition_speed := 1.0

signal bar_changed(current: float)
signal bar_consumed(amount: float)
signal activated()
signal deactivated()

var _curr_bar := 1.0:
	set(value):
		value = clampf(value, 0.0, max_bar)
		if value == _curr_bar: return
		bar_changed.emit(value)
		_curr_bar = value
var _active := false
var _target_scale := 1.0

func try_consume(amount: float) -> bool:
	if not can_pay(amount): return false
	consume(amount)
	return true

func can_pay(amount: float) -> bool:
	return _curr_bar >= amount

func consume(amount: float) -> void:
	if amount <= 0: return
	_curr_bar -= amount
	bar_consumed.emit(amount)

func is_slowed() -> bool: return _active

func slow() -> void:
	if is_slowed(): return
	if not try_consume(activation_cost): return
	_active = true
	_target_scale = slow_scale
	activated.emit()

func try_slow() -> bool:
	if can_pay(activation_cost):
		slow()
		return true
	return false

func resume() -> void:
	if not is_slowed(): return
	_active = false
	_target_scale = normal_scale
	deactivated.emit()

func _physics_process(delta: float) -> void:
	if Engine.time_scale != _target_scale:
		Engine.time_scale = lerpf(Engine.time_scale, _target_scale, transition_speed * delta)
	
	if is_slowed():
		_curr_bar -= tick_consumption * delta
	else:
		_curr_bar += tick_regen * delta
