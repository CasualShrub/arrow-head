extends Node
class_name HealthComponent

@export var current := 0:
	set(value):
		current = clamp(value, 0, max)
		changed.emit()
@export var max := 100:
	set(value):
		if current > value:
			current = value
		max = value

signal changed

func take_damage(amount: int):
	current -= amount
	
func heal(amount: int):
	current += amount
