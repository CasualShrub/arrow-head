@tool
@icon("res://addons/at-icons/used/node3d/apple.svg")
extends CharacterBody3D
class_name Player

@export var health: HealthComponent:
	set(value):
		health = value
		update_configuration_warnings()
@export var fire_input: InputComponent:
	set(value):
		fire_input = value
		update_configuration_warnings()
@export var slow_input: InputComponent:
	set(value):
		slow_input = value
		update_configuration_warnings()
@export var movement_input: VectorInputComponent:
	set(value):
		movement_input = value
		update_configuration_warnings()
@export var aim_input: VectorInputComponent:
	set(value):
		aim_input = value
		update_configuration_warnings()
@export var input_mode: InputModeComponent:
	set(value):
		input_mode = value
		update_configuration_warnings()
@export var arrows: SectorArrowsComponent:
	set(value):
		arrows = value
		update_configuration_warnings()
@export var time: TimeComponent:
	set(value):
		time = value
		update_configuration_warnings()
@export var afterimage: AfterimageComponent:
	set(value):
		afterimage = value
		update_configuration_warnings()
@export var dash: DashComponent:
	set(value):
		dash = value
		update_configuration_warnings()

@export var speed := 6.0
@export var dash_cost := 0.0
## how far arrows dig into apples skin
@export var arrow_dig_depth := 0.15
@export_group("hurt")
@export var hurt_radius := 0.4:
	set(value):
		if value < 0: value = 0
		hurt_radius = value
		_update_collider()
		
@export var hurt_reaction_duration := 0.35

@onready var _collider: CollisionShape3D = %Collider
@onready var _camera: PlayerCamera = %Camera
@onready var _sprite: AnimatedSprite3D = %Sprite
@onready var _status_sprite: AnimatedSprite3D = %StatusSprite
@onready var _eyes: PlayerEyes = %Eyes
@onready var _dash_preview: DashPreview = %DashPreview
@onready var _mouse_pivot: Node3D = %MousePivot
@onready var _sectors: Sectors = %Sectors
@onready var _chunks: CPUParticles3D = %AppleChunks
@onready var _aura: AngryAura = %Aura

signal force_walk_finished()

var _force_walk_direction := Vector3.ZERO
var _force_walk_target: Variant = null

func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	DarkenManager.register_highlighted(self)
	ScreenShaderManager.register_unfiltered(self)
	_sectors.centered = arrows.centered
	_update_collider()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return

	if is_force_walking():
		face(global_position + _force_walk_direction)
		_camera.set_lookahead(Vector2.ZERO)
		return

	var aim_target := _get_aim_target()
	face(aim_target)
	var lookahead_offset := Vector2.ZERO
	if input_mode.is_keyboard_mouse():
		lookahead_offset = _camera.get_mouse_screen_offset()
	elif input_mode.is_controller():
		lookahead_offset = aim_input.get_vector()
	_camera.set_lookahead(lookahead_offset)

	if health.is_dead(): return
	if _dash_preview.is_enabled():
		var dash_dest := dash.get_dash_destination(global_position, aim_target)
		var dash_targets := dash.get_dash_targets(global_position, dash_dest)
		_dash_preview.set_preview_position(dash_dest)
		_dash_preview.set_preview_targets(dash_targets)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or health.is_dead(): return

	if is_force_walking():
		_force_walk_step(delta)
		return

	if slow_input.consume_pressed():
		if not time.is_slowed():
			time.slow()
	if slow_input.consume_released():
		if time.is_slowed():
			time.resume()
	
	if fire_input.consume_pressed():
		if arrows.can_use():
			if not time.is_slowed():
				time.slow()
			dash.enable()
	
	if fire_input.consume_released():
		dash.try_activate(global_position, _camera.get_mouse_position())
	
	_move(movement_input.get_vector(), delta)
	
	# keep on same plane
	global_position.y = 0

func _get_component_warning(comp: Variant, comp_name: StringName) -> Variant:
	if not comp: return "Player has no %s." % comp_name
	return null

func _get_configuration_warnings() -> PackedStringArray:
	return [
		_get_component_warning(health, "HealthComponent"),
		_get_component_warning(fire_input, "FireInput"),
		_get_component_warning(slow_input, "SlowInput"),
		_get_component_warning(movement_input, "MovementInput"),
		_get_component_warning(aim_input, "AimInput"),
		_get_component_warning(input_mode, "InputMode"),
		_get_component_warning(arrows, "ArrowsComponent"),
		_get_component_warning(time, "TimeComponent"),
		_get_component_warning(afterimage, "AfterimageComponent"),
		_get_component_warning(dash, "DashComponent"),
	].filter(func(element): return element != null)

func _update_collider() -> void:
	if not _collider: return
	#if _collider.shape and _collider.shape is SphereShape3D:
		#_collider.shape.radius = hurt_radius
	#else:
		#var s := SphereShape3D.new()
		#s.radius = hurt_radius
		#_collider.shape = s

func get_camera() -> PlayerCamera:
	return _camera

func get_hit(arrow: Arrow) -> void:
	if health.is_dead():
		arrow.deactivate()
		return
	_chunks.emitting = true
	_camera.shake()
	if arrows.try_add_arrow(arrow):
		arrow.embed(arrow_dig_depth)
		var slots := arrows.get_embedded_slots(arrow)
		var sector := slots[0] if not slots.is_empty() else 0
		SoundManager.play("Q%d_fill" % clampi(sector + 1, 1, 4))
		SoundManager.play("apple_damage1") 
		#if arrow.kind != Arrow.Kind.NORMAL else "apple_damage2")
	else:
		arrow.queue_free()
		health.die()
	health.make_vulnerable()
	_eyes.set_eyes_state("hit")
	get_tree().create_timer(0.25).timeout.connect(
		func():
			_eyes.set_eyes_state(&"default")
			_refresh_eyes_state()
			health.make_vulnerable()
	)
	#_eyes_hit.start()

func _get_aim_target() -> Vector3:
	if input_mode.is_keyboard_mouse():
		return _camera.get_mouse_position()
	elif input_mode.is_controller():
		var aim_vec := aim_input.get_vector()
		return global_position + Vector3(aim_vec.x, 0, aim_vec.y)
	return Vector3.ZERO

func face(target: Vector3) -> void:
	target.y = global_position.y
	_mouse_pivot.look_at(target)
	if health.is_dead(): return
	_eyes.make_eyes_look_at(target)

func _move(dir: Vector2, _dt: float) -> void:
	var v = dir * speed
	velocity.x = v.x
	velocity.z = v.y
	velocity.y = 0
	move_and_slide()

func is_force_walking() -> bool:
	return _force_walk_direction != Vector3.ZERO

func force_walk(direction: Vector3) -> void:
	_begin_force_walk(direction)
	_force_walk_target = null

func force_walk_to(target: Vector3) -> void:
	target.y = global_position.y
	_begin_force_walk(target - global_position)
	_force_walk_target = target
	if not is_force_walking():
		force_walk_finished.emit()

func stop_force_walk() -> void:
	if not is_force_walking(): return
	_force_walk_direction = Vector3.ZERO
	_force_walk_target = null
	_collider.disabled = false
	force_walk_finished.emit()

func _begin_force_walk(direction: Vector3) -> void:
	direction.y = 0
	_force_walk_direction = direction.normalized()
	if not is_force_walking(): return
	if time.is_slowed():
		time.resume()
	dash.disable()
	_collider.disabled = true
	velocity = Vector3.ZERO

func _force_walk_step(delta: float) -> void:
	fire_input.consume_pressed()
	fire_input.consume_released()
	slow_input.consume_pressed()
	slow_input.consume_released()
	var step := _force_walk_direction * speed * delta
	if _force_walk_target != null:
		var remaining: Vector3 = _force_walk_target - global_position
		remaining.y = 0
		if remaining.length() <= step.length():
			global_position = _force_walk_target
			stop_force_walk()
			return
	global_position += step

func _refresh_eyes_state() -> void:
	if _eyes.get_eyes_state() == &"hit": return
	if dash.can_activate():
		_eyes.set_eyes_state(&"angry")
		_aura.activate()
	else:
		_eyes.set_eyes_state(&"default")
		_aura.deactivate()

func _on_died() -> void:
	arrows.clear_arrows()
	time.resume()
	
	SoundManager.play("apple_death")
	_sprite.play("death")
	
	_eyes.hide()
	_aura.deactivate_instantly()
	_status_sprite.hide()
	_sectors.hide()

func _on_dash_activated(destination: Vector3, targets: Array) -> void:
	_dash_preview.disable()
	var from := global_position
	global_position = destination
	_camera.ease_after_teleport(from, destination)
	for target in targets:
		if target is Enemy:
			target.get_hit()
	var next_used := arrows.get_using_next()
	if next_used:
		arrows.remove_arrow(next_used)
	time.bar.consume(dash_cost * time.bar.max_value)
	if time.is_slowed():
		time.resume()

func _on_slot_state_changed(
	slot: int,
	state: SectorArrowsComponent.SlotState
) -> void:
	var sector_state := (
		_sectors.SectorState.HIGHLIGHTED if state == arrows.SlotState.OCCUPIED
		else _sectors.SectorState.USABLE if state == arrows.SlotState.USABLE
		else _sectors.SectorState.DISABLED if state == arrows.SlotState.DISABLED
		else _sectors.SectorState.NONE
	)
	_sectors.set_state(slot, sector_state)
	_refresh_eyes_state()
	if not arrows.can_use():
		if dash.is_enabled(): dash.disable()

func _on_time_slowed() -> void:
	afterimage.enable()

func _on_time_resumed() -> void:
	afterimage.disable()
	#afterimage.clear()
	dash.disable()

func _on_dash_enabled() -> void:
	_dash_preview.max_range = dash.max_distance
	_dash_preview.enable()

func _on_dash_disabled() -> void:
	_dash_preview.disable()
