class_name GearButton
extends Button
## Flat round button with a vector gear, so no icon asset is needed.

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("normal", UIStyle.box(Color(1, 1, 1, 0.05), 60))
	add_theme_stylebox_override("hover", UIStyle.box(Color(1, 1, 1, 0.08), 60))
	add_theme_stylebox_override("pressed", UIStyle.box(Color(1, 1, 1, 0.12), 60))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.2
	var col := UIStyle.TEXT_DIM
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * r * 0.9, c + dir * r * 1.45, col, r * 0.5, true)
	draw_circle(c, r * 1.05, col)
	draw_circle(c, r * 0.45, UIStyle.BG_TOP)
