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
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)

	vb.add_child(UiStyle.title("Arrow-head"))
	var tagline := UiStyle.label("turn their arrows back on the tyrant", 18, UiStyle.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tagline)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	vb.add_child(gap)

	var play := UiStyle.button("Play")
	play.pressed.connect(func(): _go("res://scenes/level_1.tscn"))
	vb.add_child(play)

	var levels := UiStyle.button("Level select")
	levels.pressed.connect(func(): _go("res://scenes/ui/level_select.tscn"))
	vb.add_child(levels)

	var options := UiStyle.button("Options")
	options.pressed.connect(func(): _go("res://scenes/ui/options_menu.tscn"))
	vb.add_child(options)

	var quit := UiStyle.button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit)

	play.grab_focus()

func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)
