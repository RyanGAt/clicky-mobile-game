class_name UnlockPopup
extends ModalCard
## Short "new switch" moment: artwork pops in, bonuses shown, one-tap Equip.

var switch_id: String

func _init(id: String) -> void:
	switch_id = id

func build() -> void:
	var data: Dictionary = GameManager.switches.get(switch_id, {})
	var accent := Color(data.get("color", "#ffffff"))
	add_centered_label("NEW SWITCH UNLOCKED", 26, accent, 800)
	var art := IconTile.for_switch(switch_id, 420, Color(accent, 0.1))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(art)
	art.resized.connect(func(): art.pivot_offset = art.size * 0.5)
	art.scale = Vector2(0.6, 0.6)
	art.rotation = -0.12
	# One accent flash behind the art as it lands.
	var bg := art.get_theme_stylebox("panel") as StyleBoxFlat
	if bg:
		bg = bg.duplicate()
		art.add_theme_stylebox_override("panel", bg)
		var target := bg.bg_color
		bg.bg_color = Color(accent, 0.5)
		create_tween().tween_property(bg, "bg_color", target, 0.9).set_delay(0.1)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(art, "scale", Vector2.ONE, 0.7).set_delay(0.08)
	tw.tween_property(art, "rotation", 0.0, 0.7).set_delay(0.08)

	add_centered_label(data.get("name", switch_id), 56, UIStyle.TEXT, 800)
	add_centered_label("Tap x%s   ·   Auto x%s%s" % [
		GameManager.format_number(float(data.get("click_power_multiplier", 1.0))),
		GameManager.format_number(float(data.get("cps_multiplier", 1.0))),
		("   ·   Crit +%sx" % GameManager.format_number(float(data["crit_multiplier_bonus"]))) if data.has("crit_multiplier_bonus") else ""], 34, UIStyle.POSITIVE, 800)
	if data.has("style"):
		var style_row := CenterContainer.new()
		style_row.add_child(UIStyle.tag("%s switch" % data["style"], accent))
		content.add_child(style_row)
	add_centered_label(data.get("description", ""), 28, UIStyle.TEXT_DIM, 500)
	if data.has("flavor"):
		add_centered_label("\u201c%s\u201d" % data["flavor"], 24, UIStyle.TEXT_FAINT, 500)
	add_button("Equip now", accent, func():
		GameManager.equip_switch(switch_id)
		close())
	var later := add_button("Later", UIStyle.SURFACE_2, close)
	later.custom_minimum_size.y = 84
