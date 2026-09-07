@tool
extends Control

signal sector_activated(sector: StringName)
signal sector_hovered(sector: StringName)

@export_group("Play")
@export var play_center: float = 205.0:
	set(v): play_center = v; queue_redraw()
@export var play_half: float = 50.0:
	set(v): play_half = v; queue_redraw()
@export_group("Levels")
@export var levels_center: float = -33.0:
	set(v): levels_center = v; queue_redraw()
@export var levels_half: float = 38.0:
	set(v): levels_half = v; queue_redraw()
@export_group("Exit")
@export var exit_center: float = 47.0:
	set(v): exit_center = v; queue_redraw()
@export var exit_half: float = 38.0:
	set(v): exit_half = v; queue_redraw()

@export_group("Layout")
@export var center_offset: Vector2 = Vector2(0, 80):
	set(v): center_offset = v; queue_redraw()

var _hovered: StringName = &""

func _sectors() -> Array:
	return [
		{"name": &"play", "c": play_center, "h": play_half, "col": Color(0.31, 0.61, 1.0)},
		{"name": &"levels", "c": levels_center, "h": levels_half, "col": Color(1.0, 0.69, 0.23)},
		{"name": &"exit", "c": exit_center, "h": exit_half, "col": Color(1.0, 0.35, 0.35)},
	]

func _center() -> Vector2:
	return size * 0.5 + center_offset

func _angle_at(p: Vector2) -> float:
	var d := p - _center()
	return rad_to_deg(atan2(d.y, d.x))

func _get_angle_distance(a: float, b: float) -> float:
	var d := fmod(absf(a - b), 360.0)
	return minf(d, 360.0 - d)

func _sector_at(pos: Vector2) -> StringName:
	var angle := _angle_at(pos)
	var best := &""
	var best_d := INF
	for s in _sectors():
		var d := _get_angle_distance(angle, s["c"])
		if d <= s["h"] and d < best_d:
			best_d = d
			best = s["name"]
	return best

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var s := _sector_at(event.position)
		if s != _hovered:
			_hovered = s
			sector_hovered.emit(s)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var s := _sector_at(event.position)
		sector_activated.emit(s)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT and _hovered != &"":
		_hovered = &""
		sector_hovered.emit(_hovered)
		queue_redraw()

func _edge_point(angle_deg: float) -> Vector2:
	var c := _center()
	var dir := Vector2(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg)))
	var t := INF
	if dir.x > 0.0001:
		t = minf(t, (size.x - c.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, -c.x / dir.x)
	if dir.y > 0.0001:
		t = minf(t, (size.y - c.y) / dir.y)
	elif dir.y < -0.0001:
		t = minf(t, -c.y / dir.y)
	return c + dir * t

func _wedge(angle1: float, angle2: float) -> PackedVector2Array:
	var c := _center()
	var angles: Array[float] = [angle1, angle2]
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var centeredAngle := rad_to_deg(atan2(corner.y - c.y, corner.x - c.x))
		while centeredAngle <= angle1:
			centeredAngle += 360.0
		if centeredAngle > angle1 and centeredAngle < angle2:
			angles.append(centeredAngle)
	angles.sort()
	var pts := PackedVector2Array([c])
	for a in angles:
		pts.append(_edge_point(a))
	return pts

func _draw() -> void:
	var c := _center()
	var editor := Engine.is_editor_hint()
	for s in _sectors():
		var col: Color = s["col"]
		var a0: float = s["c"] - s["h"]
		var a1: float = s["c"] + s["h"]
		var poly := _wedge(a0, a1)
		if editor:
			draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.22))
		elif _hovered == s["name"]:
			draw_colored_polygon(poly, Color(1, 1, 1, 0.10))
		var edge_col := Color(col.r, col.g, col.b, 0.9) if editor else Color(1, 1, 1, 0.22)
		draw_line(c, _edge_point(a0), edge_col, 3.0)
		draw_line(c, _edge_point(a1), edge_col, 3.0)
