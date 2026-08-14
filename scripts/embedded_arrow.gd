extends RefCounted
class_name EmbeddedArrow

var _arrow: Arrow
var _slot: int
var _can_fire := false

signal firingEnabled()
signal firingDisabled()
#signal arrowGrabbed(Arrow)

func is_fireable() -> bool:
	return _can_fire

func enable_firing() -> void:
	if is_fireable(): return
	_can_fire = true
	firingEnabled.emit()

func disable_firing() -> void:
	if not is_fireable(): return
	_can_fire = false
	firingDisabled.emit()

func get_arrow() -> Arrow:
	return _arrow

## removes the arrow reference, stopping it from being cleaned up
#func grab_arrow() -> Arrow:
	#var arrow := _arrow
	#_arrow = null
	#arrowGrabbed.emit(arrow)
	#return arrow
#
#func try_grab_arrow() -> Arrow:
	#if is_fireable():
		#return grab_arrow()
	#return null

func is_holding(arrow: Arrow) -> bool:
	return _arrow == arrow

func get_slot() -> int:
	return _slot

# used for autocleanup
#func _notification(what):
	#if what == NOTIFICATION_PREDELETE:
		#if _arrow:
			#_arrow.queue_free()

func _init(arrow: Arrow, slot: int) -> void:
	_arrow = arrow
	_slot = slot
