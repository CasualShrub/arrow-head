@tool
extends CharacterBody3D
class_name Player

const _PLAYER_TEAM = Arrow.Team.PLAYER

@export var input: InputComponent
@export var health: HealthComponent
@export var sectors: SectorsComponent

@onready var _camera: Camera3D = %Camera
@onready var _recovery: Timer = %Recovery
@onready var _dashing: Timer = %Dashing
@onready var _dash_debounce: Timer = %DashDebounce
@onready var _sprite: Sprite3D = %Sprite
@onready var _collider: CollisionShape3D = %Collider

@export var speed := 6.0
@export_group("dashing")
@export var dash_time: float:
	set(value):
		if not _dashing: return
		_dashing.wait_time = value
	get:
		if not _dashing: return -1.0
		return _dashing.wait_time
@export var dash_cooldown: float:
	set(value):
		if not _dash_debounce: return
		_dash_debounce.wait_time = value
	get:
		if not _dash_debounce: return 0.0
		return _dash_debounce.wait_time
@export var max_dash_distance := 10.0
@export var slowdown := 0.4
@export var slowdown_speed := 0.5
@export_group("hurt")
@export var hurt_radius := 0.4:
	set(value):
		if value < 0: value = 0
		if _collider:
			_update_collider(_collider, value)  # may run before the node exists
		hurt_radius = value
@export_group("sectors")
@export var sector_count: int:
	set(value):
		if not sectors: return
		sectors.sector_count = value
	get:
		if not sectors: return -1
		return sectors.sector_count
@export var sector_centered: bool:
	set(value):
		if not sectors: return
		sectors.centered = value
	get:
		if not sectors: return false
		return sectors.centered
@export var sector_radius: float:
	set(value):
		if not sectors: return
		sectors.radius = value
	get:
		if not sectors: return false
		return sectors.radius
@export_group("eyes")
@export var eyes_normal: Texture2D
@export var eyes_lowhp: Texture2D
@export var eyes_hit: Texture2D
@export var eyes_hit_time := 0.36
@export_group("status_effects")
@export var burn_duration := 2.5
@export var freeze_duration := 2.0
@export var burn_spin_speed := 24.0
@export var burn_drift_speed := 240.0
@export var burn_redrift := 0.14  # avg time between random drift-direction changes (lurching)

signal hit(arrow: Arrow, sector: int)
signal fired(arrow: Arrow)
signal died()

var _sectors: Array[EmbeddedArrow]
var _dead := false
var _eyes_hit_showing := false
var _burn_time := 0.0
var _freeze_time := 0.0
var _burn_drift := Vector3.ZERO
var _burn_redrift := 0.0
var _burn_spin_dir := 1.0

var _dash_vel: Vector3

var _in_slowdown := false
var _slowmo_tween: Tween

@onready var _preview: DashPreviewComponent = %DashPreview
@onready var _eyes: Sprite3D = %Eyes
@onready var _arrows: Node3D = %Arrows

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c: return
	var s := SphereShape3D.new()
	s.radius = r
	c.shape = s

func get_facing() -> Vector3:
	return -global_basis.z

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
	var facing := get_facing()
	return atan2(facing.z, facing.x) + (PI / 2)

func embed_arrow(arrow: Arrow, sector: int) -> void:
	var selected_sectors := arrow.get_sectors(sector)
	var embedded := EmbeddedArrow.new(arrow, sector)
	sectors.store(selected_sectors, embedded)

func try_embed_arrow(arrow: Arrow, sector: int) -> bool:
	var selected_sectors := arrow.get_sectors(sector)
	if sectors.occupied(selected_sectors): return false
	embed_arrow(arrow, sector)
	return true

func enable_firing():
	for embedded in sectors.get_stored():
		if embedded is EmbeddedArrow:
			embedded.enable_firing()

func is_correct_catch(_arrow: Arrow, _sector: int) -> bool:
	#if arrow.kind == Arrow.Kind.NORMAL:
	#	return true  # white wildcard: any sector accepts it
	#return arrow.kind == kind_for_sector(sector)
	return true

func get_hit(arrow: Arrow) -> void:
	if is_dead():
		arrow.deactivate()
		return
	if is_dashing():
		return
	var sector := sectors.get_sector_from_position(arrow.global_position)
	if try_embed_arrow(arrow, sector):
		arrow.stick(_arrows)
		SoundManager.play("Q%d_fill" % clampi(sector + 1, 1, 4))
		SoundManager.play("apple_damage1" if arrow.kind != Arrow.Kind.NORMAL else "apple_damage2")
		if not is_correct_catch(arrow, sector):
			_apply_debuff(arrow.kind)
	else:
		arrow.queue_free()
		die()
	hit.emit(arrow, sector)
	_flash_eyes_hit()

func get_mouse_world_position() -> Vector3:
	var mouse = get_viewport().get_mouse_position()

	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)

	var plane := Plane(Vector3.UP, global_position.y)
	var hit_plane = plane.intersects_ray(origin, dir)

	if hit_plane == null:
		return Vector3.ZERO

	return hit_plane

func face_mouse() -> void:
	var mouse_pos := get_mouse_world_position()
	var look_target := Vector3(mouse_pos.x, global_position.y, mouse_pos.z)
	look_at(look_target)

func _move(dir: Vector2, _dt: float) -> void:
	var v = dir * speed
	velocity.x = v.x
	velocity.z = v.y
	velocity.y = 0
	var selected: int
	if velocity == Vector3.ZERO:
		selected = -1
	else:
		selected = sectors.get_sector_from_movement(dir)
	sectors.highlight_sector(selected)
	move_and_slide()

func is_dashing() -> bool:
	if not _dashing: return false
	return not _dashing.is_stopped()

func _can_dash() -> bool:
	if not _dash_debounce: return false
	return not is_dead() and _in_slowdown

func _try_dash() -> bool:
	if not _can_dash(): return false
	for e in sectors.get_stored():
		if e is EmbeddedArrow: #and e.is_firing_enabled():
			print("dashing")
			var mouse_pos := get_mouse_world_position()
			mouse_pos = _preview.get_end(mouse_pos)
			var mouse_offset := mouse_pos - global_position
			_dash(mouse_offset)
			return true
	return false

func _dash(dir: Vector3) -> void:
	var dir_len := dir.length()
	if dir_len < 0.001: return
	if dir_len > max_dash_distance:
		dir = dir.normalized() * max_dash_distance
	_dash_vel = dir / _dashing.wait_time
	var collided := _preview.get_enemies_in_path(global_position, global_position + dir)
	for e in collided:
		e.get_hit()
	_exit_slowdown()
	_dashing.start()

func _can_slowdown() -> bool:
	var flag := false
	for e in sectors.get_stored():
		if e is EmbeddedArrow:
			flag = true
			break
	return not is_dead() and not is_dashing() and not _in_slowdown and _dash_debounce.is_stopped() and flag

func _try_start_slowdown() -> bool:
	print("trying start")
	if not _can_slowdown(): return false
	_enter_slowdown()
	return true

func _try_cancel_slowdown() -> bool:
	if not _in_slowdown: return false
	_exit_slowdown()
	return true

func _enter_slowdown() -> void:
	print("slowing")
	_in_slowdown = true
	_preview.show()
	_set_time_scale(slowdown, slowdown_speed)

func _exit_slowdown() -> void:
	_in_slowdown = false
	_preview.hide()
	_set_time_scale(1.0, 0.0)

func _set_time_scale(target: float, duration: float) -> void:
	if _slowmo_tween: _slowmo_tween.kill()
	_slowmo_tween = create_tween()
	_slowmo_tween.tween_property(Engine, "time_scale", target, duration)

func _fire(arrow: Arrow, angle: float) -> void:
	var fire_dir := get_facing().rotated(Vector3.UP, angle)
	arrow.reparent(get_tree().current_scene)
	arrow.activate(global_position, fire_dir, _PLAYER_TEAM)
	SoundManager.play("apple_shooting")

func _try_fire(sector: int) -> void:
	print("trying to fire")
	if not _recovery.is_stopped(): return
	var embedded = sectors.take_stored(sector) as EmbeddedArrow
	if not embedded: return
	var arrow := embedded.grab()
	_fire(arrow, sectors.get_sector_center(sector))
	fired.emit(arrow)

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
	rotate(Vector3.UP, burn_spin_speed * _burn_spin_dir * delta)

func _update_status_tint() -> void:
	if is_burning():
		_sprite.modulate = Color(1, 0.5, 0.2)
	elif is_frozen():
		_sprite.modulate = Color(0.6, 0.85, 1)
	else:
		_sprite.modulate = Color.WHITE

func is_dead() -> bool:
	return _dead

func die() -> void:
	_dead = true
	_burn_time = 0.0
	_freeze_time = 0.0
	_sprite.modulate = Color.WHITE
	print("died")
	sectors.clear_stored()
	SoundManager.play("apple_death")
	died.emit()

func _on_sectors_changed() -> void:
	if sectors.full():
		enable_firing()

func _on_dashing_timeout() -> void:
	if dash_cooldown > 0.001:
		_dash_debounce.start()

func _update_slowdown(_delta: float) -> void:
	pass

func _update_dash(_delta: float) -> void:
	velocity = _dash_vel
	move_and_slide()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if is_dead(): return
	if input.consume_fire_pressed():
		_try_start_slowdown()
	if input.consume_fire_released():
		if not _try_dash():
			_try_cancel_slowdown()
	if is_burning():
		# careen chaotically: re-roll the drift direction on a short random timer
		_burn_redrift -= delta
		if _burn_redrift <= 0.0:
			_burn_drift = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
			_burn_redrift = burn_redrift * randf_range(0.6, 1.4)
		velocity = _burn_drift * burn_drift_speed
		move_and_slide()
	else:
		if is_dashing():
			_update_dash(delta)
		else:
			_move(input.get_direction(), delta)
		if _in_slowdown:
			_update_slowdown(delta)

func _update_preview(_delta: float) -> void:
	var pos := get_mouse_world_position()
	pos.y = global_position.y
	_preview.update(global_position, pos)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if _dead: return
	if _freeze_time > 0.0: _freeze_time -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_spin(delta)
	elif not is_frozen():
		face_mouse()
	if _in_slowdown:
		_update_preview(delta)
	_update_status_tint()

func _ready() -> void:
	_update_collider(_collider, hurt_radius)
	if not Engine.is_editor_hint():
		_update_eyes()
