@tool
@icon("res://addons/at-icons/used/node3d/itinerary.svg")
extends Node3D
class_name PatrolPath

@export_tool_button("Add Point", "Add")
var add_button := add_point_auto
@export_tool_button("Clear Points", "Clear")
var clear_button := clear_points
@export var loop := false:
	set(value):
		loop = value
		_update_debug()
@export_group("Display")
@export var debug_color := Color(0.0, 0.6, 0.702, 0.42):
	set(value):
		debug_color = value
		if is_instance_valid(_line_material):
			_line_material.albedo_color = value
		_update_debug()
@export var debug_draw := true:
	set(value):
		debug_draw = value
		_update_debug()
@export var debug_line_width := 0.05:
	set(value):
		debug_line_width = value
		_update_debug()
@export var debug_show_point_numbers := true:
	set(value):
		debug_show_point_numbers = value
		_update_debug()

const POINT_NAME := "Point"
const MARKER_EXTENTS := 0.2

var _line_mesh: ImmediateMesh
var _line_instance: MeshInstance3D
var _line_material: StandardMaterial3D

func _ready() -> void:
	_update_debug()
	
	child_entered_tree.connect(_on_child_entered_tree)
	#child_order_changed.connect(_update_debug)
	#child_exiting_tree.connect(_update_debug)
	for child in get_children():
		_try_connect_point(child)

func _notification(what: int) -> void:
	if not Engine.is_editor_hint(): return
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_debug()
	elif what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_update_debug()

func get_length() -> float:
	var points := get_points()
	var dist := 0.0
	for i in range(points.size() - 1):
		var pos := points[i].global_position
		var next_pos := points[i + 1].global_position
		dist += pos.distance_to(next_pos)
	
	if loop and is_loop_active(points):
		var last_pos := points[-1].global_position
		var first_pos := points[0].global_position
		dist += last_pos.distance_to(first_pos)
	return dist

func get_position_at_distance_along(dist: float) -> Vector3:
	var points := get_points()
	if points.is_empty():
		return Vector3.ZERO
	elif points.size() == 1:
		return points[0].global_position
	
	var total_len := get_length()
	var cycle := total_len if loop else total_len * 2
	var remaining := fmod(dist, cycle)
	if remaining > total_len:
		remaining = cycle - remaining
	
	for i in range(points.size() - 1):
		var pos := points[i].global_position
		var next_pos := points[i + 1].global_position
		var section_length := pos.distance_to(next_pos)
		
		if remaining <= section_length:
			if section_length == 0.0:
				return next_pos
			else:
				return pos.lerp(next_pos, remaining / section_length)
		remaining -= section_length
	if loop:
		var last_pos := points[-1].global_position
		var first_pos := points[0].global_position
		var section_length := last_pos.distance_to(first_pos)
		
		if remaining <= section_length:
			if section_length == 0.0:
				return first_pos
			else:
				return last_pos.lerp(first_pos, remaining / section_length) 
	
	return points[-1].global_position

func get_position_at_percentage(p: float) -> Vector3:
	var dist = get_length() * p
	return get_position_at_distance_along(dist)

static func is_loop_active(points: Array[PatrolPoint]) -> bool:
	return points.size() > 2

func _update_debug() -> void:
	if not Engine.is_editor_hint(): return
	_update_line()
	_update_points()

func _update_line() -> void:
	_ensure_line()
	
	if not is_instance_valid(_line_mesh):
		push_warning("Invalid line mesh.")
		return
	
	_line_mesh.clear_surfaces()
	if not debug_draw:
		return
	
	var points := get_points()
	if points.size() < 2:
		return
	
	_line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(points.size() - 1):
		_add_line_segment(
			points[i].global_position,
			points[i + 1].global_position
		)
	
	# go back to first if loop
	if loop and is_loop_active(points):
		_add_line_segment(
			points.back().global_position,
			points.front().global_position
		)
	
	_line_mesh.surface_end()

func _ensure_line() -> void:
	if is_instance_valid(_line_instance): return
	
	_line_mesh = ImmediateMesh.new()
	
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_material.albedo_color = debug_color
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_line_instance = MeshInstance3D.new()
	_line_instance.name = "__PatrolLine"
	_line_instance.mesh = _line_mesh
	_line_instance.material_override = _line_material
	
	add_child(_line_instance)
	
	# dont save
	_line_instance.owner = null

func _add_line_segment(
	start: Vector3,
	end: Vector3
) -> void:
	var direction := end - start
	
	if direction.length_squared() < 0.0001:
		return

	direction = direction.normalized()
	
	var side := Vector3(
		-direction.z,
		0.0,
		direction.x
	)

	if side.length_squared() < 0.0001:
		return

	side = side.normalized()

	var half_width := debug_line_width * 0.5

	var start_left := _line_instance.to_local(start + side * half_width)
	var start_right := _line_instance.to_local(start - side * half_width)

	var end_left := _line_instance.to_local(end + side * half_width)
	var end_right := _line_instance.to_local(end - side * half_width)

	# first tri
	_line_mesh.surface_add_vertex(start_left)
	_line_mesh.surface_add_vertex(end_left)
	_line_mesh.surface_add_vertex(end_right)

	# second tri
	_line_mesh.surface_add_vertex(start_left)
	_line_mesh.surface_add_vertex(end_right)
	_line_mesh.surface_add_vertex(start_right)

func _update_points() -> void:
	var points := get_points()
	for i in range(points.size()):
		var point := points[i]
		if debug_show_point_numbers:
			point.set_display_text(str(i + 1))
		else:
			point.hide_display_number()

func add_point_auto(idx: int = get_point_count()) -> void:
	var pos := _get_new_point_position(idx)

	var point := add_point(pos, idx)
	
	# force select new point
	EditorInterface.call_deferred("edit_node", point)

func _get_new_point_position(idx: int) -> Vector3:
	var points := get_points()
	if idx == 0:
		if points.size() == 0:
			return global_position
		else:
			var second_pos := points[1].global_position
			var first_pos := points[0].global_position
			var motion := first_pos - second_pos
			return first_pos + motion
	elif idx == 1 and points.size() == 1:
		return points[0].global_position + Vector3.FORWARD
	else:
		if points.size() > idx:
			var prev_pos := points[idx - 1].global_position
			var next_pos := points[idx].global_position
			return prev_pos.lerp(next_pos, 0.5)
		else:
			var last_pos := points[idx - 1].global_position
			var second_last_pos := points[idx - 2].global_position
			var motion := last_pos - second_last_pos
			return last_pos + motion

func get_points() -> Array[PatrolPoint]:
	var points: Array[PatrolPoint] = []
	for c in get_children():
		if c is PatrolPoint:
			points.append(c)
	return points

func get_point_count() -> int:
	var s := 0
	for c in get_children():
		if c is PatrolPoint:
			s += 1
	return s

func get_point_number(point: PatrolPoint) -> int:
	var n := 0
	for c in get_children():
		if c is PatrolPoint:
			if c == point:
				return n
			n += 1
	return -1

func add_point(at: Vector3, idx: int = get_point_count()) -> PatrolPoint:
	at.y = global_position.y
	var point := PatrolPoint.new()
	point.position = to_local(at)
	point.gizmo_extents = MARKER_EXTENTS
 
	if Engine.is_editor_hint():
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Add Patrol Point")
		undo_redo.add_do_method(self, "_do_add_point", point, idx)
		undo_redo.add_do_reference(point)
		undo_redo.add_undo_method(self, "_do_remove_point", point)
		undo_redo.commit_action()
	else:
		_do_add_point(point, idx)
	
	point.name = POINT_NAME 

	return point

func _do_add_point(point: PatrolPoint, idx: int) -> void:
	add_child(point)
	move_child(point, idx)
	
	var edited_scene = get_tree().edited_scene_root
	if edited_scene:
		point.owner = edited_scene

func _do_remove_point(point: PatrolPoint) -> void:
	if point.get_parent() == self:
		remove_child(point)

func remove_point(point: PatrolPoint) -> void:
	if Engine.is_editor_hint():
		var idx := get_point_number(point)
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Remove Patrol Point")
		undo_redo.add_do_method(self, "_do_remove_point", point)
		undo_redo.add_undo_method(self, "_do_add_point", point, idx)
		undo_redo.add_undo_reference(point)
		undo_redo.commit_action()
	else:
		point.queue_free()

func move_point_earlier(point: PatrolPoint) -> void:
	var n := get_point_number(point)
	if n == -1 or n == 0: return
	_move_point(point, n, n - 1)

func move_point_later(point: PatrolPoint) -> void:
	var n := get_point_number(point)
	if n == -1 or n == get_point_count() - 1: return
	_move_point(point, n, n + 1)

func _move_point(point: PatrolPoint, from_idx: int, to_idx: int) -> void:
	if Engine.is_editor_hint():
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Reorder Patrol Point")
		undo_redo.add_do_method(self, "_do_move_point", point, to_idx)
		undo_redo.add_undo_method(self, "_do_move_point", point, from_idx)
		undo_redo.commit_action()
	else:
		_do_move_point(point, to_idx)

func _do_move_point(point: PatrolPoint, idx: int) -> void:
	move_child(point, idx)

func clear_points() -> void:
	var points := get_points()
	
	if Engine.is_editor_hint():
		var undo_redo := EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Clear Patrol Points")
		for i in range(points.size()):
			var point := points[i]
			undo_redo.add_do_method(self, "_do_remove_point", point)
			undo_redo.add_undo_method(self, "_do_add_point", point, i)
			undo_redo.add_undo_reference(point)
		undo_redo.commit_action()
	else:
		for point in points:
			point.queue_free()
	for n in get_children():
		if n is PatrolPoint:
			remove_point(n as PatrolPoint)
	_update_debug()

func _try_connect_point(child: Node) -> void:
	if child is not PatrolPoint: return
	var point := child as PatrolPoint
	if not point.changed.is_connected(_update_debug):
		point.changed.connect(_update_debug)

func _on_child_entered_tree(child: Node) -> void:
	if child is not PatrolPoint: return
	_try_connect_point(child)
