extends CanvasLayer

signal opened
signal closed

@export var website_url := ""

const CREDITS := """[center]ARROWHEAD

Game by
Alex Francia
Charlie Lette
Eric Lee
Jeremy Wangsa
Rina Amami

Made with Godot Engine

Icons: @icons by Voxy
Fonts: Puffy, JetBrains Mono

Thanks for playing![/center]"""

const LOGO_MARK := preload("res://shared/art/settings/logo_mark.png")
const LOGO_MARK_PRESSED := preload("res://shared/art/settings/logo_mark_dark.png")
const NAV_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_focus_next", &"ui_focus_prev"]

@onready var _close_button: TextureButton = %CloseButton
@onready var _master: AppleSlider = %MasterSlider
@onready var _sfx: AppleSlider = %SfxSlider
@onready var _music: AppleSlider = %MusicSlider
@onready var _sensitivity: AppleSlider = %SensitivitySlider
@onready var _contrast: AppleSlider = %ContrastSlider
@onready var _bw: TextureButton = %BwToggle
@onready var _fullscreen: TextureButton = %FullscreenToggle
@onready var _credits_button: TextureButton = %CreditsButton
@onready var _logo_button: TextureButton = %LogoButton
@onready var _logo_mark: TextureRect = %LogoMark
@onready var _reset_button: TextureButton = %ResetButton
@onready var _credits_page: Control = %CreditsPage
@onready var _credits_body: RichTextLabel = %CreditsBody
@onready var _licenses_button: Button = %LicensesButton
@onready var _credits_back: Button = %CreditsBack
@onready var _website_popup: Control = %WebsitePopup
@onready var _website_no: TextureButton = %WebsiteNo
@onready var _website_yes: TextureButton = %WebsiteYes

var _showing_licenses := false
var _page_opener: Control
var _page_first: Control
var _main_controls: Array[Control] = []
var _controller_page: Control
var _controller_button: Button
var _vibration: HSlider
var _controller_guide: Label
var _resistance: HSlider
var _trigger_status: Label
var _trigger_test: Button

func _ready() -> void:
	hide()
	_close_button.pressed.connect(close)
	FocusFeedback.attach(_close_button, 1.15)
	_master.value_changed.connect(SettingsManager.set_master_volume)
	_sfx.value_changed.connect(SettingsManager.set_sfx_volume)
	_music.value_changed.connect(SettingsManager.set_music_volume)
	_sensitivity.value_changed.connect(SettingsManager.set_mouse_sensitivity)
	_contrast.value_changed.connect(SettingsManager.set_contrast)
	_master.drag_ended.connect(_preview_sfx)
	_sfx.drag_ended.connect(_preview_sfx)
	_bw.toggled.connect(SettingsManager.set_grayscale)
	_fullscreen.toggled.connect(SettingsManager.set_fullscreen)
	_reset_button.pressed.connect(SettingsManager.reset_to_defaults)
	_credits_button.pressed.connect(_show_credits)
	_credits_back.pressed.connect(_hide_pages)
	_licenses_button.pressed.connect(_toggle_licenses)
	_logo_button.button_down.connect(_set_logo_mark.bind(true))
	_logo_button.button_up.connect(_set_logo_mark.bind(false))
	_logo_button.pressed.connect(_show_page.bind(_website_popup, _logo_button, _website_no))
	_website_no.pressed.connect(_hide_pages)
	_website_yes.pressed.connect(_on_website_yes)
	SettingsManager.changed.connect(_sync)
	_build_controller_page()
	_sync()
	_link_focus()
	for control in _main_controls:
		var companions: Array[Control] = []
		if control is AppleSlider:
			var label := %Panel.get_node_or_null(String(control.name).replace("Slider", "Label")) as Control
			if label:
				companions.append(label)
		FocusFeedback.attach(control, 1.10 if control is AppleSlider else 1.06, companions)
	ControllerManager.changed.connect(_sync_controller_guide)
	ControllerManager.adaptive.status_changed.connect(_sync_trigger_status)
	_sync_controller_guide()
	_sync_trigger_status()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _page_first:
			_hide_pages()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif _page_first and get_viewport().gui_get_focus_owner() == null:
		for action in NAV_ACTIONS:
			if event.is_action_pressed(action):
				_page_first.grab_focus()
				get_viewport().set_input_as_handled()
				return

func open() -> void:
	show()
	opened.emit()
	_master.grab_focus()

func _process(delta: float) -> void:
	if visible and _credits_page.visible:
		_credits_body.get_v_scroll_bar().value += Input.get_axis("aim_up", "aim_down") * 550.0 * delta / Engine.time_scale

func close() -> void:
	_hide_pages()
	hide()
	closed.emit()

func is_open() -> bool:
	return visible

func _sync() -> void:
	_master.set_value_no_signal(SettingsManager.master_volume)
	_sfx.set_value_no_signal(SettingsManager.sfx_volume)
	_music.set_value_no_signal(SettingsManager.music_volume)
	_sensitivity.set_value_no_signal(SettingsManager.mouse_sensitivity)
	_contrast.set_value_no_signal(SettingsManager.contrast)
	_bw.set_pressed_no_signal(SettingsManager.grayscale)
	_fullscreen.set_pressed_no_signal(SettingsManager.fullscreen)
	if _vibration:
		_vibration.set_value_no_signal(SettingsManager.controller_vibration)
	if _resistance:
		_resistance.set_value_no_signal(SettingsManager.trigger_resistance)

func _preview_sfx() -> void:
	SoundManager.play("Q1_fill")

func _show_credits() -> void:
	_set_licenses(false)
	_show_page(_credits_page, _credits_button, _credits_back)

func _show_page(page: Control, opener: Control, first: Control) -> void:
	_page_opener = opener
	_page_first = first
	get_viewport().gui_release_focus()
	for control in _main_controls:
		control.focus_mode = Control.FOCUS_NONE
	page.show()
	first.grab_focus()

func _hide_pages() -> void:
	ControllerManager.stop_feedback()
	_credits_page.hide()
	_website_popup.hide()
	_controller_page.hide()
	_page_first = null
	for control in _main_controls:
		control.focus_mode = Control.FOCUS_ALL
	if _page_opener:
		_page_opener.grab_focus()
		_page_opener = null

func _toggle_licenses() -> void:
	_set_licenses(not _showing_licenses)

func _set_licenses(on: bool) -> void:
	_showing_licenses = on
	_credits_body.bbcode_enabled = not on
	_credits_body.text = Engine.get_license_text() if on else CREDITS
	_credits_body.scroll_to_line(0)
	_licenses_button.text = "Credits" if on else "Licenses"

func _on_website_yes() -> void:
	if website_url != "":
		OS.shell_open(website_url)
	_hide_pages()

func _set_logo_mark(pressed: bool) -> void:
	_logo_mark.texture = LOGO_MARK_PRESSED if pressed else LOGO_MARK

func _link_focus() -> void:
	var column: Array[Control] = [_master, _sfx, _music, _sensitivity, _controller_button, _contrast, _bw, _fullscreen, _credits_button, _logo_button, _reset_button, _close_button]
	_main_controls = column
	for i in column.size():
		column[i].focus_mode = Control.FOCUS_ALL
		column[i].focus_neighbor_top = column[i].get_path_to(column[(i - 1 + column.size()) % column.size()])
		column[i].focus_neighbor_bottom = column[i].get_path_to(column[(i + 1) % column.size()])
		column[i].focus_previous = column[i].focus_neighbor_top
		column[i].focus_next = column[i].focus_neighbor_bottom
	var rows: Array = [[_bw, _fullscreen], [_credits_button, _logo_button, _reset_button]]
	for row in rows:
		for i in row.size():
			var c: Control = row[i]
			c.focus_neighbor_left = c.get_path_to(row[(i - 1 + row.size()) % row.size()])
			c.focus_neighbor_right = c.get_path_to(row[(i + 1) % row.size()])
	for row in [[_licenses_button, _credits_back], [_website_no, _website_yes]]:
		for i in row.size():
			var c: Control = row[i]
			var other: NodePath = c.get_path_to(row[1 - i])
			c.focus_neighbor_top = other
			c.focus_neighbor_bottom = other
			c.focus_next = other
			c.focus_previous = other

func _build_controller_page() -> void:
	_controller_button = Button.new()
	_controller_button.name = "ControllerButton"
	_controller_button.text = "Controller"
	_controller_button.position = Vector2(835, 260)
	_controller_button.size = Vector2(275, 52)
	_controller_button.add_theme_font_override("font", preload("res://shared/fonts/Puffy-gxW55.otf"))
	_controller_button.add_theme_font_size_override("font_size", 28)
	_style_controller_button(_controller_button)
	%Panel.add_child(_controller_button)
	%Panel.move_child(_controller_button, _credits_page.get_index())
	_controller_page = Control.new()
	_controller_page.name = "ControllerPage"
	%Panel.add_child(_controller_page)
	_controller_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = preload("res://shared/art/settings/background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_controller_page.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.position = Vector2(275, 200)
	column.size = Vector2(835, 690)
	column.add_theme_constant_override("separation", 16)
	column.theme = Theme.new()
	column.theme.default_font = preload("res://shared/fonts/Puffy-gxW55.otf")
	column.theme.default_font_size = 28
	column.theme.set_color("font_color", "Label", Color(0.92, 0.94, 0.67))
	_controller_page.add_child(column)
	var title := Label.new()
	title.text = "Controller"
	title.add_theme_font_size_override("font_size", 48)
	column.add_child(title)
	_controller_guide = Label.new()
	_controller_guide.add_theme_font_size_override("font_size", 24)
	column.add_child(_controller_guide)
	var feedback_row := HBoxContainer.new()
	feedback_row.add_theme_constant_override("separation", 36)
	column.add_child(feedback_row)
	var vibration_column := VBoxContainer.new()
	vibration_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vibration_column.add_theme_constant_override("separation", 12)
	feedback_row.add_child(vibration_column)
	var trigger_column := VBoxContainer.new()
	trigger_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trigger_column.add_theme_constant_override("separation", 12)
	feedback_row.add_child(trigger_column)
	var label := Label.new()
	label.text = "Vibration (0 = off)"
	vibration_column.add_child(label)
	_vibration = HSlider.new()
	_vibration.min_value = 0.0
	_vibration.max_value = 1.0
	_vibration.step = 0.1
	_vibration.custom_minimum_size.y = 44
	_vibration.value_changed.connect(SettingsManager.set_controller_vibration)
	vibration_column.add_child(_vibration)
	var test := Button.new()
	test.text = "Test vibration"
	test.pressed.connect(func(): ControllerManager.pulse(0.5, 0.7, 0.25, 0.5, true))
	_style_controller_button(test)
	vibration_column.add_child(test)
	var trigger_label := Label.new()
	trigger_label.text = "Trigger strength (0 = off)"
	trigger_column.add_child(trigger_label)
	_resistance = HSlider.new()
	_resistance.max_value = 1.0
	_resistance.step = 0.05
	_resistance.custom_minimum_size.y = 44
	_resistance.value_changed.connect(SettingsManager.set_trigger_resistance)
	trigger_column.add_child(_resistance)
	_trigger_test = Button.new()
	_trigger_test.text = "Test R2 for 3 seconds"
	_trigger_test.pressed.connect(ControllerManager.test_trigger)
	_style_controller_button(_trigger_test)
	trigger_column.add_child(_trigger_test)
	_trigger_status = Label.new()
	_trigger_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trigger_status.add_theme_font_size_override("font_size", 22)
	_trigger_status.custom_minimum_size.y = 56
	column.add_child(_trigger_status)
	var controls: Array[Control] = [_vibration, test, _resistance, _trigger_test]
	if OS.has_feature("web"):
		var connect_button := Button.new()
		connect_button.text = "Connect DualSense"
		connect_button.pressed.connect(ControllerManager.adaptive.connect_device)
		_style_controller_button(connect_button)
		column.add_child(connect_button)
		controls.append(connect_button)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_hide_pages)
	_style_controller_button(back)
	column.add_child(back)
	controls.append(back)
	for i in controls.size():
		var c := controls[i]
		c.focus_neighbor_top = c.get_path_to(controls[posmod(i - 1, controls.size())])
		c.focus_neighbor_bottom = c.get_path_to(controls[(i + 1) % controls.size()])
		c.focus_previous = c.focus_neighbor_top
		c.focus_next = c.focus_neighbor_bottom
		FocusFeedback.attach(c, 1.05)
	for i in 2:
		var c: Control = [test, _trigger_test][i]
		c.focus_neighbor_left = c.get_path_to([_trigger_test, test][i])
		c.focus_neighbor_right = c.focus_neighbor_left
	_controller_button.pressed.connect(_show_page.bind(_controller_page, _controller_button, _vibration))
	_controller_page.hide()

func _style_controller_button(button: Button) -> void:
	button.custom_minimum_size.y = 52
	for style in [&"normal", &"hover", &"pressed", &"focus"]:
		button.add_theme_stylebox_override(style, _credits_back.get_theme_stylebox(style))
	for color in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(color, Color(0.92, 0.94, 0.67))

func _sync_controller_guide() -> void:
	var fire_buttons := ControllerManager.button_label(&"fire").split(" / ")
	_controller_guide.text = "Left stick: move\nRight stick: aim / outer edge = full range\n%s: pull to 95%% to attack, release to reset\n%s: hold to aim, release to attack\n%s: slow motion   /   %s: pause\n%s: select   /   %s: back\n%s: restart room" % [fire_buttons[0], fire_buttons[1], ControllerManager.button_label(&"slow"), ControllerManager.button_label(&"pause"), ControllerManager.button_label(&"ui_accept"), ControllerManager.button_label(&"ui_cancel"), ControllerManager.button_label(&"restart")]

func _sync_trigger_status() -> void:
	_trigger_status.text = ControllerManager.adaptive.status
	_trigger_test.disabled = not ControllerManager.adaptive.available
