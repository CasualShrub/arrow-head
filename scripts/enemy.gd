@tool
extends CharacterBody3D
class_name Enemy

const _ENEMY_TEAM = Arrow.Team.ENEMY

@export var health: HealthComponent
@export var sus: SusComponent
@export var player: Player

@export_group("firing")
@export var arrow_scene: PackedScene
@export var fire_rate := 2.0

@export var hurt_radius := 25.0:
	set(value):
		if value < 0: value = 0
		_update_collider(%HurtCollider, value)
		hurt_radius = value

var _dead := false
var _alerted := false
var _movement_pattern: Dictionary[float, Vector2] = {}

signal fired(arrow: Arrow, dir: Vector3)
signal died

func get_hit(_arrow: Arrow) -> void:
	health.take_damage(1)

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c:
		return
	var s := CapsuleShape3D.new()
	s.radius = r
	c.shape = s

# can return new dir if it wants
func _on_fire(_arrow: Arrow, dir: Vector3) -> Vector3:
	return dir

func _parse_movement_pattern(pattern: Dictionary[float, Vector2]) -> Dictionary[float, Vector3]:
	var parsed := {}
	var curr_tick = Time.get_ticks_msec()
	for t in pattern:
		var o := pattern[t]
		var offset := position
		offset.x += o.x
		offset.z += o.y
		parsed[t+curr_tick] = offset
	return parsed

func _get_arrow_angle(i: int, spread: float, offset: float) -> float:
	var i_spread := spread / i
	return i_spread + offset

func _get_arrow_dir(angle: float) -> Vector3:
	return -global_basis.z.rotated(Vector3.UP, angle)

func _make_arrow(scene: PackedScene) -> Arrow:
	var arrow: Arrow = scene.instantiate()
	return arrow

func _get_rand(min_val: Variant, max_val: Variant) -> Variant:
	if min_val >= max_val:
		return min_val
	if min_val is int:
		return randi_range(min_val, max_val)
	else:
		return randf_range(min_val, max_val)

func _execute_instance(instance: FiringInstance, i: int, spread: float, offset: float) -> void:
	var arrow := _make_arrow(instance.type)
	var angle := _get_arrow_angle(i, instance.spread, offset)
	var dir := _get_arrow_dir(angle)
	fire(arrow, dir)

func _on_instance_timer_timeout(timer: Timer,
	instance: FiringInstance,
	count: int,
	spread: float,
	offset: float) -> void:
		var nfired = timer.get_meta("fired")
		_execute_instance(instance, nfired, spread, offset)
		nfired += 1
		timer.set_meta("fired", nfired)
		if nfired >= count:
			timer.queue_free()

func _execute_volley(instance: FiringInstance, count: int, spread: float, offset: float):
	if instance.instance_delay == 0.0 and instance.max_instance_delay == 0.0:
			for i in range(count):
				_execute_instance(instance, i, spread, offset)
	else:
		var instance_deb := Timer.new()
		instance_deb.set_meta("fired", 0)
		instance_deb.autostart = true
		instance_deb.wait_time = instance.instance_delay
		instance_deb.one_shot = false
		instance_deb.timeout.connect(_on_instance_timer_timeout.bind(
			instance_deb,
			instance,
			count,
			spread,
			offset
		))
		%InstanceTimers.add_child(instance_deb)

func perform(pattern: ArrowPattern) -> void:
	if pattern.has_movement_pattern:
		var p = _parse_movement_pattern(pattern.movement_pattern)
		_movement_pattern = p
	for instance in pattern.instances:
		var startup: int = _get_rand(instance.starting_delay, instance.starting_delay)
		var count: int = _get_rand(instance.count, instance.max_count)
		var spread: float = _get_rand(instance.spread, instance.max_spread)
		var offset: float = _get_rand(instance.offset, instance.max_offset)
		
		if startup == 0.0:
			_execute_volley(instance, count, spread, offset)
		else:
			get_tree().create_timer(startup).timeout.connect(_execute_volley.bind(
				instance,
				count,
				spread,
				offset
			))
	
	var _check_empty: Callable
	_check_empty = func():
		if !%InstanceTimers.child_exiting_tree.is_connected(_check_empty):
			return
		if %InstanceTimers.get_child_count() == 0:
			%InstanceTimers.child_exiting_tree.disconnect(_check_empty)
			%Recovery.start()
	%InstanceTimers.child_exiting_tree.connect(_check_empty)
	_check_empty.call()

func fire(arrow: Arrow, dir: Vector3) -> void:
	var new_v := _on_fire(arrow, dir)
	if new_v: dir = new_v
	get_tree().current_scene.add_child(arrow)
	arrow.activate(global_position, dir, _ENEMY_TEAM)
	fired.emit(arrow, dir)

func _look_at_player() -> void:
	if not player:
		return
	look_at(player.global_position)

func _patrol() -> void:
	pass

func _sussy() -> void:
	pass

func _alert() -> void:
	pass

func is_dead() -> bool:
	return _dead

func die() -> void:
	died.emit()

func _ready() -> void:
	if not Engine.is_editor_hint():
		%FireDebounce.wait_time = fire_rate
		%FireDebounce.timeout.connect(_on_fire_timeout)
		%FireDebounce.start()

func _on_fire_timeout() -> void:
	_look_at_player()
	if arrow_scene:
		fire(_make_arrow(arrow_scene), _get_arrow_dir(0))
	%FireDebounce.start()

func _physics_process(_delta: float) -> void:
	if not _alerted:
		_patrol()
	else:
		_sussy()
