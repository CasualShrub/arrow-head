@tool
extends CharacterBody2D
class_name Enemy

const _ENEMY_TEAM = Arrow.Team.ENEMY

@export var health: HealthComponent
@export var sus: SusComponent
@export var player: Player

@export_group("firing")
@export var arrow_scene: PackedScene
@export var fire_rate := 2.0

@export var aim_time := 0.4
@export var release_time := 0.12
@export var hit_flash_time := 0.15

@export var hurt_radius := 25.0:
	set(value):
		if value < 0: value = 0
		_update_collider(%HurtCollider, value)
		hurt_radius = value

@export_group("sprites")
@export var frame1: Texture2D
@export var frame2: Texture2D
@export var frame3: Texture2D
@export var frame4: Texture2D
@export var hit_normal: Texture2D
@export var hit_stretch: Texture2D

var _facing := Vector2()
var _dead := false
var _alerted := false
var _aiming := false
var _hit_showing := false
var _base_tex: Texture2D 
var _movement_pattern: Dictionary[float, Vector2] = {}

@onready var _sprite: Sprite2D = $Sprite2D

signal fired(arrow: Arrow)
signal died

func get_hit(_arrow: Arrow) -> void:
	health.take_damage(1)
	_show_hit()

func _update_collider(c: CollisionShape2D, r: float) -> void:
	if not c:
		return
	var s := CircleShape2D.new()
	s.radius = r
	c.shape = s

func _on_fire(arrow: Arrow) -> void:
	pass

func _parse_movement_pattern(pattern: Dictionary[float, Vector2]) -> Dictionary[float, Vector2]:
	var parsed := {}
	var curr_tick = Time.get_ticks_msec()
	for t in pattern:
		var o := pattern[t]
		parsed[t+curr_tick] = position + o
	return parsed

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

func fire(arrow: Arrow, dir: Vector2) -> void:
	get_tree().current_scene.add_child(arrow)
	arrow.activate(global_position, dir, _ENEMY_TEAM)
	fired.emit(arrow)

func _look_at_player() -> void:
	if not player:
		return
	_facing = (player.global_position - global_position).normalized()

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
	if Engine.is_editor_hint():
		return
	_set_base(frame1)
	if health and not health.changed.is_connected(_on_health_changed):
		health.changed.connect(_on_health_changed)
	%FireDebounce.wait_time = fire_rate
	%FireDebounce.timeout.connect(_on_fire_timeout)
	%FireDebounce.start()

func _on_health_changed() -> void:
	# drained to 0 = death: stop the zombie (it kept firing) and leave the tree
	if not _dead and health.current <= 0:
		_dead = true
		die()
		queue_free()

func _on_fire_timeout() -> void:
	_look_at_player()
	_aiming = true
	var draw := [frame1, frame2, frame3]
	var step := aim_time / draw.size()
	for frame in draw:
		_set_base(frame)
		await get_tree().create_timer(step).timeout
		if _dead:
			return
	if arrow_scene:
		fire(_make_arrow(arrow_scene), _facing)
	_set_base(frame4)
	await get_tree().create_timer(release_time).timeout
	if _dead:
		return
	_aiming = false
	_set_base(frame1)
	%FireDebounce.start()

func _set_base(tex: Texture2D) -> void:
	_base_tex = tex
	if not _hit_showing:
		_set_sprite(tex)

func _set_sprite(tex: Texture2D) -> void:
	if _sprite:
		_sprite.texture = tex

func _show_hit() -> void:
	_hit_showing = true
	_set_sprite(hit_stretch if _aiming else hit_normal)
	await get_tree().create_timer(hit_flash_time).timeout
	_hit_showing = false
	if _dead:
		return
	_set_sprite(_base_tex)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_look_at_player()
	if _sprite and _facing != Vector2.ZERO:
		_sprite.rotation = _facing.angle()
	if not _alerted:
		_patrol()
	else:
		_sussy()
