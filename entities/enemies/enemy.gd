@tool
@icon("res://addons/at-icons/used/node3d/troll.svg")
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
@export var camera_focus := false
@export var stationary := false
@export var fixed_facing := false
@export var max_hits := 1
@export_group("firing")
@export var patterns: Array[ArrowPattern] = []
@export var fixed_patterns := false
@export var fire_release_frame := 3
@export var nock_points: Array[Vector2] = []

@export_group("hit")
@export var hit_flash_time := 0.2
@export var juice_color := Color(0.95, 0.85, 0.35)
@export var death_juice_style: JuiceSplatStyle = preload("res://systems/blood/juice_splat_death.tres")
@export_group("combat")
@export var combat_speed := 1.5
@export var combat_retreat_speed := 3.5
@export var combat_acceleration := 8.0
@export var orbit_radius := 3.0
@export var orbit_radius_tolerance := 0.75
@export var orbit_speed := 1.5
@export var orbit_flip_interval_min := 2.5
@export var orbit_flip_interval_max := 6.0
@export var orbit_spacing_angle := 60.0
@export var separation_radius := 1.5
@export var wall_probe_distance := 0.6
@export_group("maneuver")
@export_range(0.0, 1.0) var maneuver_chance := 0.35
@export var maneuver_duration_min := 0.7
@export var maneuver_duration_max := 1.4
@export var push_radius_scale := 0.4
@export var push_speed_scale := 1.8
@export var retreat_radius_scale := 1.7
@export var maneuver_orbit_scale := 0.5

enum Maneuver { ORBIT, PUSH, RETREAT, HOLD }

signal fired(arrow: Arrow, dir: Vector3)

var _maneuver := Maneuver.ORBIT
var _maneuver_timer := 0.0

var _orbit_dir := 1.0
var _orbit_flip_timer := 0.0
var _wall_flip_cooldown := 0.0

var _facing := Vector3.FORWARD

var _nocked: Arrow

var _pattern_index := 0
var _hits_taken := 0

@onready var _visual_root: Node3D = %VisualRoot
@onready var _sprite: AnimatedSprite3D = %Sprite
@onready var _recovery: Timer = %Recovery
@onready var _inst_timers: Node = %InstanceTimers
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

	add_to_group("tree_fade_targets")
	add_to_group("enemies")
	if randf() < 0.5:
		_orbit_dir = -1.0
	_reset_orbit_flip_timer()
	_sprite.set_layer_mask_value(ScreenShaderManager.UNFILTERED_LAYER, true)
	_sprite.frame_changed.connect(_update_nocked)
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	if fixed_facing:
		face(global_position - global_basis.z)
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

func _on_sprite_animation_finished() -> void:
	if health.is_dead(): return
	if _sprite.animation != &"fire": return
	_sprite.animation = &"default"

func is_dead() -> bool:
	return health.is_dead()

func _parse_movement_pattern(
	pattern: Dictionary[float, Vector2]
) -> Dictionary[float, Vector3]:
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

func _get_arrow_angle(
	offset: float,
	spread: float,
	count: int,
	i: int) -> float:
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

func _execute_instance(
	instance: FiringInstance,
	offset: float,
	spread: float,
	count: int,
	i: int
) -> void:
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
		if health.is_dead():
			timer.queue_free()
			return
		var nfired = timer.get_meta("fired")
		if nfired >= count:
			return
		if nfired > 0 and instance.reload_anim:
			await _play_shooting_anim(instance.type)
			if not is_instance_valid(timer):
				return
			if health.is_dead():
				timer.queue_free()
				return
		_execute_instance(instance, offset, spread, count, nfired)
		nfired += 1
		timer.set_meta("fired", nfired)
		if nfired >= count:
			timer.queue_free()
		else:
			timer.start()

func _play_shooting_anim(scene: PackedScene) -> void:
	_sprite.play("fire")
	_sprite.frame = 0
	_sprite.frame_progress = 0.0
	_nock_scene(scene)
	await _await_fire_release()
	_release_nocked()

func _execute_volley(instance: FiringInstance):
	if health.is_dead(): return
	var count: int = _get_rand(instance.count, instance.max_count)
	var spread := deg_to_rad(_get_rand(instance.spread, instance.max_spread))
	var offset := deg_to_rad(_get_rand(instance.offset, instance.max_offset))
	if instance.instance_delay == 0.0 and instance.max_instance_delay == 0.0:
		for i in range(count):
			_execute_instance(instance, offset, spread, count, i)
	else:
		var instance_deb := Timer.new()
		instance_deb.set_meta("fired", 0)
		instance_deb.wait_time = instance.instance_delay
		instance_deb.one_shot = true
		instance_deb.timeout.connect(_on_instance_timer_timeout.bind(
			instance_deb,
			instance,
			offset,
			spread,
			count
		))
		_inst_timers.add_child(instance_deb)
		# no timeout on first instance
		_on_instance_timer_timeout(
			instance_deb,
			instance,
			offset,
			spread,
			count
		)
		instance_deb.start()

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
	if health.is_dead(): return
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
	if fixed_facing: return
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
	if fixed_patterns:
		var next := patterns[_pattern_index % len(patterns)]
		_pattern_index += 1
		return next
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
	if stationary: return
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

	if not stationary:
		_orbit(player, dt)

	_face_player()

func _orbit(player: Player, dt: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var forward := Vector3.FORWARD
	if dist > 0.001:
		forward = to_player / dist
	var tangent := forward.cross(Vector3.UP)

	_tick_orbit_flip(dt, dist)

	var radial_error := dist - _get_target_radius()
	var radial_weight := clampf(radial_error / orbit_radius_tolerance, -1.0, 1.0)
	var radial := forward * radial_weight * combat_speed
	if radial_weight < 0.0:
		radial = forward * radial_weight * combat_retreat_speed
	if _maneuver == Maneuver.PUSH:
		radial *= push_speed_scale

	var orbit_weight := _orbit_dir * _get_orbit_scale() + _get_orbit_spacing(player)
	var orbital := tangent * orbit_weight * orbit_speed

	var desired := radial + orbital + _get_separation() * combat_speed
	desired.y = 0.0

	if _is_blocked(orbital):
		_flip_orbit()

	velocity = velocity.move_toward(desired, combat_acceleration * dt)
	move_and_slide()

func _tick_orbit_flip(dt: float, dist: float) -> void:
	_wall_flip_cooldown = maxf(_wall_flip_cooldown - dt, 0.0)
	if _maneuver != Maneuver.ORBIT:
		_maneuver_timer -= dt
		if _maneuver_timer <= 0.0:
			_maneuver = Maneuver.ORBIT
		return
	_orbit_flip_timer -= dt
	if _orbit_flip_timer > 0.0:
		return
	_reset_orbit_flip_timer()
	if randf() < maneuver_chance:
		_start_maneuver(dist)
	else:
		_orbit_dir = -_orbit_dir

func _start_maneuver(dist: float) -> void:
	var roll := randf()
	if dist > orbit_radius * 1.5:
		if roll < 0.7:
			_maneuver = Maneuver.PUSH
		else:
			_maneuver = Maneuver.HOLD
	elif dist < orbit_radius * 0.6:
		if roll < 0.7:
			_maneuver = Maneuver.RETREAT
		else:
			_maneuver = Maneuver.HOLD
	else:
		if roll < 0.4:
			_maneuver = Maneuver.PUSH
		elif roll < 0.75:
			_maneuver = Maneuver.RETREAT
		else:
			_maneuver = Maneuver.HOLD
	_maneuver_timer = randf_range(maneuver_duration_min, maneuver_duration_max)

func _get_target_radius() -> float:
	match _maneuver:
		Maneuver.PUSH:
			return orbit_radius * push_radius_scale
		Maneuver.RETREAT:
			return orbit_radius * retreat_radius_scale
	return orbit_radius

func _get_orbit_scale() -> float:
	match _maneuver:
		Maneuver.PUSH, Maneuver.RETREAT:
			return maneuver_orbit_scale
		Maneuver.HOLD:
			return 0.0
	return 1.0

func _reset_orbit_flip_timer() -> void:
	_orbit_flip_timer = randf_range(orbit_flip_interval_min, orbit_flip_interval_max)

func _flip_orbit() -> void:
	if _wall_flip_cooldown > 0.0:
		return
	_orbit_dir = -_orbit_dir
	_wall_flip_cooldown = 0.5
	_reset_orbit_flip_timer()

func _is_blocked(dir: Vector3) -> bool:
	if dir.length_squared() < 0.001:
		return false
	return test_move(global_transform, dir.normalized() * wall_probe_distance)

func _get_living_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if not other or other == self:
			continue
		if other.is_dead():
			continue
		result.append(other)
	return result

func _get_orbit_spacing(player: Player) -> float:
	var spacing := deg_to_rad(orbit_spacing_angle)
	if spacing <= 0.0:
		return 0.0
	var center := player.global_position
	var my_angle := atan2(global_position.z - center.z, global_position.x - center.x)
	var push := 0.0
	for other in _get_living_enemies():
		var other_angle := atan2(other.global_position.z - center.z, other.global_position.x - center.x)
		var diff := wrapf(my_angle - other_angle, -PI, PI)
		if absf(diff) >= spacing:
			continue
		var strength := 1.0 - absf(diff) / spacing
		if diff < 0.0:
			strength = -strength
		push -= strength
	return clampf(push, -1.5, 1.5)

func _get_separation() -> Vector3:
	var push := Vector3.ZERO
	for other in _get_living_enemies():
		var away := global_position - other.global_position
		away.y = 0.0
		var d := away.length()
		if d >= separation_radius or d < 0.001:
			continue
		push += away / d * (1.0 - d / separation_radius)
	return push

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
	JuiceSplatter.splat(global_position, Vector3.ZERO, juice_color, 1.0, death_juice_style)
	_dash_target.make_invulnerable()
	_release_nocked()
	for t in _inst_timers.get_children():
		t.queue_free()
	_sprite.play("death")

func _on_sus_alerted() -> void:
	_recovery.start()
	var p = get_parent()
	for e in p.get_children():
		if (
			e.global_position.distance_to(global_position) < 10.0
			and not e.sus.is_alert()
		): 
			e.sus.baka(1.1)

func _on_recovery_timeout() -> void:
	if health.is_dead(): return
	var pattern := _select_pattern()
	if pattern.uses_windup and _sprite.sprite_frames.has_animation("windup"):
		_sprite.play("windup")
	else:
		_sprite.play("fire")
	_sprite.frame = 0
	_sprite.frame_progress = 0.0
	_nock_arrow(pattern)
	await _await_fire_release()
	_release_nocked()
	if health.is_dead(): return
	perform(pattern)

func _on_dash_targeted() -> void:
	DarkenManager.register_highlighted(self)

func _on_dash_untargeted() -> void:
	DarkenManager.unregister_highlighted(self)

func _on_dash_hit() -> void:
	if health.is_dead(): return
	_splat_juice()
	await _show_hit()
	_hits_taken += 1
	if _hits_taken >= max_hits:
		health.take_damage(1)
	else:
		_sprite.animation = &"default"

func _splat_juice() -> void:
	var dir := Vector3.ZERO
	var player := _get_player()
	if player:
		dir = global_position - player.global_position
	JuiceSplatter.splat(global_position, dir, juice_color)

func _await_fire_release() -> void:
	while (
		not health.is_dead()
		and _sprite.animation == "fire"
		and _sprite.frame < fire_release_frame
	):
		await _sprite.frame_changed

# only bananas should use this!!! TODO: proper enemy inheritance mayvbe?
func _nock_arrow(pattern: ArrowPattern) -> void:
	_release_nocked()
	if nock_points.is_empty():
		return
	if pattern.instances.is_empty():
		return
	_nock_scene(pattern.instances[0].type)

func _nock_scene(scene: PackedScene) -> void:
	_release_nocked()
	if nock_points.is_empty():
		return
	if not scene:
		return
	_nocked = scene.instantiate() as Arrow
	if not _nocked:
		return
	_visual_root.add_child(_nocked)
	_update_nocked()

func _update_nocked() -> void:
	if not _nocked:
		return
	if _sprite.animation != "fire" or _sprite.frame >= nock_points.size():
		_nocked.hide()
		return
	var point := nock_points[_sprite.frame]
	var lateral := -point.x
	if _sprite.flip_v:
		lateral = point.x
	_nocked.position = Vector3(lateral, 0.0, point.y - _nocked.tail_position)
	_nocked.show()

func _release_nocked() -> void:
	if not _nocked:
		return
	_nocked.queue_free()
	_nocked = null

#end banana code

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
