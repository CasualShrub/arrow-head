extends Control

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)

	vb.add_child(UiStyle.title("Options", 44))

	vb.add_child(_volume_row("Master", Settings.master_volume, Settings.set_master_volume))
	vb.add_child(_volume_row("Music", Settings.music_volume, Settings.set_music_volume))
	vb.add_child(_volume_row("SFX", Settings.sfx_volume, Settings.set_sfx_volume))

	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_font_size_override("font_size", 20)
	fs.add_theme_color_override("font_color", UiStyle.TEXT)
	fs.toggled.connect(func(on): Settings.set_fullscreen(on))
	vb.add_child(fs)

	var back := UiStyle.button("Back")
	back.pressed.connect(func(): get_tree().change_scene_to_file("uid://dq024rj3sseom"))
	vb.add_child(back)
	back.grab_focus()

# one labelled volume slider wired to a Settings setter (live-apply + save)
func _volume_row(label: String, value: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := UiStyle.label(label, 20)
	lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(240, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(setter)
	row.add_child(slider)
	return row
