@tool
extends CharacterBody3D
class_name Player

@export var input: InputComponent
@export var health: HealthComponent
@export var arrows: SectorArrowsComponent
@export var time: TimeComponent
@export var dash: DashComponent

@export var speed := 6.0
@export var arrow_dig_depth := 0.15 #dig arrow deeper into apple's skin a bit
@export var chunk_fx: PackedScene   ## burst of apple bits spawned where an arrow embeds
@export_group("hurt")
@export var hurt_radius := 0.4:
	set(value):
		if value < 0: value = 0
		if _collider:
			_update_collider(_collider, value)  # may run before the node exists
		hurt_radius = value
@export_group("eyes")
@export var eye_deadzone := 0.4
@export var eyes_hit_time := 0.36:
	set(value):
		if not _eyes_hit: return
		_eyes_hit.wait_time = value
	get:
		if not _eyes_hit: return false
		return _eyes_hit.wait_time

@onready var _camera: Camera3D = %Camera
@onready var _recovery: Timer = %Recovery
@onready var _eyes_hit: Timer = %EyesHit
@onready var _sprite: AnimatedSprite3D = %Sprite
@onready var _eyes: AnimatedSprite3D = %Eyes
@onready var _status_sprite: AnimatedSprite3D = %StatusSprite
@onready var _collider: CollisionShape3D = %Collider
@onready var _dash_preview: DashPreview = %DashPreview
@onready var _sectors := %Sectors
@onready var _arrows: Node3D = %Arrows

@onready var _sprite_basis := _sprite.global_basis
@onready var _eyes_basis := _eyes.global_basis

func _ready() -> void:
	_sectors._update_occupied_mask()
	_update_collider(_collider, hurt_radius)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if health.is_dead(): return
	if time.is_slowed():
		var mouse_pos := get_mouse_world_position()
		_dash_preview.update_preview_position(mouse_pos)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if health.is_dead(): return
	if input.consume_fire_pressed():
		if time.is_slowed():
			var mouse_pos := get_mouse_world_position()
			var dash_to := dash.get_dash_destination(global_position, mouse_pos)
			dash.dash(global_position, dash_to)
	_move(input.get_direction(), delta)
	
	global_position.y = 0

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c: return
	if c.shape and c.shape is SphereShape3D:
		c.shape.radius = r
	else:
		var s := SphereShape3D.new()
		s.radius = r
		c.shape = s

func get_facing() -> Vector3:
	return -global_basis.z

enum EyeDir { HIDDEN = -1, CENTERED, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST }

func _get_eye_state() -> String:
	if not _eyes_hit.is_stopped():
		return "hit"
	if _sectors.full():
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
	if health.is_dead():
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

func get_hit(arrow: Arrow) -> void:
	if health.is_dead():
		arrow.deactivate()
		return
	_spawn_chunks(global_position)  
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
	_update_eyes()

# burst a few apple bits at the apple's current position
func _spawn_chunks(_pos: Vector3) -> void:
	if not chunk_fx:
		return
	var fx := chunk_fx.instantiate() as Node3D
	add_child(fx)               # child of the player at local origin -> born at the apple
	fx.position = Vector3.ZERO

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
	look_at(direction)
	_sprite.global_basis = _sprite_basis
	_eyes.global_basis = _eyes_basis
	_update_eyes()

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
	global_position = destination
	for target in targets:
		if target is Enemy:
			target.get_hit()

func _on_slot_occupied(slot: int, _arrow: Arrow) -> void:
	_sectors.highlight_sector(slot)

func _on_slot_cleared(slot: int) -> void:
	_sectors.unhighlight_sector(slot)

func _on_firing_enabled(_arrow: Arrow) -> void:
	pass # Replace with function body.

func _on_firing_disabled(_arrow: Arrow) -> void:
	pass # Replace with function body.
