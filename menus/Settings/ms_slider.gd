extends HSlider

@onready var texture_rect = $TextureRect # Make sure this matches your scene tree path

func _ready() -> void:
	# Update the shader immediately when the game starts
	_update_shader_fill(value)
	
	# Connect the built-in signal to track user dragging
	value_changed.connect(_update_shader_fill)

func _update_shader_fill(new_value: float) -> void:
	# Calculate fill ratio between 0.0 and 1.0
	var fill_ratio = (new_value - min_value) / (max_value - min_value)
	
	# Pass the percentage to your TextureRect's shader material
	var mat = texture_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fill_amount", fill_ratio)
