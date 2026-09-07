@icon("res://addons/at-icons/used/node/glass.svg")
extends Node
class_name BarComponent

@export var init_value := 0.0
@export var max_value := 1.0
@export var tick_regen := 1.0

signal changed(current: float)
signal consumed(amount: float)
signal regenerated(amount: float)

@onready var value := init_value:
	set(val):
		val = clampf(val, 0.0, max_value)
		if val == value: return
		value = val
		changed.emit(val)

func try_consume(amount: float) -> bool:
	if amount <= 0.0: return true
	if not can_consume(amount): return false
	consume(amount)
	return true

func can_consume(amount: float) -> bool:
	return value >= amount

func consume(amount: float) -> void:
	value -= amount
	consumed.emit(amount)

func regenerate(amount: float) -> void:
	amount = max(amount, 0)
	value += amount
	regenerated.emit(amount)

func is_full() -> bool:
	return value == max_value

## Returns the percent of the max value the bar is at.
func get_percentage() -> float:
	return value / max_value
