extends Node3D

@export var frames := 4
@export var quad_size := 0.015

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_prewarm")

func _prewarm() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var materials: Array[Material] = []
	_collect(get_tree().current_scene, materials)
	if materials.is_empty():
		return

	var holder := Node3D.new()
	cam.add_child(holder)

	var offset := -float(materials.size()) * quad_size * 0.5
	for m in materials:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(quad_size, quad_size)
		mi.mesh = quad
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(offset, 0.0, -0.25)
		offset += quad_size
		holder.add_child(mi)

	for _i in frames:
		await get_tree().process_frame

	holder.queue_free()

func _collect(node: Node, out: Array[Material]) -> void:
	if node is GeometryInstance3D:
		var go := node as GeometryInstance3D
		if go.material_override:
			_add(out, go.material_override)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				_add(out, mi.mesh.surface_get_material(i))
			for i in mi.get_surface_override_material_count():
				_add(out, mi.get_surface_override_material(i))
	if node is CSGPrimitive3D:
		_add(out, (node as CSGPrimitive3D).material)
	for c in node.get_children():
		_collect(c, out)

func _add(out: Array[Material], m: Material) -> void:
	if m and not out.has(m):
		out.append(m)
