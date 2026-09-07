extends Control

const GAME_SCENE := "uid://c8ghost4gme01"

@export var scenes_to_warm: Array[String] = []

@onready var _level_select: Control = $LevelSelect
@onready var _sectors: Control = $"Sectors (Buttons)"
@onready var _apple: Control = $Apple
@onready var _title: Control = $Title
@onready var _labels := {
	&"play": $Labels/Play,
	&"levels": $Labels/Levels,
	&"exit": $Labels/Exit,
}
var _label_base_scale := {}

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
	for key in _labels:
		_label_base_scale[key] = _labels[key].scale  # keep the size set in the editor
	_sectors.sector_activated.connect(_on_sector_activated)
	_sectors.sector_hovered.connect(_on_sector_hovered)
	_on_sector_hovered(&"")
	if _level_select:
		_level_select.hide()

func _on_sector_activated(sector: StringName) -> void:
	match sector:
		&"play":
			get_tree().change_scene_to_file(GAME_SCENE)
		&"levels":
			_open_levels()
		&"exit":
			get_tree().quit()

func _on_sector_hovered(sector: StringName) -> void:
	for key in _labels:
		var label: Control = _labels[key]
		var active: bool = key == sector
		var base: Vector2 = _label_base_scale.get(key, label.scale)
		label.scale = base * 1.08 if active else base
		label.modulate = Color.WHITE if active else Color(0.86, 0.86, 0.86)

func _set_menu_shown(shown: bool) -> void:
	_sectors.visible = shown
	_apple.visible = shown
	_title.visible = shown
	$Labels.visible = shown

func _open_levels() -> void:
	if _level_select:
		_set_menu_shown(false)
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
		_set_menu_shown(true)
