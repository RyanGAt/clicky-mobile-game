class_name SwitchCard
extends PanelContainer
## A switch in the Switches tab: art, tier, playstyle, description, flavour,
## multipliers, mastery progress, and Equip / Equipped / unlock progress.

signal equip_requested(id: String)

var switch_id: String
var _art: IconTile
var _status_host: VBoxContainer
var _progress: ProgressBar
var _progress_label: Label
var _mastery_host: HBoxContainer
var _mastery_label: Label
var _last_state := ""
var _last_mastery := -1

func _init(id: String) -> void:
	switch_id = id

func _ready() -> void:
	var data: Dictionary = GameManager.switches.get(switch_id, {})
	var accent := Color(data.get("color", "#ffffff"))
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE_2, 30, 24))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	add_child(row)
	_art = IconTile.for_switch(switch_id, 210, Color(accent, 0.08))
	_art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_art)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	text.add_child(head)
	head.add_child(UIStyle.label(str(data.get("tier_label", "Tier %d" % int(data.get("tier", 1)))).to_upper(), 22, Color(accent, 0.9), 800))
	if data.has("style"):
		head.add_child(UIStyle.tag(str(data["style"]), UIStyle.TEXT_DIM))
	text.add_child(UIStyle.label(data.get("name", switch_id), 40, UIStyle.TEXT, 800))
	var desc := UIStyle.label(data.get("description", ""), 26, UIStyle.TEXT_DIM, 500)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	if data.has("flavor"):
		var flavor := UIStyle.label("“%s”" % data["flavor"], 23, UIStyle.TEXT_FAINT, 500)
		flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(flavor)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	text.add_child(chips)
	chips.add_child(_chip("Tap x%s" % _mult(data.get("click_power_multiplier", 1.0))))
	chips.add_child(_chip("Auto x%s" % _mult(data.get("cps_multiplier", 1.0))))
	if data.has("crit_multiplier_bonus"):
		chips.add_child(_chip("Crit +%sx" % _mult(data["crit_multiplier_bonus"])))

	_mastery_host = HBoxContainer.new()
	_mastery_host.add_theme_constant_override("separation", 12)
	text.add_child(_mastery_host)

	_status_host = VBoxContainer.new()
	_status_host.add_theme_constant_override("separation", 8)
	text.add_child(_status_host)
	resized.connect(func(): pivot_offset = size * 0.5)
	refresh()

func _mult(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f

func _chip(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := UIStyle.box(Color(1, 1, 1, 0.06), 18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UIStyle.label(text, 24, UIStyle.TEXT, 700))
	return p

func _refresh_mastery() -> void:
	var data: Dictionary = GameManager.switches.get(switch_id, {})
	var level: int = GameManager.get_mastery_level(switch_id)
	var thresholds: Array = GameManager.get_mastery_thresholds()
	if level != _last_mastery:
		_last_mastery = level
		for c in _mastery_host.get_children():
			c.queue_free()
		_mastery_host.add_child(UIStyle.label("MASTERY", 20, UIStyle.TEXT_FAINT, 800))
		var pips := UIStyle.mastery_pips(level, thresholds.size(), Color(data.get("color", "#ffffff")))
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_mastery_host.add_child(pips)
		_mastery_label = UIStyle.label("", 22, UIStyle.TEXT_DIM, 600)
		_mastery_host.add_child(_mastery_label)
	var presses := int(GameManager.presses_by_switch.get(switch_id, 0))
	var bonus := roundi((GameManager.get_mastery_multiplier(switch_id) - 1.0) * 100.0)
	if level >= thresholds.size():
		_mastery_label.text = "Mastered · +%d%%" % bonus
	else:
		_mastery_label.text = "%s / %s presses%s" % [GameManager.format_number(presses), GameManager.format_number(float(thresholds[level])), ("  · +%d%%" % bonus) if bonus > 0 else ""]

func refresh() -> void:
	var data: Dictionary = GameManager.switches.get(switch_id, {})
	var unlocked := GameManager.is_switch_unlocked(switch_id)
	var equipped := GameManager.equipped_switch == switch_id
	var state := "%s|%s" % [unlocked, equipped]
	var requirement := float(data.get("unlock_requirement_clicks", 0.0))
	_mastery_host.visible = unlocked
	if unlocked:
		_refresh_mastery()
	if state != _last_state:
		_last_state = state
		for c in _status_host.get_children():
			c.queue_free()
		_progress = null
		_art.set_locked(not unlocked)
		if equipped:
			_status_host.add_child(UIStyle.label("EQUIPPED", 26, UIStyle.POSITIVE, 800))
		elif unlocked:
			var b := Button.new()
			b.text = "Equip"
			b.custom_minimum_size = Vector2(0, 84)
			b.add_theme_font_size_override("font_size", 30)
			var accent := Color(data.get("color", "#ffffff"))
			UIStyle.style_button(b, accent, UIStyle.on_color(accent))
			b.pressed.connect(func(): equip_requested.emit(switch_id))
			_status_host.add_child(b)
		else:
			_progress = ProgressBar.new()
			_progress.show_percentage = false
			_progress.custom_minimum_size = Vector2(0, 14)
			_progress.add_theme_stylebox_override("background", UIStyle.box(UIStyle.SURFACE_3, 7))
			_progress.add_theme_stylebox_override("fill", UIStyle.box(Color(data.get("color", "#ffffff")), 7))
			_progress.max_value = maxf(requirement, 1.0)
			_status_host.add_child(_progress)
			_progress_label = UIStyle.label("", 24, UIStyle.TEXT_FAINT, 600)
			_status_host.add_child(_progress_label)
	if _progress:
		_progress.value = GameManager.lifetime_clicks
		_progress_label.text = "Unlocks at %s lifetime Clicks  (%s / %s)" % [
			GameManager.format_number(requirement),
			GameManager.format_number(minf(GameManager.lifetime_clicks, requirement)),
			GameManager.format_number(requirement)]

func flash() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale = Vector2(0.97, 0.97)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3)
