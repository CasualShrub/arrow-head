extends TextureButton

@onready var SettingsPopup: Control = $"../SettingsPopup"
@export var fade_duration: float = 0.15

var is_showing: bool = false
var fade_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready():

	SettingsPopup.visible=false
	
	#this stuff is AI code, cuz I can't get the gear to appear in the right place on run if I want it to spin
	#await get_tree().process_frame
	#var original_pos = global_position
	#pivot_offset = size/2
	#global_position=original_pos

func _on_pressed():
	
	is_showing = !is_showing
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	
	var tween: Tween = create_tween()
	
	self.rotation_degrees=0

	if SettingsPopup.visible == false:
		SettingsPopup.visible=true
		
		fade_tween.tween_property(SettingsPopup, "modulate:a", 1.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "rotation_degrees", 45, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	else:
		SettingsPopup.visible=false
		
	
	
