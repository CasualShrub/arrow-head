@tool
extends Label

@export var base_text := "Loading"
@export var max_dots := 3
@export var interval := 0.4

var _dots := 0
var _elapsed := 0.0

func _ready() -> void:
	_refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < interval:
		return
	_elapsed -= interval
	_dots = (_dots + 1) % (max_dots + 1)
	_refresh()

func _refresh() -> void:
	text = base_text + ".".repeat(_dots)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		text = base_text
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_refresh()
