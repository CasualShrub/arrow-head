@icon("res://addons/at-icons/node3d/arrow_projectile.svg")
extends Node3D
class_name Arrow

@export var speed := 7.0
@export var max_lifetime := -1.0
@export var max_bounces := -1
## Time after sticking into a wall the arrow is cleaned up.
@export var wall_stick_decay_time := -1.0
@export var free_on_deactivate := false

signal activated()
signal deactivated()
signal collided(with: ArrowCollider, normal: Vector3, point: Vector3)

var _shape_cast: ShapeCast3D
var _shape_cast_offset: Vector3

var scene: PackedScene

var simulation: ArrowSimulation

func _ready() -> void:
	var collision_shapes := find_children("*", "ShapeCast3D", true, false)
	#assert(
	#	collision_shapes.size() == 1,
	#	"%s must have exactly 1 ShapeCast3D." % get_path()
	#)
	if collision_shapes.is_empty():
		_shape_cast = ShapeCast3D.new()
	else:
		_shape_cast = collision_shapes[0]
	_shape_cast_offset = _shape_cast.position
	
	deactivate()

func _physics_process(delta: float) -> void:
	if not simulation or not simulation.enabled: return
	simulate(simulation, delta)
	apply_simulation()

func is_active() -> bool:
	return simulation != null

func activate(
	at: Vector3,
	velocity: Vector3,
	target_mask: int,
) -> void:
	simulation = create_simulation()
	
	simulation.position = at
	velocity.y = 0
	simulation.velocity = velocity * speed
	simulation.collision_mask = target_mask
	simulation.lifetime_remaining = INF if max_lifetime < 0.0 else max_lifetime

	global_position = simulation.position
	#var look_dir := simulation.velocity
	#look_dir = look_dir.normalized()
	look_at(global_position + simulation.facing)

	show()

	_on_activated()
	activated.emit()

func _on_activated() -> void:
	SoundManager.play("arrow_woosh")
	
func deactivate() -> void:
	if not is_active(): return
	
	simulation = null
	
	hide()
	
	_on_deactivated()
	deactivated.emit()
	if free_on_deactivate:
		queue_free()

func _on_deactivated() -> void:
	pass

func create_simulation() -> ArrowSimulation:
	if simulation:
		return simulation.duplicate()
	else:
		return ArrowSimulation.new(self)

func apply_simulation(sim: ArrowSimulation = simulation) -> void:
	simulation = sim
	var max_bounces_reached := max_bounces >= 0 and sim.bounces > max_bounces
	global_position = sim.position
	look_at(global_position + sim.facing)
	if not sim.alive or max_bounces_reached or sim.is_lifetime_over():
		deactivate()
		return
	if not sim.enabled:
		return
	for i in range(sim.get_collision_count()):
		var collider := sim.get_collision_collider(i)
		if not collider:
			continue
		var normal := sim.get_collision_normal(i)
		var point := sim.get_collision_point(i)
		collider.collide(self, normal, point)
		collided.emit(collider, normal, point)
	sim.clear_collisions()

func _on_collided(_sim: ArrowSimulation, _collider: ArrowCollider) -> void:
	pass

## Modifies sim in place.
func simulate(
	sim: ArrowSimulation,
	delta: float
) -> void:
	if not sim.enabled: return
	sim.increment_lifetime(delta)
	
	var angle := Vector3.FORWARD.signed_angle_to(
	sim.facing,
	Vector3.UP
	)
	var offset := _shape_cast_offset.rotated(
	Vector3.UP,
	angle
	)
	
	var motion := sim.velocity * delta
	var target_pos := sim.position + motion
	
	var cast_start := sim.position + offset
	var cast_end := target_pos + offset
	
	_shape_cast.global_position = cast_start
	_shape_cast.target_position = _shape_cast.to_local(cast_end)
	
	_shape_cast.collision_mask = sim.collision_mask
	
	_shape_cast.force_shapecast_update()
	if not _shape_cast.is_colliding():
		sim.position = target_pos
		return
	var found: Dictionary[CollisionObject3D, bool] = {}
	for i in range(_shape_cast.get_collision_count()):
		var collider := _shape_cast.get_collider(i) as CollisionObject3D
		if found.get(collider): continue
		found.set(collider, true)
		var normal := _shape_cast.get_collision_normal(i)
		var point := _shape_cast.get_collision_point(i)
		sim.position = point - offset
		var incoming_facing := sim.facing
		if collider is not ArrowCollider:
			ArrowCollider.default_bounce(sim, normal, point)
		else:
			collider.simulate_collision(sim, normal, point)
		if sim.bounces >= max_bounces:
			if wall_stick_decay_time > 0.0:
				sim.position = _project_onto_axis(
					sim.position,
					incoming_facing,
					point
				)
				sim.facing = incoming_facing
				sim.disable()
			else:
				sim.kill()
		_on_collision_simulated(sim, collider)
		sim.collided.append([collider, normal, point])
		if not sim.enabled: break

func _on_collision_simulated(
	_sim: ArrowSimulation,
	_collider: CollisionObject3D
) -> void:
	pass

func change_direction(dir: Vector3) -> void:
	simulation.change_direction(dir)

func embed(dig := 0.0) -> void:
	if not simulation: return
	if dig > 0.0:
		global_position += (-global_basis.z) * dig
	simulation.disable()

func _project_onto_axis(from: Vector3, dir: Vector3, point: Vector3) -> Vector3:
	var to_point := point - from
	var t := to_point.dot(dir.normalized())
	return from + dir.normalized() * t

func get_occupied_slots(collided_with: int) -> Array[int]:
	return [collided_with]
