extends Node
class_name DashComponent

@export var max_distance := 10.0
@export var cooldown := 0.1

@export_group("collision")
@export var radius := 0.4:
	set(value):
		_update_shape(value)
		radius = value
@export_flags_3d_physics var collision_mask := 1 << 2
@export_flags_3d_physics var targeting_mask := 1 << 3

@onready var _dash_shape := SphereShape3D.new()
var _parent: Node3D

signal cooldown_started(duration: float)
signal cooldown_reset()
signal activated(destination: Vector3, targets: Array)
signal enabled()
signal disabled()

var _dash_available := -1.0
var _dash_enabled := false

func _ready() -> void:
	var p := get_parent()
	assert(p is Node3D, "%s must be the child of a Node3D" % get_path())
	_parent = p
	
	_update_shape(radius)

func _update_shape(new_radius: float) -> void:
	_dash_shape.radius = new_radius

func try_activate(origin: Vector3, target: Vector3) -> bool:
	if can_activate():
		activate(origin, target)
		return true
	return false

func activate(origin: Vector3, wish_pos: Vector3) -> void:
	var dest := get_dash_destination(origin, wish_pos)
	var targets := get_dash_targets(origin, dest)
	for t in targets:
		t.mark_hit()
	start_cooldown()
	activated.emit(dest, targets)

func can_activate() -> bool:
	return is_enabled() and not is_on_cooldown()

func is_enabled() -> bool:
	return _dash_enabled

func enable() -> void:
	if is_enabled(): return
	_dash_enabled = true
	enabled.emit()

func disable() -> void:
	if not is_enabled(): return
	_dash_enabled = false
	disabled.emit()

func is_on_cooldown() -> bool:
	if _dash_available < 0.0:
		return false
	elif Time.get_ticks_msec() >= _dash_available:
		# reset for quicker checks in future
		_dash_available = -1.0
		return false
	return true

func start_cooldown(cd: float = cooldown) -> void:
	_dash_available = Time.get_ticks_msec() + cd * 1000
	cooldown_started.emit(cd)

func reset_cooldown() -> void:
	_dash_available = -1.0
	cooldown_reset.emit()

func get_dash_destination(origin: Vector3, target: Vector3) -> Vector3:
	var motion = target - origin
	motion = motion.limit_length(max_distance)
	
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _dash_shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = motion
	query.collision_mask = collision_mask
	query.exclude = [_parent.get_rid()]
	
	var state_space := _parent.get_world_3d().direct_space_state
	
	var result := state_space.cast_motion(query)
	
	if result[0] < 1.0:
		return origin + motion * result[0]
	
	return target

func get_dash_targets(origin: Vector3, dest: Vector3) -> Array[TargetArea]:
	var targets: Array[TargetArea] = []
	
	var full_motion := dest - origin
	var dist := full_motion.length()
	if dist < 0.001:
		dist = 0.0
	
	var step := maxf(radius, 0.01)
	var steps := int(ceil(dist / step)) + 1
	
	var space_state := _parent.get_world_3d().direct_space_state
	
	var exclude := [_parent.get_rid()]
	
	for i in range(steps + 1):
		var t := float(i) / float(steps) if steps > 0 else 0.0
		var sample_pos := origin + full_motion * t
		
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _dash_shape
		query.transform = Transform3D(Basis.IDENTITY, sample_pos)
		query.collision_mask = targeting_mask
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.exclude = exclude
		
		var intersected := space_state.intersect_shape(query)
		for c in intersected:
			var coll := c.collider as CollisionObject3D
			if not coll or coll is not TargetArea: continue
			if not coll.is_vulnerable or coll in targets: continue
			targets.append(c.collider)
			exclude.append(c.collider.get_rid())
	
	return targets
