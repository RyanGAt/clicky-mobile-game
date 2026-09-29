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
	var art := IconTile.new(data.get("asset_path", ""), data.get("name", switch_id), 420, Color(accent, 0.1))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(art)
	art.resized.connect(func(): art.pivot_offset = art.size * 0.5)
	art.scale = Vector2(0.6, 0.6)
	art.rotation = -0.12
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(art, "scale", Vector2.ONE, 0.7).set_delay(0.08)
	tw.tween_property(art, "rotation", 0.0, 0.7).set_delay(0.08)

	add_centered_label(data.get("name", switch_id), 56, UIStyle.TEXT, 800)
	add_centered_label("Tap x%s   ·   Auto x%s" % [
		GameManager.format_number(float(data.get("click_power_multiplier", 1.0))),
		GameManager.format_number(float(data.get("cps_multiplier", 1.0)))], 34, UIStyle.POSITIVE, 800)
	add_centered_label(data.get("description", ""), 28, UIStyle.TEXT_DIM, 500)
	add_button("Equip now", accent, func():
		GameManager.equip_switch(switch_id)
		close())
	var later := add_button("Later", UIStyle.SURFACE_2, close)
	later.custom_minimum_size.y = 84
