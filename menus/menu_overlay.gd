extends CanvasLayer
class_name MenuOverlay

# Shared behaviour for the pause menu and the two end screens. They all freeze
# the tree while open, wire the same Restart and Main Menu buttons and answer
# the same keys. The primary button is Continue on the pause and game over
# screens and Next Level on the cleared one.

@export var primary_button := "Continue"

const GROUP := &"menu_overlays"

@onready var _root: Control = get_node_or_null("%Root")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	var primary := get_node_or_null("%" + primary_button)
	if primary:
		primary.pressed.connect(_on_primary)
	%Restart.pressed.connect(restart)
	%MainMenu.pressed.connect(to_menu)
	%MainMenu.completed.connect(to_menu)   # held the key down
	var container: Node = _root if _root else get_node("VBoxContainer")
	for button in container.find_children("*", "Button", true, false):
		button.focus_mode = Control.FOCUS_ALL
		FocusFeedback.attach(button, 1.04)
	_set_open(false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open(): return
	if event.is_action_pressed("restart"):
		restart()
		get_viewport().set_input_as_handled()

# the end screens dim behind a Root control, the pause menu is the layer itself
func is_open() -> bool:
	return _root.visible if _root else visible

static func any_open(tree: SceneTree) -> bool:
	return tree.get_nodes_in_group(GROUP).any(func(overlay: MenuOverlay) -> bool: return overlay.is_open())

func _set_open(value: bool) -> void:
	if _root:
		_root.visible = value
	else:
		visible = value

func open() -> void:
	_set_open(true)
	get_tree().paused = true
	var primary := get_node_or_null("%" + primary_button) as Control
	if primary:
		primary.grab_focus()

func close() -> void:
	get_viewport().gui_release_focus()
	_set_open(false)
	get_tree().paused = false

func _on_primary() -> void:
	pass

func restart() -> void:
	MenuNav.restart(get_tree())

func to_menu() -> void:
	MenuNav.to_menu(get_tree())
