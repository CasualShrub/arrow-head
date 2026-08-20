extends Node

const MAIN_GAME = preload("res://resources/campaigns/main_game.tres")

signal campaign_started(campaign: CampaignState)
signal campaign_ended(campaign: CampaignState)
signal level_loaded(level: Level)
signal level_unloading(level: Level)

var current_campaign: CampaignState
var current_level: Level
var player: Player:
	get():
		return current_level.player if current_level else null

func start() -> void:
	start_campaign(MAIN_GAME)

func start_campaign(data: CampaignData) -> void:
	current_campaign = CampaignState.new(data)
	campaign_started.emit(current_campaign)
	load_level()

func end_campaign() -> void:
	campaign_ended.emit(current_campaign)
	current_campaign = null

func load_level(
	scene: PackedScene = current_campaign.get_current_level()
) -> void:
	var level := scene.instantiate()
	assert(level is Level, "Invalid level loaded %s." % scene.resource_path)
	level.ended.connect(_on_level_ended)
	current_level = level
	level_loaded.emit(level)
	level.start()

func unload_level() -> void:
	if not current_level: return
	level_unloading.emit(current_level)
	current_level.queue_free()
	current_level = null

func _on_level_ended() -> void:
	unload_level()
	if not current_campaign.has_next_level():
		end_campaign()
		return
	current_campaign.advance()
	load_level()
