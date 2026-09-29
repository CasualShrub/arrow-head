extends Node

const UNFILTERED_LAYER := 19
const PSX_LAYER := 5
const PSX_SHADER := preload("res://shaders/psx.gdshader")

var _mask_vp: SubViewport
var _mask_cam: Camera3D
var _psx_layer: CanvasLayer
var _main_cam: Camera3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_mask()
	_build_psx_layer()
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func _build_mask() -> void:
	_mask_vp = SubViewport.new()
	_mask_vp.transparent_bg = true
	_mask_vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask_vp)

	_mask_cam = Camera3D.new()
	_mask_cam.cull_mask = 0
	_mask_cam.set_cull_mask_value(UNFILTERED_LAYER, true)
	_mask_vp.add_child(_mask_cam)

func _build_psx_layer() -> void:
	_psx_layer = CanvasLayer.new()
	_psx_layer.layer = PSX_LAYER
	_psx_layer.visible = false
	add_child(_psx_layer)

	var mat := ShaderMaterial.new()
	mat.shader = PSX_SHADER
	mat.set_shader_parameter(&"mask_tex", _mask_vp.get_texture())

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	_psx_layer.add_child(rect)

func _on_resize() -> void:
	var size: Vector2i = get_viewport().size
	if _main_cam:
		size = _main_cam.get_viewport().size
	_mask_vp.size = size

func register_camera(cam: Camera3D) -> void:
	_main_cam = cam
	_mask_vp.world_3d = cam.get_world_3d()
	_psx_layer.visible = true
	cam.tree_exiting.connect(_on_camera_exiting.bind(cam), CONNECT_ONE_SHOT)
	_on_resize()

func _on_camera_exiting(cam: Camera3D) -> void:
	if _main_cam != cam: return
	_main_cam = null
	_psx_layer.visible = false

func sync_camera(cam: Camera3D) -> void:
	_mask_cam.global_transform = cam.global_transform
	_mask_cam.fov = cam.fov
	_mask_cam.near = cam.near
	_mask_cam.far = cam.far
	_mask_cam.keep_aspect = cam.keep_aspect
