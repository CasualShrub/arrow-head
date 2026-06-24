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
		var base := _kind_color(i)  # each sector tinted by the kind it catches
		var occupied: bool = player.get_embedded(i) != null
		var fill := base
		fill.a = 0.5 if occupied else 0.14
		if i == aimed:
			fill = base.lerp(Color.WHITE, 0.5)
			fill.a = 0.45
		draw_colored_polygon(pts, fill)
		# arc (outer curve): brighter on the aimed wedge
		var arc_color := base
		arc_color.a = 0.6 if i == aimed else 0.35
		draw_polyline(pts.slice(1), arc_color, 1.5)
		# inner cone sides: bold white on the aimed wedge, the kind color on the rest
		var sides := PackedVector2Array([pts[1], pts[0], pts[pts.size() - 1]])
		if i == aimed:
			draw_polyline(sides, Color(1, 1, 1, 0.95), 3.0)
		else:
			var side_c := base
			side_c.a = 0.35
			draw_polyline(sides, side_c, 1.5)

func _wedge(a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for s in 11:
		var a: float = lerp(a0, a1, s / 10.0)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

func _kind_color(sector: int) -> Color:
	var k: int = player.sector_kinds[sector] if sector < player.sector_kinds.size() else Arrow.Kind.NORMAL
	return Arrow.KIND_COLORS.get(k, Color.WHITE)
