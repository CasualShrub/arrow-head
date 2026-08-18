extends Area3D
class_name ArrowOld

@export var scene: PackedScene
@export_group("movement")
@export var speed := 7.0
@export_group("lifetime")
@export var max_lifetime := -1.0
@export var max_bounces := 8
## time after sticking into a wall the arrow is cleaned up
@export var decay_time := -1.0
@export var free_on_finish := true

@export_group("collision")
@export_flags_3d_physics var damage_mask := 1 << 0
@export_flags_3d_physics var bounce_mask := 1 << 2

signal hit(target: CollisionObject3D)
signal finished()
signal bounced(off: Node3D)
signal stuck(into: Node3D)

var direction := Vector3.RIGHT:
	set(value):
		value = value.normalized() if value.length_squared() < 0.0001 else Vector3.FORWARD
		direction = value

var _bounces: int
var _lifetime_ends: float

var _collider: CollisionShape3D

func _ready() -> void:
	var collision_shapes := find_children("*", "CollisionShape3D", true, false)
	assert(collision_shapes.size() == 1, "Arrow must have exactly 1 CollisionShape3D")
	_shape = collision_shapes[0]

func _physics_process(delta: float) -> void:
	_life += delta
	if get_remaining_lifetime() <= 0:
		_finish()
		return
	global_position += direction * speed * delta
	var collision := move_and_collide(_direction * speed * delta)
	var target_mask := (body as CollisionObject3D).collision_layer
	if _any_layer_matches(damage_mask, target_mask):
		_on_hit(body)
	elif _any_layer_matches(bounce_mask, target_mask):
		_bounce(body)
	else:
		_wall_stick()
	if collision:
		var collider := collision.get_collider() as CollisionObject3D

func _any_layer_matches(mask1: int, mask2: int) -> bool:
	return mask1 & mask2 > 0

func _get_collision(start: Vector3, motion: Vector3) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()

	query.shape = _shape
	query.transform = Transform3D(
		global_basis,
		start
	)
	query.motion = motion
	query.collision_mask = collision_mask

	return get_world_3d().direct_space_state.cast_motion(query)

func _bounce(collision: KinematicCollision3D) -> void:
	SoundManager.play("arrow_bounce", 0.0, 0.08)
	if max_bounces >= 0 and _bounces >= max_bounces:
		# out of bounces: stick facing the way we flew in, don't reflect
		_wall_stick()
		return
	var n := collision.get_normal()
	_direction = _direction.bounce(n)
	face(_direction)   # re-orient the sprite to the new travel direction
	move_and_collide(collision.get_remainder().bounce(n))
	_bounces += 1

func _wall_stick() -> void:
	stuck.emit()
	_disable()
	if decay_time >= 0:
		if decay_time > 0:
			await get_tree().create_timer(decay_time).timeout
		_finish()

func _on_hit(target) -> void:
	if target.has_method("get_hit"):
		target.get_hit(self)
	hit.emit(target)

func get_remaining_lifetime() -> float:
	if max_lifetime == 0: return INF
	return max_lifetime - _life

func get_slots_occupied(collided_with: int) -> Array[int]:
	return [collided_with]
	
func _start_lifetime() -> void:
	if max_lifetime >= 0.0:
		_lifetime_ends = Time.get_ticks_msec() + max_lifetime
	else:
		_lifetime_ends = -1.0

func activate(pos: Vector3, dir: Vector3, target_mask := damage_mask) -> void:
	global_position = pos
	direction = dir
	face(dir)
	damage_mask = target_mask
	
	_start_lifetime()
	_bounces = 0
	
	show()
	_collider.set_deferred("disabled", false)
	set_physics_process(true)

func _disable() -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	_collider.set_deferred("disabled", true)

func stick(host: Node3D, dig := 0.0) -> void:
	if dig > 0.0:
		global_position += _direction * dig
	_disable()
	reparent.call_deferred(host)
	stuck.emit(host)

func deactivate() -> void:
	_disable()
	hide()

func _finish() -> void:
	deactivate()
	finished.emit()
	if free_on_finish:
		queue_free()

func face(direction: Vector3) -> void:
	if direction.length() < 0.0001: return
	look_at(global_position + direction)

#func _apply_outline() -> void:
	#if not _sprite or not _sprite.texture:
		#return
	#var mat := _sprite.material_override
	#if mat is ShaderMaterial:
		#mat.set_shader_parameter("tex", _sprite.texture)
		#var s := _sprite.texture.get_size()
		#if s.x > 0 and s.y > 0:
			#mat.set_shader_parameter("tex_pixel_size", Vector2(1.0 / s.x, 1.0 / s.y))
