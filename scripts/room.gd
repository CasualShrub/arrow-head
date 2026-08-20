extends Node3D
class_name Room

@export var player: Player
@export var is_boss_level := false
@export var music_track := "Lvl_1"

signal started()
signal ended(won: bool)

var _ongoing := false

@onready var _enemies := %Enemies

func _ready() -> void:
	var players := find_children("*", "Player", true)
	assert(players.size() == 1, "Room must have exactly one Player.")
	add_player(players[0])
	
	var enemies := find_children("*", "Enemy", true)
	for e in enemies:
		add_enemy(e)
	
	start()

func _input(event: InputEvent) -> void:
	if not _ongoing: return   # end screens handle their own keys
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func is_ongoing() -> bool:
	return _ongoing

func start() -> void:
	if is_ongoing(): return
	Engine.time_scale = 1.0
	SoundManager.play_music(music_track)
	_ongoing = true
	
	started.emit()

func end(won: bool) -> void:
	if not is_ongoing(): return
	_ongoing = false
	Engine.time_scale = 1.0
	
	ended.emit(won)

func add_player(p: Player):
	player = p
	p.died.connect(_on_player_died.bind())

func get_player() -> Player:
	return player

func get_enemies() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	for e in %Enemies.get_children():
		if e is Enemy:
			enemies.append(e)
	return enemies

func add_enemy(enemy: Enemy) -> void:
	var p := enemy.get_parent()
	if p and p != _enemies:
		p.remove_child(enemy)
	
	enemy.player = player
	enemy.died.connect(_on_enemy_died.bind(enemy))
	if not enemy.get_parent():
		_enemies.add_child(enemy)

func any_enemy_alive() -> bool:
	for e in get_enemies():
		if not e.is_dead():
			return true
	return false

func _on_enemy_died(_enemy: Enemy) -> void:
	if not any_enemy_alive():
		end(true)

func _on_player_died() -> void:
	end(false)
