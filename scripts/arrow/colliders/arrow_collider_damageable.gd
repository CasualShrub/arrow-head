extends ArrowCollider
class_name ArrowColliderDamageable

@export var health: HealthComponent:
	set(value):
		if health:
			health.revived.disconnect(_on_revived)
			health.died.disconnect(_on_died)
		value.revived.connect(_on_revived)
		value.died.connect(_on_died)
		health = value

func _init() -> void:
	assert(health, "ArrowColliderDamageable needs HealthComponent.")

func collide(arrow: Arrow, normal: Vector3, point: Vector3) -> void:
	health.take_damage(1)
	if not health.is_dead():
		super(arrow, normal, point)

func simulate_collision(
	sim: ArrowSimulation,
	normal: Vector3,
	point: Vector3
) -> void:
	if would_die_to(sim.simulating): return
	super(sim, normal, point)

func would_die_to(_arrow: Arrow) -> bool:
	return health.value <= 1

func _on_revived() -> void:
	monitorable = true
	monitoring = true

func _on_died() -> void:
	monitorable = false
	monitoring = false
