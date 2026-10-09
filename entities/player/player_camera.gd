extends Camera3D
class_name PlayerCamera

@export var height := 10.0:
	set(value):
		height = value
		position.y = height
@export_group("lookahead")
@export var max_lookahead_offset := 5.0
@export var lookahead_strength := 0.25
@export var lookahead_smoothing := 6.0
@export_group("shake")
@export var screen_shake: ScreenShake
@export_group("dash")
@export var dash_catchup_smoothing := 14.0
@export_group("focus")
@export var focus_weight := 0.5
@export var focus_zoom := 1.3
@export var focus_zoom_max := 2.5
@export var focus_margin := 1.5
@export var focus_smoothing := 3.0

signal shaken(strength: float)

var _current_lookahead := Vector3.ZERO
var _target_lookahead := Vector3.ZERO
var _follow_offset := Vector3.ZERO
var _focus_target: Node3D
var _focus_offset := Vector3.ZERO
var _zoom := 1.0
@onready var _anchor: Node3D = get_parent()
var _aim := AimCursor.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_aim)
	add_child(TreeFader.new())
	DarkenManager.register_camera(self)
	ScreenShaderManager.register_camera(self)

func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale
	var running := not get_tree().paused

	if running:
		_current_lookahead = _current_lookahead.lerp(
			_target_lookahead,
			1.0 - exp(-lookahead_smoothing * real_delta)
		)

	_follow_offset = _follow_offset.lerp(
		Vector3.ZERO,
		1.0 - exp(-dash_catchup_smoothing * real_delta)
	)

	var focus_target := Vector3.ZERO
	var zoom_target := 1.0
	if is_instance_valid(_focus_target):
		focus_target = (_focus_target.global_position - _anchor.global_position) * focus_weight
		focus_target.y = 0.0
		var aspect := get_viewport().get_visible_rect().size.aspect()
		var reach := maxf(absf(focus_target.z) + focus_margin, (absf(focus_target.x) + focus_margin) / aspect)
		var fit := reach / tan(deg_to_rad(fov * 0.5)) / height
		zoom_target = clampf(maxf(focus_zoom, fit), focus_zoom, focus_zoom_max)
	var focus_t := 1.0 - exp(-focus_smoothing * real_delta)
	_focus_offset = _focus_offset.lerp(focus_target, focus_t)
	_zoom = lerpf(_zoom, zoom_target, focus_t)

	position = Vector3(
		_current_lookahead.x + _follow_offset.x + _focus_offset.x,
		height * _zoom,
		_current_lookahead.z + _follow_offset.z + _focus_offset.z
	)

	if running and screen_shake.intensity > 0.0:
		var offset := screen_shake.poll(real_delta)
		position += Vector3(offset.x, 0.0, offset.y)

	_aim.anchor_to(unproject_position(_anchor.global_position))

	DarkenManager.sync_mask_camera(self)
	ScreenShaderManager.sync_camera(self)

## Takes normalized input.
func set_lookahead(input: Vector2) -> void:
	input = input.limit_length(1.0)
	
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	_target_lookahead = (
		right * input.x +
		forward * input.y
	) * lookahead_strength


func focus_on(target: Node3D) -> void:
	_focus_target = target

func clear_focus() -> void:
	_focus_target = null

func ease_after_teleport(from: Vector3, to: Vector3) -> void:
	_follow_offset += from - to

func add_shake(amount: float) -> void:
	screen_shake.add(amount)
	shaken.emit(amount)

func shake() -> void:
	add_shake(screen_shake.stimulus_amount)

func get_mouse_position() -> Vector3:
	var mouse := _aim.aim_position()
	var origin := project_ray_origin(mouse)
	var dir := project_ray_normal(mouse)

	if abs(dir.y) < 0.001:
		return Vector3.ZERO

	var distance := -origin.y / dir.y
	return origin + dir * distance
	
	# more general
	#var mouse = get_viewport().get_mouse_position()
#
	#var origin = project_ray_origin(mouse)
	#var dir = project_ray_normal(mouse)
#
	#var query = PhysicsRayQueryParameters3D.new()
	#query.from = origin
	#query.to = origin + dir * 2000.0
	#query.collision_mask = collision_mask
#
	#var result = get_world_3d().direct_space_state.intersect_ray(query)
#
	#if result.is_empty():
		#return Vector3.ZERO
#
	#return result.position as Vector3

## Returns a normalized Vector2.
func get_mouse_screen_offset() -> Vector2:
	var viewport := get_viewport()
	var mouse := _aim.aim_position()
	var viewport_size := viewport.get_visible_rect().size
	#var center := viewport_size * 0.5
	var center := unproject_position(_anchor.global_position)

	var screen_offset := mouse - center

	var normalized := Vector2(
		screen_offset.x / (viewport_size.x * 0.5),
		screen_offset.y / (viewport_size.y * 0.5)
	)

	normalized = normalized.limit_length(1.0)
	return normalized
