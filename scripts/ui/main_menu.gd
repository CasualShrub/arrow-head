extends Control

const TUTORIAL_SCENE := "res://scenes/levels/tutorial.tscn"

@onready var _level_select: Control = $LevelSelect

func _ready() -> void:
	SoundManager.play_music("TITLE_SCREEN")
	$Play.pressed.connect(_on_play_pressed)
	$Levels.pressed.connect(_on_levels_pressed)
	$Quit.pressed.connect(_on_quit_pressed)
	if _level_select:
		_level_select.hide()
		var back := _level_select.get_node_or_null("Back")
		if back:
			back.pressed.connect(_level_select.hide)
	$Play.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(TUTORIAL_SCENE)

func _on_levels_pressed() -> void:
	if _level_select:
		_level_select.show()

func _on_quit_pressed() -> void:
	get_tree().quit()
