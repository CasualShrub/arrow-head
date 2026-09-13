extends HSlider

#Some AI code that runs, delete it if its better in the settings_manager, I couldn't get the thingy to work
@export var audio_bus_name: String = "SFX"
@onready var texture_rect = $TextureRect
var bus_index: int

func _ready() -> void:
	# Get the index of the "Music" bus
	bus_index = AudioServer.get_bus_index(audio_bus_name)
	
	# Connect the slider's signal to our function
	value_changed.connect(_on_value_changed)
	
	# Set the initial slider position to match the current volume
	var current_db = AudioServer.get_bus_volume_db(bus_index)
	value = db_to_linear(current_db)
	
	#slider shader
	_update_shader_fill(value)
	value_changed.connect(_update_shader_fill)

func _on_value_changed(new_value: float) -> void:
	# Convert the 0.0-1.0 slider value to decibels and apply it
	var db_value = linear_to_db(new_value)
	AudioServer.set_bus_volume_db(bus_index, db_value)
	
	
	
func _update_shader_fill(new_value: float) -> void: #updates slider
	# Calculate fill ratio between 0.0 and 1.0
	var fill_ratio = (new_value - min_value) / (max_value - min_value)
	
	# Pass the percentage to your TextureRect's shader material
	var mat = texture_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fill_amount", fill_ratio)

func _on_drag_ended(value_changed):
	SettingsManager._save()
