extends Area3D
class_name ExitArea

signal player_entered()
signal locked_changed(is_locked: bool)

var _locked := true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func is_locked() -> bool:
	return _locked

func lock() -> void:
	if _locked: return
	_locked = true
	locked_changed.emit(true)

func unlock() -> void:
	if not _locked: return
	_locked = false
	locked_changed.emit(false)
	for body in get_overlapping_bodies():
		if body is Player:
			player_entered.emit()
			return

func _on_body_entered(body: Node3D) -> void:
	if _locked: return
	if body is Player:
		player_entered.emit()
