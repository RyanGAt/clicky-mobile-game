class_name SegmentedControl
extends PanelContainer
## Small pill selector (used for the x1 / x10 / Max purchase mode).

signal selected(value: int)

var _buttons: Array[Button] = []
var _values: Array = []
var _current := 0
var accent := UIStyle.TEXT

func setup(labels: Array, values: Array, initial: int) -> void:
	_values = values
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE_2, 26, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.custom_minimum_size = Vector2(118, 64)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(func(): select(values[i]))
		row.add_child(b)
		_buttons.append(b)
	select(initial, false)

func select(value: int, notify: bool = true) -> void:
	_current = maxi(_values.find(value), 0)
	for i in _buttons.size():
		var active := i == _current
		UIStyle.style_button(_buttons[i], UIStyle.SURFACE_3 if active else Color(0, 0, 0, 0), UIStyle.TEXT if active else UIStyle.TEXT_FAINT, 22)
	if notify:
		selected.emit(_values[_current])
