@tool
extends CharacterBody3D
class_name Enemy

const _ENEMY_TEAM = Arrow.Team.ENEMY

@export var health: HealthComponent
@export var sus: SusComponent
@export var player: Player

@export var has_intro := false
@export_group("firing")
@export var patrol_route: Array[Vector3] = []
@export var patterns: Array[ArrowPattern] = []
# when set, overrides every pattern's arrow type — the fire/frost variants use this
@export var arrow_scene: PackedScene = null
@export var aim_time := 0.4
@export var release_time := 0.12
@export var fire_release_frame := 3

@export_group("hit")
@export var hit_flash_time := 0.15
@export var hurt_radius := 0.4:
	set(value):
		if value < 0: value = 0
		if _collider:
			_update_collider(_collider, value)
		hurt_radius = value
@export_group("patrol")
@export var patrol_speed := 1.0
@export var patrol_is_closed_loop := false
@export var alwayds_alert := false
@export_group("combat")
@export var combat_speed := 1.0
@export var combat_strafe_radius := 4.0
@export var combat_strafe_speed := 2.0
@export var combat_reposition_chance := 0.3

enum CombatState { STRAFE, CHARGE, RETREAT, STOP }
var _combat_state := CombatState.STRAFE

var _patrol_world_points: Array[Vector3] = []
var _patrol_len: float
var _patrol_progress := 0.0
var _patrol_dir := 1.0

var _strafe_dir := 1.0
var _reposition_timer := 0.0
var _reposition_interval := 2.0

signal fired(arrow: Arrow, dir: Vector3)
signal died

@onready var _sprite: AnimatedSprite3D = %Sprite
@onready var _collider: CollisionShape3D = %Collider
@onready var _recovery: Timer = %Recovery
@onready var _inst_timers: Node = %InstanceTimers
@onready var _patrol_points: Node3D = %PatrolPoints
@onready var _ray_left: RayCast3D = %RayLeft
@onready var _ray_right: RayCast3D = %RayRight
@onready var _ray_forward: RayCast3D = %RayForward

var _dead := false
var _movement_pattern: Dictionary[float, Vector3] = {}
var _movement_pattern_start: float

func get_hit() -> void:
	if is_dead():
		return
	await _show_hit()
	health.take_damage(1)

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c:
		return
	var s := SphereShape3D.new()
	s.radius = r
	c.shape = s

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

func _start_movement_pattern(pattern: Dictionary[float, Vector2]) -> void:
	_movement_pattern = _parse_movement_pattern(pattern)
	_movement_pattern_start = Time.get_ticks_msec()

func _get_arrow_angle(offset: float, spread: float, count: int, i: int) -> float:
	if count <= 1:
		return offset
	var i_spread := -(spread / 2) + (i as float / (count - 1) as float * spread)
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

func _execute_instance(instance: FiringInstance, offset: float, spread: float, count: int, i: int) -> void:
	if instance.individual_offset:
		offset = _get_rand(instance.offset, instance.max_offset)
	var arrow := _make_arrow(arrow_scene if arrow_scene else instance.type)
	var angle := _get_arrow_angle(offset, spread, count, i)
	var dir := _get_arrow_dir(angle)
	fire(arrow, dir)

func _on_instance_timer_timeout(timer: Timer,
	instance: FiringInstance,
	offset: float,
	spread: float,
	count: int) -> void:
		var nfired = timer.get_meta("fired")
		if nfired >= count:
			return
		_execute_instance(instance, offset, spread, count, nfired)
		nfired += 1
		timer.set_meta("fired", nfired)
		if nfired >= count:
			timer.queue_free()

func _execute_volley(instance: FiringInstance):
	var count: int = _get_rand(instance.count, instance.max_count)
	var spread: float = _get_rand(instance.spread, instance.max_spread)
	var offset: float = _get_rand(instance.offset, instance.max_offset)
	if instance.instance_delay == 0.0 and instance.max_instance_delay == 0.0:
			for i in range(count):
				_execute_instance(instance, offset, spread, count, i)
	else:
		var instance_deb := Timer.new()
		instance_deb.set_meta("fired", 0)
		instance_deb.autostart = true
		instance_deb.wait_time = instance.instance_delay
		instance_deb.one_shot = false
		instance_deb.timeout.connect(_on_instance_timer_timeout.bind(
			instance_deb,
			instance,
			offset,
			spread,
			count
		))
		_inst_timers.add_child(instance_deb)

func perform(pattern: ArrowPattern) -> void:
	if pattern.has_movement_pattern:
		_start_movement_pattern(pattern.movement_pattern)
	var max_startup := 0.0
	for instance in pattern.instances:
		var startup: int = _get_rand(instance.starting_delay, instance.starting_delay)
		
		if startup == 0.0:
			_execute_volley(instance)
		else:
			max_startup = max(startup, max_startup)
			get_tree().create_timer(startup).timeout.connect(_execute_volley.bind(
				instance
			))
	
	if max_startup > 0.0:
		await get_tree().create_timer(max_startup).timeout
	
	while _inst_timers.get_child_count() > 0:
		var c = await _inst_timers.child_exiting_tree as Node
		# fully out
		await c.tree_exited

	_recovery.wait_time = pattern.recovery

	_recovery.start()

func fire(arrow: Arrow, dir: Vector3) -> void:
	var new_v := _on_fire(arrow, dir)
	if new_v: dir = new_v
	get_tree().current_scene.add_child(arrow)
	arrow.activate(global_position, dir, _ENEMY_TEAM)
	SoundManager.play("arrow_woosh")
	fired.emit(arrow, dir)

func _look_at_player() -> void:
	if not player:
		return
	look_at(player.global_position)

func _select_pattern() -> ArrowPattern:
	if len(patterns) == 0:
		return ArrowPattern.new()
	var total := 0.0
	for p in patterns:
		total += p.weight
	var roll := randf_range(0.0, total)
	var c := 0.0
	for p in patterns:
		c += p.weight
		if c >= roll:
			return p
	return patterns[0]

func _get_patrol_pos() -> Vector3:
	if _patrol_len == 0.0:
		return global_position

	var target_dist := _patrol_progress * _patrol_len
	var curr_dist := 0.0

	for i in range(1, len(_patrol_world_points)):
		var last_pos := _patrol_world_points[i - 1]
		var p_pos: Vector3 = _patrol_world_points[i]
		var dist := last_pos.distance_to(p_pos)

		if curr_dist + dist >= target_dist:
			var offset := target_dist - curr_dist
			var new_pos := last_pos.lerp(p_pos, offset / dist)
			new_pos.y = global_position.y
			return new_pos

		curr_dist += dist

	var final_pos: Vector3 = _patrol_points.get_child(
		_patrol_points.get_child_count() - 1
	).global_position
	final_pos.y = global_position.y
	return final_pos

func _patrol(dt: float) -> void:
	if _patrol_len == 0.0 or len(_patrol_world_points) == 1:
		return
	var new_pos := _get_patrol_pos()
	if new_pos != global_position:
		look_at(new_pos)
	global_position = new_pos
	_patrol_progress += dt * patrol_speed / _patrol_len * _patrol_dir
	if _patrol_progress > 1.0:
		_patrol_progress = 1 - (_patrol_progress - 1)
		_patrol_dir = -1.0
	elif _patrol_progress < 0.0:
		_patrol_progress *= -1.0
		_patrol_dir = 1.0

func _med_sus(_dt: float) -> void:
	_look_at_player()
	
func _high_sus(_dt: float) -> void:
	_look_at_player()

func _alert(dt: float) -> void:
	if not player:
		return

	var to_player := (player.global_position - global_position)
	to_player.y = 0.0
	var dist := to_player.length()
	var forward := to_player.normalized()
	var right := forward.rotated(Vector3.UP, PI * 0.5)
	var move := Vector3.ZERO

	_reposition_timer += dt
	if _reposition_timer >= _reposition_interval:
		_reposition_timer = 0.0
		_reposition_interval = randf_range(1.5, 3.5)
		_pick_combat_state(dist)

	match _combat_state:
		CombatState.STRAFE:
			if dist > combat_strafe_radius + 1.0:
				move += forward
			elif dist < combat_strafe_radius - 1.0:
				move -= forward
			move += right * _strafe_dir
		CombatState.CHARGE:
			move += forward * 2.0  # faster, aggressive
		CombatState.RETREAT:
			move -= forward
			move += right * _strafe_dir  # sidestep while backing off

	# Wall avoidance
	if _ray_forward.is_colliding():
		move -= forward * 2.0
	if _ray_left.is_colliding():
		move += right
	if _ray_right.is_colliding():
		move -= right

	if move.length() > 0.001:
		velocity = move.normalized() * combat_speed
		move_and_slide()
	
	look_at(player.global_position)

func _pick_combat_state(dist: float) -> void:
	_strafe_dir = 1.0 if randf() > 0.5 else -1.0
	var roll := randf()
	if dist > combat_strafe_radius * 2.0:
		# far away — charge or strafe toward them
		_combat_state = CombatState.CHARGE if roll < 0.6 else CombatState.STRAFE
	elif dist < combat_strafe_radius * 0.5:
		# too close — retreat or strafe
		_combat_state = CombatState.RETREAT if roll < 0.6 else CombatState.STRAFE
	else:
		# comfortable range — mostly strafe, occasional charge
		if roll < 0.45:
			_combat_state = CombatState.STRAFE
		elif roll < 0.7:
			_combat_state = CombatState.CHARGE
		elif roll < 0.85:
			_combat_state = CombatState.STOP
		else:
			_combat_state = CombatState.RETREAT
	
	if _combat_state == CombatState.STOP:
		_reposition_interval = randf_range(0.5, 1.2)

func _select_behaviour(dt: float) -> void:
	if sus.is_alert():
		_alert(dt)
	else:
		match sus.get_stage():
			sus.SusStage.LW:
				_patrol(dt)
			sus.SusStage.MD:
				_med_sus(dt)
			sus.SusStage.HI:
				_high_sus(dt)

func is_dead() -> bool:
	return _dead

func die() -> void:
	_dead = true
	SoundManager.play("banana_death")
	_sprite.play("death")
	died.emit()

func _on_sus_alerted() -> void:
	_recovery.start()
	var p = get_parent()
	for e in p.get_children():
		if e.global_position.distance_to(global_position) < 10.0 and not e.sus.is_alert(): 
			e.sus.baka(1.1)

func _on_health_changed() -> void:
	if not _dead and health.current <= 0:
		die()

func _on_recovery_timeout() -> void:
	if _dead: return
	var pattern := _select_pattern()
	if pattern.uses_windup and _sprite.sprite_frames.has_animation("windup"):
		_sprite.play("windup")
	else:
		_sprite.play("fire")
	await _await_fire_release()
	if _dead: return
	perform(pattern)

func _await_fire_release() -> void:
	while not _dead and _sprite.animation == "fire" and _sprite.frame < fire_release_frame:
		await _sprite.frame_changed

func highlight_on(c: Color) -> void:
	if is_dead(): return
	_sprite.modulate = c

func highlight_off() -> void:
	_sprite.modulate = Color(1, 1, 1, 1)

func _show_hit() -> void:
	_sprite.animation = "hit"
	_sprite.modulate = Color(10.0, 10.0, 10.0, 10.0)
	get_tree().set_deferred("paused", true)
	await get_tree().create_timer(hit_flash_time, true, false, true).timeout
	get_tree().paused = false
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if is_dead(): return
	_select_behaviour(delta)
	global_position.y = 0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_patrol_len = 0.0
	var last: Node3D = null
	for p in _patrol_points.get_children():
		_patrol_world_points.append(p.global_position)
		if last != null:
			_patrol_len += last.global_position.distance_to(p.global_position)
		last = p
	if has_intro and not CusteneManager.played:
		CusteneManager.played = true
		sus._vision.hide()
		%CameraPivot.focus(global_position)
		_sprite.play("intro")
		_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		%CameraPivot.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().set_deferred("paused", true)
		await _sprite.animation_finished
		get_tree().paused = false
		_sprite.process_mode = Node.PROCESS_MODE_INHERIT
		%CameraPivot.process_mode = Node.PROCESS_MODE_INHERIT
		_sprite.animation = "default"
		%CameraPivot.unfocus()
		sus._vision.show()
	if alwayds_alert:
		sus.baka(1.1)
