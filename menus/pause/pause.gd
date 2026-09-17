@icon("res://addons/at-icons/used/control/pause.svg")
extends MenuOverlay

@onready var _settings: CanvasLayer = $Settings

func _ready() -> void:
	super()
	%SettingsButton.pressed.connect(_settings.open)
	_settings.opened.connect($VBoxContainer.hide)
	_settings.closed.connect($VBoxContainer.show)

func _input(event: InputEvent) -> void:
	if _settings.is_open() or not event.is_action_pressed("pause"): return
	if is_open():
		close()
	elif _can_pause():
		open()

func _unhandled_input(event: InputEvent) -> void:
	if not _settings.is_open():
		super(event)

func _can_pause() -> bool:
	var encounter := get_parent()
	if encounter and encounter.has_method("is_ongoing"):
		return encounter.is_ongoing()   # the end screens take over from here
	return true

func _on_primary() -> void:
	close()
