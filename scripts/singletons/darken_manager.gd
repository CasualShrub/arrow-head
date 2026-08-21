extends Node

const EXCLUDE_LAYER := 20

var mask_vp: SubViewport
var mask_cam: Camera3D
var _darken_rect: ColorRect
var _main_cam: Camera3D

func _ready():
	mask_vp = SubViewport.new()
	mask_vp.transparent_bg = true
	add_child(mask_vp)

	mask_cam = Camera3D.new()
	mask_cam.cull_mask = 0
	mask_cam.set_cull_mask_value(EXCLUDE_LAYER, true)
	mask_vp.add_child(mask_cam)

	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func _process(_delta):
	if _main_cam and mask_cam:
		mask_cam.global_transform = _main_cam.global_transform
		mask_cam.fov = _main_cam.fov
		mask_cam.near = _main_cam.near
		mask_cam.far = _main_cam.far
		mask_cam.keep_aspect = _main_cam.keep_aspect

func _on_resize():
	if _main_cam:
		mask_vp.size = _main_cam.get_viewport().size

func register_overlay(rect: ColorRect) -> void:
	_darken_rect = rect
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("mask_tex", mask_vp.get_texture())

func register_camera(cam: Camera3D) -> void:
	_main_cam = cam
	mask_vp.world_3d = cam.get_world_3d()

func set_darken(amount: float, duration: float = 0.0) -> void:
	if not _darken_rect: return
	var mat := _darken_rect.material as ShaderMaterial
	if duration <= 0.0:
		mat.set_shader_parameter("darken_amount", amount)
	else:
		create_tween().tween_property(
			mat,
			"shader_parameter/darken_amount",
			amount,
			duration)
