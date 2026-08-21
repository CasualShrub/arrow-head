extends RefCounted
class_name ArrowSimulation

var simulating: Arrow

var position := Vector3.ZERO
var velocity := Vector3.ZERO:
	set(value):
		velocity = value
		print("velocity changed ", value)

var enabled := true
var alive := true

var collision_mask := 0
var bounces := 0

var lifetime_remaining := 0.0

var collided: Array[Array] = []

var state: Dictionary[StringName, Variant] = {}

func _init(arrow: Arrow) -> void:
	simulating = arrow

func change_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	var speed := velocity.length()
	velocity = dir * speed

func change_speed(speed: float) -> void:
	if velocity.length_squared() < 0.001:
		velocity = Vector3.FORWARD
	else:
		velocity = velocity.normalized()
	velocity *= speed

func kill() -> void:
	disable()
	alive = false

func enable() -> void:
	enabled = true

func disable() -> void:
	enabled = false

func is_lifetime_over() -> bool:
	return get_remaining_lifetime() <= 0.0

func get_remaining_lifetime() -> float:
	return lifetime_remaining

func increment_lifetime(delta: float) -> void:
	lifetime_remaining = max(lifetime_remaining - delta, 0)

func get_collision_count() -> int:
	return collided.size()

func get_collision_collider(i: int) -> ArrowCollider:
	if i >= get_collision_count(): return null
	return collided[i][0] as ArrowCollider

func get_collision_normal(i: int) -> Vector3:
	assert(i < get_collision_count(), "Collision %d not found." % i)
	return collided[i][1] as Vector3

func get_collision_point(i: int) -> Vector3:
	assert(i < get_collision_count(), "Collision %d not found." % i)
	return collided[i][2] as Vector3

func clear_collisions() -> void:
	collided = []

func duplicate() -> ArrowSimulation:
	var dup := ArrowSimulation.new(simulating)
	
	dup.position = position
	dup.velocity = velocity
	
	dup.enabled = enabled
	dup.alive = alive
	
	dup.collision_mask = collision_mask
	dup.bounces = bounces
	
	dup.lifetime_remaining = lifetime_remaining
	
	dup.collided = collided.duplicate(true)
	
	dup.state = state.duplicate(true)
	
	return dup
