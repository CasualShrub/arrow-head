extends CharacterBody2D
class_name Enemy

@export var health: HealthComponent

@export_group("firing")
@export var arrow_scene: PackedScene

# maybe if the enemy shoots several in a volley have several directions??
# add a way for the enemy to track player ?
@export var volley_directions: Array[Vector2] = [Vector2.DOWN]
@export var fire_cooldown := 2.0

var _cooldown_remaining := 0.0

signal fired(arrows: Array[Arrow])

func _physics_process(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining <= 0.0:
		_fire()
		_cooldown_remaining = fire_cooldown

func _fire() -> void:
	if volley_directions.is_empty():
		return
	var spawned: Array[Arrow] = []
	for direction in volley_directions:
		var arrow: Arrow = arrow_scene.instantiate()
		get_tree().current_scene.add_child(arrow)
		arrow.activate(global_position, direction, Arrow.Team.ENEMY)
		spawned.append(arrow)
	fired.emit(spawned)
