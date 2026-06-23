@tool
extends CharacterBody2D
class_name Enemy

const _ENEMY_TEAM = Arrow.Team.ENEMY

@export var health: HealthComponent

@export_group("firing")
@export var arrow_scene: PackedScene

var _facing := Vector2()
var _alerted := false
var _movement_pattern: Dictionary[float, Vector2] = {}

signal fired(arrow: Arrow)

func get_hit(_arrow: Arrow) -> void:
	health.take_damage(1)

func _on_fire(arrow: Arrow) -> void:
	pass

func _parse_movement_pattern(pattern: Dictionary[float, Vector2]) -> Dictionary[float, Vector2]:
	var parsed := {}
	var curr_tick = Time.get_ticks_msec()
	for t in pattern:
		var o := pattern[t]
		parsed[t+curr_tick] = position + o
	return parsed

func _get_spread(min_spread, max_spread) -> float:
	if max_spread == 0.0: return min_spread
	return randf_range(min_spread, max_spread)

func _get_arrow_angle(i: int, spread: float, offset: float) -> float:
	var i_spread := spread / i
	return i_spread + offset

func _get_arrow_dir(angle: float) -> Vector2:
	return _facing.rotated(angle)

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

func perform(pattern: ArrowPattern) -> void:
	if pattern.has_movement_pattern:
		var p = _parse_movement_pattern(pattern.movement_pattern)
		_movement_pattern = p
	for instance in pattern.instances:
		var count: int = _get_rand(instance.count, instance.max_count)
		var spread: float = _get_rand(instance.spread, instance.max_spread)
		var offset: float = _get_rand(instance.offset, instance.max_offset)
		
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
	
	var _check_empty: Callable
	_check_empty = func():
		if !%InstanceTimers.child_exiting_tree.is_connected(_check_empty):
			return
		if %InstanceTimers.get_child_count() == 0:
			%InstanceTimers.child_exiting_tree.disconnect(_check_empty)
			%Recovery.start()
	%InstanceTimers.child_exiting_tree.connect(_check_empty)
	_check_empty.call()

func fire(arrow: Arrow, dir: Vector2) -> void:
	arrow.activate(position, dir, _ENEMY_TEAM)
	fired.emit(arrow)

func look_at_player(_player: Player) -> void:
	pass

func _on_recovered() -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass
