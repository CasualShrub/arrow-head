extends CharacterBody2D
class_name Arrow

## A projectile (the "bullet" substitute) for the reverse bullet-hell.
##
## - Faction-aware: ENEMY arrows hit the player, PLAYER (re-fired) arrows hit enemies.
## - Poolable-ready: activate()/deactivate() let a future pool recycle arrows.
## - Currency: a caught arrow is deactivate()'d (banked by `value`), never freed while
##   it still has worth. Only uncaught arrows that hit or leave the screen _finish().
##
## Lives on physics layer 2 (projectile) so the player's CatchBox/SkimBox detect it.

enum Team { ENEMY, PLAYER }

# Physics layer this projectile occupies (1-indexed layer 2 -> bit 1 -> value 2).
const _LAYER_PROJECTILE := 1 << 1   # layer 2

# Mask bits (project.godot: player=1, projectile=2, wall=3, enemy=4).
const _MASK_PLAYER := 1 << 0        # layer 1
const _MASK_WALL := 1 << 2          # layer 3
const _MASK_ENEMY := 1 << 3         # layer 4

@export var team: Team = Team.ENEMY:
	set(value):
		team = value
		_apply_team()

@export_group("combat")
@export var damage := 10
@export var value := 1              ## Currency worth when banked; 1 = one unit.

@export_group("movement")
@export var speed := 300.0          ## px/sec
@export var max_bounces := 3        # -1 = unlimited
@export var direction := Vector2.RIGHT:
	set(value):
		direction = value.normalized() if value != Vector2.ZERO else Vector2.RIGHT

@export_group("lifetime")
@export var max_lifetime := 0.0     ## seconds; 0 = unlimited (rely on off-screen notifier)
@export var free_on_finish := true  ## a pool sets this false to recycle instead of free

signal hit_target(target: Node)
signal finished(arrow: Arrow)

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _life := 0.0
var _bounces := 0

func _ready() -> void:
	collision_layer = _LAYER_PROJECTILE
	_apply_team()
	if _notifier and not _notifier.screen_exited.is_connected(_on_screen_exited):
		_notifier.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	rotation = direction.angle()
	if max_lifetime > 0.0:
		_life += delta
		if _life >= max_lifetime:
			_finish()
			return
	var collision := move_and_collide(direction * speed * delta)
	if collision:
		if _is_wall(collision.get_collider()):
			_bounce(collision)
		else:
			_on_impact(collision.get_collider())

# --- Faction -----------------------------------------------------------------

func _apply_team() -> void:
	match team:
		Team.ENEMY:
			collision_mask = _MASK_PLAYER | _MASK_WALL
		Team.PLAYER:
			collision_mask = _MASK_ENEMY | _MASK_WALL

func _is_wall(body: Object) -> bool:
	return body is CollisionObject2D and body.get_collision_layer_value(3)  # layer 3 = wall

func _bounce(collision: KinematicCollision2D) -> void:
	var n := collision.get_normal()
	direction = direction.bounce(n)
	move_and_collide(collision.get_remainder().bounce(n))
	_bounces += 1
	if max_bounces >= 0 and _bounces > max_bounces:
		_finish()

# --- Hit handling (damage is decoupled from the target's own logic) -----------

func _on_impact(target: Node) -> void:
	var hp := _find_health(target)
	if hp:
		hp.take_damage(damage)
	if target.has_method("get_hit"):
		target.get_hit(self)        # notification hook only (Player.get_hit emits `hit`)
	hit_target.emit(target)
	_finish()

## Finds the target's HealthComponent: an exported `health` property (Player) or a
## direct HealthComponent child. Returns null for non-damageable bodies (e.g. walls).
func _find_health(node: Node) -> HealthComponent:
	if node == null:
		return null
	var h = node.get("health")
	if h is HealthComponent:
		return h
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null

# --- Poolable lifecycle ------------------------------------------------------

## (Re)launch this arrow. A pool calls this to recycle a deactivated arrow.
func activate(pos: Vector2, dir: Vector2, new_team := team) -> void:
	global_position = pos
	team = new_team                 # setter applies the collision mask
	direction = dir                 # setter normalizes
	rotation = direction.angle()
	_life = 0.0
	_bounces = 0
	show()
	if _shape:
		_shape.set_deferred("disabled", false)
	set_physics_process(true)

## Alias for call sites that read as "reset this pooled arrow".
func reset(pos: Vector2, dir: Vector2, new_team := team) -> void:
	activate(pos, dir, new_team)

## Take the arrow out of play WITHOUT freeing it (used when caught/banked).
func deactivate() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	hide()
	if _shape:
		_shape.set_deferred("disabled", true)

func _finish() -> void:
	deactivate()
	finished.emit(self)
	if free_on_finish:
		queue_free()

func _on_screen_exited() -> void:
	_finish()
