@icon("res://addons/at-icons/used/node3d/ground.svg")
extends Node3D
class_name JuiceSplatter

const DEFAULT_STYLE: JuiceSplatStyle = preload("res://systems/blood/juice_splat_hit.tres")
const NODE_NAME := &"JuiceSplatter"
const FALLBACK_FLOOR_HEIGHT := -0.2
const FLOOR_OFFSET := 0.01
const LAYER_STEP := 0.0005
const LAYER_COUNT := 16
const DROP_RENDER_PRIORITY := 0

var _floor_height := FALLBACK_FLOOR_HEIGHT
var _layer := 0
var _materials: Dictionary[String, StandardMaterial3D] = {}
var _style_roots: Dictionary[JuiceSplatStyle, Node3D] = {}
var _drop_meshes: Dictionary[JuiceSplatStyle, SphereMesh] = {}
var _drop_materials: Dictionary[String, StandardMaterial3D] = {}

static func splat(
	at: Vector3,
	direction: Vector3,
	color: Color,
	size := 1.0,
	style: JuiceSplatStyle = DEFAULT_STYLE
) -> void:
	if not VisualFeatureManager.blood: return
	var splatter := _get_splatter()
	if not splatter: return
	splatter.add_splat(at, direction, color, size, style)

static func spurt(
	from: Vector3,
	landing: Vector3,
	color: Color,
	size := 1.0,
	style: JuiceSplatStyle = DEFAULT_STYLE
) -> void:
	if not VisualFeatureManager.blood: return
	var splatter := _get_splatter()
	if not splatter: return
	splatter.add_spurt(from, landing, color, size, style)

static func _get_splatter() -> JuiceSplatter:
	var room := _get_room()
	if not room: return null
	var existing := room.get_node_or_null(NodePath(NODE_NAME)) as JuiceSplatter
	if existing: return existing
	var splatter := JuiceSplatter.new()
	splatter.name = NODE_NAME
	room.add_child(splatter)
	return splatter

static func _get_room() -> Room:
	var level := GameManager.current_level
	if level and level.current_room:
		return level.current_room
	var tree := Engine.get_main_loop() as SceneTree
	if not tree: return null
	var scene := tree.current_scene
	if scene is Room:
		return scene as Room
	if scene:
		var rooms := scene.find_children("*", "Room", true, false)
		if not rooms.is_empty():
			return rooms[0] as Room
	return null

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var room_floor := get_parent().get_node_or_null(^"Floor") as Node3D
	if room_floor:
		_floor_height = room_floor.global_position.y

func add_splat(
	at: Vector3,
	direction: Vector3,
	color: Color,
	size := 1.0,
	style: JuiceSplatStyle = DEFAULT_STYLE
) -> void:
	var splat := MeshInstance3D.new()
	splat.mesh = _make_mesh(style, size)
	splat.material_override = _get_material(style, style.get_random_variant(), _random_shade(style, color))
	splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root := _get_style_root(style)
	root.add_child(splat)

	splat.global_position = Vector3(at.x, _next_height(), at.z)
	splat.global_basis = Basis(Vector3.UP, _random_yaw(style, direction))
	if randf() < 0.5:
		splat.scale = Vector3(1.0, 1.0, -1.0)

	_grow_in(style, splat)
	_trim_oldest(style, root)

func _get_style_root(style: JuiceSplatStyle) -> Node3D:
	if _style_roots.has(style):
		return _style_roots[style]
	var root := Node3D.new()
	root.name = style.resource_path.get_file().get_basename()
	add_child(root)
	_style_roots[style] = root
	return root

func add_spurt(
	from: Vector3,
	landing: Vector3,
	color: Color,
	size := 1.0,
	style: JuiceSplatStyle = DEFAULT_STYLE
) -> void:
	landing.y = _floor_height
	var drop := MeshInstance3D.new()
	drop.mesh = _get_drop_mesh(style)
	drop.material_override = _get_drop_material(color)
	drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drop)
	drop.global_position = from
	drop.scale = Vector3.ONE * size

	var flight_time := randf_range(style.air_time_range.x, style.air_time_range.y)
	var tween := drop.create_tween()
	tween.tween_method(_move_drop.bind(drop, from, landing, style.air_arc_height), 0.0, 1.0, flight_time)
	tween.tween_callback(_land_drop.bind(drop, from, landing, color, size, style))

func _move_drop(t: float, drop: Node3D, from: Vector3, landing: Vector3, arc_height: float) -> void:
	var arc := Vector3.UP * arc_height * 4.0 * t * (1.0 - t)
	drop.global_position = from.lerp(landing, t) + arc

func _land_drop(
	drop: Node3D,
	from: Vector3,
	landing: Vector3,
	color: Color,
	size: float,
	style: JuiceSplatStyle
) -> void:
	drop.queue_free()
	add_splat(landing, landing - from, color, size, style)

func _get_drop_mesh(style: JuiceSplatStyle) -> SphereMesh:
	if _drop_meshes.has(style):
		return _drop_meshes[style]
	var mesh := SphereMesh.new()
	mesh.radius = style.air_drop_radius
	mesh.height = style.air_drop_radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	_drop_meshes[style] = mesh
	return mesh

func _get_drop_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if _drop_materials.has(key):
		return _drop_materials[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = DROP_RENDER_PRIORITY
	mat.albedo_color = color
	_drop_materials[key] = mat
	return mat

func _make_mesh(style: JuiceSplatStyle, size: float) -> QuadMesh:
	var tex_size := Vector2(style.texture_size)
	var jitter := randf_range(1.0 - style.length_jitter, 1.0 + style.length_jitter)
	var length := style.world_length * size * jitter
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2(length, length * tex_size.y / tex_size.x)
	mesh.center_offset = Vector3((0.5 - style.origin_x / tex_size.x) * length, 0.0, 0.0)
	return mesh

func _random_shade(style: JuiceSplatStyle, color: Color) -> Color:
	var shade: float = style.shades.pick_random()
	return Color(color.r * shade, color.g * shade, color.b * shade, style.opacity)

func _random_yaw(style: JuiceSplatStyle, direction: Vector3) -> float:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return randf() * TAU
	var jitter := randf_range(-style.angle_jitter, style.angle_jitter)
	return atan2(-direction.z, direction.x) + jitter

func _next_height() -> float:
	var height := _floor_height + FLOOR_OFFSET + _layer * LAYER_STEP
	_layer = (_layer + 1) % LAYER_COUNT
	return height

func _grow_in(style: JuiceSplatStyle, splat: Node3D) -> void:
	var final_scale := splat.scale
	splat.scale = final_scale * style.grow_start_scale
	var tween := splat.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(splat, "scale", final_scale, style.grow_time)

func _trim_oldest(style: JuiceSplatStyle, root: Node3D) -> void:
	while root.get_child_count() > style.max_splats:
		var oldest := root.get_child(0)
		root.remove_child(oldest)
		oldest.queue_free()

func _get_material(style: JuiceSplatStyle, variant: int, tint: Color) -> StandardMaterial3D:
	var key := "%d_%d_%s" % [style.get_instance_id(), variant, tint.to_html(false)]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = style.get_texture(variant)
	mat.albedo_color = tint
	_materials[key] = mat
	return mat
