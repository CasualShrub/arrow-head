extends CanvasLayer

const WIPE = preload("res://menus/loading/retry_transition.gdshader")
const PATTERN = preload("res://menus/loading/yellow pattern.PNG")
const GROUP := &"retry_transition"

var _cover: ColorRect

static func play(tree: SceneTree, action: Callable) -> void:
	if tree.has_group(GROUP):
		return
	var transition = load("res://menus/loading/retry_transition.gd").new()
	tree.root.add_child(transition)
	transition._run(action)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	add_to_group(GROUP)
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = WIPE
	material.set_shader_parameter("pattern", PATTERN)
	material.set_shader_parameter("offset", -1.0)
	_cover.material = material
	add_child(_cover)
	_cover.resized.connect(_resize)
	_resize()

func _resize() -> void:
	_cover.material.set_shader_parameter("viewport_size", _cover.size)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _animate_offset(to: float, duration: float, easing: Tween.EaseType) -> Tween:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	tween.tween_property(_cover.material, "shader_parameter/offset", to, duration) \
		.set_trans(Tween.TRANS_CUBIC if to == 0.0 else Tween.TRANS_QUAD).set_ease(easing)
	return tween

func _draw_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

func _run(action: Callable) -> void:
	var tree := get_tree()
	tree.paused = true
	Engine.time_scale = 1.0
	await _animate_offset(0.0, 0.246, Tween.EASE_OUT).finished
	await _draw_frame()
	action.call()
	tree.paused = true
	Engine.time_scale = 1.0
	# Stay over the new room until it has entered the tree and rendered.
	await tree.process_frame
	await tree.process_frame
	await _draw_frame()
	await tree.create_timer(0.045, true, false, true).timeout
	await _animate_offset(1.0, 0.269, Tween.EASE_IN).finished
	tree.paused = false
	queue_free()
