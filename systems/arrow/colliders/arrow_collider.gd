extends Area3D
class_name ArrowCollider

## Ordered.
@export var collision_effects: Array[ArrowCollisionEffect] = []

signal collided(arrow: Arrow, normal: Vector3, point: Vector3)

func collide(arrow: Arrow, normal: Vector3, point: Vector3) -> void:
	for e in collision_effects:
		e.apply(self, arrow, normal, point)
	_on_collide(arrow, normal, point)
	collided.emit(arrow)

func _on_collide(_arrow: Arrow, _normal: Vector3, _point: Vector3) -> void:
	pass

func simulate_collision(
	sim: ArrowSimulation,
	normal: Vector3,
	point: Vector3
) -> void:
	_on_collision_simulated(sim, normal, point)

func _on_collision_simulated(
	_sim: ArrowSimulation,
	_normal: Vector3,
	_point: Vector3
) -> void:
	pass

static func default_bounce(
	sim: ArrowSimulation,
	normal,
	point: Vector3
) -> void:
	sim.velocity = sim.velocity.bounce(normal)
	sim.bounces += 1
