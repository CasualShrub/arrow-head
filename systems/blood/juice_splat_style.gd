@tool
@icon("res://addons/at-icons/used/node3d/ground.svg")
extends Resource
class_name JuiceSplatStyle

@export_group("texture")
@export var texture_size := Vector2i(256, 128)
@export var origin_x := 40
@export var variant_count := 8

@export_group("pool")
@export var pool_blob_count := 9
@export var pool_radius_range := Vector2(18.0, 24.0)
@export var pool_offset_back := 0.6
@export var pool_offset_forward := 0.9
@export var pool_offset_side := 0.6

@export_group("streaks")
@export var streak_count_range := Vector2i(4, 7)
@export var streak_min_reach := 70.0
@export var streak_max_angle := 0.45
@export var streak_width_range := Vector2(5.0, 9.0)
@export var streak_tip_width := 1.2
@export var streak_wobble := 2.0
@export var streak_end_drop_range := Vector2(2.5, 4.5)

@export_group("droplets")
@export var droplet_count_range := Vector2i(18, 30)
@export var droplet_spread := 0.8
@export var droplet_near_radius := 5.0
@export var droplet_far_radius := 1.5

@export_group("back spatter")
@export var back_count_range := Vector2i(3, 6)
@export var back_radius_range := Vector2(1.5, 3.5)

@export_group("placement")
@export var world_length := 1.6
@export var length_jitter := 0.15
@export var angle_jitter := 0.25
@export var shades: Array[float] = [0.78, 0.86, 0.93, 1.0]
@export var grow_time := 0.12
@export var grow_start_scale := 0.3
@export var max_splats := 300

@export_group("preview")
@export_tool_button("Generate Preview", "Reload")
var preview_button := func():
	preview = build_texture()
	notify_property_list_changed()
@export var preview: Texture2D

var _textures: Array[ImageTexture] = []

func _validate_property(property: Dictionary) -> void:
	if property.name == "preview":
		property.usage = property.usage & ~PROPERTY_USAGE_STORAGE

func get_texture(variant: int) -> ImageTexture:
	if _textures.is_empty():
		for i in variant_count:
			_textures.append(build_texture())
	return _textures[variant % _textures.size()]

func get_random_variant() -> int:
	return randi() % variant_count

func build_texture() -> ImageTexture:
	var img := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var origin := Vector2(origin_x, texture_size.y * 0.5)
	var pool_radius := randf_range(pool_radius_range.x, pool_radius_range.y)

	_paint_pool(img, origin, pool_radius)
	_paint_streaks(img, origin)
	_paint_droplets(img, origin, pool_radius)
	_paint_back_spatter(img, origin, pool_radius)

	return ImageTexture.create_from_image(img)

func _paint_pool(img: Image, origin: Vector2, pool_radius: float) -> void:
	for i in pool_blob_count:
		var offset := Vector2(
			randf_range(-pool_offset_back, pool_offset_forward),
			randf_range(-pool_offset_side, pool_offset_side)
		) * pool_radius
		_draw_circle(img, origin + offset, pool_radius * randf_range(0.45, 0.8))

func _paint_streaks(img: Image, origin: Vector2) -> void:
	for i in randi_range(streak_count_range.x, streak_count_range.y):
		var dir := Vector2.from_angle(randf_range(-streak_max_angle, streak_max_angle))
		var max_reach := _distance_to_edge(origin, dir) - 12.0
		var reach := randf_range(minf(streak_min_reach, max_reach), max_reach)
		var side := Vector2(-dir.y, dir.x)
		var start_width := randf_range(streak_width_range.x, streak_width_range.y)
		var steps := int(reach / 2.0)
		for s in steps:
			var t := float(s) / steps
			var wobble := side * sin(t * 9.0 + i) * streak_wobble
			_draw_circle(img, origin + dir * t * reach + wobble, lerpf(start_width, streak_tip_width, t))
		_draw_circle(img, origin + dir * reach, randf_range(streak_end_drop_range.x, streak_end_drop_range.y))

func _paint_droplets(img: Image, origin: Vector2, pool_radius: float) -> void:
	for i in randi_range(droplet_count_range.x, droplet_count_range.y):
		var dir := Vector2.from_angle(randf_range(-droplet_spread, droplet_spread))
		var max_dist := _distance_to_edge(origin, dir)
		var dist := randf_range(pool_radius, max_dist - 6.0)
		var pos := origin + dir * dist
		var radius := lerpf(droplet_near_radius, droplet_far_radius, dist / max_dist) * randf_range(0.6, 1.2)
		if _fits(img, pos, radius):
			_draw_circle(img, pos, radius)

func _paint_back_spatter(img: Image, origin: Vector2, pool_radius: float) -> void:
	for i in randi_range(back_count_range.x, back_count_range.y):
		var pos := origin + Vector2.from_angle(randf() * TAU) * randf_range(pool_radius, pool_radius * 2.0)
		_draw_circle(img, pos, randf_range(back_radius_range.x, back_radius_range.y))

func _distance_to_edge(origin: Vector2, dir: Vector2) -> float:
	var dist := INF
	if dir.x > 0.001:
		dist = minf(dist, (texture_size.x - origin.x) / dir.x)
	elif dir.x < -0.001:
		dist = minf(dist, origin.x / -dir.x)
	if dir.y > 0.001:
		dist = minf(dist, (texture_size.y - origin.y) / dir.y)
	elif dir.y < -0.001:
		dist = minf(dist, origin.y / -dir.y)
	return dist

func _fits(img: Image, center: Vector2, radius: float) -> bool:
	return (
		center.x - radius >= 0.0
		and center.y - radius >= 0.0
		and center.x + radius < img.get_width()
		and center.y + radius < img.get_height()
	)

func _draw_circle(img: Image, center: Vector2, radius: float) -> void:
	var min_x := maxi(int(center.x - radius), 0)
	var max_x := mini(int(center.x + radius) + 1, img.get_width() - 1)
	var min_y := maxi(int(center.y - radius), 0)
	var max_y := mini(int(center.y + radius) + 1, img.get_height() - 1)
	var r2 := radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var d := Vector2(x + 0.5, y + 0.5) - center
			if d.length_squared() <= r2:
				img.set_pixel(x, y, Color.WHITE)
