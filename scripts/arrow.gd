extends CharacterBody3D
class_name Arrow

enum Team { ENEMY, PLAYER }
enum Kind { NORMAL, INCENDIARY, FROST }

const _MASK_PLAYER := 1 << 0
const _MASK_WALL := 1 << 2
const _MASK_ENEMY := 1 << 3

@export var scene: PackedScene
@export var damage := 10
@export var kind: Kind = Kind.NORMAL
@export_group("movement")
@export var speed := 7.0

@export_group("lifetime")
@export var max_lifetime := 0.0
@export var free_on_finish := true
@export var max_bounces := 8
@export var decay_time := -1.0

@onready var _collider: CollisionShape3D = %Collider

signal hit(target: Player)
signal finished
signal stuck

var _team: Team = Team.ENEMY:
	set(value):
		_team = value
		_apply_team()
var _life := 0.0
var _bounces := 0
var _direction := Vector3.RIGHT:
	set(value):
		_direction = value.normalized() if value != Vector3.ZERO else Vector3.RIGHT

func _apply_team() -> void:
	match _team:
		Team.ENEMY:
			collision_mask = _MASK_PLAYER | _MASK_WALL
		Team.PLAYER:
			collision_mask = _MASK_ENEMY | _MASK_WALL
			
func _is_wall(body: Object) -> bool:
	return body.get_collision_layer_value(3)

func _bounce(collision: KinematicCollision3D) -> void:
	SoundManager.play("arrow_bounce", 0.0, 0.08)
	var n := collision.get_normal()
	_direction = _direction.bounce(n)
	face(_direction)   # re-orient the sprite to the new travel direction
	move_and_collide(collision.get_remainder().bounce(n))
	_bounces += 1
	if max_bounces >= 0 and _bounces > max_bounces:
		_wall_stick()

func _wall_stick() -> void:
	stuck.emit()
	_disable()
	if decay_time >= 0:
		if decay_time > 0:
			await get_tree().create_timer(decay_time).timeout
		_finish()

func _on_hit(target) -> void:
	if target.has_method("get_hit"):
		target.get_hit(self)
	hit.emit(target)
	#if _team == Team.PLAYER:
	#	_finish()  # a shot-back arrow is spent on impact; the enemy doesn't stop it like the player does

func get_remaining_lifetime() -> float:
	if max_lifetime == 0: return INF
	return max_lifetime - _life

func get_sectors(collided: int) -> Array[int]:
	return [collided]

func activate(pos: Vector3, dir: Vector3, new_team := _team) -> void:
	global_position = pos
	_team = new_team
	_direction = dir
	face(dir)
	_life = 0.0
	_bounces = 0
	show()
	_collider.set_deferred("disabled", false)
	set_physics_process(true)

func _disable() -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	_collider.set_deferred("disabled", true)

# a: i wanted the arrow to stick a bit further in the apple
func stick(host: Node3D, dig := 0.0) -> void:
	if dig > 0.0:
		global_position += _direction * dig
	_disable()
	reparent.call_deferred(host)

func deactivate() -> void:
	_disable()
	hide()

func _finish() -> void:
	deactivate()
	finished.emit()
	if free_on_finish:
		queue_free()

func face(direction: Vector3) -> void:
	if direction.length() < 0.0001: return
	look_at(global_position + direction)

func _ready() -> void:
	_apply_team()

func _physics_process(delta: float) -> void:
	_life += delta
	if get_remaining_lifetime() <= 0:
		_finish()
		return
	var collision := move_and_collide(_direction * speed * delta)
	if collision:
		var collider := collision.get_collider()
		if collider.has_method("get_hit"):
			_on_hit(collider)
		elif _is_wall(collision.get_collider()):
			_bounce(collision)
		else:
			_wall_stick()
