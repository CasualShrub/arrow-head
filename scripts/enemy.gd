@tool
extends CharacterBody3D
class_name Enemy

const _ENEMY_TEAM = Arrow.Team.ENEMY

@export var health: HealthComponent
@export var sus: SusComponent
@export var player: Player

@export_group("firing")
@export var patterns: Array[ArrowPattern] = []
# when set, overrides every pattern's arrow type — the fire/frost variants use this
@export var arrow_scene: PackedScene = null
@export var aim_time := 0.4
@export var release_time := 0.12

@export_group("sprites")
@export var frame1: Texture2D
@export var frame2: Texture2D
@export var frame3: Texture2D
@export var frame4: Texture2D   
@export var hit_normal: Texture2D
@export var hit_stretch: Texture2D

@export_group("hit")
@export var hit_flash_time := 0.15
@export var hurt_radius := 0.4:
	set(value):
		if value < 0: value = 0
		if _collider:
			_update_collider(_collider, value)
		hurt_radius = value

signal fired(arrow: Arrow, dir: Vector3)
signal died

@onready var _sprite: Sprite3D = %Sprite
@onready var _collider: CollisionShape3D = %Collider
@onready var _recovery: Timer = %Recovery
@onready var _inst_timers: Node = %InstanceTimers

var _dead := false
var _aiming := false
var _hit_showing := false
var _base_tex: Texture2D
var _movement_pattern: Dictionary[float, Vector3] = {}
var _movement_pattern_start: float

func get_hit() -> void:
	if is_dead():
		return
	health.take_damage(1)
	_show_hit()

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c:
		return
	var s := SphereShape3D.new()
	s.radius = r
	c.shape = s

func _on_fire(_arrow: Arrow, dir: Vector3) -> Vector3:
	_aiming = false
	_set_base(frame4)
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

func _patrol(dt: float) -> void:
	_alert(dt)

func _med_sus(dt: float) -> void:
	_patrol(dt)
	
func _high_sus(dt: float) -> void:
	_patrol(dt)

func _alert(_dt: float) -> void:
	_look_at_player()

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
	died.emit()

func _on_health_changed() -> void:
	if not _dead and health.current <= 0:
		die()

func _on_recovery_timeout() -> void:
	if _dead: return
	var pattern := _select_pattern()
	await _play_draw()
	if _dead: return
	perform(pattern)

func _set_sprite(tex: Texture2D) -> void:
	if _sprite:
		_sprite.texture = tex

func highlight_on(c: Color) -> void:
	_sprite.modulate = c

func highlight_off() -> void:
	_sprite.modulate = Color(1, 1, 1, 1)
func _set_base(tex: Texture2D) -> void:
	_base_tex = tex
	if not _hit_showing:
		_set_sprite(tex)

func _play_draw() -> void:
	_aiming = true
	var draw := [frame1, frame2, frame3]
	var step := aim_time / draw.size()
	for f in draw:
		_set_base(f)
		await get_tree().create_timer(step).timeout
		if _dead: return

func _show_hit() -> void:
	_hit_showing = true
	_set_sprite(hit_stretch if _aiming else hit_normal)
	await get_tree().create_timer(hit_flash_time).timeout
	_hit_showing = false
	if _dead: return
	_set_sprite(_base_tex)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if is_dead(): return
	_select_behaviour(delta)

func _ready() -> void:
	if not Engine.is_editor_hint():
		_set_base(frame1)
