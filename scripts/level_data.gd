extends Resource
class_name LevelData

@export var music: AudioStream
@export_file("*.tscn", "*.scn") var rooms: Array[String] = []

func get_room_count() -> int:
	return rooms.size()

func get_room(index: int) -> PackedScene:
	var obj := load(rooms[index])
	assert(
		obj is PackedScene,
		"Attempted to load invalid room %s." % obj.resource_path
	)
	return obj as PackedScene
