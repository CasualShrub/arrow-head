@tool
extends CharacterBody3D
class_name Player

const _PLAYER_TEAM = Arrow.Team.PLAYER

@export var input: InputComponent
@export var health: HealthComponent
@export var sectors: SectorsComponent

@export var speed := 6.0
@export_group("dashing")
@export var dash_time: float:
	set(value):
		if not _dashing: return
		_dashing.wait_time = value
	get:
		if not _dashing: return -1.0
		return _dashing.wait_time
@export var arrow_dig_depth := 0.15 #dig arrow deeper into apple's skin a bit
@export var chunk_fx: PackedScene   ## burst of apple bits spawned where an arrow embeds
@export_group("shooting")
@export var shoot_cooldown := 0.25
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
@export var eye_deadzone := 0.4
@export var eyes_hit_time := 0.36:
	set(value):
		if not _eyes_hit: return
		_eyes_hit.wait_time = value
	get:
		if not _eyes_hit: return false
		return _eyes_hit.wait_time
@export_group("status_effects")
@export var burn_duration := 2.5
@export var freeze_duration := 2.0
@export var freeze_warn_time := 0.6
@export var freeze_blink_rate := 12.0
@export var burn_spin_speed := 24.0
@export var burn_drift_speed := 7.2
@export var burn_redrift := 0.14

signal hit(arrow: Arrow, sector: int)
signal fired(arrow: Arrow)
signal died()

var _dead := false
var _burn_time := 0.0
var _freeze_time := 0.0
var _burn_drift := Vector3.ZERO
var _burn_redrift := 0.0
var _burn_spin_dir := 1.0

var _dash_vel: Vector3

var _in_slowdown := false
var _slowmo_tween: Tween

var _invul := false

@onready var _camera: Camera3D = %Camera
@onready var _recovery: Timer = %Recovery
@onready var _dashing: Timer = %Dashing
@onready var _dash_debounce: Timer = %DashDebounce
@onready var _eyes_hit: Timer = %EyesHit
@onready var _sprite: AnimatedSprite3D = %Sprite
@onready var _eyes: AnimatedSprite3D = %Eyes
@onready var _status_sprite: AnimatedSprite3D = %StatusSprite
@onready var _collider: CollisionShape3D = %Collider
@onready var _preview: DashPreviewComponent = %DashPreview
@onready var _arrows: Node3D = %Arrows

@onready var _sprite_basis := _sprite.global_basis
@onready var _eyes_basis := _eyes.global_basis

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c: return
	var s := SphereShape3D.new()
	s.radius = r
	c.shape = s

func get_facing() -> Vector3:
	return -global_basis.z

enum EyeDir { HIDDEN = -1, CENTERED, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST }

func _get_eye_state() -> String:
	if not _eyes_hit.is_stopped():
		return "hit"
	if is_angry():
		return "angry"
	return "default"

func _get_eye_frame() -> int:
	var mouse_pos := get_mouse_world_position()
	var mouse_offset := global_position.direction_to(mouse_pos)
	var offset_len := global_position.distance_to(mouse_pos)
	var dir := Vector2(mouse_offset.x, mouse_offset.z)
	if offset_len < eye_deadzone:
		return 0
	var deg := rad_to_deg(atan2(dir.y, dir.x))
	if deg > -22.5 and deg <= 22.5:
		return 1 # right
	elif deg > 22.5 and deg <= 67.5:
		return 2 # down-right
	elif deg > 67.5 and deg <= 112.5:
		return 3 # down
	elif deg > 112.5 and deg <= 157.5:
		return 4 # down-left
	elif deg > 157.5 or deg <= -157.5:
		return 5 # left
	elif deg > -157.5 and deg <= -112.5:
		return -1 # up-left
	elif deg > -112.5 and deg <= -67.5:
		return -1 # up
	else: # -67.5 to -22.5
		return -1 # up-right

func _update_eyes() -> void:
	if not _eyes or is_dead():
		return
	var frame := _get_eye_frame()
	if frame == -1:
		if _eyes.visible:
			_eyes.hide()
		return
	elif not _eyes.visible:
		_eyes.show()
	var state := _get_eye_state()
	if _eyes.animation != state:
		_eyes.animation = state
	if _eyes.frame != frame:
		_eyes.frame = frame

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

func is_angry() -> bool:
	return sectors.full()

func get_hit(arrow: Arrow) -> void:
	if is_dead():
		arrow.deactivate()
		return
	if is_dashing():
		return
	var sector := sectors.get_sector_from_position(arrow.global_position)
	_spawn_chunks(global_position)  
	if try_embed_arrow(arrow, sector):
		arrow.stick(_arrows, arrow_dig_depth)
		SoundManager.play("Q%d_fill" % clampi(sector + 1, 1, 4))
		SoundManager.play("apple_damage1" if arrow.kind != Arrow.Kind.NORMAL else "apple_damage2")
		if arrow.kind != Arrow.Kind.NORMAL:
			_apply_debuff(arrow.kind)
	else:
		arrow.queue_free()
		if not _invul:
			die()
	_invul = true
	get_tree().create_timer(0.25).timeout.connect(func(): _invul = false)
	hit.emit(arrow, sector)
	_eyes_hit.start()
	_update_eyes()

# burst a few apple bits at the apple's current position
func _spawn_chunks(_pos: Vector3) -> void:
	if not chunk_fx:
		return
	var fx := chunk_fx.instantiate() as Node3D
	add_child(fx)               # child of the player at local origin -> born at the apple
	fx.position = Vector3.ZERO

func get_mouse_world_position() -> Vector3:
	var mouse = get_viewport().get_mouse_position()

	var origin = _camera.project_ray_origin(mouse)
	var dir = _camera.project_ray_normal(mouse)

	var query = PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + dir * 2000.0
	query.collision_mask = 1 << 4

	var result = get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return Vector3.ZERO

	var pos: Vector3 = result.position
	pos.y = global_position.y

	return pos

func _face_dir(look_target: Vector3) -> void:
	look_at(look_target)
	_sprite.global_basis = _sprite_basis
	_eyes.global_basis = _eyes_basis
	_update_eyes()

func face_mouse() -> void:
	var mouse_pos := get_mouse_world_position()
	var look_target := Vector3(mouse_pos.x, global_position.y, mouse_pos.z)
	_face_dir(look_target)

func _move(dir: Vector2, _dt: float) -> void:
	var v = dir * speed
	velocity.x = v.x
	velocity.z = v.y
	velocity.y = 0
	move_and_slide()

func is_dashing() -> bool:
	if not _dashing: return false
	return not _dashing.is_stopped()

func _can_dash() -> bool:
	if not _dash_debounce: return false
	return not is_dead() and _in_slowdown

func _try_dash() -> bool:
	if not _can_dash(): return false
	var stored := sectors.get_stored()
	for i in range(len(stored)):
		var e = sectors.get_stored_at(i)
		if e is EmbeddedArrow and e.is_firing_enabled():
			var mouse_pos := get_mouse_world_position()
			mouse_pos = _preview.get_end(mouse_pos)
			var mouse_offset := mouse_pos - global_position
			sectors.take_stored(i)
			var arrow = e.grab()
			arrow.queue_free()
			_dash(mouse_offset)
			return true
	return false

func _dash(dir: Vector3) -> void:
	var dir_len := dir.length()
	if dir_len < 0.001: return
	var tween = create_tween()
	tween.tween_property(_sprite, "scale", Vector3(0.6, 1.4, 1.0), 0.08)
	tween.tween_property(_sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
	if dir_len > max_dash_distance:
		dir = dir.normalized() * max_dash_distance
	_dash_vel = dir / _dashing.wait_time
	var collided := _preview.get_enemies_in_path(global_position, global_position + dir)
	for e in collided:
		e.get_hit()
	_exit_slowdown()
	_collider.disabled = true
	_dashing.start()

func _can_slowdown() -> bool:
	var flag := false
	for e in sectors.get_stored():
		if e is EmbeddedArrow and e.is_firing_enabled():
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

func is_burning() -> bool:
	return _burn_time > 0.0
func is_frozen() -> bool:
	return _freeze_time > 0.0

func _apply_debuff(kind: int) -> void:
	match kind:
		Arrow.Kind.INCENDIARY:
			_burn_time = burn_duration
			_burn_redrift = 0.0  # re-roll the drift on the first burning frame
			_burn_spin_dir = 1.0 if randf() < 0.5 else -1.0
		Arrow.Kind.FROST:
			_freeze_time = freeze_duration
	_display_status()

func _burn_spin(delta: float) -> void:
	_face_dir(global_position + get_facing().rotated(Vector3.UP, burn_spin_speed * _burn_spin_dir * delta))

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
	_sprite.play("death")
	_eyes.hide()
	_status_sprite.hide()
	sectors.hide()

func _on_sectors_changed() -> void:
	if sectors.full():
		enable_firing()
	_update_eyes()

func _on_dashing_timeout() -> void:
	_collider.disabled = false
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
		#_burn_redrift -= delta
		#if _burn_redrift <= 0.0:
		#	_burn_drift = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
		#	_burn_redrift = burn_redrift * randf_range(0.6, 1.4)
		#velocity = _burn_drift * burn_drift_speed
		#move_and_slide()
		_burn_time -= delta
		if not is_burning():
			_display_status()
	elif is_frozen():
		_freeze_time -= delta
		if _freeze_time < freeze_warn_time:
			_status_sprite.visible = fmod(_freeze_time * freeze_blink_rate, 2.0) < 1.0
		if not is_frozen():
			_display_status()
	if is_dashing():
		_update_dash(delta)
	else:
		_move(input.get_direction(), delta)
	if _in_slowdown:
		_update_slowdown(delta)
	global_position.y = 0

func _update_preview(_delta: float) -> void:
	var pos := get_mouse_world_position()
	pos.y = global_position.y
	_preview.update(global_position, pos)

func _display_status() -> void:
	if is_burning():
		_status_sprite.show()
		_status_sprite.play("fire")
	elif is_frozen():
		_status_sprite.show()
		_status_sprite.play("ice")
	else:
		_status_sprite.hide()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if _dead: return
	if is_burning():
		_burn_spin(delta)
	elif not is_frozen():
		face_mouse()
	if _in_slowdown:
		_update_preview(delta)
	var flag := false
	var stored := sectors.get_stored()
	for i in range(len(stored)):
		var e = stored[i]
		if e is EmbeddedArrow and e.is_firing_enabled():
			flag = true
			sectors.highlight_sector(i)
			break
	if not flag:
		sectors.highlight_sector()
	_update_status_tint()

func _ready() -> void:
	sectors._update_occupied_mask()
	_update_collider(_collider, hurt_radius)
