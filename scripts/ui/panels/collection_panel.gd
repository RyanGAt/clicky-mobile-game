class_name CollectionPanel
extends TabPanel
## Three sections with completion counts. Locked items stay visible as
## silhouettes so the player can see what is left to find.

var _switch_tiles: Dictionary = {} # id -> [IconTile, pips host, name label]
var _keycap_tiles: Array[KeycapTile] = []
var _achievement_rows: Dictionary = {}
var _counts: Dictionary = {}
var _last_signature := ""

func build() -> void:
	add_title("COLLECTION")
	_counts["switches"] = _section("Switches")
	var sgrid := _grid(3)
	for id in GameManager.switches.keys():
		var data: Dictionary = GameManager.switches[id]
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		var tile := IconTile.for_switch(id, 180, Color(Color(data.get("color", "#ffffff")), 0.07))
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(tile)
		var name_label := UIStyle.label(data.get("name", id), 22, UIStyle.TEXT, 700)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(name_label)
		var pips_host := CenterContainer.new()
		cell.add_child(pips_host)
		sgrid.add_child(cell)
		_switch_tiles[id] = [tile, pips_host, name_label]

	_counts["keycaps"] = _section("Keycaps")
	var kgrid := _grid(2)
	for id in GameManager.keycaps.keys():
		var tile := KeycapTile.new(id)
		tile.equip_requested.connect(func(kid): GameManager.equip_keycap(kid))
		kgrid.add_child(tile)
		_keycap_tiles.append(tile)
	var note := UIStyle.label("Keycaps are cosmetic. Your equipped keycap shows in the top-left badge.", 22, UIStyle.TEXT_FAINT, 500)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)

	_counts["achievements"] = _section("Achievements")
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

func _section(title: String) -> Label:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	list.add_child(spacer)
	var row := HBoxContainer.new()
	list.add_child(row)
	var l := UIStyle.label(title.to_upper(), 28, UIStyle.TEXT, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var count := UIStyle.label("", 26, UIStyle.TEXT_DIM, 700)
	row.add_child(count)
	return count

func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 16)
	list.add_child(g)
	return g

## Returns {"switches": [have, total], "keycaps": [...], "achievements": [...]}.
static func completion() -> Dictionary:
	return {
		"switches": [GameManager.unlocked_switches.size(), GameManager.switches.size()],
		"keycaps": [GameManager.unlocked_keycaps.size(), GameManager.keycaps.size()],
		"achievements": [AchievementManager.unlocked.size(), AchievementManager.achievements.size()],
	}

func refresh() -> void:
	for tile in _keycap_tiles:
		tile.refresh()
	var c := completion()
	var mastery_sig := ""
	for id in _switch_tiles.keys():
		mastery_sig += str(GameManager.get_mastery_level(id))
	var signature := "%s|%s" % [c, mastery_sig]
	if signature == _last_signature:
		return
	_last_signature = signature
	_counts["switches"].text = "%d / %d · %d mastered" % [c["switches"][0], c["switches"][1], GameManager.get_mastered_count()]
	_counts["keycaps"].text = "%d / %d" % c["keycaps"]
	_counts["achievements"].text = "%d / %d · +%d%% all income" % [c["achievements"][0], c["achievements"][1], roundi(c["achievements"][0] * float(GameManager.balance.get("achievement_bonus", 0.0)) * 100.0)]
	for id in _switch_tiles.keys():
		var unlocked := GameManager.is_switch_unlocked(id)
		var parts: Array = _switch_tiles[id]
		(parts[0] as IconTile).set_locked(not unlocked)
		(parts[2] as Label).text = GameManager.switches[id].get("name", id) if unlocked else "???"
		for child in (parts[1] as Control).get_children():
			child.queue_free()
		if unlocked:
			(parts[1] as Control).add_child(UIStyle.mastery_pips(GameManager.get_mastery_level(id), GameManager.get_mastery_thresholds().size(), Color(GameManager.switches[id].get("color", "#ffffff")), 14))
	for id in _achievement_rows.keys():
		var done := AchievementManager.is_unlocked(id)
		var row: PanelContainer = _achievement_rows[id][0]
		var title: Label = _achievement_rows[id][1]
		row.modulate = Color(1, 1, 1, 1.0 if done else 0.5)
		title.add_theme_color_override("font_color", UIStyle.POSITIVE if done else UIStyle.TEXT)
