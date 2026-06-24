@tool
extends TileMapLayer
class_name GrassTiles

# i decided to just randomize variants so it's random every time. can change tho
const _VARIANTS := 6

@export var half_width_px := 640:
	set(value):
		half_width_px = max(value, 0)
		_build()
@export var half_height_px := 384:
	set(value):
		half_height_px = max(value, 0)
		_build()
@export var rng_seed := 7:
	set(value):
		rng_seed = value
		_build()

func _ready() -> void:
	_build()

func _build() -> void:
	if not is_node_ready() or tile_set == null:
		return
	clear()
	var tile := tile_set.tile_size.x
	var row := int(ceil(float(half_width_px) / tile))
	var column := int(ceil(float(half_height_px) / tile))
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed


	for x in range(-row - 1, row + 1):
		for y in range(-column - 1, column + 1):
			set_cell(Vector2i(x, y), rng.randi() % _VARIANTS, Vector2i(0, 0))
