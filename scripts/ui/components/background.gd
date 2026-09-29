class_name GameBackground
extends Control
## Charcoal vertical gradient with one soft, slowly drifting glow tinted by
## the equipped switch. Drawn once per frame with a handful of primitives.

var glow_center := Vector2(0.5, 0.4) # normalised
var accent := Color("#d9cfb5")

var _gradient_tex: GradientTexture2D
var _glow_tex: GradientTexture2D
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, UIStyle.BG_TOP)
	g.set_color(1, UIStyle.BG_BOTTOM)
	_gradient_tex = GradientTexture2D.new()
	_gradient_tex.gradient = g
	_gradient_tex.fill_from = Vector2(0, 0)
	_gradient_tex.fill_to = Vector2(0, 1)
	_gradient_tex.width = 4
	_gradient_tex.height = 256

	var r := Gradient.new()
	r.set_color(0, Color(1, 1, 1, 1))
	r.set_color(1, Color(1, 1, 1, 0))
	r.add_point(0.45, Color(1, 1, 1, 0.35))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = r
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256

func set_accent(color: Color) -> void:
	accent = color

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(_gradient_tex, Rect2(Vector2.ZERO, size), false)
	var drift := Vector2(sin(_time * 0.21), cos(_time * 0.17)) * size.x * 0.04
	var radius := size.x * 0.75
	var c := glow_center * size + drift
	draw_texture_rect(_glow_tex, Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(accent, 0.075))
