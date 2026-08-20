extends Node3D
class_name Level

var _data: LevelData

signal started()
signal ending()
signal ended()
signal room_loaded(room: Room)
signal room_unloading(room: Room)

var current_room: Room
var current_room_index := 0
var player: Player:
	get():
		return current_room.get_player() if current_room else null

func _init(level_data: LevelData) -> void:
	assert(
		level_data.get_room_count() > 0,
		"Attempted to load data with no rooms %s." % level_data.resource_path
	)
	_data = level_data

func get_data() -> LevelData:
	return _data

func has_next_room() -> bool:
	return current_room_index < _data.get_room_count() - 1

func start() -> void:
	load_room(0)
	started.emit()

func end() -> void:
	ending.emit()
	_unload_room()
	ended.emit()

func restart() -> void:
	_unload_room()
	start()

func advance_room() -> void:
	if not has_next_room():
		end()
		return
	load_room(current_room_index + 1)

func load_room(index: int) -> void:
	if current_room:
		_unload_room()
	assert(
		index >= 0 and index < _data.get_room_count(),
		"Tried to load invalid Room at index %d." % index
	)
	var scene := _data.get_room(index)
	var room := scene.instantiate() as Room
	assert(
		room is Room,
		"Tried to insantiate invalid Room %s." % scene.resource_path
	)
	room.ended.connect(_on_room_ended)
	current_room_index = index
	current_room = room
	room_loaded.emit(room)

func _unload_room() -> void:
	if not current_room: return
	room_unloading.emit(current_room)
	current_room.queue_free()
	current_room = null

func reload_room() -> void:
	if not current_room: return
	_unload_room()
	load_room(current_room_index)

func _get_scene_type(scene: PackedScene) -> String:
	var state = scene.get_state()
	# check custom classes
	for i in state.get_node_property_count(0):
		var prop_name = state.get_node_property_name(0, i)
		
		if prop_name == "script":
			var script = state.get_node_property_value(0, i) as Script
			if script and script.get_global_name() != &"":
				return script.get_global_name()
	
	return state.get_node_type(0)

func _on_room_ended() -> void:
	advance_room()
