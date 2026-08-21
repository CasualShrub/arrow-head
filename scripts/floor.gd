@tool
extends GeometryInstance3D
class_name GrassFloor

const FLOOR_TILES: Array[Texture2D] = [
	preload("res://tiles/grass1.PNG"),
	preload("res://tiles/grass2.PNG"),
	preload("res://tiles/grass3.PNG"),
	preload("res://tiles/grass4.png"),
	preload("res://tiles/grass6.png"),
]

@export_tool_button("Reload", "Reload")
var reload_button := func():
	_preview_material = null
	_preview_texture = null
	_apply_preview()

@export var cells := 8
@export var cell_px := 192
@export var uv_scale := 0.06

var _preview_material: StandardMaterial3D
var _preview_texture: ImageTexture


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_apply_preview")
	else:
		_apply_preview()

func _validate_property(property: Dictionary) -> void:
	if property.name == "material_override":
		property.usage = property.usage & ~PROPERTY_USAGE_STORAGE

#func _exit_tree() -> void:
	#if Engine.is_editor_hint():
		#material_override = null
		#_preview_material = null
		#_preview_texture = null

func _apply_preview() -> void:
	if not is_inside_tree():
		return

	# Don't rebuild the preview every time the tool script runs.
	if _preview_material != null:
		material_override = _preview_material
		return

	_preview_texture = _build_texture()

	_preview_material = StandardMaterial3D.new()
	_preview_material.albedo_texture = _preview_texture
	_preview_material.uv1_triplanar = true
	_preview_material.uv1_world_triplanar = true
	_preview_material.uv1_scale = Vector3.ONE * uv_scale

	# Don't make this resource part of the saved scene.
	_preview_material.resource_local_to_scene = true

	material_override = _preview_material


func _build_texture() -> ImageTexture:
	var dim := cells * cell_px

	var canvas := Image.create(
		dim,
		dim,
		false,
		Image.FORMAT_RGBA8
	)

	for cy in range(cells):
		for cx in range(cells):
			var tex: Texture2D = FLOOR_TILES.pick_random()
			var src := tex.get_image()

			if src.is_compressed():
				src = src.duplicate()
				src.decompress()

			if src.get_format() != Image.FORMAT_RGBA8:
				src.convert(Image.FORMAT_RGBA8)

			if src.get_width() != cell_px or src.get_height() != cell_px:
				src.resize(cell_px, cell_px)

			canvas.blit_rect(
				src,
				Rect2i(0, 0, cell_px, cell_px),
				Vector2i(cx * cell_px, cy * cell_px)
			)

	return ImageTexture.create_from_image(canvas)
