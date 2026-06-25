extends CanvasLayer

func _ready() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if visible: hide()
		else: show()
