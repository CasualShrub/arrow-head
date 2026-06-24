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
@export_group("hurt")
@export var hurt_radius := 25.0:
	set(value):
		if value < 0: value = 0
		_update_collider(%HurtCollider, value)
		hurt_radius = value
@export var sector_count := 4
@export var sector_centered := false

signal hit(arrow: Arrow, sector: int)
signal fired(arrow: Arrow)
signal died()

var _sectors: Array[EmbeddedArrow]
var _dead := false
var _facing := Vector2()
var _melee_ready := true

func _update_collider(c: CollisionShape2D, r: float) -> void:
	if not c: return
	var s := CircleShape2D.new()
	s.radius = r
	c.shape = s

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
	if fully_embedded():
		enable_firing()

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

func get_hit(arrow: Arrow) -> void:
	var sector := get_sector(arrow.global_position - global_position)
	if try_embed_arrow(arrow, sector):
		arrow.stick(%Arrows)
	else:
		arrow.queue_free()
		die()
	hit.emit(arrow, sector)

func face_mouse(mouse_pos: Vector2) -> void:
	_facing = global_position.direction_to(mouse_pos)
	var angle := get_facing_angle()
	%Sprite.rotation = angle
	%Arrows.rotation = angle

func move(dir: Vector2, _dt: float) -> void:
	velocity = dir * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		melee()

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
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var col = hit.get("collider")
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

func is_dead() -> bool:
	return _dead

func die() -> void:
	_dead = true
	print("You died!")
	clear_embedded()
	died.emit()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	move(input.get_direction(), delta)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	face_mouse(get_global_mouse_position())

func _ready() -> void:
	_setup_sectors()
	_update_collider(%HurtCollider, hurt_radius)
