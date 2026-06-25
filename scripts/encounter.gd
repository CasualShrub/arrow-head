extends Node3D

@export var player: Player
@export var is_boss_level := false

var _ongoing := false
var _won: bool

signal ended(won: bool)

func get_enemies() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	for e in %Enemies.get_children():
		if e is Enemy:
			enemies.append(e)
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
	p.died.connect(_on_player_died.bind())

func start() -> void:
	var enemies := find_children("*", "Enemy")
	for e in enemies:
		add_enemy(e)
	add_player(player)
	_ongoing = true

func _end(won: bool) -> void:
	if not _ongoing: return
	_ongoing = false
	_won = won
	if won:
		SoundManager.play("big_win_kill_boss_jingle" if is_boss_level else "enemy_death_small_win_jingle")
	ended.emit(_won)

func _on_enemy_died(_enemy: Enemy) -> void:
	if not enemies_alive():
		_end(true)

func _on_player_died() -> void:
	_end(false)

func _ready() -> void:
	if not player: player = %Player
	SoundManager.play_music("Lvl_1")   # switch from title music to level music
	start()
