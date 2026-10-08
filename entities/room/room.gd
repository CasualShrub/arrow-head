@icon("res://addons/at-icons/used/node3d/house.svg")
extends Node3D
class_name Room

@export var entrance: EntranceArea
@export var exit: ExitArea
@export var entrance_walk_distance := 4.0
@export var allow_ricochet := true

signal started()
signal cleared()
signal ended(won: bool)

var player: Player
var _ongoing := false
var _cleared := false

@onready var _enemies := %Enemies
@onready var _juice_bar := %JuiceBar
@onready var _exit_indicator := %ExitIndicator

func _ready() -> void:
	if allow_ricochet:
		ArrowManager.max_bounces_override = -1
	else:
		ArrowManager.max_bounces_override = 0
	_setup_player()
	_setup_enemies()
	_setup_juice_bar()
	_setup_exit()
	_setup_exit_indicator()

	DarkenManager.register_overlay(%DarkenOverlay)

	start()

	if not any_enemy_alive():
		_clear()

func _input(event: InputEvent) -> void:
	if not _ongoing: return   # end screens handle their own keys
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if GameManager.current_level:
			GameManager.restart_room()
		else:
			ArrowManager.deactivate_all()
			get_tree().reload_current_scene()

func _setup_player() -> void:
	var players := find_children("*", "Player", true)
	assert(players.size() == 1, "Room must have exactly one Player.")
	add_player(players[0])
	if entrance:
		player.global_position = entrance.global_position

func _setup_enemies() -> void:
	var enemies := find_children("*", "Enemy", true)
	for e in enemies:
		add_enemy(e)

func _setup_exit() -> void:
	if not exit:
		for node in find_children("*", "", true, false):
			if node is ExitArea:
				exit = node
				break
		if not exit:
			return
	exit.player_entered.connect(_on_exit_entered)

func _setup_exit_indicator() -> void:
	if not exit:
		_exit_indicator.hide()
		return
	_exit_indicator.bind(exit)
	_exit_indicator.set_active(not exit.is_locked())
	exit.locked_changed.connect(func(is_locked: bool): _exit_indicator.set_active(not is_locked))


func _setup_juice_bar() -> void:
	_juice_bar.bind(player.time.bar)

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

func _camera():
	return player.get_node("%Camera")

func get_player() -> Player:
	return player

func add_player(p: Player):
	player = p
	p.health.died.connect(_on_player_died)
	for e in get_enemies():
		if e.camera_focus:
			_camera().focus_on(e)

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
	
	enemy.health.died.connect(_on_enemy_died.bind(enemy))
	if enemy.camera_focus and player:
		_camera().focus_on(enemy)
	if not enemy.get_parent():
		_enemies.add_child(enemy)

func any_enemy_alive() -> bool:
	for e in get_enemies():
		if not e.is_dead():
			return true
	return false

func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.camera_focus:
		_camera().clear_focus()
	if not any_enemy_alive():
		_clear()

func _clear() -> void:
	if _cleared:
		return
	_cleared = true
	cleared.emit()
	if exit:
		exit.unlock()

func play_entrance(direction: Vector3) -> void:
	if entrance:
		direction = entrance.get_entry_direction()
	var spawn := player.global_position
	player.global_position = spawn - direction * entrance_walk_distance
	player.force_walk_to(spawn)

func _on_exit_entered() -> void:
	if not is_ongoing(): return
	player.force_walk(exit.get_exit_direction())
	end(true)

func _on_player_died() -> void:
	end(false)
