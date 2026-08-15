extends Area3D
class_name Arrow

@export var speed := 7.0
@export var max_lifetime := -1.0
@export var max_bounces := -1
## time after sticking into a wall the arrow is cleaned up
@export var wall_stick_decay_time := -1.0
@export var free_on_deactivate := true

@export_group("collision")
@export_flags_3d_physics var damage_mask := 1 << 0:
	set(value):
		_update_mask()
		damage_mask = value
@export_flags_3d_physics var bounce_mask := 1 << 2:
	set(value):
		_update_mask()
		bounce_mask = value

signal activated()
signal deactivated()
signal enabled()
signal disabled()
signal bounced(off: Node3D)
signal stuck_into(wall: CollisionShape3D)
signal embedded(player: Player)

var _shape_cast: ShapeCast3D

var _active := false
var _enabled := false
var _lifetime_ends: float
var _bounces: int

var direction := Vector3.FORWARD:
	set(value):
		value = value.normalized() if value.length_squared() > 0.001 else Vector3.FORWARD
		direction = value

func _ready() -> void:
	var collision_shapes := find_children("*", "ShapeCast3D", true, false)
	assert(collision_shapes.size() == 1, "Arrow must have exactly 1 ShapeCast3D")
	_shape_cast = collision_shapes[0]
	
	_update_mask()
	
	deactivate()

func _physics_process(delta: float) -> void:
	if not is_active(): return
	if get_remaining_lifetime() <= 0.0:
		deactivate()
		return
	
	var dist_remaining := speed * delta
	while is_active() and dist_remaining > 0.0:
		_move(dist_remaining)

func _update_mask() -> void:
	_shape_cast.collision_mask = damage_mask & bounce_mask

func _has_lifetime() -> bool:
	return _lifetime_ends >= 0.0

func _start_lifetime(dur: float) -> void:
	_lifetime_ends = -1.0 if dur < 0.0 else Time.get_ticks_msec() + dur

func get_remaining_lifetime() -> float:
	return _lifetime_ends - Time.get_ticks_msec() if _has_lifetime() else INF

func is_active() -> bool:
	return _active

func activate(
	at: Vector3,
	facing: Vector3,
	target_mask: int,
	new_speed: float = speed
) -> void:
	if is_active(): return
	_active = true
	
	position = at
	direction = facing
	speed = new_speed
	
	_start_lifetime(max_lifetime)
	_bounces = 0
	
	show()
	activated.emit()
	
func deactivate() -> void:
	if not is_active(): return
	_active = false
	
	hide()
	deactivated.emit()
	
	if free_on_deactivate:
		queue_free()

func is_enabled() -> bool:
	return _enabled
	
func enable() -> void:
	if is_enabled(): return
	_enabled = true
	enabled.emit()

func disable() -> void:
	if not is_enabled(): return
	_enabled = false
	disabled.emit()

func _any_layer_matches(mask1: int, mask2: int) -> bool:
	return mask1 & mask2

## returns distance remaining
func _move(distance: float) -> float:
	var motion = direction * distance
	
	_shape_cast.position = _shape_cast.to_local(global_position + motion)
	if _shape_cast.is_colliding():
		var frac := _shape_cast.get_closest_collision_safe_fraction()
		var safe_dist := distance * frac
		var safe_motion := direction * safe_dist
		
		position += safe_motion
		
		for i in range(_shape_cast.get_collision_count()):
			var collider := _shape_cast.get_collider(i)
			var point := _shape_cast.get_collision_point(i)
			var normal := _shape_cast.get_collision_normal(i)
			_handle_collision(collider, point, normal)
		
		return safe_dist
	else:
		position += motion
		return 0.0

func _handle_collision(
	collider: CollisionObject3D,
	collision_point: Vector3,
	collision_normal: Vector3
) -> void:
	var layer_mask = collider.collision_layer
	if _any_layer_matches(damage_mask, layer_mask):
		_hit(collider, collision_point)
	elif _any_layer_matches(bounce_mask, layer_mask):
		_bounce(collider, collision_point, collision_normal)

func _hit(target: Object, collision_point: Vector3) -> void:
	var arrows_components := find_children("*", "ShapeCast3D", true, false)
	for a: ArrowsComponent in arrows_components:
		a.add_arrow(self)
	if target.has_method("get_hit"):
		target.get_hit(self, collision_point)

func _bounce(
	collider: CollisionObject3D,
	point: Vector3,
	normal: Vector3
) -> void:
	if _bounces >= max_bounces:
		_stick_into(collider, point)
	else:
		direction.bounce(normal)
		_bounces += 1
		bounced.emit(collider)

func _stick_into(collider: CollisionObject3D, point: Vector3) -> void:
	disable()
	global_position = point
	stuck_into.emit(collider)

func get_occupied_slots(collided_with: int) -> Array[int]:
	return [collided_with]
