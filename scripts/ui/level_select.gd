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
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)

	vb.add_child(UiStyle.title("Select level", 44))

	# only level 1 is playable so far; 2-5 are locked stubs
	for i in range(1, 6):
		var b := UiStyle.button("Level %d" % i)
		if i == 1:
			b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/level.tscn"))
		else:
			b.text = "Level %d  —  locked" % i
			b.disabled = true
		vb.add_child(b)

	var back := UiStyle.button("Back")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	vb.add_child(back)
	back.grab_focus()
