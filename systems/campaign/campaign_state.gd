extends RefCounted
class_name CampaignState

var data: CampaignData
var current_level_index := 0

func _init(campaign_data: CampaignData) -> void:
	data = campaign_data

#func get_level(idx: int) -> LevelData:
		#
	#return data.levels[idx]
	
#func _init(campaign_data: CampaignData, selected_difficulty = GameManager.Difficulty.HARD) -> void:
	#data = campaign_data
	#difficulty = selected_difficulty

# Helper function to get the correct array based on difficulty
func _get_active_level_array() -> Array[LevelData]:
	match SettingsManager.current_difficulty:
		SettingsManager.Difficulty.EASY:
			return data.easyLevels
		SettingsManager.Difficulty.EXPERT:
			return data.expertLevels
		_:
			return data.levels # Default / Hard

func get_level(idx: int) -> LevelData:
	var active_levels = _get_active_level_array()
	return active_levels[idx]

func get_current_level() -> LevelData:
	return get_level(current_level_index)

func get_level_count() -> int:
	return _get_active_level_array().size()

func has_next_level() -> bool:
	return current_level_index < get_level_count() - 1

func advance() -> void:
	if has_next_level():
		current_level_index += 1
