class_name KeycapBadge
extends Button
## Round top-bar badge showing the equipped keycap's artwork.

var _art: TextureRect

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		add_theme_stylebox_override(state, UIStyle.box(Color(1, 1, 1, 0.05 if state != "pressed" else 0.1), 60))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_left = 8
	_art.offset_top = 8
	_art.offset_right = -8
	_art.offset_bottom = -8
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

func show_keycap(id: String) -> void:
	var path: String = GameManager.keycaps.get(id, {}).get("asset_path", "")
	_art.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
	tooltip_text = GameManager.keycaps.get(id, {}).get("name", id)
	pivot_offset = size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale = Vector2(0.85, 0.85)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)
