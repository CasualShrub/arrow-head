extends CharacterBody3D
class_name Arrow

enum Team { ENEMY, PLAYER }
enum Kind { NORMAL, INCENDIARY, FROST }

const KIND_COLORS := {
	Kind.NORMAL: Color(1, 1, 1, 1),
	Kind.INCENDIARY: Color(0.95, 0.35, 0.12, 1),
	Kind.FROST: Color(0.35, 0.75, 1.0, 1),
}

const _MASK_PLAYER := 1 << 0
const _MASK_WALL := 1 << 2
const _MASK_ENEMY := 1 << 3

@export var scene: PackedScene
@export var team: Team = Team.ENEMY:
	set(value):
		team = value
		_apply_team()
@export var kind: Kind = Kind.NORMAL:
	set(value):
		kind = value
		_apply_kind()

@export var damage := 10
@export_group("movement")
@export var speed := 7.0
@export var max_bounces := 8
@export var direction := Vector3.RIGHT:
	set(value):
		direction = value.normalized() if value != Vector3.ZERO else Vector3.RIGHT

@export_group("lifetime")
@export var max_lifetime := 0.0
@export var free_on_finish := true

@onready var collider: CollisionShape3D = %Collider

signal hit(target: Player)
signal finished(arrow: Arrow)

var _life := 0.0
var _bounces := 0

func _ready() -> void:
	_apply_team()
	_apply_kind()
	if not %VisibleOnScreenNotifier2D.screen_exited.is_connected(_on_screen_exited):
		%VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	rotation = direction.angle()
	_life += delta
	if get_remaining_lifetime() <= 0:
		_finish()
		return
	var collision := move_and_collide(direction * speed * delta)
	if collision:
		if _is_wall(collision.get_collider()):
			_bounce(collision)
		else:
			_on_hit(collision.get_collider())

func _apply_team() -> void:
	match team:
		Team.ENEMY:
			collision_mask = _MASK_PLAYER | _MASK_WALL
		Team.PLAYER:
			collision_mask = _MASK_ENEMY | _MASK_WALL

func _apply_kind() -> void:
	var v := get_node_or_null("Visual") as Polygon2D
	if v:
		v.color = KIND_COLORS.get(kind, Color.WHITE)
			
func _is_wall(body: Object) -> bool:
	return body is CollisionObject3D and body.get_collision_layer_value(3)

func _bounce(collision: KinematicCollision3D) -> void:
	var n := collision.get_normal()
	direction = direction.bounce(n)
	move_and_collide(collision.get_remainder().bounce(n))
	_bounces += 1
	if max_bounces >= 0 and _bounces > max_bounces:
		_finish()

func _on_hit(target) -> void:
	# player and enemy both expose get_hit(arrow); our team's mask decides which one we can strike
	if target.has_method("get_hit"):
		target.get_hit(self)
	hit.emit(target)
	if team == Team.PLAYER:
		_finish()  # a shot-back arrow is spent on impact; the enemy doesn't stop it like the player does

func get_remaining_lifetime() -> float:
	if max_lifetime == 0: return INF
	return max_lifetime - _life

func get_sectors(collided: int) -> Array[int]:
	return [collided]

func activate(pos: Vector3, dir: Vector3, new_team := team) -> void:
	global_position = pos
	team = new_team
	direction = dir
	_face_vector(direction)
	_life = 0.0
	_bounces = 0
	show()
	collider.set_deferred("disabled", false)
	set_physics_process(true)

func stick(host: Node3D) -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	collider.set_deferred("disabled", true)
	reparent.call_deferred(host)

func deactivate() -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	hide()
	collider.set_deferred("disabled", true)

func _finish() -> void:
	deactivate()
	finished.emit(self)
	if free_on_finish:
		queue_free()

func _face_vector(dir: Vector3) -> void:
	look_at(global_position + dir)

func _ready() -> void:
	_apply_team()

func _physics_process(delta: float) -> void:
	_face_vector(direction)
	_life += delta
	if get_remaining_lifetime() <= 0:
		_finish()
		return
	var collision := move_and_collide(direction * speed * delta)
	if collision:
		if _is_wall(collision.get_collider()):
			_bounce(collision)
		else:
			_on_hit(collision.get_collider())
