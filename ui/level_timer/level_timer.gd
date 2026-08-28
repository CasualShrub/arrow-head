@tool
extends Control
class_name LevelTimer

## Whether the timer will be affected by Engine.time_scale.
@export var scaled := true
@export var font_scale := 0.5:
	set(value):
		font_scale = value
		_update_scale()
@export var autostart := true
@export var start_time := 0.0

@onready var _label: Label = %TimeLabel

@onready var _elapsed := start_time
@onready var _running := autostart

func _ready() -> void:
	_update_scale()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running: return
	var real_delta := delta
	if not scaled:
		real_delta /= Engine.time_scale
	_elapsed += real_delta
	_label.text = format_time(_elapsed)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_scale()

func _update_scale() -> void:
	if not _label: return
	var min_size = min(size.x, size.y)
	_label.add_theme_font_size_override("font_size", min_size * font_scale)

func resume() -> void:
	_running = true

func pause() -> void:
	_running = false

func get_elapsed() -> float:
	return _elapsed

func reset() -> void:
	_elapsed = 0.0

static func format_time(t: float) -> String:
	var minutes := (t / 60) as int
	var seconds := (t as int) % 60
	var centis := int(fmod(t, 1.0) * 100.0)
	return "%02d:%02d.%02d" % [minutes, seconds, centis]
