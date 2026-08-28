extends ArrowCollisionEffect
class_name ArrowBounceEffect

@export var bounces_added := 1
@export var can_stick := true

func apply(
	_target: ArrowCollider,
	_arrow: Arrow,
	_normal: Vector3,
	_point: Vector3
) -> void:
	pass

func simulate(
	_target: ArrowCollider,
	sim: ArrowSimulation,
	normal: Vector3,
	point: Vector3
) -> void:
	if would_stick(sim):
		sim.velocity
	else:
		sim.velocity.bounce(normal)
		sim.bounces += 1
	
func would_stick(sim: ArrowSimulation) -> bool:
	return sim.bounces >= 1
