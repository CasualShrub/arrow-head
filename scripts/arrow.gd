extends CharacterBody2D
class_name Arrow

enum Team { ENEMY, PLAYER }

const _MASK_PLAYER := 1 << 0
const _MASK_WALL := 1 << 2
const _MASK_ENEMY := 1 << 3

@export var scene: PackedScene
@export var team: Team = Team.ENEMY:
	set(value):
		team = value
		_apply_team()

@export var damage := 10
@export_group("movement")
@export var speed := 700.0
@export var max_bounces := 8
@export var direction := Vector2.RIGHT:
	set(value):
		direction = value.normalized() if value != Vector2.ZERO else Vector2.RIGHT

@export_group("lifetime")
@export var max_lifetime := 0.0
@export var free_on_finish := true

signal hit(target: Player)
signal finished(arrow: Arrow)

var _life := 0.0
var _bounces := 0

func _ready() -> void:
	_apply_team()
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
			
func _is_wall(body: Object) -> bool:
	return body is CollisionObject2D and body.get_collision_layer_value(3)

func _bounce(collision: KinematicCollision2D) -> void:
	var n := collision.get_normal()
	direction = direction.bounce(n)
	move_and_collide(collision.get_remainder().bounce(n))
	_bounces += 1
	if max_bounces >= 0 and _bounces > max_bounces:
		_finish()

func _on_hit(target: Player) -> void:
	#target.health.take_damage(damage)
	target.get_hit(self)
	hit.emit(target)

func get_remaining_lifetime() -> float:
	if max_lifetime == 0: return INF
	return max_lifetime - _life

func get_sector(collided: int) -> Array[int]:
	return [collided]

func activate(pos: Vector2, dir: Vector2, new_team := team) -> void:
	global_position = pos
	team = new_team
	direction = dir
	rotation = direction.angle()
	_life = 0.0
	_bounces = 0
	show()
	%Collider.set_deferred("disabled", false)
	set_physics_process(true)

func deactivate() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	hide()
	%Collider.set_deferred("disabled", true)

func _finish() -> void:
	deactivate()
	finished.emit(self)
	if free_on_finish:
		queue_free()

func _on_screen_exited() -> void:
	_finish()
