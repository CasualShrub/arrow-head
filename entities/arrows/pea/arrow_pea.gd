extends Arrow
class_name ArrowPea

@export var spin_speed := 12.0
@export_group("split")
@export var split_scene: PackedScene
@export var split_count := 3
@export var split_spread := 60.0
@export var split_offset := 0.5
@export var split_speed := 8.0

const EXPLODE_FRAMES: SpriteFrames = preload("res://entities/arrows/pea/pea_explode_frames.tres")

var _sprite: Sprite3D
var _base_basis: Basis
var _spin_angle := 0.0

func _ready() -> void:
	super()
	_sprite = find_child("Sprite3D", true, false) as Sprite3D
	if _sprite:
		_base_basis = _sprite.transform.basis
	collided.connect(_on_hit)

func _on_hit(_with: ArrowCollider, _normal: Vector3, _point: Vector3) -> void:
	if is_active(): return
	_explode(global_position)

func _on_activated() -> void:
	super()
	_spin_angle = 0.0

func _on_collision_simulated(sim: ArrowSimulation, collider: CollisionObject3D) -> void:
	if sim.alive: return
	if collider is ArrowCollider: return
	if sim != simulation: return
	_explode(sim.position)
	_split(sim)

func _split(sim: ArrowSimulation) -> void:
	if not split_scene: return
	if split_count <= 0: return
	if ArrowManager.max_bounces_override >= 0: return
	var base_dir := sim.velocity.normalized()
	var step := 0.0
	if split_count > 1:
		step = deg_to_rad(split_spread) / (split_count - 1)
	var start := -step * (split_count - 1) / 2.0
	for i in range(split_count):
		var dir := base_dir.rotated(Vector3.UP, start + step * i)
		var at := sim.position + dir * split_offset
		_spawn_split.call_deferred(at, dir, sim.collision_mask)

func _spawn_split(at: Vector3, dir: Vector3, mask: int) -> void:
	var pea := ArrowManager.make_arrow(split_scene, at, dir, mask)
	pea.simulation.change_speed(split_speed)

func _explode(at: Vector3) -> void:
	var fx := AnimatedSprite3D.new()
	fx.sprite_frames = EXPLODE_FRAMES
	fx.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fx.double_sided = false
	var sprite_scale := 0.385
	if _sprite:
		sprite_scale = _base_basis.get_scale().x
	fx.basis = Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3.ONE * sprite_scale)
	if _sprite:
		fx.layers = _sprite.layers
		fx.render_priority = _sprite.render_priority
	get_parent().add_child(fx)
	fx.global_position = at
	fx.animation_finished.connect(fx.queue_free)
	fx.play(&"explode")

func _process(delta: float) -> void:
	if not _sprite: return
	if not simulation or not simulation.enabled: return
	_spin_angle = fposmod(_spin_angle + spin_speed * delta, TAU)
	_sprite.transform.basis = Basis(Vector3.UP, _spin_angle) * _base_basis
