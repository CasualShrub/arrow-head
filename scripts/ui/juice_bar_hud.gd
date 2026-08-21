extends CanvasLayer
class_name JuiceBarHud

# looks weird but this is just bc the apple core outline blocks view and I can't be bothered to mess with scaling the asset
const FILL_EMPTY := 0.1
const FILL_FULL := 0.825

@onready var _juice: TextureProgressBar = %Juice

var _source: BarComponent

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

#gotta bind this to the barcomponent of the time component of the player
func bind(bar: BarComponent) -> void:
	if _source == bar:
		return
	if _source and _source.changed.is_connected(_on_bar_changed):
		_source.changed.disconnect(_on_bar_changed)
	_source = bar
	if _source:
		_source.changed.connect(_on_bar_changed)
		_refresh()

func _on_bar_changed(_current: float) -> void:
	_refresh()

func _refresh() -> void:
	if not _source or not _juice:
		return
	_juice.value = lerpf(FILL_EMPTY, FILL_FULL, _source.get_percentage())
