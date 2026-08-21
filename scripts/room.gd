extends Node3D
class_name Room

signal started()
signal cleared()
signal ended(won: bool)

var player: Player
var _ongoing := false
var _cleared := false
var _door: Door

@onready var _enemies := %Enemies

func _ready() -> void:
	var players := find_children("*", "Player", true)
	assert(players.size() == 1, "Room must have exactly one Player.")
	add_player(players[0])
	
	var enemies := find_children("*", "Enemy", true)
	for e in enemies:
		add_enemy(e)
	

	var doors := find_children("*", "Door", true)
	if doors.size() > 0:
		_door = doors[0] as Door
		_door.player_entered.connect(_on_door_entered)

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
	_ongoing = true
	
	started.emit()

func end(won: bool) -> void:
	if not is_ongoing(): return
	_ongoing = false
	Engine.time_scale = 1.0
	
	ended.emit(won)

func get_player() -> Player:
	return player

func add_player(p: Player):
	player = p
	p.health.died.connect(_on_player_died)

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
		_clear()

func _clear() -> void:
	if _cleared:
		return
	_cleared = true
	cleared.emit()
	if _door:
		_door.unlock()

func _on_door_entered() -> void:
	end(true)

func _on_player_died() -> void:
	end(false)
