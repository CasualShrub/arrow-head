extends Node
class_name ArrowsComponent

signal arrow_added(arrow: Arrow)
signal arrow_removed(arrow: Arrow)

@export var container: Node3D

var _arrows := ArrowSet.new()

func is_empty() -> bool:
	return _arrows.is_empty()

func is_full() -> bool:
	return false

func has_arrow(arrow: Arrow) -> bool:
	return _arrows.has(arrow)

func get_arrow_count() -> int:
	return _arrows.size()

func add_arrow(arrow: Arrow) -> bool:
	if has_arrow(arrow) or is_full() or not _can_add_arrow(arrow):
		return false
	_arrows.add(arrow)
	arrow.reparent(container)
	_on_arrow_added(arrow)
	arrow_added.emit(arrow)
	return true

## Destroys arrow if its found.[br]
## Returns whether or not arrow was destroyed.
func remove_arrow(arrow: Arrow) -> bool:
	if not has_arrow(arrow): return false
	_arrows.remove(arrow)
	_on_arrow_removed(arrow)
	arrow_removed.emit(arrow)
	arrow.queue_free()
	return true

func clear_arrows() -> void:
	for arrow in _arrows.to_array():
		remove_arrow(arrow)

func _can_add_arrow(_arrow: Arrow) -> bool:
	return true

func _on_arrow_added(_arrow: Arrow) -> void:
	pass
	
func _on_arrow_removed(_arrow: Arrow) -> void:
	pass
