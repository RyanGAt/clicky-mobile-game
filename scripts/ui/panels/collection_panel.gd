class_name CollectionPanel
extends TabPanel

var _tiles: Array[KeycapTile] = []
var _achievement_rows: Dictionary = {}
var _layering_note: Label

func build() -> void:
	add_title("COLLECTION")
	list.add_child(UIStyle.label("Keycaps", 30, UIStyle.TEXT, 800))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	list.add_child(grid)
	for id in GameManager.keycaps.keys():
		var tile := KeycapTile.new(id)
		tile.equip_requested.connect(func(kid): GameManager.equip_keycap(kid))
		grid.add_child(tile)
		_tiles.append(tile)
	_layering_note = UIStyle.label("Keycaps are cosmetic. Your equipped keycap is shown in the top-left badge.", 22, UIStyle.TEXT_FAINT, 500)
	_layering_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_layering_note)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	list.add_child(spacer)
	list.add_child(UIStyle.label("Achievements", 30, UIStyle.TEXT, 800))
	for id in AchievementManager.achievements.keys():
		var data: Dictionary = AchievementManager.achievements[id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE_2, 24, 20))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var title := UIStyle.label(data.get("name", id), 28, UIStyle.TEXT, 800)
		col.add_child(title)
		var desc := UIStyle.label(data.get("description", ""), 24, UIStyle.TEXT_DIM, 500)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)
		list.add_child(row)
		_achievement_rows[id] = [row, title]

func refresh() -> void:
	for tile in _tiles:
		tile.refresh()
	for id in _achievement_rows.keys():
		var done := AchievementManager.is_unlocked(id)
		var row: PanelContainer = _achievement_rows[id][0]
		var title: Label = _achievement_rows[id][1]
		row.modulate = Color(1, 1, 1, 1.0 if done else 0.5)
		title.add_theme_color_override("font_color", UIStyle.POSITIVE if done else UIStyle.TEXT)
