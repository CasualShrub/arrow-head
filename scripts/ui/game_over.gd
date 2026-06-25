extends CanvasLayer

@onready var _root: Control = $Root

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false

func _on_encounter_ended(won: bool) -> void:
	if won:
		return
	_root.visible = true
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().paused = false
		get_tree().reload_current_scene()
