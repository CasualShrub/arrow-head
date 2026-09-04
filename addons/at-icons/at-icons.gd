@tool
extends EditorPlugin


var dock: EditorDock


func _enter_tree() -> void:
	dock = EditorDock.new()
	dock.title = "@icons"
	dock.dock_icon = preload("res://addons/at-icons/at.svg")
	dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL

	var dock_content := preload(
		"res://addons/at-icons/icon_browser.tscn"
	).instantiate()

	dock.add_child(dock_content)
	add_dock(dock)


func _exit_tree() -> void:
	if dock:
		remove_dock(dock)
		dock.queue_free()
		dock = null
