extends Node2D
class_name Encounter

# owns the win/lose verdict for one fight. enemies register in the "enemies" group and
# report death via their `died` signal; the player reports via `died`. emits ended(won)
# for the HUD to present — the HUD never decides the outcome itself.
@export var player: Player

var _ongoing := false

signal ended(won: bool)

func get_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")

func enemies_alive() -> bool:
	for e in get_enemies():
		if is_instance_valid(e) and not e.is_dead():
			return true
	return false

func start() -> void:
	if _ongoing:
		return
	for e in get_enemies():
		if e is Enemy:
			e.player = player
			if not e.died.is_connected(_on_enemy_died):
				e.died.connect(_on_enemy_died)
	if player and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	_ongoing = true

func _end(won: bool) -> void:
	if not _ongoing:
		return
	_ongoing = false
	ended.emit(won)

func _on_enemy_died() -> void:
	if not enemies_alive():
		_end(true)

func _on_player_died() -> void:
	_end(false)

func _ready() -> void:
	# defer so every enemy's _ready (group registration) has run first
	start.call_deferred()
