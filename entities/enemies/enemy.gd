@tool
@icon("res://addons/at-icons/node3d/troll.svg")
extends CharacterBody3D
class_name Enemy

@export var health: HealthComponent
@export var suspicion: SuspicionComponent
@export var patrol: PatrolComponent
@export var patrol_path: PatrolPath:
	set(value):
		if not patrol: return
		patrol.path = value
	get:
		return patrol.path if patrol else null

@export var has_intro := false
@export_group("firing")
@export var patterns: Array[ArrowPattern] = []
@export var fire_release_frame := 3

@export_group("hit")
@export var hit_flash_time := 0.2
@export_group("combat")
@export var combat_speed := 1.0
@export var combat_strafe_radius := 4.0
@export var combat_strafe_speed := 2.0
@export var combat_reposition_chance := 0.3

enum CombatState { STRAFE, CHARGE, RETREAT, STOP }

signal fired(arrow: Arrow, dir: Vector3)

var _combat_state := CombatState.STRAFE

var _strafe_dir := 1.0
var _reposition_timer := 0.0
var _reposition_interval := 2.0

var _facing := Vector3.FORWARD

@onready var _visual_root: Node3D = %VisualRoot
@onready var _sprite: AnimatedSprite3D = %Sprite
@onready var _recovery: Timer = %Recovery
@onready var _inst_timers: Node = %InstanceTimers
@onready var _ray_left: RayCast3D = %RayLeft
@onready var _ray_right: RayCast3D = %RayRight
@onready var _ray_forward: RayCast3D = %RayForward
@onready var _dash_target: TargetArea = %DashTarget

@onready var _init_flip := _sprite.flip_v

var _movement_pattern: Dictionary[float, Vector3] = {}
var _movement_pattern_start: float

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	if health.is_dead(): return
	_select_behaviour(delta)
	global_position.y = 0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	suspicion.state = suspicion.SuspicionState.HIGH
	_recovery.start()
	
	#if has_intro and not CusteneManager.played:
		#CusteneManager.played = true
		#%CameraPivot.focus(global_position)
		#_sprite.play("intro")
		#_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		#%CameraPivot.process_mode = Node.PROCESS_MODE_ALWAYS
		#get_tree().set_deferred("paused", true)
		#await _sprite.animation_finished
		#get_tree().paused = false
		#_sprite.process_mode = Node.PROCESS_MODE_INHERIT
		#%CameraPivot.process_mode = Node.PROCESS_MODE_INHERIT
		#_sprite.animation = "default"
		#%CameraPivot.unfocus()

func is_dead() -> bool:
	return health.is_dead()

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
	return _facing.rotated(Vector3.UP, angle)

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
	
	var angle := _get_arrow_angle(offset, spread, count, i)
	var dir := _get_arrow_dir(angle)
	
	fire(instance.type, dir)

func _on_instance_timer_timeout(timer: Timer,
	instance: FiringInstance,
	offset: float,
	spread: float,
	count: int
) -> void:
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
		var startup: int = _get_rand(
			instance.starting_delay,
			instance.max_starting_delay
		)
		
		if startup == 0.0:
			_execute_volley(instance)
		else:
			max_startup = max(startup, max_startup)
			get_tree().create_timer(startup).timeout.connect(
				_execute_volley.bind(instance)
			)
	
	if max_startup > 0.0:
		await get_tree().create_timer(max_startup).timeout
	
	while _inst_timers.get_child_count() > 0:
		var c = await _inst_timers.child_exiting_tree as Node
		# fully out
		await c.tree_exited

	_recovery.wait_time = pattern.recovery

	_recovery.start()

func fire(scene: PackedScene, dir: Vector3) -> void:
	var arrow := ArrowManager.make_arrow(scene, global_position, dir)
	if not arrow:
		push_error("Tried to fire invalid arrow.")
	
	var mod_dir := _modify_firing_direction(arrow, dir)
	arrow.change_direction(mod_dir)
	
	_on_fire(arrow, dir)
	fired.emit(arrow, dir)

func _on_fire(_arrow: Arrow, _dir: Vector3) -> void:
	pass

func _modify_firing_direction(_arrow: Arrow, dir: Vector3) -> Vector3:
	return dir

func _get_player() -> Player:
	if GameManager.player:
		return GameManager.player
	
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0]
	
	return null

func _face_player() -> void:
	var player := _get_player()
	if not player:
		return
	face(player.global_position)

func get_facing() -> Vector3:
	return _facing

func face(target: Vector3) -> void:
	target.y = global_position.y
	var direction := target - global_position
	direction.y = 0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	if _facing == direction:
		return
	
	_facing = direction
	_visual_root.look_at(target)
	if direction.x < 0:
		_sprite.flip_v = not _init_flip
	else:
		_sprite.flip_v = _init_flip

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

func _patrol(delta: float) -> void:
	if not patrol.has_path(): return
	patrol.tick(delta)
	var patrol_pos := patrol.get_patrol_position()
	if patrol_pos != global_position:
		face(patrol_pos)
	global_position = patrol_pos

func _med_sus(_dt: float) -> void:
	_face_player()
	
func _high_sus(_dt: float) -> void:
	_face_player()

func _alert(dt: float) -> void:
	var player := _get_player()
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

	_face_player()

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
	if suspicion.is_alert():
		_alert(dt)
	else:
		match suspicion.state:
			suspicion.SuspicionState.LOW:
				_patrol(dt)
			suspicion.SuspicionState.MEDIUM:
				_med_sus(dt)
			suspicion.SuspicionState.HIGH:
				_high_sus(dt)

func _on_died() -> void:
	SoundManager.play("banana_death")
	_dash_target.make_invulnerable()
	_sprite.play("death")

func _on_sus_alerted() -> void:
	_recovery.start()
	var p = get_parent()
	for e in p.get_children():
		if e.global_position.distance_to(global_position) < 10.0 and not e.sus.is_alert(): 
			e.sus.baka(1.1)

func _on_recovery_timeout() -> void:
	if health.is_dead(): return
	var pattern := _select_pattern()
	if pattern.uses_windup and _sprite.sprite_frames.has_animation("windup"):
		_sprite.play("windup")
	else:
		_sprite.play("fire")
	await _await_fire_release()
	perform(pattern)

func _on_dash_targeted() -> void:
	_sprite.set_layer_mask_value(20, true)

func _on_dash_untargeted() -> void:
	_sprite.set_layer_mask_value(20, false)

func _on_dash_hit() -> void:
	if health.is_dead(): return
	await _show_hit()
	health.take_damage(1)

func _await_fire_release() -> void:
	while not health.is_dead() and _sprite.animation == "fire" and _sprite.frame < fire_release_frame:
		await _sprite.frame_changed

func highlight_on(c: Color) -> void:
	if health.is_dead(): return
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
