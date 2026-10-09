extends Node

var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _test_player()
	await _test_menus()
	SoundManager.stop_music()
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: controller input, analog aim, attack, pause, menus and settings")
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await get_tree().process_frame

func _button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _attacks(player: Player) -> int:
	return player.arrows.get_slots_with_state(SectorArrowsComponent.SlotState.USABLE).size()

func _wait(seconds := 0.05) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--screenshots=").path_join(name + ".png"))

func _test_player() -> void:
	for device in Input.get_connected_joypads():
		print("Controller: ", Input.get_joy_name(device))
	ControllerManager._use_mouse()
	var player := preload("res://entities/player/player.tscn").instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	await _wait()
	await _axis(JOY_AXIS_RIGHT_X, 0.05)
	_check(not ControllerManager.using_controller, "Stick drift changed input mode")
	await _axis(JOY_AXIS_RIGHT_X, 1.0)
	_check(player.input_mode.is_controller(), "Controller mode not selected")
	var full := player._get_aim_target() - player.global_position
	_check(absf(full.length() - player.dash.max_distance) < 0.01 and full.normalized().dot(Vector3.RIGHT) > 0.99, "Outer stick does not aim at max range")
	await _axis(JOY_AXIS_RIGHT_X, 0.6)
	var half := player._get_aim_target() - player.global_position
	_check(absf(half.length() - player.dash.max_distance * 0.5) < 0.05, "Partial stick does not give partial range")
	await _axis(JOY_AXIS_RIGHT_X, 0.0)
	_check((player._get_aim_target() - player.global_position).is_equal_approx(half), "Aim not retained when stick returns to centre")
	await _axis(JOY_AXIS_RIGHT_X, 1.0)
	await _axis(JOY_AXIS_RIGHT_Y, 1.0)
	_check(is_equal_approx((player._get_aim_target() - player.global_position).length(), player.dash.max_distance), "Diagonal stick exceeds max range")
	await _axis(JOY_AXIS_RIGHT_Y, 0.0)
	var directions := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	for i in directions.size():
		if i == 3:
			await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6)
			await _wait()
			_check(player.time.is_slowed() and not player.dash.is_enabled(), "R2 showed the aim preview before the sectors were full")
		var arrow := preload("res://entities/arrows/arrow.tscn").instantiate() as Arrow
		add_child(arrow)
		arrow.global_position = player.global_position + directions[i]
		_check(player.arrows.try_add_arrow(arrow), "Could not fill a test arrow sector")
	await _wait()
	_check(player.dash.is_enabled(), "Final arrow while slowed did not show the aim preview")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait()
	_check(_attacks(player) == 4 and ControllerManager._attack_available, "Full sectors did not prepare four attacks")
	var shots := [0]
	player.dash.activated.connect(func(_destination, _targets): shots[0] += 1)
	var origin := player.global_position
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	await _wait()
	_check(player.dash.is_enabled() and player.time.is_slowed(), "R2 did not slow time and show the aim preview")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _wait(0.25)
	_check(shots[0] == 0 and player.global_position.distance_to(origin) < 0.1, "Full R2 pull fired on its own")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait()
	_check(shots[0] == 1 and _attacks(player) == 3, "R1 did not fire and consume exactly one arrow")
	_check(player.global_position.distance_to(origin + full) < 0.1, "R1 shot did not follow the stick")
	_check(not player.dash.is_enabled() and not player.time.is_slowed(), "Dash did not end slow motion and aiming")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait()
	_check(shots[0] == 1, "R1 fired again without a fresh R2 pull")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait()
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait()
	_check(shots[0] == 1, "R1 fired without R2 held")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	await _wait()
	get_tree().paused = true
	await _wait()
	get_tree().paused = false
	await _wait()
	_check(not player.dash.is_enabled() and not player.time.is_slowed(), "Pause did not cancel aiming")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait()
	_check(shots[0] == 1, "Held R2 kept aiming through pause")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait()
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	await _wait()
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait()
	_check(shots[0] == 2 and _attacks(player) == 2, "Fresh R2 aim after pause failed")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait(0.15)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _wait()
	_check(shots[0] == 2, "Mouse fired before release")
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await _wait()
	_check(shots[0] == 3 and _attacks(player) == 1, "Mouse release did not consume an arrow")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	await _wait()
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait()
	_check(shots[0] == 4 and _attacks(player) == 0, "R2 aim and R1 did not consume the last arrow")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait()
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	await _wait()
	_check(player.time.is_slowed() and not player.dash.is_enabled(), "Empty R2 did not slow time without an aim preview")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait()
	_check(shots[0] == 4, "Empty attack fired")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _wait()
	_check(not player.time.is_slowed(), "R2 release did not resume time")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _wait()
	_check(not player.time.is_slowed(), "L2 still slows time")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var shoulder := InputEventJoypadButton.new()
	shoulder.device = 0
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await _wait()
	_check(not player.time.is_slowed(), "L1 still slows time")
	shoulder = shoulder.duplicate()
	shoulder.pressed = false
	Input.parse_input_event(shoulder)
	await _wait(0.25)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(8, 0)
	Input.parse_input_event(motion)
	await _wait()
	_check(player.input_mode.is_keyboard_mouse(), "Mouse input did not switch modes")
	player.queue_free()
	await _wait()
	Engine.time_scale = 1.0

func _test_menus() -> void:
	GameManager.main_menu_intro_played = true
	var main := preload("res://menus/main_menu/main_menu.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	_check(get_viewport().gui_get_focus_owner() == main.get_node("PlayFocus"), "Main menu has no initial selection")
	await _capture("main-controller")
	await _button(JOY_BUTTON_DPAD_DOWN)
	_check(get_viewport().gui_get_focus_owner() == main.get_node("LevelsFocus"), "D-pad did not select Levels")
	await _button(JOY_BUTTON_A)
	await _wait(0.9)
	_check(main.get_node("LevelSelect").visible, "Controller confirm did not open Levels")
	_check(get_viewport().gui_get_focus_owner() == main.get_node("LevelSelect/Center/Layout/Tutorial"), "Level select has no focus")
	await _button(JOY_BUTTON_B)
	_check(not main.get_node("LevelSelect").visible, "Circle/B did not close Levels")
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	var settings := main.get_node("Settings")
	_check(settings.is_open(), "Controller did not open Settings")
	var slider := settings.get_node("%MasterSlider") as AppleSlider
	_check(slider.has_focus(), "First settings field has no focus")
	var original := slider.value
	slider.set_value_no_signal(0.5)
	await _button(JOY_BUTTON_DPAD_LEFT)
	await _wait(0.15)
	_check(slider.value < 0.5, "D-pad did not adjust slider")
	_check(slider.scale.x > 1.125, "Focused slider does not zoom")
	var master_label := settings.get_node("%Panel/MasterLabel") as Control
	_check(is_equal_approx(master_label.scale.x, 1.1), "Focused slider label does not enlarge")
	settings.get_node("%ContrastSlider").grab_focus()
	await _wait(0.15)
	_check(master_label.scale.is_equal_approx(Vector2.ONE), "Previous slider label stays enlarged")
	_check(is_equal_approx(settings.get_node("%Panel/ContrastLabel").scale.x, 1.1), "Contrast label does not enlarge")
	await _capture("contrast-focused")
	slider.grab_focus()
	await _wait(0.15)
	var reduced_value := slider.value
	await _axis(JOY_AXIS_LEFT_X, 1.0)
	await _axis(JOY_AXIS_LEFT_X, 0.0)
	_check(slider.value > reduced_value, "Right stick navigation reduced a slider")
	await _axis(JOY_AXIS_LEFT_X, -1.0)
	await _wait(0.5)
	await _axis(JOY_AXIS_LEFT_X, 0.0)
	_check(slider.value < reduced_value, "Held slider navigation did not repeat")
	await _capture("settings-focused")
	SettingsManager.set_master_volume(original)
	settings.get_node("%CreditsButton").grab_focus()
	await _button(JOY_BUTTON_A)
	_check(settings.get_node("%CreditsBack").has_focus(), "Credits page has no initial focus")
	await _button(JOY_BUTTON_DPAD_DOWN)
	_check(settings.get_node("%LicensesButton").has_focus(), "Credits focus escaped modal")
	await _button(JOY_BUTTON_B)
	_check(settings.get_node("%CreditsButton").has_focus(), "Credits did not restore focus")
	settings._controller_button.grab_focus()
	await _button(JOY_BUTTON_A)
	_check(settings._vibration.has_focus(), "Controller page has no focus")
	_check("attack while aiming" in settings._controller_guide.text, "Controller guide omits the attack button")
	settings._resistance.grab_focus()
	var resistance: float = SettingsManager.trigger_resistance
	await _button(JOY_BUTTON_DPAD_LEFT)
	_check(SettingsManager.trigger_resistance < resistance, "R2 resistance setting cannot be adjusted by controller")
	SettingsManager.set_trigger_resistance(resistance)
	await _capture("controller-settings")
	await _button(JOY_BUTTON_B)
	_check(settings._controller_button.has_focus(), "Controller page did not restore focus")
	await _button(JOY_BUTTON_B)
	_check(not settings.is_open() and main.get_node("Gear").has_focus(), "Settings did not return focus to gear")
	main.queue_free()
	await _wait()
	var pause := preload("res://menus/pause/pause.tscn").instantiate()
	add_child(pause)
	await _button(JOY_BUTTON_START)
	_check(pause.is_open() and get_tree().paused, "Options/Start did not pause")
	_check(pause.get_node("%Continue").has_focus(), "Pause has no selected button")
	pause.get_node("%SettingsButton").grab_focus()
	await _button(JOY_BUTTON_A)
	await _button(JOY_BUTTON_B)
	_check(pause.is_open() and not pause.get_node("Settings").is_open(), "Closing pause settings also unpaused")
	_check(pause.get_node("%SettingsButton").has_focus(), "Pause settings did not restore focus")
	await _button(JOY_BUTTON_B)
	_check(not pause.is_open() and not get_tree().paused, "Circle/B did not resume")
	pause.queue_free()
	await _wait()
