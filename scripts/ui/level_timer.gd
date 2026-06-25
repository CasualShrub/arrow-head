extends CanvasLayer
class_name LevelTimer

@onready var _label: Label = %TimeLabel

var _elapsed := 0.0
var _running := true

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_label.text = format_time(_elapsed)

func stop(_a = null, _b = null, _c = null) -> void:
	_running = false
	hide()

func get_elapsed() -> float:
	return _elapsed

static func format_time(t: float) -> String:
	var total := int(t)
	var minutes := total / 60
	var seconds := total % 60
	var centis := int(fmod(t, 1.0) * 100.0)
	return "%02d:%02d.%02d" % [minutes, seconds, centis]
