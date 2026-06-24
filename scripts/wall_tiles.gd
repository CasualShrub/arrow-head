@tool
extends TileMapLayer
class_name WallTiles

const _DIRT_SOURCE := 1
const _DIRT_ATLAS := Vector2i(1, 1)

@export var half_width := 36:
	set(value):
		half_width = max(value, 1)
		_build()
@export var half_height := 20:
	set(value):
		half_height = max(value, 1)
		_build()

func _ready() -> void:
	_build()

func _build() -> void:
	if not is_node_ready():
		return
	clear()
	for x in range(-half_width, half_width + 1):
		for y in range(-half_height, half_height + 1):
			if x == -half_width or x == half_width \
				or y == -half_height or y == half_height:
				set_cell(Vector2i(x, y), _DIRT_SOURCE, _DIRT_ATLAS)
