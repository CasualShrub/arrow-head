extends Node

const PATH := "user://settings.cfg"

var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
var fullscreen := false

func _ready() -> void:
	_load()
	apply()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	_save()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	_save()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	_save()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	_save()

func apply() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# route a 0..1 slider value to a named bus in dB (volume is perceived logarithmically)
func _apply_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0: return  # bus layout missing/renamed — skip instead of erroring
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = cfg.get_value("audio", "master", 1.0)
	music_volume = cfg.get_value("audio", "music", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx", 1.0)
	fullscreen = cfg.get_value("video", "fullscreen", false)
