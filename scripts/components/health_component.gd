extends Node
class_name HealthComponent

@export var current := 0:
	set(value):
		current = clamp(value, 0, max_value)
		changed.emit()
@export var max_value := 100:
	set(value):
		if current > value:
			current = value
		max_value = value

signal changed

func take_damage(amount: int):
	current -= amount

func heal(amount: int):
	current += amount
