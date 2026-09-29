class_name IconTile
extends PanelContainer
## Rounded tile showing an artwork texture. If the file is missing it shows
## the item's initials instead of failing, and logs which file is expected.

var _texture_rect: TextureRect

func _init(texture_path: String, fallback_name: String, side: float, tint: Color = Color(1, 1, 1, 0.05)) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UIStyle.box(tint, 26, 6))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		_texture_rect = TextureRect.new()
		_texture_rect.texture = load(texture_path)
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_texture_rect)
	else:
		if texture_path != "":
			push_warning("Artwork missing: %s (showing initials)" % texture_path)
		var initials := ""
		for word in fallback_name.split(" ", false):
			initials += word.substr(0, 1)
		var l := UIStyle.label(initials.substr(0, 2).to_upper(), int(side * 0.32), UIStyle.TEXT_DIM, 800)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)

func set_art_modulate(color: Color) -> void:
	if _texture_rect:
		_texture_rect.modulate = color
