extends RefCounted
class_name CampaignState

var data: CampaignData
var current_level_index := 0

func _init(campaign_data: CampaignData) -> void:
	data = campaign_data

func get_current_level() -> PackedScene:
	var loaded := load(data.levels[current_level_index])
	assert(
		loaded is PackedScene,
		"Attempted to load invalid level %s." % loaded.resource_path
	)
	return loaded

func get_level_count() -> int:
	return data.levels.size()

func has_next_level() -> bool:
	return current_level_index < get_level_count() - 1

func advance() -> void:
	current_level_index += 1
