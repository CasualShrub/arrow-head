extends Node

const MAIN_GAME = preload("res://resources/campaigns/main_game.tres")
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

signal campaign_started(campaign: CampaignState)
signal campaign_ended(campaign: CampaignState)
signal level_loaded(level: Level)
signal level_unloading(level: Level)

var current_campaign: CampaignState
var current_level: Level
var game_parent : Node #just a node for the level data to serve as parent of spawning level data
var player: Player:
	get():
		return current_level.player if current_level else null

func start(host: Node) -> void:
	start_campaign(MAIN_GAME, host)

func start_campaign(data: CampaignData, host: Node) -> void:
	game_parent = host
	current_campaign = CampaignState.new(data)
	campaign_started.emit(current_campaign)
	load_level()

func end_campaign() -> void:
	campaign_ended.emit(current_campaign)
	current_campaign = null
	current_level = null
	game_parent = null
	get_tree().change_scene_to_file(MAIN_MENU)

func abort() -> void:
	current_campaign = null
	current_level = null
	game_parent = null

func load_level(data: LevelData = current_campaign.get_current_level()) -> void:
	var level := Level.new(data)
	level.ended.connect(_on_level_ended)
	current_level = level
	game_parent.add_child(level)
	level_loaded.emit(level)
	level.start()

func unload_level() -> void:
	if not current_level: return
	level_unloading.emit(current_level)
	current_level.queue_free()
	current_level = null

func restart_room() -> void:
	if current_level:
		current_level.reload_room()

func _on_level_ended() -> void:
	unload_level()
	if not current_campaign.has_next_level():
		end_campaign()
		return
	current_campaign.advance()
	load_level()
