class_name ThemeM1
extends RefCounted

## Shared visual language for the M1 rework: dark translucent panels, yellow
## accent, bold system font with Cyrillic. Deliberately asset-free so the first
## slice does not depend on a downloaded font.

const BG := Color("0e1116")
const PANEL := Color(0.07, 0.08, 0.10, 0.90)
const PANEL_SOFT := Color(0.09, 0.10, 0.12, 0.78)
const ACCENT := Color("f2c230")
const DANGER := Color("e2453c")
const SUCCESS := Color("3f9b4f")
const TEXT := Color("f5f5f5")
const MUTED := Color(0.72, 0.76, 0.82, 0.85)

static var _font_bold: Font = null
static var _font_regular: Font = null

static func font_bold() -> Font:
	if _font_bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "SF Pro Display", "Roboto", "Arial"])
		f.font_weight = 700
		_font_bold = f
	return _font_bold

static func font_regular() -> Font:
	if _font_regular == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "SF Pro Display", "Roboto", "Arial"])
		f.font_weight = 400
		_font_regular = f
	return _font_regular

static func panel_style(alpha: float = 0.90, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, alpha)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	return style

static func button_style(accent: bool = false, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.92) if accent else Color(0.10, 0.11, 0.14, 0.92)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(18)
	style.border_color = Color(1, 1, 1, 0.10)
	style.set_border_width_all(1)
	return style

static func apply_button(button: Button, accent: bool = false, font_size: int = 30) -> void:
	button.add_theme_font_override("font", font_bold())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("101216") if accent else TEXT)
	button.add_theme_color_override("font_hover_color", Color("101216") if accent else ACCENT)
	button.add_theme_color_override("font_pressed_color", Color("101216") if accent else ACCENT)
	button.add_theme_color_override("font_focus_color", Color("101216") if accent else TEXT)
	button.add_theme_stylebox_override("normal", button_style(accent))
	button.add_theme_stylebox_override("hover", button_style(accent))
	button.add_theme_stylebox_override("pressed", button_style(accent))
	var focus := button_style(accent)
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.custom_minimum_size.y = 64

static func apply_label(label: Label, size: int, color: Color = TEXT, bold: bool = true) -> void:
	label.add_theme_font_override("font", font_bold() if bold else font_regular())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 2)
