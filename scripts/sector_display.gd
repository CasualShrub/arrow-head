extends Node2D
class_name SectorDisplay

# draws the player's quadrants: filled = holds an arrow, white = the one you're aiming at
@export var player: Player
@export var radius := 42.0

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	global_position = player.global_position
	rotation = player.get_facing_angle()  # sectors rotate with the apple's facing
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var n := player.sector_count
	if n <= 0:
		return
	var size := TAU / n
	var aimed := -1
	if player._facing != Vector2.ZERO:
		aimed = player.get_sector(player._facing)
	for i in n:
		var a0 := i * size
		if player.sector_centered:
			a0 -= size * 0.5
		var pts := _wedge(a0, a0 + size)
		var occupied: bool = player.get_embedded(i) != null
		draw_colored_polygon(pts, Color(0.95, 0.85, 0.3, 0.4) if occupied else Color(0.6, 0.65, 0.75, 0.08))
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(0.85, 0.87, 0.95, 0.45), 1.5)
		if i == aimed:
			draw_polyline(edge, Color(1, 1, 1, 0.95), 3.0)

func _wedge(a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for s in 11:
		var a: float = lerp(a0, a1, s / 10.0)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
