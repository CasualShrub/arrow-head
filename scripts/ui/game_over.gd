extends EndScreen

@export var death_anim_delay := 1.0

func _on_encounter_ended(won: bool) -> void:
	if won:
		return
	_show_time()
	await get_tree().create_timer(death_anim_delay).timeout
	open()
