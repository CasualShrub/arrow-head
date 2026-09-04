@icon("res://addons/at-icons/used/node3d/node_graph_target.svg")
extends Area3D
class_name TargetArea

signal targeted()
signal untargeted()
signal hit()
signal vulerability_changed(vulnerable: bool)

@export var is_vulnerable := true

var _targeted := false

func is_targeted() -> bool:
	return _targeted

func mark_targeted() -> void:
	if is_targeted(): return
	_targeted = true
	targeted.emit()

func mark_untargeted() -> void:
	if not is_targeted(): return
	_targeted = false
	untargeted.emit()

func mark_hit() -> void:
	hit.emit()

func make_vulnerable() -> void:
	if is_vulnerable: return
	is_vulnerable = true
	monitoring = true
	monitorable = true
	vulerability_changed.emit(true)

func make_invulnerable() -> void:
	if not is_vulnerable: return
	is_vulnerable = false
	monitoring = false
	monitorable = false
	mark_untargeted()
	vulerability_changed.emit(false)
