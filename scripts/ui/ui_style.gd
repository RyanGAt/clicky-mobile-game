class_name UIStyle
extends RefCounted
## Shared palette, fonts and theme. Everything is authored for the 1080px-wide
## base viewport and scales with the canvas_items stretch mode.

const BG_TOP := Color("#1b1c20")
const BG_BOTTOM := Color("#0e0f11")
const SURFACE := Color("#1d1f23")
const SURFACE_2 := Color("#26292e")
const SURFACE_3 := Color("#30333a")
const BORDER := Color("#34373e")
const TEXT := Color("#eeebe5")
const TEXT_DIM := Color("#a4a5aa")
const TEXT_FAINT := Color("#6d7077")
const GOLD := Color("#ffd35a")
const POSITIVE := Color("#9ed6a0")

const FONT_PATH := "res://assets/fonts/Manrope-Variable.ttf"

static var _fonts: Dictionary = {}

static func font(weight: int = 600) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var result: Font
	if ResourceLoader.exists(FONT_PATH):
		var fv := FontVariation.new()
		fv.base_font = load(FONT_PATH)
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		fv.variation_opentype = {tag: weight}
		result = fv
	else:
		push_warning("UI font missing at %s; using engine default." % FONT_PATH)
		result = ThemeDB.fallback_font
	_fonts[weight] = result
	return result

static func box(color: Color, radius: int = 28, pad: int = 0, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb

static func label(text: String, size: int, color: Color = TEXT, weight: int = 600) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font(weight))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Solid pill button in the accent colour (or muted when `primary` is false).
static func style_button(button: Button, fill: Color, text_color: Color, radius: int = 24) -> void:
	button.add_theme_stylebox_override("normal", box(fill, radius, 12))
	button.add_theme_stylebox_override("hover", box(fill.lightened(0.06), radius, 12))
	button.add_theme_stylebox_override("pressed", box(fill.darkened(0.15), radius, 12))
	button.add_theme_stylebox_override("disabled", box(fill, radius, 12))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(key, text_color)

## Dark text on light accents, light text on dark ones.
static func on_color(fill: Color) -> Color:
	return Color("#15161a") if fill.get_luminance() > 0.5 else TEXT

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 32
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", box(SURFACE_2, 24, 16))
	t.set_stylebox("hover", "Button", box(SURFACE_3, 24, 16))
	t.set_stylebox("pressed", "Button", box(SURFACE.darkened(0.1), 24, 16))
	t.set_stylebox("disabled", "Button", box(SURFACE_2, 24, 16))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_font("font", "Button", font(700))

	t.set_stylebox("panel", "PanelContainer", box(SURFACE, 32, 0))
	t.set_stylebox("panel", "Panel", box(SURFACE, 32, 0))

	# Thin, unobtrusive scrollbar; touch scrolling is the primary input.
	var grabber := box(Color(1, 1, 1, 0.14), 4)
	grabber.set_content_margin_all(3)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)

	var slider_track := box(SURFACE_3, 8)
	slider_track.content_margin_top = 8
	slider_track.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", slider_track)
	t.set_stylebox("grabber_area", "HSlider", box(TEXT_DIM, 8, 8))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(TEXT, 8, 8))
	return t
