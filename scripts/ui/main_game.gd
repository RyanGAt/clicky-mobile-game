extends Control
## Main screen wiring: routes switch taps to the economy, keeps the view in
## sync with game state, and shows popups/toasts. Presentation lives in the
## components under scripts/ui/components and scripts/ui/panels.

const TAB_NAMES := ["Upgrades", "Switches", "Collection"]
const HINT_TAP := "tap_switch"

@onready var background: GameBackground = %Background
@onready var switch_view: SwitchView = %SwitchView
@onready var switch_name: Label = %SwitchName
@onready var switch_tier: Label = %SwitchTier
@onready var goal_bar: GoalBar = %GoalBar
@onready var currency: CurrencyDisplay = %CurrencyDisplay
@onready var settings_button: Button = %SettingsButton
@onready var keycap_badge: KeycapBadge = %KeycapBadge
@onready var sheet: PanelContainer = %Sheet
@onready var tabs: HBoxContainer = %Tabs
@onready var panels: Array[TabPanel] = [%UpgradesPanel, %SwitchesPanel, %CollectionPanel]
@onready var fx_layer: Control = %FxLayer
@onready var popup_layer: CanvasLayer = %PopupLayer

var _tab_buttons: Array[Button] = []
var _current_tab := 0
var _accent := Color.WHITE
var _hint: Label
var _refresh_timer := 0.0
var _unlock_queue: Array[String] = []

func _ready() -> void:
	theme = UIStyle.build_theme()
	_style_static_labels()
	_build_tabs()

	switch_view.pressed.connect(_on_switch_pressed)
	switch_view.released.connect(func(): Feedback.play(Feedback.Sound.KEY_UP, 0.04))
	settings_button.pressed.connect(func(): _open_popup(SettingsPopup.new()))
	keycap_badge.pressed.connect(func(): _select_tab(2))
	(panels[0] as UpgradesPanel).upgrade_bought.connect(_on_upgrade_bought)

	GameManager.switch_equipped.connect(func(_id): _apply_equipped(true))
	GameManager.keycap_equipped.connect(func(_id): _apply_equipped(true))
	GameManager.switch_unlocked.connect(_on_switch_unlocked)
	GameManager.keycap_unlocked.connect(_on_keycap_unlocked)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	SaveManager.offline_earnings_ready.connect(func(_e, _s): _show_offline_earnings_if_pending())
	SaveManager.load_problem.connect(func(msg): _toast(msg))
	get_viewport().size_changed.connect(_layout_sheet)

	_apply_equipped(false)
	_layout_sheet()
	_select_tab(0)
	_show_offline_earnings_if_pending()
	if SaveManager.last_load_problem != "":
		_toast(SaveManager.last_load_problem)
	if GameManager.tap_count == 0 and not SaveManager.seen_hints.get(HINT_TAP, false):
		_show_tap_hint()

func _process(delta: float) -> void:
	# Panel refresh is cheap (cards cache their last state) but there is no
	# need to do it every frame.
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.1
		panels[_current_tab].refresh()
	var stage_rect := switch_view.get_global_rect()
	background.glow_center = (stage_rect.get_center()) / size

# --- Layout -----------------------------------------------------------------

func _style_static_labels() -> void:
	switch_name.add_theme_font_override("font", UIStyle.font(800))
	switch_name.add_theme_font_size_override("font_size", 44)
	switch_tier.add_theme_font_override("font", UIStyle.font(700))
	switch_tier.add_theme_font_size_override("font_size", 24)
	var sheet_style := UIStyle.box(UIStyle.SURFACE, 44, 0, Color(1, 1, 1, 0.05))
	sheet_style.shadow_color = Color(0, 0, 0, 0.35)
	sheet_style.shadow_size = 30
	sheet.add_theme_stylebox_override("panel", sheet_style)

func _layout_sheet() -> void:
	# Bottom sheet takes ~40% of the height; the switch gets the rest.
	var h := get_viewport_rect().size.y
	sheet.custom_minimum_size.y = clampf(h * 0.4, 640.0, 980.0)

func _build_tabs() -> void:
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(_select_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

func _select_tab(index: int) -> void:
	_current_tab = index
	for i in panels.size():
		panels[i].visible = i == index
	panels[index].refresh()
	_paint_tabs()

func _paint_tabs() -> void:
	for i in _tab_buttons.size():
		var active := i == _current_tab
		var b := _tab_buttons[i]
		var sb := UIStyle.box(Color(_accent, 0.12) if active else Color(0, 0, 0, 0), 34)
		sb.set_expand_margin_all(-14)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(key, _accent.lightened(0.35) if active else UIStyle.TEXT_FAINT)
		b.add_theme_font_override("font", UIStyle.font(800 if active else 600))

# --- Switch -----------------------------------------------------------------

func _on_switch_pressed(pos: Vector2) -> void:
	var result := GameManager.tap()
	var is_crit := bool(result["is_crit"])
	var amount := GameManager.format_number(float(result["amount"]))
	switch_view.show_tap_result(("CRIT +%s" if is_crit else "+%s") % amount, is_crit, pos)
	Feedback.play(Feedback.Sound.CRIT if is_crit else Feedback.Sound.KEY_DOWN, 0.04)
	Feedback.vibrate("crit" if is_crit else "tap")
	if _hint:
		_dismiss_hint()

func get_display_texture() -> Texture2D:
	var path: String = GameManager.get_equipped_switch_data().get("asset_path", "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	push_warning("Switch artwork missing: '%s'" % path)
	return null

func _apply_equipped(animate: bool) -> void:
	var data := GameManager.get_equipped_switch_data()
	_accent = Color(data.get("color", "#d9cfb5"))
	switch_view.set_switch_texture(get_display_texture(), _accent, animate)
	switch_name.text = data.get("name", "Switch")
	switch_tier.text = String(data.get("tier_label", "Tier %d" % int(data.get("tier", 1)))).to_upper()
	switch_tier.add_theme_color_override("font_color", Color(_accent, 0.85))
	background.set_accent(_accent)
	keycap_badge.show_keycap(GameManager.equipped_keycap)
	goal_bar.set_accent(_accent)
	for p in panels:
		p.set_accent(_accent)
	_paint_tabs()

# --- Events -----------------------------------------------------------------

func _on_upgrade_bought(card: UpgradeCard, _id: String, _amount: int) -> void:
	Feedback.play(Feedback.Sound.PURCHASE)
	Feedback.vibrate("purchase")
	switch_view.pulse(0.03)

func _on_switch_unlocked(id: String) -> void:
	Feedback.play(Feedback.Sound.UNLOCK)
	Feedback.vibrate("unlock")
	_unlock_queue.append(id)
	if _unlock_queue.size() == 1:
		_show_next_unlock()

func _show_next_unlock() -> void:
	if _unlock_queue.is_empty():
		return
	var popup := UnlockPopup.new(_unlock_queue[0])
	popup.closed.connect(func():
		_unlock_queue.pop_front()
		_show_next_unlock())
	_open_popup(popup)

func _on_keycap_unlocked(id: String) -> void:
	_toast("New keycap: %s" % GameManager.keycaps.get(id, {}).get("name", id))

func _on_achievement_unlocked(id: String) -> void:
	_toast("Achievement: %s" % AchievementManager.achievements.get(id, {}).get("name", id))

func _open_popup(popup: Control) -> void:
	switch_view.release_all_touches()
	popup_layer.add_child(popup)

func _show_offline_earnings_if_pending() -> void:
	var offline := SaveManager.consume_pending_offline_earnings()
	if float(offline["earnings"]) > 0.0:
		_open_popup(OfflineEarningsPopup.new(float(offline["earnings"]), float(offline["seconds"])))

# --- Toasts & hints ---------------------------------------------------------

var _toast_count := 0

func _toast(message: String) -> void:
	var pill := PanelContainer.new()
	var sb := UIStyle.box(UIStyle.SURFACE_3, 40)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIStyle.label(message, 28, UIStyle.TEXT, 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = minf(size.x - 160.0, 820.0)
	pill.add_child(l)
	fx_layer.add_child(pill)
	pill.reset_size()
	var slot := _toast_count
	_toast_count += 1
	# Toasts sit over the goal-bar row (stacking upward) so they never cover
	# the switch, where the floating numbers rise.
	var g := goal_bar.get_global_rect()
	var y := g.position.y + (g.size.y - pill.size.y) * 0.5 - slot * (pill.size.y + 12.0)
	pill.position = Vector2((size.x - pill.size.x) * 0.5, y - 30.0)
	pill.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pill, "modulate:a", 1.0, 0.2)
	tw.tween_property(pill, "position:y", y, 0.25)
	tw.chain().tween_interval(2.2)
	tw.chain().tween_property(pill, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func():
		_toast_count = maxi(_toast_count - 1, 0)
		pill.queue_free())

func _show_tap_hint() -> void:
	_hint = UIStyle.label("Tap the switch", 32, UIStyle.TEXT_DIM, 700)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx_layer.add_child(_hint)
	await get_tree().process_frame
	if _hint == null:
		return
	var r := switch_view.get_global_rect()
	_hint.size.x = size.x
	_hint.position = Vector2(0, r.end.y - 40.0)
	var tw := _hint.create_tween().set_loops()
	tw.tween_property(_hint, "modulate:a", 0.35, 0.8)
	tw.tween_property(_hint, "modulate:a", 1.0, 0.8)

func _dismiss_hint() -> void:
	SaveManager.mark_hint_seen(HINT_TAP)
	var hint := _hint
	_hint = null
	var tw := create_tween()
	tw.tween_property(hint, "modulate:a", 0.0, 0.25)
	tw.tween_callback(hint.queue_free)
