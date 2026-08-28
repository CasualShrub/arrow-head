extends Control
class_name JuiceBarHud

@export var lerp_speed := 10.0
@export var ghost_bar_drain_speed := 4.0
@export var ghost_bar_freeze_time := 0.12
@export var big_loss_threshold := 0.1
@export var shake_strength := 7.0
@export var shake_decay := 45.0
@export var drain_shiver_angle := 0.022
@export var drain_shiver_speed := 26.0
@export var drain_shiver_pivot := Vector2(111.0, 224.0)
@export var drain_shiver_linger := 0.1

const FILL_EMPTY := 0.07
const FILL_FULL := 0.825

@onready var _juice: TextureProgressBar = %Juice
@onready var _ghost_bar: TextureProgressBar = %GhostBar

var _source: BarComponent
var _freeze_timer := 0.0
var _shake := 0.0
var _drain_timer := 0.0
var _drain_phase := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_instance_valid(_source):
		return

	var real_delta := delta / Engine.time_scale
	var target := _fill_for(_source.get_percentage())

	var weight := 1.0 - exp(-lerp_speed * real_delta)
	_juice.value = lerpf(_juice.value, target, weight)

	if _freeze_timer > 0.0:
		_freeze_timer -= real_delta
	elif _ghost_bar.value > _juice.value:
		var drain := 1.0 - exp(-ghost_bar_drain_speed * real_delta)
		_ghost_bar.value = lerpf(_ghost_bar.value, _juice.value, drain)
	else:
		_ghost_bar.value = _juice.value

	var shake_offset := Vector2.ZERO
	if _shake > 0.0:
		shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, shake_decay * real_delta)

	var angle := 0.0
	if _drain_timer > 0.0:
		_drain_phase += drain_shiver_speed * real_delta
		angle = sin(_drain_phase) * drain_shiver_angle
		_drain_timer -= real_delta

	var t := Transform2D(angle, Vector2.ZERO)
	t.origin = drain_shiver_pivot - t.basis_xform(drain_shiver_pivot) + shake_offset
	transform = t


func bind(bar: BarComponent) -> void:
	_source = bar
	_source.consumed.connect(_on_consumed)
	var fill := _fill_for(bar.get_percentage())
	_juice.value = fill
	_ghost_bar.value = fill

func _fill_for(percentage: float) -> float:
	return lerpf(FILL_EMPTY, FILL_FULL, percentage)

func _on_consumed(amount: float) -> void:
	if amount < big_loss_threshold:
		_drain_timer = drain_shiver_linger
		return
	var previous := clampf((_source.value + amount) / _source.max_value, 0.0, 1.0)
	_juice.value = _fill_for(_source.get_percentage())
	_ghost_bar.value = _fill_for(previous)
	_freeze_timer = ghost_bar_freeze_time
	_shake = shake_strength
