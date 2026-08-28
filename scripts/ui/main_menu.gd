extends Control

const GAME_SCENE := "uid://c8ghost4gme01"

@export var scenes_to_warm: Array[String] = []

@onready var _level_select: Control = $LevelSelect

func _ready() -> void:
	Engine.time_scale = 1.0  # clear leftover slowmo when quitting out mid-game
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1, 1)  # tiny, barely renders
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	
	for scene_path in scenes_to_warm:
		var instance = load(scene_path).instantiate()
		viewport.add_child(instance)
	
	# Wait 2 frames for shaders to compile
	await get_tree().process_frame
	await get_tree().process_frame
	
	viewport.queue_free()
	
	SoundManager.play_music("TITLE_SCREEN")
	$Play.pressed.connect(_on_play_pressed)
	$Levels.pressed.connect(_on_levels_pressed)
	$Quit.pressed.connect(_on_quit_pressed)
	if _level_select:
		_level_select.hide()
	$Play.grab_focus()

func _set_main_buttons(shown: bool) -> void:
	$Play.visible = shown
	$Levels.visible = shown
	$Quit.visible = shown

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_levels_pressed() -> void:
	if _level_select:
		_set_main_buttons(false)
		_level_select.show()

func _load_level(path: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	# just a fallback incase resource isn't valid
	else:
		get_tree().change_scene_to_file(GAME_SCENE)

func _close_levels() -> void:
	if _level_select:
		_level_select.hide()
		_set_main_buttons(true)

func _on_quit_pressed() -> void:
	get_tree().quit()
