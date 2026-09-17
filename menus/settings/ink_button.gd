extends TextureButton
class_name InkButton

@onready var _fill: CanvasItem = $Highlight

func _ready() -> void:
	button_down.connect(_refresh)
	button_up.connect(_refresh)
	_refresh()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT, NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_VISIBILITY_CHANGED:
			if is_node_ready():
				_refresh()

func _refresh() -> void:
	var mode := get_draw_mode()
	_fill.visible = is_hovered() or has_focus() or mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
