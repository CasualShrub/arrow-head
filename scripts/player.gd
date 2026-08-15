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
@export var arrows: SectorArrowsComponent:
	set(value):
		arrows = value
		update_configuration_warnings()
@export var time: TimeComponent:
	set(value):
		time = value
		update_configuration_warnings()
@export var dash: DashComponent:
	set(value):
		dash = value
		update_configuration_warnings()

@export var speed := 6.0
## how far arrows dig into apples skin
@export var arrow_dig_depth := 0.15
## burst of apple bits spawned where an arrow embeds
@export_group("hurt")
@export var hurt_radius := 0.4:
	set(value):
		if value < 0: value = 0
		_update_collider(_collider, value)
		hurt_radius = value
@export_group("eyes")
@export var eyes_hit_time: float:
	set(value):
		if not _eyes_hit: return
		_eyes_hit.wait_time = value
	get:
		if not _eyes_hit: return false
		return _eyes_hit.wait_time

@onready var _camera: PlayerCamera = %Camera
@onready var _eyes_hit: Timer = %EyesHit
@onready var _sprite: AnimatedSprite3D = %Sprite
@onready var _eyes: PlayerEyes = %Eyes
@onready var _status_sprite: AnimatedSprite3D = %StatusSprite
@onready var _collider: CollisionShape3D = %Collider
@onready var _dash_preview: DashPreview = %DashPreview
@onready var _mouse_pivot: Node3D = %MousePivot
@onready var _sectors: Sectors = %Sectors
@onready var _chunks: GPUParticles3D = %AppleChunks

func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
	
	_sectors._update_occupied_mask()
	_update_collider(_collider, hurt_radius)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if health.is_dead(): return
	if _dash_preview.is_enabled():
		var mouse_pos := get_mouse_world_position()
		var dash_dest := dash.get_dash_destination(global_position, mouse_pos)
		var dash_targets := dash.get_dash_targets(global_position, dash_dest)
		_dash_preview.set_preview_position(dash_dest)
		_dash_preview.set_preview_targets(dash_targets)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if health.is_dead(): return
	
	if slow_input.consume_pressed():
		time.slow()
	if slow_input.consume_released():
		time.resume()
	
	if fire_input.consume_released():
		if time.is_slowed():
			var wish_pos = _camera.get_mouse_position()
			dash.dash(global_position, wish_pos)
	
	_move(movement_input.get_vector(), delta)
	
	# keep on same plane
	global_position.y = 0

func _get_component_warning(comp: Variant, comp_name: String) -> Variant:
	if not comp: return "Player has no {0}.".format([comp_name])
	return null

func _get_configuration_warnings() -> PackedStringArray:
	return [
		_get_component_warning(health, "HealthComponent"),
		_get_component_warning(fire_input, "FireInput"),
		_get_component_warning(slow_input, "SlowInput"),
		_get_component_warning(movement_input, "MovementInput"),
		_get_component_warning(arrows, "ArrowsComponent"),
		_get_component_warning(time, "TimeComponent"),
		_get_component_warning(dash, "DashComponent"),
	].filter(func(element): return element != null)

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c: return
	if c.shape and c.shape is SphereShape3D:
		c.shape.radius = r
	else:
		var s := SphereShape3D.new()
		s.radius = r
		c.shape = s

func get_hit(arrow: Arrow) -> void:
	if health.is_dead():
		arrow.deactivate()
		return
	_chunks.emitting = true
	if arrows.add_arrow(arrow):
		var slots := arrows.get_slots_of(arrow)
		var sector := slots[0] if slots.size() > 0 else 0
		SoundManager.play("Q%d_fill" % clampi(sector + 1, 1, 4))
		SoundManager.play("apple_damage1") #if arrow.kind != Arrow.Kind.NORMAL else "apple_damage2")
	else:
		arrow.queue_free()
		health.die()
	health.make_vulnerable()
	get_tree().create_timer(0.25).timeout.connect(
		func(): health.make_vulnerable()
	)
	_eyes_hit.start()
	_eyes.set_eyes_state("hit")

func get_mouse_world_position() -> Vector3:
	if not _camera: return Vector3.ZERO
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

func face(direction: Vector3) -> void:
	_mouse_pivot.look_at(direction)
	_eyes.make_eyes_look_at(direction)

func _move(dir: Vector2, _dt: float) -> void:
	var v = dir * speed
	velocity.x = v.x
	velocity.z = v.y
	velocity.y = 0
	move_and_slide()
	
func _on_died() -> void:
	arrows.clear_arrows()
	time.resume()
	
	SoundManager.play("apple_death")
	_sprite.play("death")
	
	_eyes.hide()
	_status_sprite.hide()
	_sectors.hide()

func _on_dash_activated(destination: Vector3, targets: Array) -> void:
	_dash_preview.disable()
	global_position = destination
	for target in targets:
		if target is Enemy:
			target.get_hit()

func _on_slot_occupied(slot: int, _arrow: Arrow) -> void:
	_sectors.highlight_sector(slot)

func _on_slot_cleared(slot: int) -> void:
	_sectors.unhighlight_sector(slot)

func _on_firing_enabled(_arrow: Arrow) -> void:
	pass

func _on_firing_disabled(_arrow: Arrow) -> void:
	pass # Replace with function body.

func _on_time_slowed() -> void:
	if arrows.has_fireable():
		_dash_preview.enable()

func _on_time_resumed() -> void:
	_dash_preview.disable()

func _on_fire_pressed() -> void:
	if dash.can_dash():
		_dash_preview.enable()

func _on_fire_released() -> void:
	_dash_preview.disable()
	var mouse_pos := _camera.get_mouse_position()
	if dash.try_activate(global_position, mouse_pos):
		time.resume()
