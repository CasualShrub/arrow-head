extends Control

const FRAME_DIR := "res://systems/cutscene/frames/"
const NEXT_SCENE := "uid://dq024rj3sseom"
const OVERLAY_COUNT := 6
const WARM_SCENES: Array[String] = [
	"res://entities/enemies/enemy.tscn",
	"res://entities/player/player.tscn",
]

@export var default_fade_time: float = 0.2
@export var crossfade_time: float = 0.35
@export var overlay_step_time: float = 0.08
@export var overlay_loops: int = 3
@export var prompt_visible_time: float = 3.0

var _steps: Array[Dictionary] = [
	{"logo": true, "hold": 2.0, "fade_in": 0.8, "fade_out": 0.8},
	{"frame": 1, "hold": 4.06, "fade_out": 0.07},
	{"frame": 2, "hold": 1.3, "shake": 1.0, "fade_in": 0.05, "fade_color": Color(1.0, 0.5, 0.1), "fade_out": 0.25},
	{"frame": 3, "hold": 2.5, "fade_in": 0.8, "fade_out": 1.8},
	{"frame": 4, "hold": 2.20, "fade_in": 1.7},
	{"frame": 5, "hold": 1.75, "enter": "cut", "shake": 0.7},
	{"frame": 6, "hold": 0.75, "enter": "crossfade"},
	{"frame": 7, "hold": 2.1, "enter": "crossfade"},
	{"frame": 8, "hold": 2.55},
	{"frame": 9, "hold": 2.7, "enter": "crossfade"},
	{"frame": 10, "hold": 0.0, "enter": "crossfade", "overlays": true},
	{"frame": 11, "hold": 1.5},
	{"frame": 12, "hold": 2, "enter": "cut", "shake": 1.0, "sound": true, "fade_color": Color.WHITE, "fade_out": 1.2},
	{"frame": 13, "hold": 2, "fade_in": 0.7, "fade_out": 0.6},
]

@onready var _frame: TextureRect = $Frame
@onready var _logo: Control = $Logo
@onready var _frame_in: TextureRect = $FrameIn
@onready var _overlay: TextureRect = $Overlay
@onready var _fade: ColorRect = $Fade
@onready var _image_fade: ColorRect = $ImageFade
@onready var _skip_prompt: Label = $SkipPrompt

var _textures: Dictionary = {}
var _skip_presses := 0
var _prompt_tween: Tween
var _skipping := false
var _fade_tween: Tween
var _active_fade: ColorRect
var _shake := ScreenShake.new()

func _ready() -> void:
	_skip_prompt.modulate.a = 0.0
	_shake.max_offset = 45.0
	_fade.color = Color.BLACK
	_fade.modulate.a = 1.0
	_active_fade = _fade
	ResourceLoader.load_threaded_request(NEXT_SCENE)
	_warm()
	_play()

func _warm() -> void:
	for path in WARM_SCENES:
		ResourceLoader.load_threaded_request(path)
	await get_tree().process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1, 1)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for path in WARM_SCENES:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var scene := ResourceLoader.load_threaded_get(path) as PackedScene
		viewport.add_child(scene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	viewport.queue_free()
	GameManager.scenes_warmed = true

func _unhandled_input(event: InputEvent) -> void:
	if _skipping or not _is_skip_input(event):
		return
	get_viewport().set_input_as_handled()
	_skip_presses += 1
	if _skip_presses >= 2:
		_skip()
		return
	_skip_prompt.modulate.a = 1.0
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_interval(prompt_visible_time)
	_prompt_tween.tween_property(_skip_prompt, "modulate:a", 0.0, 0.4)
	_prompt_tween.tween_callback(func(): _skip_presses = 0)

func _is_skip_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE:
		return true
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT

func _load_frame(frame_name: String) -> Texture2D:
	if not _textures.has(frame_name):
		_textures[frame_name] = load(FRAME_DIR + frame_name + ".PNG")
	return _textures[frame_name]

func _play() -> void:
	for i in _steps.size():
		if _skipping:
			return
		await _play_step(i)
	if not _skipping:
		_finish()

func _play_step(index: int) -> void:
	var step := _steps[index]
	_overlay.visible = false
	_logo.visible = step.get("logo", false)
	if _logo.visible:
		SoundManager.play("logo")
	else:
		SoundManager.play_music("cutscene")
	var texture: Texture2D = null
	if not _logo.visible:
		texture = _load_frame(str(step["frame"]))
	var enter: String = step.get("enter", "fade")
	if step.has("shake") and enter != "cut":
		_shake.add(step["shake"])
	if enter == "crossfade":
		await _crossfade_to(texture)
	else:
		_frame.texture = texture
		if enter == "cut":
			_impact(step.get("shake", _shake.stimulus_amount), step.get("sound", false))
		else:
			await _fade_to(0.0, step.get("fade_in", default_fade_time))
	if _skipping:
		return
	await _wait(step["hold"])
	if _skipping:
		return
	if step.get("overlays", false):
		await _play_overlays()
		if _skipping:
			return
	var next_enter := "fade"
	if index + 1 < _steps.size():
		next_enter = _steps[index + 1].get("enter", "fade")
	if next_enter != "fade":
		return
	var color: Color = step.get("fade_color", Color.BLACK)
	if color == Color.BLACK:
		_active_fade = _fade
	else:
		_active_fade = _image_fade
	_active_fade.color = color
	await _fade_to(1.0, step.get("fade_out", default_fade_time))

func _crossfade_to(texture: Texture2D) -> void:
	_frame_in.texture = texture
	_frame_in.modulate.a = 0.0
	_frame_in.visible = true
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_frame_in, "modulate:a", 1.0, crossfade_time)
	await _fade_tween.finished
	_frame.texture = texture
	_frame_in.visible = false

func _impact(amount: float, sound: bool) -> void:
	_shake.add(amount)
	if sound:
		SoundManager.play("apple_damage1")

func _process(delta: float) -> void:
	if _shake.intensity <= 0.0:
		return
	get_viewport().canvas_transform = Transform2D(0.0, _shake.poll(delta))

func _play_overlays() -> void:
	_overlay.visible = true
	for loop in overlay_loops:
		for i in range(1, OVERLAY_COUNT + 1):
			_overlay.texture = _load_frame("Overlay" + str(i))
			await _wait(overlay_step_time)
			if _skipping:
				return

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _fade_to(alpha: float, time: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_active_fade, "modulate:a", alpha, time)
	await _fade_tween.finished

func _skip() -> void:
	_skipping = true
	_finish()

func _finish() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY
	while ResourceLoader.load_threaded_get_status(NEXT_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(NEXT_SCENE))
