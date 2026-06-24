@tool
extends Node2D
class_name WallTiles

## Builds the arena's outer wall ring out of fence_block decorations. Each block is
## a StaticBody2D on the wall layer, so the player and arrows collide with it.

const _BLOCK := preload("res://scenes/deco/fence_block.tscn")
const _BLOCK_W := 231.0
const _BLOCK_H := 199.0

## Distance from center to the wall ring, in pixels.
@export var half_width_px := 576:
	set(value):
		half_width_px = max(value, 0)
		_rebuild()
@export var half_height_px := 324:
	set(value):
		half_height_px = max(value, 0)
		_rebuild()
@export var block_scale := 0.3:
	set(value):
		block_scale = maxf(value, 0.01)
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_node_ready():
		return
	for c in get_children():
		c.queue_free()
	var step_x := _BLOCK_W * block_scale
	var step_y := _BLOCK_H * block_scale
	var w := float(half_width_px)
	var h := float(half_height_px)
	# top & bottom edges (corners included here)
	_edge(Vector2(-w, -h), Vector2(w, -h), step_x)
	_edge(Vector2(-w, h), Vector2(w, h), step_x)
	# left & right edges (start past the corners so they aren't doubled)
	_edge(Vector2(-w, -h + step_y), Vector2(-w, h - step_y), step_y)
	_edge(Vector2(w, -h + step_y), Vector2(w, h - step_y), step_y)

func _edge(from: Vector2, to: Vector2, step: float) -> void:
	var dist := from.distance_to(to)
	var n := maxi(int(round(dist / step)), 1)
	for i in range(n + 1):
		_place(from.lerp(to, float(i) / n))

func _place(pos: Vector2) -> void:
	var block := _BLOCK.instantiate()
	add_child(block)
	block.position = pos
	block.scale = Vector2(block_scale, block_scale)
