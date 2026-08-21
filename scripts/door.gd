extends Area3D
class_name Door

signal player_entered()
signal locked_changed(is_locked: bool)

@export var locked_color := Color(0.75, 0.2, 0.2)
@export var open_color := Color(0.3, 0.85, 0.35)

var _locked := true
var _mat: StandardMaterial3D

@onready var _mesh: MeshInstance3D = %Mesh

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	if _mesh:
		_mesh.material_override = _mat
	body_entered.connect(_on_body_entered)
	_update_color()

func is_locked() -> bool:
	return _locked

func lock() -> void:
	if _locked: return
	_locked = true
	_update_color()
	locked_changed.emit(true)

func unlock() -> void:
	if not _locked: return
	_locked = false
	_update_color()
	locked_changed.emit(false)
	for body in get_overlapping_bodies():
		if body is Player:
			player_entered.emit()
			return

func _on_body_entered(body: Node3D) -> void:
	if _locked: return
	if body is Player:
		player_entered.emit()

func _update_color() -> void:
	if _mat:
		_mat.albedo_color = open_color if not _locked else locked_color
