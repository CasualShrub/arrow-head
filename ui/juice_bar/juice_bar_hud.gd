extends Control
class_name JuiceBarHud

@export var lerp_speed := 10.0

const FILL_EMPTY := 0.07
const FILL_FULL := 0.825

@onready var _juice: TextureProgressBar = %Juice

var _source: BarComponent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_instance_valid(_source):
		return

	var target := lerpf(
		FILL_EMPTY,
		FILL_FULL,
		_source.get_percentage()
	)
	
	var real_delta := delta / Engine.time_scale
	var weight := 1.0 - exp(-lerp_speed * real_delta)
	_juice.value = lerpf(_juice.value, target, weight)


func bind(bar: BarComponent) -> void:
	_source = bar
