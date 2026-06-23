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

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	var vol_label := UiStyle.label("Volume", 20)
	vol_label.custom_minimum_size = Vector2(120, 0)
	vol_row.add_child(vol_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Settings.master_volume
	slider.custom_minimum_size = Vector2(240, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v): Settings.set_master_volume(v))  # live-apply + save
	vol_row.add_child(slider)
	vb.add_child(vol_row)

	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_font_size_override("font_size", 20)
	fs.add_theme_color_override("font_color", UiStyle.TEXT)
	fs.toggled.connect(func(on): Settings.set_fullscreen(on))
	vb.add_child(fs)

	var back := UiStyle.button("Back")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	vb.add_child(back)
	back.grab_focus()
