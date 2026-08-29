@tool
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

var _dash_charges := 0
var _dash_arrows: Array[Arrow] = []

func _ready() -> void:
	if Engine.is_editor_hint(): update_configuration_warnings()
	_update_collider()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	
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

	var target_slot := _get_target_slot()
	if _dash_charges > 0 and target_slot >= 0:
		_sectors.set_primed(target_slot)
	else:
		_sectors.clear_primed()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or health.is_dead(): return
	
	if slow_input.consume_pressed():
		if not time.is_slowed():
			time.slow()
	if slow_input.consume_released():
		if time.is_slowed():
			time.resume()
	
	if fire_input.consume_pressed():
		if _dash_charges > 0:
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
	if arrows.add_arrow(arrow):
		arrow.embed(arrow_dig_depth)
		var slots := arrows.get_slots_of(arrow)
		var sector := slots[0] if slots.size() > 0 else 0
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
			_eyes.set_eyes_state("default")
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

func _on_died() -> void:
	_dash_charges = 0
	_dash_arrows.clear()
	arrows.clear_arrows()
	_sectors.clear()
	time.resume()
	
	SoundManager.play("apple_death")
	_sprite.play("death")
	
	_eyes.hide()
	_status_sprite.hide()
	_sectors.hide()

func _get_target_slot() -> int:
	var start := arrows.get_facing_slot()
	for i in range(arrows.slot_count):
		var slot := (start + i) % arrows.slot_count
		var arrow := arrows.get_embedded_in(slot)
		if arrow and arrow in _dash_arrows:
			return slot
	return -1

func _on_dash_activated(destination: Vector3, targets: Array) -> void:
	_dash_preview.disable()
	var from := global_position
	global_position = destination
	_camera.ease_after_teleport(from, destination)
	for target in targets:
		if target is Enemy:
			target.get_hit()
	var consumed_slot := _get_target_slot()
	if consumed_slot >= 0:
		var consumed_arrow := arrows.get_embedded_in(consumed_slot)
		if consumed_arrow:
			_dash_arrows.erase(consumed_arrow)
			arrows.remove_arrow(consumed_arrow)
			_dash_charges = maxi(_dash_charges - 1, 0)
	time.bar.consume(dash_cost * time.bar.max_value)
	if time.is_slowed():
		time.resume()

func _on_slot_occupied(slot: int, _arrow: Arrow) -> void:
	_sectors.highlight_sector(slot)
	if _dash_charges == 0 and arrows.is_full():
		_dash_charges = arrows.slot_count
		_dash_arrows.clear()
		for i in range(arrows.slot_count):
			var a := arrows.get_embedded_in(i)
			if a:
				_dash_arrows.append(a)

func _on_slot_cleared(slot: int) -> void:
	_sectors.unhighlight_sector(slot)

func _on_firing_enabled(_arrow: Arrow) -> void:
	if time.is_slowed():
		dash.enable()

func _on_firing_disabled(_arrow: Arrow) -> void:
	if not arrows.is_full():
		dash.disable()

func _on_time_slowed() -> void:
	afterimage.enable()

func _on_time_resumed() -> void:
	afterimage.disable()
	#afterimage.clear()
	dash.disable()

func _on_dash_enabled() -> void:
	_dash_preview.enable()

func _on_dash_disabled() -> void:
	_dash_preview.disable()
