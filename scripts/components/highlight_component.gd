extends Node
class_name HighlightComponent

@export var default_color := Color(0.5, 0, 0)

signal enabled(highlight_color: Color)
signal disabled()

var _current_color: Color
var _enabled := false

func is_enabled() -> bool:
	return _enabled

func enable(color: Color = default_color) -> void:
	if is_enabled(): return
	_enabled = true
	_current_color = color
	enabled.emit(color)
	
func disable() -> void:
	if not is_enabled(): return
	_enabled = false
	disabled.emit()
