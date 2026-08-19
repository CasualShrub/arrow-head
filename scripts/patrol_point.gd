@tool
extends Marker3D
class_name PatrolPoint

@export_tool_button("Move Earlier", "Back")
var move_earlier_button := move_earlier
@export_tool_button("Move Later", "Forward")
var move_later_button := move_later
@export_tool_button("Add Before", "InsertBefore")
var add_before_button := add_before
@export_tool_button("Add After", "InsertAfter")
var add_after_button := add_after
@export_tool_button("Remove", "Remove")
var remove_button := remove

signal changed()

var _label: Label3D

func _ready() -> void:
	if not Engine.is_editor_hint(): return
	
	_ensure_display_number()

func _notification(what: int) -> void:
	if not Engine.is_editor_hint(): return
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		changed.emit()

func get_number() -> int:
	var parent = get_parent()
	if parent is PatrolPath:
		return parent.get_point_number(self)
	return -1

func move_earlier() -> void:
	var parent = get_parent()
	if parent is PatrolPath:
		parent.move_point_earlier(self)

func move_later() -> void:
	var parent := get_parent()
	if parent is PatrolPath:
		parent.move_point_later(self)

func add_before() -> void:
	var parent := get_parent()
	if parent is PatrolPath:
		parent.add_point_auto(self.get_number())

func add_after() -> void:
	var parent := get_parent()
	if parent is PatrolPath:
		parent.add_point_auto(self.get_number() + 1)

func remove() -> void:
	var parent = get_parent()
	if parent is PatrolPath:
		parent.call_deferred("remove_point", self)

func _ensure_display_number() -> void:
	_label = Label3D.new()
	
	_label.owner = null

func set_display_text(txt: String) -> void:
	if not is_instance_valid(_label): return
	show_display_number()
	_label.text = txt

func show_display_number() -> void:
	if not is_instance_valid(_label) or _label.visible: return
	_label.show()

func hide_display_number() -> void:
	if not is_instance_valid(_label) or not _label.visible: return
	_label.hide()
