extends Area3D
class_name TargetArea

signal targeted()
signal untargeted()
signal hit()

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
