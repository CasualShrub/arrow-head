extends Node3D

func _ready() -> void:
	if GameManager.pending_campaign:
		GameManager.start_campaign(GameManager.pending_campaign, self)
		GameManager.current_campaign.current_level_index = GameManager.pending_level
		GameManager.load_level(
			GameManager.current_campaign.get_level(GameManager.pending_level)
		)
		GameManager.current_level.load_room(GameManager.pending_room)
		GameManager.pending_campaign = null
		GameManager.pending_level = 0
		GameManager.pending_room = 0
	else:
		GameManager.start(self)
