extends CanvasLayer

const START_TEXT := "ArrowHead the apple likes catching arrows!\n(But not too many in one spot.)"
const ANGRY_TEXT := "Hold and release spacebar to use an arrow to release your anger!"

@onready var _label: Label = %PromptLabel

var _player: Player
var _switched := false

func _ready() -> void:
	_label.text = START_TEXT
	_player = get_node_or_null("../SubViewportContainer/SubViewport/World/Player") as Player
	if _player:
		_player.hit.connect(_on_player_hit)

func dismiss(_a = null, _b = null, _c = null) -> void:
	hide()

func _on_player_hit(_arrow: Arrow, _sector: int) -> void:
	if _switched:
		return
	if _player.is_angry():
		_switched = true
		_label.text = ANGRY_TEXT
