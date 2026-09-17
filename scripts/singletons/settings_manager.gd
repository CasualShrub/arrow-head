extends Node

signal changed
signal mouse_sensitivity_changed(value: float)

const PATH := "user://settings.cfg"
const SAVE_DELAY := 0.25
const SENSITIVITY_MIN := 0.5
const SENSITIVITY_MAX := 1.5
const CONTRAST_MIN := 0.5
const CONTRAST_MAX := 1.5

var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
var mouse_sensitivity := 1.0
var fullscreen := false
var grayscale := false
var contrast := 1.0

var _filter: ColorRect
var _save_timer := Timer.new()
var _dirty := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.ignore_time_scale = true
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	_build_filter()
	_load()
	_apply()

func _notification(what: int) -> void:
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE) and _dirty:
		save()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus(&"Master", master_volume)
	_changed()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus(&"Music", music_volume)
	_changed()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus(&"SFX", sfx_volume)
	_changed()

func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, SENSITIVITY_MIN, SENSITIVITY_MAX)
	mouse_sensitivity_changed.emit(mouse_sensitivity)
	_changed()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_changed()

func set_grayscale(on: bool) -> void:
	grayscale = on
	_apply_filter()
	_changed()

func set_contrast(v: float) -> void:
	contrast = clampf(v, CONTRAST_MIN, CONTRAST_MAX)
	_apply_filter()
	_changed()

func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	mouse_sensitivity = 1.0
	fullscreen = false
	grayscale = false
	contrast = 1.0
	_apply()
	_apply_window()
	mouse_sensitivity_changed.emit(mouse_sensitivity)
	_changed()

func save() -> void:
	_save_timer.stop()
	_dirty = false
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "grayscale", grayscale)
	cfg.set_value("video", "contrast", contrast)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	grayscale = bool(cfg.get_value("video", "grayscale", false))
	contrast = clampf(float(cfg.get_value("video", "contrast", 1.0)), CONTRAST_MIN, CONTRAST_MAX)
	mouse_sensitivity = clampf(float(cfg.get_value("controls", "mouse_sensitivity", 1.0)), SENSITIVITY_MIN, SENSITIVITY_MAX)

func _changed() -> void:
	changed.emit()
	_dirty = true
	_save_timer.start()

func _apply() -> void:
	_apply_bus(&"Master", master_volume)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)
	_apply_filter()
	if fullscreen:
		_apply_window()

func _apply_bus(bus: StringName, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.0)
	if v > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))

func _apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_filter() -> void:
	var mat := _filter.material as ShaderMaterial
	mat.set_shader_parameter(&"grayscale", 1.0 if grayscale else 0.0)
	mat.set_shader_parameter(&"contrast", contrast)
	_filter.visible = grayscale or not is_equal_approx(contrast, 1.0)

func _build_filter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/display_filter.gdshader")
	_filter = ColorRect.new()
	_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.material = mat
	layer.add_child(_filter)
