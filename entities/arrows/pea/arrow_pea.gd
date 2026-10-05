extends Arrow
class_name ArrowPea

@export var spin_speed := 12.0

const EXPLODE_FRAMES: SpriteFrames = preload("res://entities/arrows/pea/pea_explode_frames.tres")

var _sprite: Sprite3D
var _base_basis: Basis
var _spin_angle := 0.0

func _ready() -> void:
	super()
	_sprite = find_child("Sprite3D", true, false) as Sprite3D
	if _sprite:
		_base_basis = _sprite.transform.basis

func _on_activated() -> void:
	super()
	_spin_angle = 0.0

func _on_collision_simulated(sim: ArrowSimulation, collider: CollisionObject3D) -> void:
	if sim.alive: return
	if collider is ArrowCollider: return
	_explode(sim.position)

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
