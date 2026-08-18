extends Node
class_name HealthComponent

@export var value := 0:
	set(v):
		if not is_vulnerable(): return
		v = clamp(value, 0, max_value)
		if value == v: return
		value = v
		if value == 0:
			die()
		changed.emit(value)
@export var max_value := 100:
	set(v):
		if value > v:
			value = v
		max_value = value

signal changed(current: int)
signal damaged(amount: int)
signal healed(amount: int)
signal vulnerability_toggled(is_vulnerable: bool)
signal died()
signal revived()

var _vuln := true
var _dead := false

func _ready() -> void:
	value = max_value

func take_damage(amount: int) -> void:
	value -= amount
	damaged.emit(amount)

func heal(amount: int) -> void:
	value += amount
	healed.emit(amount)

func is_vulnerable() -> bool:
	return _vuln

func make_vulnerable() -> void:
	if is_vulnerable(): return
	_vuln = true
	vulnerability_toggled.emit(true)

func make_invulnerable() -> void:
	if not is_vulnerable(): return
	_vuln = false
	vulnerability_toggled.emit(false)

func is_dead() -> bool:
	return _dead

func die() -> void:
	if is_dead() or not is_vulnerable(): return
	value = 0
	_dead = true
	died.emit()

func revive() -> void:
	if not is_dead(): return
	_dead = false
	revived.emit()
