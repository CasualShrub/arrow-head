extends CanvasLayer

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Continue.pressed.connect(_on_continue_pressed)
	%MainMenu.pressed.connect(_on_main_menu_pressed)
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_resume()
		else:
			_pause()

func _pause() -> void:
	get_tree().paused = true
	show()

func _resume() -> void:
	get_tree().paused = false
	hide()

func _on_continue_pressed() -> void:
	_resume()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
