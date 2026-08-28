extends ArrowCollider
class_name DestructibleComponent

@export var hits := 1 #increase this to increase hits needed to destroy object
@export var target: Node3D
@export var debris: PackedScene
@export var debris_lifetime := 2.0
@export var destroy_sound := ""
@export var destroy_sound_volume := 0.0
@export var will_destroy_arrow := false

signal hit(remaining: int)
signal destroyed()

var _remaining: int
var _destroyed := false

func _ready() -> void:
	_remaining = hits
	if not target:
		target = get_parent() as Node3D

func collide(arrow: Arrow, normal: Vector3, point: Vector3) -> void:
	if _destroyed:
		return
	_remaining -= 1
	hit.emit(_remaining)
	if _remaining <= 0:
		_destroy(arrow, point)
		return
	super(arrow, normal, point)

func simulate_collision(sim: ArrowSimulation, normal: Vector3, point: Vector3) -> void:
	if _would_break():
		return
	ArrowCollider.default_bounce(sim, normal, point)

func _would_break() -> bool:
	return _remaining <= 1

func _destroy(arrow: Arrow, point: Vector3) -> void:
	if _destroyed:
		return
	_destroyed = true
	monitorable = false
	monitoring = false

	if destroy_sound != "":
		SoundManager.play(destroy_sound, destroy_sound_volume)

	if debris:
		_spawn_debris(point)

	if will_destroy_arrow and is_instance_valid(arrow):
		arrow.deactivate()

	destroyed.emit()

	if is_instance_valid(target):
		target.queue_free()

func _spawn_debris(point: Vector3) -> void:
	var node := debris.instantiate()
	var host := get_tree().current_scene
	if not host:
		host = get_tree().root
	host.add_child(node)
	if node is Node3D:
		node.global_position = point if point != Vector3.ZERO else global_position
	for p in _collect_particles(node):
		p.emitting = true
	if debris_lifetime > 0.0:
		get_tree().create_timer(debris_lifetime).timeout.connect(node.queue_free)

func _collect_particles(root: Node) -> Array:
	var found := []
	if root is CPUParticles3D or root is GPUParticles3D:
		found.append(root)
	for c in root.find_children("*", "CPUParticles3D", true, false):
		found.append(c)
	for c in root.find_children("*", "GPUParticles3D", true, false):
		found.append(c)
	return found

func _has_collision_shape() -> bool:
	for c in get_children():
		if c is CollisionShape3D or c is CollisionPolygon3D:
			return true
	return false
