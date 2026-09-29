class_name SafeArea
extends MarginContainer
## Pads its content by the device safe area (notches, rounded corners, home
## indicator) plus a base gutter. Desktop builds only get the gutter.

const MAX_CONTENT_WIDTH := 1320.0

@export var gutter := 36
@export var top_extra := 12
@export var bottom_extra := 0

func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()

func _apply() -> void:
	var insets := Rect2(0, 0, 0, 0) # left, top, right, bottom in viewport units
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0:
			var to_view := get_viewport_rect().size / screen
			insets = Rect2(
				safe.position.x * to_view.x,
				safe.position.y * to_view.y,
				(screen.x - safe.end.x) * to_view.x,
				(screen.y - safe.end.y) * to_view.y)
	# On tablets keep the column phone-width instead of stretching cards.
	var extra := maxf(0.0, (get_viewport_rect().size.x - MAX_CONTENT_WIDTH) * 0.5)
	add_theme_constant_override("margin_left", gutter + int(insets.position.x + extra))
	add_theme_constant_override("margin_right", gutter + int(insets.size.x + extra))
	add_theme_constant_override("margin_top", gutter + top_extra + int(insets.position.y))
	add_theme_constant_override("margin_bottom", bottom_extra + int(insets.size.y))
