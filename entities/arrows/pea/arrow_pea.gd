extends Arrow
class_name ArrowPea

@export var spin_speed := 12.0

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

func _process(delta: float) -> void:
	if not _sprite: return
	if not simulation or not simulation.enabled: return
	_spin_angle = fposmod(_spin_angle + spin_speed * delta, TAU)
	_sprite.transform.basis = Basis(Vector3.UP, _spin_angle) * _base_basis
