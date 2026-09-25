@icon("res://addons/at-icons/used/control/skull_and_crossbones.svg")
extends MenuOverlay

enum Phase { IDLE, DYING, REVEALING, READY, LEAVING }

const TRANSITION = preload("res://menus/loading/retry_transition.gd")
const CONTENT_SIZE := Vector2(430, 310)

@export_range(0.0, 0.2, 0.01) var impact_freeze := 0.07
@export_range(0.0, 2.0, 0.05) var death_anim_delay := 0.6
@export_range(0.0, 1.0, 0.05) var death_shake := 0.85
@export_range(0.1, 2.0, 0.05) var dot_fade_duration := 0.78
@export_range(0.0, 1.0, 0.05) var dot_opacity := 0.65

@onready var _backdrop: ColorRect = %Backdrop
@onready var _flash: ColorRect = %Flash
@onready var _content: Control = %Content
@onready var _art: Control = %Art
@onready var _restart: Button = %Restart
@onready var _main_menu: Button = %MainMenu

var _phase := Phase.IDLE
var _sequence: Tween
var _art_position := Vector2.ZERO
var _animation_finished := false
var _hold_finished := false

func _ready() -> void:
	super()
	show()
	_art_position = _art.position
	_root.resized.connect(_layout)
	_layout()
	_reset_presentation()
	var font := _restart.get_theme_font("font").duplicate() as FontFile
	font.multichannel_signed_distance_field = true
	for control in [_restart, _main_menu, _restart.get_node("Keycap")]:
		control.add_theme_font_override("font", font)

func _layout() -> void:
	var factor := minf(_root.size.x / 748.0, _root.size.y / 468.0)
	_content.scale = Vector2.ONE * factor
	_content.position = (_root.size - CONTENT_SIZE * factor) * 0.5
	_backdrop.material.set_shader_parameter("viewport_size", _root.size)

func _reset_presentation() -> void:
	_backdrop.material.set_shader_parameter("reveal", 0.0)
	_backdrop.material.set_shader_parameter("dots_progress", 0.0)
	_backdrop.material.set_shader_parameter("dot_opacity", dot_opacity)
	_flash.modulate.a = 0.0
	for control in [_art, _restart, _main_menu]:
		control.modulate.a = 0.0
	_restart.disabled = true
	_main_menu.disabled = true

func _new_sequence() -> Tween:
	if _sequence and _sequence.is_valid():
		_sequence.kill()
	_sequence = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_sequence.set_ignore_time_scale(true)
	return _sequence

func _on_encounter_ended(won: bool) -> void:
	if won or _phase != Phase.IDLE:
		return
	_phase = Phase.DYING
	_set_open(true)
	var player: Player = get_parent().get_player()
	if is_instance_valid(player):
		player.death_animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	else:
		_animation_finished = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	_flash.modulate.a = 0.23
	var tween := _new_sequence().set_parallel(true)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.13)
	tween.tween_callback(_release_impact.bind(player)).set_delay(impact_freeze)
	tween.tween_callback(_on_hold_finished).set_delay(death_anim_delay)

func _release_impact(player: Player) -> void:
	if _phase != Phase.DYING:
		return
	get_tree().paused = false
	if is_instance_valid(player):
		player.get_camera().add_shake(death_shake)

func _on_death_animation_finished() -> void:
	_animation_finished = true
	_try_reveal()

func _on_hold_finished() -> void:
	_hold_finished = true
	_try_reveal()

func _try_reveal() -> void:
	if _phase == Phase.DYING and _animation_finished and _hold_finished:
		_reveal()

func _reveal() -> void:
	_phase = Phase.REVEALING
	get_tree().paused = true
	_art.position = _art_position - Vector2(0, 12)
	_art.scale = Vector2(0.975, 1.08)
	var tween := _new_sequence().set_parallel(true)
	tween.tween_property(_backdrop.material, "shader_parameter/reveal", 1.0, 0.36) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_backdrop.material, "shader_parameter/dots_progress", 1.0, dot_fade_duration).set_delay(0.13)
	tween.tween_property(_art, "modulate:a", 1.0, 0.045).set_delay(0.11)
	tween.tween_property(_art, "position", _art_position, 0.11).set_delay(0.11) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_art, "scale", Vector2.ONE, 0.035).set_delay(0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_restart, "modulate:a", 1.0, 0.14).set_delay(0.26)
	tween.tween_property(_main_menu, "modulate:a", 1.0, 0.14).set_delay(0.37)
	tween.tween_callback(_enable_buttons).set_delay(0.51)
	tween.finished.connect(func() -> void: _phase = Phase.READY)

func _enable_buttons() -> void:
	_restart.disabled = false
	_main_menu.disabled = false
	_restart.grab_focus()

func _input(event: InputEvent) -> void:
	if _phase == Phase.IDLE:
		return
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		restart()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _on_primary() -> void:
	restart()

func restart() -> void:
	_leave(MenuNav.restart.bind(get_tree()))

func to_menu() -> void:
	_leave(MenuNav.to_menu.bind(get_tree()))

func _leave(action: Callable) -> void:
	if _phase == Phase.IDLE or _phase == Phase.LEAVING:
		return
	_phase = Phase.LEAVING
	if _sequence and _sequence.is_valid():
		_sequence.kill()
	_restart.disabled = true
	_main_menu.disabled = true
	TRANSITION.play(get_tree(), action)
