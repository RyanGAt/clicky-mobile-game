class_name UpgradeCard
extends PanelContainer
## One upgrade: icon, name, level, description, current benefit and a buy
## button whose cost reflects the panel's purchase mode (x1 / x10 / Max).

signal purchased(id: String, amount: int)

var upgrade_id: String
var purchase_mode := 1

var _level: Label
var _benefit: Label
var _button: Button
var _cost: Label
var _amount: Label
var _last_state := ""
var _punch := 0.0

func _init(id: String) -> void:
	upgrade_id = id

func _ready() -> void:
	var data: Dictionary = GameManager.upgrades.get(upgrade_id, {})
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE_2, 30, 22))
	mouse_filter = Control.MOUSE_FILTER_PASS

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	row.add_child(IconTile.new(data.get("icon_path", ""), data.get("name", upgrade_id), 132))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title_row)
	title_row.add_child(UIStyle.label(data.get("name", upgrade_id), 36, UIStyle.TEXT, 800))
	_level = UIStyle.label("", 28, UIStyle.TEXT_FAINT, 700)
	title_row.add_child(_level)

	var desc := UIStyle.label(data.get("description", ""), 26, UIStyle.TEXT_DIM, 500)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	_benefit = UIStyle.label("", 26, UIStyle.POSITIVE, 700)
	_benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_benefit)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(210, 124)
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_buy_pressed)
	row.add_child(_button)
	var btn_box := VBoxContainer.new()
	btn_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 0)
	btn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(btn_box)
	_cost = UIStyle.label("", 34, UIStyle.TEXT, 800)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_box.add_child(_cost)
	_amount = UIStyle.label("", 22, UIStyle.TEXT_DIM, 700)
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_box.add_child(_amount)

	resized.connect(func(): pivot_offset = size * 0.5)
	refresh()

func set_purchase_mode(mode: int) -> void:
	purchase_mode = mode
	refresh()

func _describe_benefit() -> String:
	var b := GameManager.get_upgrade_benefit(upgrade_id)
	if b.is_empty():
		return ""
	var owned := int(GameManager.owned.get(upgrade_id, 0))
	var text := ""
	var n := GameManager.format_number
	match b["stat"]:
		"click_power_bonus":
			text = ("+%s per tap · next +%s" % [n.call(b["total"]), n.call(b["per_level"])]) if owned > 0 else "+%s per tap each" % n.call(b["per_level"])
		"cps_bonus":
			text = ("+%s per sec · next +%s" % [n.call(b["total"]), n.call(b["per_level"])]) if owned > 0 else "+%s per sec each" % n.call(b["per_level"])
		"crit_chance_bonus":
			text = "%d%% crit chance · crits x%s" % [roundi(GameManager.get_crit_chance() * 100.0), n.call(GameManager.get_crit_multiplier())]
	var data: Dictionary = GameManager.upgrades.get(upgrade_id, {})
	var every := int(data.get("milestone_every", 0))
	if every > 0:
		var next_milestone := (owned / every + 1) * every
		text += " · x%s at Lv %d" % [GameManager.format_number(float(data.get("milestone_multiplier", 2))), next_milestone]
	return text

func refresh() -> void:
	var owned := int(GameManager.owned.get(upgrade_id, 0))
	var maxed := GameManager.is_upgrade_maxed(upgrade_id)
	var amount := GameManager.get_purchase_amount(upgrade_id, purchase_mode)
	var display_amount := maxi(amount, 1)
	var affordable := amount > 0 and GameManager.can_afford(upgrade_id, amount)
	var cost := GameManager.get_upgrade_cost(upgrade_id, display_amount)

	var state := "%d|%s|%s|%d|%s" % [owned, maxed, affordable, display_amount, GameManager.format_number(cost)]
	if state == _last_state:
		return
	_last_state = state

	var cap := GameManager.get_max_owned(upgrade_id)
	_level.text = "Lv %d%s" % [owned, ("/%d" % cap) if cap >= 0 else ""]
	_benefit.text = _describe_benefit()
	_button.disabled = not affordable
	var accent: Color = get_meta("accent", UIStyle.TEXT)
	if maxed:
		_cost.text = "MAX"
		_amount.text = ""
		UIStyle.style_button(_button, UIStyle.SURFACE_3, UIStyle.TEXT_DIM)
	else:
		_cost.text = GameManager.format_number(cost)
		_amount.text = ("MAX x%d" % amount) if purchase_mode < 0 and amount > 0 else "BUY x%d" % display_amount
		var fill := accent if affordable else UIStyle.SURFACE_3
		var ink := UIStyle.on_color(fill) if affordable else UIStyle.TEXT_FAINT
		UIStyle.style_button(_button, fill, ink)
		_cost.add_theme_color_override("font_color", ink)
		_amount.add_theme_color_override("font_color", Color(ink, 0.7))
	modulate = Color(1, 1, 1, 1) if affordable or maxed else Color(1, 1, 1, 0.82)

func set_accent(color: Color) -> void:
	set_meta("accent", color)
	_last_state = ""
	refresh()

func _on_buy_pressed() -> void:
	var amount := GameManager.get_purchase_amount(upgrade_id, purchase_mode)
	if amount > 0 and GameManager.buy_upgrade(upgrade_id, amount):
		_punch = 1.0
		purchased.emit(upgrade_id, amount)

func _process(delta: float) -> void:
	if _punch > 0.0:
		_punch = maxf(_punch - delta * 5.0, 0.0)
		var s := 1.0 + 0.035 * sin(_punch * PI)
		scale = Vector2(s, s)
