extends Control

signal closed

@onready var switch_list: VBoxContainer = %SwitchList
@onready var achievement_list: VBoxContainer = %AchievementList
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_populate_switches()
	_populate_achievements()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _populate_switches() -> void:
	for id in GameManager.switches.keys():
		var data: Dictionary = GameManager.switches[id]
		var unlocked := GameManager.is_switch_unlocked(id)
		var equipped := id == GameManager.equipped_switch

		var row := PanelContainer.new()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 16)
		row.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		margin.add_child(hbox)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(text_box)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", 28)
		if unlocked:
			title.text = "%s%s" % [data.get("name", id), "  (Equipped)" if equipped else ""]
		else:
			title.text = "??? Locked"
		text_box.add_child(title)

		var subtitle := Label.new()
		subtitle.add_theme_font_size_override("font_size", 18)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
		if unlocked:
			subtitle.text = "%s\nTap x%.1f  |  Auto x%.1f" % [
				data.get("description", ""),
				data.get("click_power_multiplier", 1.0),
				data.get("cps_multiplier", 1.0),
			]
		else:
			subtitle.text = "Unlocks at %s lifetime Clicks" % GameManager.format_number(
				data.get("unlock_requirement_clicks", 0.0)
			)
		text_box.add_child(subtitle)

		if unlocked and not equipped:
			var equip_button := Button.new()
			equip_button.text = "Equip"
			equip_button.pressed.connect(func(): _on_equip_pressed(id))
			hbox.add_child(equip_button)

		switch_list.add_child(row)

func _populate_achievements() -> void:
	for id in AchievementManager.achievements.keys():
		var data: Dictionary = AchievementManager.achievements[id]
		var unlocked := AchievementManager.is_unlocked(id)

		var row := PanelContainer.new()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 12)
		row.add_child(margin)

		var text_box := VBoxContainer.new()
		margin.add_child(text_box)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", 24)
		title.modulate = Color(1, 1, 1) if unlocked else Color(0.5, 0.5, 0.5)
		title.text = data.get("name", id) if unlocked else "???"
		text_box.add_child(title)

		var subtitle := Label.new()
		subtitle.add_theme_font_size_override("font_size", 16)
		subtitle.modulate = Color(0.8, 0.8, 0.8) if unlocked else Color(0.45, 0.45, 0.45)
		subtitle.text = data.get("description", "")
		text_box.add_child(subtitle)

		achievement_list.add_child(row)

func _on_equip_pressed(id: String) -> void:
	GameManager.equip_switch(id)
	closed.emit()
	queue_free()
