extends Resource
class_name ArrowCollisionEffect


func apply(
	_target: ArrowCollider,
	_arrow: Arrow,
	_normal: Vector3,
	_point: Vector3
) -> void:
	pass

func simulate(
	_target: ArrowCollider,
	_sim: ArrowSimulation,
	_normal: Vector3,
	_point: Vector3
) -> void:
	pass
