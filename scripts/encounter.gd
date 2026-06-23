extends Node2D

@export var player: Player

var _ongoing := false
var _won: bool

signal ended(won: bool)

func get_enemies() -> Array[Enemy]:
	var enemies = %Enemies.get_children()
	return enemies

func enemies_alive() -> bool:
	for e in get_enemies():
		if not e.is_dead():
			return true
	return false

func add_enemy(enemy: Enemy) -> void:
	var p := enemy.get_parent()
	if p and p != %Enemies:
		p.remove_child(enemy)
	
	enemy.player = player
	enemy.died.connect(_on_enemy_died.bind(enemy))
	if not enemy.get_parent():
		%Enemies.add_child(enemy)
		
func add_player(p: Player):
	p.died.connect(_on_player_died.bind(p))

func start() -> void:
	for e in get_enemies():
		add_enemy(e)
	add_player(player)
	_ongoing = true

func _end(won: bool) -> void:
	if not _ongoing: return
	_ongoing = false
	_won = won
	ended.emit(_won)

func _on_enemy_died(_enemy: Enemy) -> void:
	if not enemies_alive():
		_end(true)

func _on_player_died() -> void:
	_end(false)

func _ready() -> void:
	if not player: player = %Player
