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
var _close_tween: Tween

func _ready() -> void:
	hide()
	_close_button.pressed.connect(close)
	_close_button.pivot_offset = _close_button.size * 0.5
	_close_button.mouse_entered.connect(_grow_close.bind(1.15))
	_close_button.mouse_exited.connect(_grow_close.bind(1.0))
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
	_sync()
	_link_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _credits_page.visible or _website_popup.visible:
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

func _preview_sfx() -> void:
	SoundManager.play("Q1_fill")

func _show_credits() -> void:
	_set_licenses(false)
	_show_page(_credits_page, _credits_button, _credits_back)

func _show_page(page: Control, opener: Control, first: Control) -> void:
	_page_opener = opener
	_page_first = first
	get_viewport().gui_release_focus()
	page.show()

func _hide_pages() -> void:
	_credits_page.hide()
	_website_popup.hide()
	_page_first = null
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

func _grow_close(factor: float) -> void:
	if _close_tween:
		_close_tween.kill()
	_close_tween = create_tween().set_ignore_time_scale()
	_close_tween.tween_property(_close_button, "scale", Vector2.ONE * factor, 0.08)

func _set_logo_mark(pressed: bool) -> void:
	_logo_mark.texture = LOGO_MARK_PRESSED if pressed else LOGO_MARK

func _link_focus() -> void:
	var column: Array[Control] = [_master, _sfx, _music, _sensitivity, _contrast, _bw, _fullscreen, _credits_button, _logo_button, _reset_button]
	for i in column.size():
		column[i].focus_neighbor_top = column[i].get_path_to(column[(i - 1 + column.size()) % column.size()])
		column[i].focus_neighbor_bottom = column[i].get_path_to(column[(i + 1) % column.size()])
	var rows: Array = [[_bw, _fullscreen], [_credits_button, _logo_button, _reset_button]]
	for row in rows:
		for i in row.size():
			var c: Control = row[i]
			c.focus_neighbor_left = c.get_path_to(row[(i - 1 + row.size()) % row.size()])
			c.focus_neighbor_right = c.get_path_to(row[(i + 1) % row.size()])
