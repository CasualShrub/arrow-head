extends EndScreen

var _next_scene := "res://scenes/levels/level_1.tscn"

func _on_encounter_cleared(_won: bool, next_scene: String, is_last_level: bool) -> void:
	_show_time()
	_next_scene = next_scene
	if is_last_level:
		%NextLevel.text = "Finish"
	open()

func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_open(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_on_primary()

func _on_primary() -> void:
	MenuNav.go(get_tree(), _next_scene)
