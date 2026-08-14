extends MenuOverlay

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"): return
	if is_open():
		close()
	elif _can_pause():
		open()

func _can_pause() -> bool:
	var encounter := get_parent()
	if encounter and encounter.has_method("is_ongoing"):
		return encounter.is_ongoing()   # the end screens take over from here
	return true

func _on_primary() -> void:
	close()
