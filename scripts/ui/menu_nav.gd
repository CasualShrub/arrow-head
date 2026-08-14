extends RefCounted
class_name MenuNav

# Scene changes made from the pause and end screens. Each one lifts the pause
# first, otherwise the next scene loads frozen.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

static func restart(tree: SceneTree) -> void:
	tree.paused = false
	tree.reload_current_scene()

static func to_menu(tree: SceneTree) -> void:
	go(tree, MAIN_MENU)

static func go(tree: SceneTree, path: String) -> void:
	tree.paused = false
	tree.change_scene_to_file(path)
