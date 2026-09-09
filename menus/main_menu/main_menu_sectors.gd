@tool
extends Control

signal sector_activated(sector: StringName)
signal sector_hovered(sector: StringName)

@export_group("Play")
@export var play_center: float = 205.0:
	set(v): play_center = v; queue_redraw()
@export var play_half: float = 50.0:
	set(v): play_half = v; queue_redraw()
@export var play_pattern: Texture2D 
@export_group("Levels")
@export var levels_center: float = -33.0:
	set(v): levels_center = v; queue_redraw()
@export var levels_half: float = 38.0:
	set(v): levels_half = v; queue_redraw()
@export var levels_pattern: Texture2D
@export_group("Exit")
@export var exit_center: float = 47.0:
	set(v): exit_center = v; queue_redraw()
@export var exit_half: float = 38.0:
	set(v): exit_half = v; queue_redraw()
@export var exit_pattern: Texture2D

@export_group("Layout")
@export var center_offset: Vector2 = Vector2(0, 80):
	set(v): center_offset = v; queue_redraw()

@export_group("Pattern")
@export var pattern_shader: Shader
@export var pattern_pan_speed: Vector2 = Vector2(-0.025, -0.025)
@export var pattern_tiling: Vector2 = Vector2(3, 2)

var _hovered: StringName = &""
var _hover_fill: Polygon2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mat := ShaderMaterial.new()
	mat.shader = pattern_shader
	mat.set_shader_parameter("pan_speed", pattern_pan_speed)
	mat.set_shader_parameter("tiling", pattern_tiling)
	_hover_fill = Polygon2D.new()
	_hover_fill.material = mat
	_hover_fill.show_behind_parent = true
	_hover_fill.hide()
	add_child(_hover_fill)

func _update_hover_fill() -> void:
	if _hover_fill == null:
		return
	if _hovered == &"":
		_hover_fill.hide()
		return
	for s in _sectors():
		if s["name"] == _hovered:
			var tex: Texture2D = s["tex"]
			if tex == null:
				_hover_fill.hide()
				return
			var poly := _wedge(s["c"] - s["h"], s["c"] + s["h"])
			_hover_fill.polygon = poly
			_hover_fill.texture = tex
			(_hover_fill.material as ShaderMaterial).set_shader_parameter("pattern", tex)
			var tex_size := tex.get_size()
			var uv := PackedVector2Array()
			for p in poly:
				uv.append(Vector2(p.x / maxf(size.x, 1.0), p.y / maxf(size.y, 1.0)) * tex_size)
			_hover_fill.uv = uv
			_hover_fill.show()
			return

func _sectors() -> Array:
	return [
		{"name": &"play", "c": play_center, "h": play_half, "col": Color(0.31, 0.61, 1.0), "tex": play_pattern},
		{"name": &"levels", "c": levels_center, "h": levels_half, "col": Color(1.0, 0.69, 0.23), "tex": levels_pattern},
		{"name": &"exit", "c": exit_center, "h": exit_half, "col": Color(1.0, 0.35, 0.35), "tex": exit_pattern},
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
			_update_hover_fill()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var s := _sector_at(event.position)
		sector_activated.emit(s)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_hover_fill()
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT and _hovered != &"":
		_hovered = &""
		sector_hovered.emit(_hovered)
		_update_hover_fill()
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
		var edge_col := Color(col.r, col.g, col.b, 0.9) if editor else Color(1, 1, 1, 0.22)
		draw_line(c, _edge_point(a0), edge_col, 3.0)
		draw_line(c, _edge_point(a1), edge_col, 3.0)
