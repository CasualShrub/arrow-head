extends StaticBody3D
class_name ShakeOnHitProp

@export var shake_target: Node3D
@export var shake_distance := 0.045
@export var shake_duration := 0.4
@export var shake_cycles := 4.0

var _tween: Tween
var _rest_position := Vector3.ZERO

func _ready() -> void:
	if not shake_target:
		shake_target = get_node_or_null("Mesh") as Node3D
	if shake_target:
		_rest_position = shake_target.position

func on_arrow_stuck(direction: Vector3) -> void:
	if not shake_target: return
	var axis := Vector3(direction.x, 0.0, direction.z)
	if axis.length_squared() < 0.001:
		axis = Vector3.RIGHT
	var parent := shake_target.get_parent() as Node3D
	if parent:
		axis = parent.global_basis.inverse() * axis
	axis = axis.normalized()
	if parent:
		axis /= maxf(parent.global_basis.get_scale().x, 0.001)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_shake.bind(axis), 0.0, 1.0, shake_duration)
	_tween.finished.connect(_reset_shake)

func _apply_shake(t: float, axis: Vector3) -> void:
	var falloff := 1.0 - t
	var wave := sin(t * shake_cycles * TAU)
	shake_target.position = _rest_position + axis * wave * falloff * shake_distance

func _reset_shake() -> void:
	shake_target.position = _rest_position
