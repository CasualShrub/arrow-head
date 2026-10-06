extends Node

var _handles: Array[ScreenEffectHandle] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play(effect: ScreenEffect, bound_to: Node = null) -> ScreenEffectHandle:
	if not VisualFeatureManager.screen_effects: return null
	var handle := ScreenEffectHandle.new()
	handle.effect = effect
	handle.material = ShaderMaterial.new()
	handle.material.shader = effect.shader
	for key in effect.parameters:
		handle.material.set_shader_parameter(key, effect.parameters[key])
	handle.material.set_shader_parameter(effect.intensity_parameter, 0.0)

	var rect := ColorRect.new()
	rect.material = handle.material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	handle.layer = CanvasLayer.new()
	handle.layer.layer = effect.layer
	handle.layer.add_child(rect)
	add_child(handle.layer)

	_handles.append(handle)
	_fade(handle, 1.0, effect.fade_in_time)
	if bound_to:
		bound_to.tree_exiting.connect(_stop_immediately.bind(handle), CONNECT_ONE_SHOT)
	return handle

func stop_all() -> void:
	for handle in _handles.duplicate():
		_stop_immediately(handle)

func stop(handle: ScreenEffectHandle, instant := false) -> void:
	if handle == null or not _handles.has(handle):
		return
	_handles.erase(handle)
	if instant:
		handle.layer.queue_free()
		return
	_fade(handle, 0.0, handle.effect.fade_out_time)
	handle.tween.tween_callback(handle.layer.queue_free)

func _stop_immediately(handle: ScreenEffectHandle) -> void:
	_handles.erase(handle)
	if handle.tween:
		handle.tween.kill()
	if is_instance_valid(handle.layer):
		handle.layer.queue_free()

func set_parameter(handle: ScreenEffectHandle, param: StringName, value: Variant) -> void:
	if handle == null or not _handles.has(handle):
		return
	handle.material.set_shader_parameter(param, value)

func _fade(handle: ScreenEffectHandle, target: float, time: float) -> void:
	if handle.tween:
		handle.tween.kill()
	var param := handle.effect.intensity_parameter
	var from: float = handle.material.get_shader_parameter(param)
	handle.tween = handle.layer.create_tween()
	handle.tween.tween_method(_set_intensity.bind(handle), from, target, time)

func _set_intensity(value: float, handle: ScreenEffectHandle) -> void:
	handle.material.set_shader_parameter(handle.effect.intensity_parameter, value)
