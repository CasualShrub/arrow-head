extends Node
class_name ArrowTrajectoryVisualiser

@export var simulation_lookahead := 1.0
@export var simulation_frame_rate := 30:
	set(value):
		_frame_step = 1.0 / simulation_frame_rate

var _frame_step := 0.0

var _arrow: Arrow

func _init(arrow: Arrow) -> void:
	set_arrow(arrow)

func get_arrow() -> Arrow:
	return _arrow

func set_arrow(arrow: Arrow) -> void:
	if _arrow: clear_arrow()
	_arrow = arrow
	_arrow.tree_exited.connect(_on_arrow_exiting)

func clear_arrow() -> void:
	if not _arrow: return
	_arrow.tree_exited.disconnect(_on_arrow_exiting)
	_arrow = null

func _on_arrow_exiting() -> void:
	queue_free()
	_arrow = null

func update_display(lookahead: float = simulation_lookahead) -> void:
	if not _arrow.is_active(): return
	var positions: Array[Vector3] = []
	var sim = _arrow.create_simulation()
	for i in range(lookahead * simulation_frame_rate):
		_arrow.simulate(sim, _frame_step)
		positions.append(sim.position)
	var inst = MeshInstance3D.new()
	inst.mesh = build_ribbon(positions, 1.0)

func build_ribbon(
	points: Array[Vector3],
	width: float,
	camera_up: Vector3 = Vector3.UP
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var dir := (points[min(i + 1, points.size() - 1)] - points[max(i - 1, 0)]).normalized()
		var side := dir.cross(camera_up).normalized() * (width * 0.5)
		var uv_y := float(i) / float(points.size() - 1)
		st.set_uv(Vector2(0, uv_y))
		st.add_vertex(points[i] - side)
		st.set_uv(Vector2(1, uv_y))
		st.add_vertex(points[i] + side)
	return st.commit()
