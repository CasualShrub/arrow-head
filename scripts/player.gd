@tool
extends CharacterBody3D
class_name Player

const _PLAYER_TEAM = Arrow.Team.PLAYER

@export var input: InputComponent
@export var health: HealthComponent
@export var sectors: SectorsComponent

@onready var camera: Camera3D = %Camera

@export var speed := 6.0
@export_group("arrows")
@export var fire_cooldown := 1.0:
	set(value):
		if value < 0: value = 0
		%FireDebounce.wait_time = value
		fire_cooldown = value
@export_group("hurt")
@export var hurt_radius := 25.0:
	set(value):
		if value < 0: value = 0
		_update_collider(%HurtCollider, value)
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

signal hit(arrow: Arrow, sector: int)
signal fired(arrow: Arrow)
signal died

var _dead := false

func _update_collider(c: CollisionShape3D, r: float) -> void:
	if not c: return
	var s := SphereShape3D.new()
	s.radius = r
	c.shape = s

func get_facing() -> Vector3:
	return -global_basis.z

func get_facing_angle() -> float:
	var facing := get_facing()
	return atan2(facing.z, facing.x) + (PI / 2)

func embed_arrow(arrow: Arrow, sector: int) -> void:
	var selected_sectors := arrow.get_sectors(sector)
	var embedded := EmbeddedArrow.new(arrow, sector)
	sectors.store(selected_sectors, embedded)
	if sectors.full():
		enable_firing()

func try_embed_arrow(arrow: Arrow, sector: int,) -> bool:
	var selected_sectors := arrow.get_sectors(sector)
	if sectors.occupied(selected_sectors): return false
	embed_arrow(arrow, sector)
	return true

func enable_firing():
	for embedded in sectors.get_stored():
		embedded.enable_firing()

func get_hit(arrow: Arrow) -> void:
	var sector := sectors.get_sector_from_position(arrow.global_position)
	if try_embed_arrow(arrow, sector):
		arrow.stick(%Arrows)
	else:
		arrow.queue_free()
		die()
	hit.emit(arrow, sector)

func get_mouse_world_position() -> Vector3:
	var mouse = get_viewport().get_mouse_position()

	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)

	var plane := Plane(Vector3.UP, global_position.y)
	var hit_plane = plane.intersects_ray(origin, dir)

	return hit_plane

func face_mouse() -> void:
	var mouse_pos := get_mouse_world_position()
	var look_target := Vector3(mouse_pos.x, global_position.y, mouse_pos.z)
	look_at(look_target)

func move(dir: Vector2, _dt: float) -> void:
	var v = dir * speed
	velocity.x = v.x
	velocity.z = v.y
	velocity.y = 0
	move_and_slide()

func try_fire(sector: int) -> void:
	if not %FireDebounce.is_stopped(): return
	var embedded = sectors.get_stored_at(sector) as EmbeddedArrow
	if not embedded: return
	var arrow := embedded.try_grab()
	if arrow:
		fire(arrow)

func fire(arrow: Arrow) -> void:
	if not arrow: return
	%FireDebounce.start()
	if arrow.get_parent() != get_tree().current_scene:
		arrow.reparent(get_tree().current_scene)
	arrow.activate(global_position, get_facing(), _PLAYER_TEAM)
	fired.emit(arrow)

func is_dead() -> bool:
	return _dead

func die() -> void:
	_dead = true
	print("You died!")
	sectors.clear_stored()
	died.emit()

func _on_recovery_timeout() -> void:
	pass

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	move(input.get_direction(), delta)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	face_mouse()

func _ready() -> void:
	_update_collider(%HurtCollider, hurt_radius)
	if Engine.is_editor_hint(): return
