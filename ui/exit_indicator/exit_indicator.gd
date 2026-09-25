extends Control
class_name ExitIndicator

@export var edge_margin: float = 72.0
@export var fade_speed: float = 9.0
@export var base_scale: float = 0.09
@export var pulse_amount: float = 0.14
@export var pulse_speed: float = 4.0

@onready var _arrow: Node2D = %Arrow
@onready var _sprite: Sprite2D = %Sprite

var _target: Node3D
var _active: bool = false
var _pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	_arrow.modulate.a = 0.0

func bind(target: Node3D) -> void:
	_target = target

func set_active(active: bool) -> void:
	_active = active

func _process(delta: float) -> void:
	var unscaled_delta: float = delta / maxf(Engine.time_scale, 0.001)

	_pulse_time += unscaled_delta * pulse_speed
	var pulse_scale: float = base_scale * (1.0 + pulse_amount * sin(_pulse_time))
	_sprite.scale = Vector2(pulse_scale, pulse_scale)

	var camera: Camera3D = get_viewport().get_camera_3d()
	var target_alpha: float = 0.0
	if _active and is_instance_valid(_target) and camera and _update_arrow(camera):
		target_alpha = 1.0

	var fade_weight: float = 1.0 - exp(-fade_speed * unscaled_delta)
	_arrow.modulate.a = lerpf(_arrow.modulate.a, target_alpha, fade_weight)
	_arrow.visible = _arrow.modulate.a > 0.01

func _update_arrow(camera: Camera3D) -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	var screen_center: Vector2 = viewport_size * 0.5
	var target_world_pos: Vector3 = _target.global_position

	var target_screen_pos: Vector2 = camera.unproject_position(target_world_pos)
	var target_behind_camera: bool = camera.is_position_behind(target_world_pos)

	var half_bounds: Vector2 = viewport_size * 0.5 - Vector2(edge_margin, edge_margin)
	var offset_from_center: Vector2 = target_screen_pos - screen_center
	if not target_behind_camera and absf(offset_from_center.x) <= half_bounds.x and absf(offset_from_center.y) <= half_bounds.y:
		return false

	if target_behind_camera:
		offset_from_center = -offset_from_center

	var direction: Vector2 = offset_from_center
	if direction.length() < 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()

	var distance_to_border: float = INF
	if absf(direction.x) > 0.0001:
		distance_to_border = minf(distance_to_border, half_bounds.x / absf(direction.x))
	if absf(direction.y) > 0.0001:
		distance_to_border = minf(distance_to_border, half_bounds.y / absf(direction.y))

	_arrow.position = screen_center + direction * distance_to_border
	_sprite.rotation = direction.angle() + PI * 0.5
	return true
