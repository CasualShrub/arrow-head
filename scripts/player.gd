@tool
extends CharacterBody2D
class_name Player

const _PLAYER_TEAM = Arrow.Team.PLAYER

@export var input: InputComponent
@export var health: HealthComponent

@export var speed := 200.0
@export_group("melee")
@export var melee_range := 70.0
@export var melee_cooldown := 0.4
@export_group("shooting")
@export var shoot_cooldown := 0.25
@export_group("hurt")
@export var hurt_radius := 25.0:
	set(value):
		if value < 0: value = 0
		_update_collider(get_node_or_null("%HurtCollider"), value)  # may run before the node exists
		hurt_radius = value
@export var sector_count := 4
@export var sector_centered := false
@export_group("eyes")
@export var eyes_normal: Texture2D
@export var eyes_lowhp: Texture2D
@export var eyes_hit: Texture2D
@export var eyes_hit_time := 0.36
@export_group("sectors")
# sector index -> the Arrow.Kind correctly caught there (size should match sector_count)
@export var sector_kinds: Array[int] = [
	Arrow.Kind.INCENDIARY,
	Arrow.Kind.FROST,
	Arrow.Kind.INCENDIARY,
	Arrow.Kind.FROST,
]
@export_group("status_effects")
@export var burn_duration := 2.5
@export var freeze_duration := 2.0
@export var burn_spin_speed := 24.0
@export var burn_drift_speed := 140.0
@export var burn_redrift := 0.14  # avg time between random drift-direction changes (lurching)

signal hit(arrow: Arrow, sector: int)
signal fired(arrow: Arrow)
signal ammo_changed(count: int)
signal died()

var _sectors: Array[EmbeddedArrow]
var _ammo: Array[Arrow] = []
var _dead := false
var _facing := Vector2()
var _melee_ready := true
var _shoot_ready := true
var _eyes_hit_showing := false
var _burn_time := 0.0
var _freeze_time := 0.0
var _burn_drift := Vector2.ZERO
var _burn_redrift := 0.0
var _burn_spin_dir := 1.0

@onready var _eyes: Sprite2D = %Eyes

func _update_collider(c: CollisionShape2D, r: float) -> void:
	if not c: return
	var s := CircleShape2D.new()
	s.radius = r
	c.shape = s


func embedded_count() -> int:
	var n := 0
	for em in _sectors:
		if em:
			n += 1
	return n

func _update_eyes() -> void:
	if not _eyes or _eyes_hit_showing:
		return
	_eyes.texture = eyes_lowhp if embedded_count() >= 3 else eyes_normal

func _flash_eyes_hit() -> void:
	if not _eyes:
		return
	_eyes_hit_showing = true
	_eyes.texture = eyes_hit
	await get_tree().create_timer(eyes_hit_time).timeout
	_eyes_hit_showing = false
	_update_eyes()

func get_facing_angle() -> float:
	return atan2(_facing.y, _facing.x) + (PI / 2)

func _setup_sectors() -> void:
	_sectors = []
	_sectors.resize(sector_count)

func get_sector(pos: Vector2) -> int:
	var sector_size := 2 * PI / sector_count
	var theta := atan2(pos.y, pos.x) - get_facing_angle()
	if sector_centered:
		theta += sector_size / 2
	if theta < 0:
		theta += 2 * PI
	elif theta >= 2 * PI:
		theta -= 2 * PI
	return floor(theta / sector_size)

func get_embedded(sector: int) -> EmbeddedArrow:
	return _sectors[sector]

func fully_embedded() -> bool:
	for embedded in _sectors:
		if not embedded: return false
	return true

func sector_occupied(sector: int) -> bool:
	return get_embedded(sector) != null

func sectors_occupied(sectors: Array[int]) -> bool:
	for s in sectors:
		if sector_occupied(s): return true
	return false

func embed_arrow(arrow: Arrow, sector: int) -> void:
	var selected_sectors := arrow.get_sector(sector)
	var embedded := EmbeddedArrow.new(arrow, sector)
	for s in selected_sectors:
		_sectors[s] = embedded
	_try_absorb()

func try_embed_arrow(arrow: Arrow, sector: int,) -> bool:
	var selected_sectors := arrow.get_sector(sector)
	if sectors_occupied(selected_sectors): return false
	embed_arrow(arrow, sector)
	return true

func enable_firing():
	for embedded in _sectors:
		embedded.enable_firing()

func clear_embedded() -> void:
	var freed := {}
	for embedded in _sectors:
		if not embedded or freed.has(embedded):
			continue
		freed[embedded] = true
		var arrow := embedded.get_arrow()
		if arrow:
			arrow.queue_free()
		embedded.queue_free()
	_setup_sectors()
	_update_eyes()

func kind_for_sector(sector: int) -> int:
	if sector < 0 or sector >= sector_kinds.size():
		return Arrow.Kind.NORMAL
	return sector_kinds[sector]

func is_correct_catch(arrow: Arrow, sector: int) -> bool:
	if arrow.kind == Arrow.Kind.NORMAL:
		return true  # white wildcard: any sector accepts it
	return arrow.kind == kind_for_sector(sector)

func get_hit(arrow: Arrow) -> void:
	if _dead:
		return
	var sector := get_sector(arrow.global_position - global_position)
	var correct := is_correct_catch(arrow, sector)
	# arrows always pincushion: stick in the sector they hit, or kill on an occupied one.
	# a wrong-color arrow still sticks, but its debuff fires as the penalty.
	if try_embed_arrow(arrow, sector):
		arrow.stick(%Arrows)
		if not correct:
			_apply_debuff(arrow.kind)
	else:
		arrow.queue_free()
		die()
	hit.emit(arrow, sector)
	_flash_eyes_hit()

func face_mouse(mouse_pos: Vector2) -> void:
	_facing = global_position.direction_to(mouse_pos)
	%Arrows.rotation = get_facing_angle()

func move(dir: Vector2, _dt: float) -> void:
	velocity = dir * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if is_burning(): return  # no control at all while spinning on fire
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			melee()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			shoot()

# swing toward the mouse: weaponize the arrow stuck in the aimed sector, then clear it
func melee() -> void:
	if not _melee_ready: return
	var sector := get_sector(_facing)
	var embedded := get_embedded(sector)
	if not embedded: return
	var arrow := embedded.get_arrow()
	_melee_ready = false
	get_tree().create_timer(melee_cooldown).timeout.connect(func(): _melee_ready = true)
	_melee_hit()
	_consume(embedded)
	fired.emit(arrow)

func _melee_hit() -> void:
	var shape := CircleShape2D.new()
	shape.radius = melee_range
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + _facing * (melee_range * 0.5))
	q.collision_mask = 1 << 3  # enemy = layer 4
	for result in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var col = result.get("collider")
		if not (col is Enemy):
			continue
		var to_enemy: Vector2 = (col.global_position - global_position).normalized()
		if _facing.dot(to_enemy) > 0.3:  # only enemies in front of the swing
			col.get_hit(null)

func _consume(embedded: EmbeddedArrow) -> void:
	var arrow := embedded.get_arrow()
	if arrow:
		arrow.queue_free()
	for s in _sectors.size():
		if _sectors[s] == embedded:
			_sectors[s] = null
	embedded.queue_free()
	_update_eyes()

# status effects from mis-caught special arrows
func is_burning() -> bool: return _burn_time > 0.0
func is_frozen() -> bool: return _freeze_time > 0.0

func _apply_debuff(kind: int) -> void:
	match kind:
		Arrow.Kind.INCENDIARY:
			_burn_time = burn_duration
			_burn_redrift = 0.0  # re-roll the drift on the first burning frame
			_burn_spin_dir = 1.0 if randf() < 0.5 else -1.0
		Arrow.Kind.FROST:
			_freeze_time = freeze_duration

func _burn_spin(delta: float) -> void:
	if _facing == Vector2.ZERO:
		_facing = Vector2.RIGHT
	_facing = _facing.rotated(burn_spin_speed * _burn_spin_dir * delta)
	%Arrows.rotation = get_facing_angle()

func _update_status_tint() -> void:
	if is_burning():
		%Sprite.modulate = Color(1, 0.5, 0.2)
	elif is_frozen():
		%Sprite.modulate = Color(0.6, 0.85, 1)
	else:
		%Sprite.modulate = Color.WHITE

# a full set of 4 gets pulled out of the sectors into a shoot-back pool, but only while the
# pool is empty — you must spend the current batch before the next one loads
func _try_absorb() -> void:
	if not fully_embedded() or not _ammo.is_empty():
		return
	var taken := {}
	for em in _sectors:
		if not em or taken.has(em):
			continue
		taken[em] = true
		var arrow := em.get_arrow()
		if arrow and is_instance_valid(arrow):
			arrow.free_on_finish = false  # held in the pool: don't let it self-free off-screen
			arrow.deactivate()
			_ammo.append(arrow)
		em.queue_free()
	_setup_sectors()
	_update_eyes()
	ammo_changed.emit(_ammo.size())

# right-click: fling one stored arrow back toward the mouse as a player-team projectile
func shoot() -> void:
	if not _shoot_ready:
		return
	while not _ammo.is_empty() and not is_instance_valid(_ammo[-1]):
		_ammo.pop_back()  # discard any pooled arrow that got freed out from under us
	if _ammo.is_empty():
		ammo_changed.emit(_ammo.size())
		return
	var arrow: Arrow = _ammo.pop_back()
	_shoot_ready = false
	get_tree().create_timer(shoot_cooldown).timeout.connect(func(): _shoot_ready = true)
	arrow.free_on_finish = true  # back in flight: clean it up when it leaves the arena
	if arrow.get_parent() != get_tree().current_scene:
		arrow.reparent(get_tree().current_scene)
	arrow.activate(global_position, _facing, _PLAYER_TEAM)
	fired.emit(arrow)
	ammo_changed.emit(_ammo.size())
	_try_absorb()

func is_dead() -> bool:
	return _dead

func die() -> void:
	_dead = true
	_burn_time = 0.0
	_freeze_time = 0.0
	%Sprite.modulate = Color.WHITE
	print("You died!")
	clear_embedded()
	died.emit()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if _dead: return
	if is_burning():
		# careen chaotically: re-roll the drift direction on a short random timer
		_burn_redrift -= delta
		if _burn_redrift <= 0.0:
			_burn_drift = Vector2.RIGHT.rotated(randf() * TAU)
			_burn_redrift = burn_redrift * randf_range(0.6, 1.4)
		velocity = _burn_drift * burn_drift_speed
		move_and_slide()
	else:
		move(input.get_direction(), delta)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if _dead: return
	if _freeze_time > 0.0: _freeze_time -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_spin(delta)
	elif not is_frozen():
		face_mouse(get_global_mouse_position())
	_update_status_tint()

func _ready() -> void:
	_setup_sectors()
	_update_collider(%HurtCollider, hurt_radius)
	_update_eyes()
