extends RefCounted
class_name UiStyle

const BG := Color(0.09, 0.1, 0.13)
const PANEL := Color(0.12, 0.13, 0.16)
const PANEL_HOVER := Color(0.16, 0.17, 0.21)
const PANEL_PRESSED := Color(0.2, 0.18, 0.1)
const TEXT := Color(0.88, 0.89, 0.92)
const MUTED := Color(0.5, 0.55, 0.65)
const ACCENT := Color(0.95, 0.85, 0.3)

static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = border
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.5))
	b.add_theme_stylebox_override("normal", _box(PANEL, MUTED))
	b.add_theme_stylebox_override("hover", _box(PANEL_HOVER, ACCENT))
	b.add_theme_stylebox_override("pressed", _box(PANEL_PRESSED, ACCENT))
	b.add_theme_stylebox_override("focus", _box(PANEL_HOVER, ACCENT))
	b.add_theme_stylebox_override("disabled", _box(Color(0.1, 0.1, 0.12), Color(0.28, 0.3, 0.35)))
	return b

static func title(text: String, size := 56) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	return l

static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
