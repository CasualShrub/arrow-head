extends GeometryInstance3D
class_name GrassFloor


const FLOOR_TILES: Array[Texture2D] = [
	preload("res://tiles/grass1.PNG"),
	preload("res://tiles/grass2.PNG"),
	preload("res://tiles/grass3.PNG"),
	preload("res://tiles/grass4.png"),
	preload("res://tiles/grass6(1).png"),
]

@export var cells := 8
@export var cell_px := 192
@export var uv_scale := 0.06 

func _ready() -> void:
	randomize()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _build_texture()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	material_override = mat

func _build_texture() -> ImageTexture:
	var dim := cells * cell_px
	var canvas := Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	for cy in cells:
		for cx in cells:
			var tex: Texture2D = FLOOR_TILES.pick_random()
			var src := tex.get_image()
			if src.is_compressed():
				src.decompress()
			src.convert(Image.FORMAT_RGBA8)
			src.resize(cell_px, cell_px)
			canvas.blit_rect(src, Rect2i(0, 0, cell_px, cell_px), Vector2i(cx * cell_px, cy * cell_px))
	return ImageTexture.create_from_image(canvas)
