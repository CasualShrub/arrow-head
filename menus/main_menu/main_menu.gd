extends Control

@export var game_scene: PackedScene

@export var scenes_to_warm: Array[String] = []

@export_group("Arrows")
@export var play_arrow: Texture2D
@export var levels_arrow: Texture2D
@export var exit_arrow: Texture2D
@export var embed_ratio: float = 0.4

@export var launch_distance: float = 1500.0
@export var launch_time: float = 0.32
@export_group("Impact Shake")
@export var shake: ScreenShake

@onready var _level_select: Control = $LevelSelect
@onready var _sectors: Control = $"Sectors (Buttons)"
@onready var _apple: Control = $Apple
@onready var _title: Control = $Title
@onready var _launch_arrow: Sprite2D = $LaunchArrow

var _launching := false
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
	if _launching:
		return
	match sector:
		&"play":
			_launch(_sectors.play_center, play_arrow, func() -> void: get_tree().change_scene_to_packed(game_scene))
		&"levels":
			_launch(_sectors.levels_center, levels_arrow, _open_levels)
		&"exit":
			_launch(_sectors.exit_center, exit_arrow, func() -> void: get_tree().quit())

func _launch(sector_center_deg: float, texture: Texture2D, on_complete: Callable) -> void:
	_launching = true

	var apple_center: Vector2 = _apple.global_position + _apple.size * 0.5
	var sector_angle := deg_to_rad(sector_center_deg)
	var out_dir := Vector2(cos(sector_angle), sin(sector_angle))
	var start := apple_center + out_dir * launch_distance

	var rest_rotation := sector_angle + PI * 0.5
	_launch_arrow.texture = texture
	_launch_arrow.position = start
	_launch_arrow.rotation = rest_rotation
	_launch_arrow.show()

	var arrow_length := texture.get_height() * _launch_arrow.scale.y
	var end_pos := apple_center + out_dir * (arrow_length * embed_ratio)

	var tween := create_tween()
	tween.tween_property(_launch_arrow, "position", end_pos, launch_time) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	tween.tween_callback(shake.trigger)
	tween.tween_property(_launch_arrow, "rotation", rest_rotation, 0.35) \
		.from(rest_rotation - 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await tween.finished
	shake.intensity = 0.0
	get_viewport().canvas_transform = Transform2D.IDENTITY
	on_complete.call()
	_launch_arrow.hide()
	_launching = false

func _process(delta: float) -> void:
	if shake.intensity <= 0.0:
		return
	get_viewport().canvas_transform = Transform2D(0.0, shake.poll(delta))

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
		get_tree().change_scene_to_packed(game_scene)

func _close_levels() -> void:
	if _level_select:
		_level_select.hide()
		_set_menu_shown(true)
