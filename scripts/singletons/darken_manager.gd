extends Node

const EXCLUDE_LAYER := 20


var _main_cam: Camera3D
var mask_vp: SubViewport
var mask_cam: Camera3D
var _darken_rect: ColorRect

var _darken_tween: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mask_vp = SubViewport.new()
	mask_vp.transparent_bg = true
	mask_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mask_vp)

	mask_cam = Camera3D.new()
	mask_cam.cull_mask = 0
	mask_cam.set_cull_mask_value(EXCLUDE_LAYER, true)
	mask_cam.current = true
	mask_vp.add_child(mask_cam)

	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func register_camera(cam: Camera3D) -> void:
	print("cam reistered ", cam)
	_main_cam = cam

	_on_resize()

func register_overlay(rect: ColorRect) -> void:
	_darken_rect = rect
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("mask_tex", mask_vp.get_texture())

func register_highlighted(obj: Node3D) -> void:
	var parent_inst := obj as VisualInstance3D
	if parent_inst:
		parent_inst.set_layer_mask_value(EXCLUDE_LAYER, true)
	var visual_insts: Array[Node] = obj.find_children(
		"*",
		"VisualInstance3D",
		true,
		false
	)
	for i in visual_insts:
		var inst := i as VisualInstance3D
		if inst:
			inst.set_layer_mask_value(EXCLUDE_LAYER, true)

func unregister_highlighted(obj: Node3D) -> void:
	var parent_inst := obj as VisualInstance3D
	if parent_inst:
		parent_inst.set_layer_mask_value(EXCLUDE_LAYER, false)
	var visual_insts: Array[Node] = obj.find_children(
		"*",
		"VisualInstance3D",
		true,
		false
	)
	for i in visual_insts:
		var inst := i as VisualInstance3D
		if inst:
			inst.set_layer_mask_value(EXCLUDE_LAYER, false)

func _on_resize():
	mask_vp.size = get_viewport().get_visible_rect().size
	
	if _main_cam:
		sync_mask_camera(_main_cam)

func sync_mask_camera(cam: Camera3D) -> void:
	mask_cam.global_transform = cam.global_transform
	
	mask_cam.projection = cam.projection
	mask_cam.fov = cam.fov
	mask_cam.size = cam.size
	
	mask_cam.near = cam.near
	mask_cam.far = cam.far
	
	mask_cam.keep_aspect = cam.keep_aspect

func set_darken(amount: float, duration: float = 0.0) -> void:
	if not _darken_rect: return
	if not VisualFeatureManager.darken: amount = 0.0
	var mat := _darken_rect.material as ShaderMaterial
	if duration <= 0.0:
		mat.set_shader_parameter("darken_amount", amount)
	else:
		if _darken_tween:
			_darken_tween.kill()
		_darken_tween = create_tween()
		_darken_tween.set_ignore_time_scale(true)
		_darken_tween.tween_property(
			mat,
			"shader_parameter/darken_amount",
			amount,
			duration)
