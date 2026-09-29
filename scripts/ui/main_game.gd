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
	GameManager.mastery_reached.connect(_on_mastery_reached)
	GameManager.event_triggered.connect(_on_event)
	SaveManager.offline_earnings_ready.connect(func(_e, _s): _show_offline_earnings_if_pending())
	SaveManager.load_problem.connect(func(msg): _toast(msg))
	get_viewport().size_changed.connect(_layout_sheet)

	_build_streak_pill()
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
	_update_streak_pill(stage_rect)

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
	var changed := index != _current_tab
	_current_tab = index
	for i in panels.size():
		panels[i].visible = i == index
	panels[index].refresh()
	_paint_tabs()
	if changed:
		# Quick fade so tab changes read as a transition, not a jump.
		var panel := panels[index]
		panel.modulate.a = 0.0
		create_tween().tween_property(panel, "modulate:a", 1.0, 0.16)

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
	var is_perfect := bool(result["is_perfect"])
	var amount := GameManager.format_number(float(result["amount"]))
	if is_perfect:
		switch_view.show_tap_result("PERFECT +%s" % amount, true, pos, "perfect")
		Feedback.play(Feedback.Sound.PERFECT_PRESS)
		Feedback.vibrate("perfect")
	else:
		switch_view.show_tap_result(("CRIT +%s" if is_crit else "+%s") % amount, is_crit, pos, "", bool(result["streak"]))
		Feedback.vibrate("crit" if is_crit else "tap")
		if is_crit:
			Feedback.play(Feedback.Sound.CRIT, 0.04)
	Feedback.play(Feedback.Sound.KEY_DOWN, 0.04)
	if _hint:
		_dismiss_hint()

func _apply_equipped(animate: bool) -> void:
	var data := GameManager.get_equipped_switch_data()
	_accent = Color(data.get("color", "#d9cfb5"))
	var art := UIStyle.switch_art(GameManager.equipped_switch)
	switch_view.set_switch_texture(art["texture"], _accent, animate, art["tint"])
	switch_name.text = data.get("name", "Switch")
	switch_tier.text = String(data.get("tier_label", "Tier %d" % int(data.get("tier", 1)))).to_upper()
	if art["placeholder"]:
		switch_tier.text += "  ·  TEMP ART"
	switch_tier.add_theme_color_override("font_color", Color(_accent, 0.85))
	background.set_accent(_accent)
	keycap_badge.show_keycap(GameManager.equipped_keycap)
	goal_bar.set_accent(_accent)
	for p in panels:
		p.set_accent(_accent)
	_paint_tabs()

# --- Events -----------------------------------------------------------------

func _on_upgrade_bought(_card: UpgradeCard, _id: String, _amount: int) -> void:
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

func _on_mastery_reached(id: String, level: int) -> void:
	var name: String = GameManager.switches.get(id, {}).get("name", id)
	var bonus := roundi((GameManager.get_mastery_multiplier(id) - 1.0) * 100.0)
	var total: int = GameManager.get_mastery_thresholds().size()
	_toast(("%s mastered! +%d%%" if level >= total else "%s mastery %d · +%d%%") % ([name, bonus] if level >= total else [name, level, bonus]))
	Feedback.play(Feedback.Sound.MASTERY)
	Feedback.vibrate("unlock")
	switch_view.pulse(0.08)

func _on_event(kind: String) -> void:
	if kind == "hot_streak":
		Feedback.play(Feedback.Sound.HOT_STREAK)

# --- Hot Streak pill --------------------------------------------------------

var _streak_pill: PanelContainer
var _streak_bar: ProgressBar

func _build_streak_pill() -> void:
	_streak_pill = PanelContainer.new()
	var sb := UIStyle.box(Color("#ff8a3d", 0.16), 30)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_streak_pill.add_theme_stylebox_override("panel", sb)
	_streak_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_streak_pill.add_child(col)
	var l := UIStyle.label("HOT STREAK  x%s TAPS" % GameManager.format_number(float(GameManager.balance.get("streak_multiplier", 2))), 26, Color("#ffb27a"), 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	_streak_bar = ProgressBar.new()
	_streak_bar.show_percentage = false
	_streak_bar.custom_minimum_size = Vector2(0, 6)
	_streak_bar.max_value = float(GameManager.balance.get("streak_duration", 5.0))
	_streak_bar.add_theme_stylebox_override("background", UIStyle.box(Color(1, 1, 1, 0.08), 3))
	_streak_bar.add_theme_stylebox_override("fill", UIStyle.box(Color("#ff8a3d"), 3))
	col.add_child(_streak_bar)
	_streak_pill.visible = false
	fx_layer.add_child(_streak_pill)

func _update_streak_pill(stage_rect: Rect2) -> void:
	var active: bool = GameManager.is_streak_active()
	if active and not _streak_pill.visible:
		_streak_pill.visible = true
		_streak_pill.modulate.a = 0.0
		create_tween().tween_property(_streak_pill, "modulate:a", 1.0, 0.15)
	elif not active and _streak_pill.visible:
		_streak_pill.visible = false
	if active:
		_streak_bar.value = GameManager.get_streak_remaining()
		_streak_pill.reset_size()
		_streak_pill.position = Vector2((size.x - _streak_pill.size.x) * 0.5, stage_rect.position.y + 6.0)

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

var _toast_queue: Array[String] = []
var _toast_showing := false

## Toasts show one at a time. A backlog of achievement toasts is merged
## into a single summary so a burst of unlocks never stacks up on screen.
func _toast(message: String) -> void:
	_toast_queue.append(message)
	if not _toast_showing:
		_show_next_toast()

func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_showing = false
		return
	_toast_showing = true
	var achievements := _toast_queue.filter(func(m): return m.begins_with("Achievement: "))
	var message: String
	if achievements.size() >= 3:
		for m in achievements:
			_toast_queue.erase(m)
		message = "%d achievements unlocked" % achievements.size()
	else:
		message = _toast_queue.pop_front()
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
	# Sits over the goal-bar row so it never covers the switch.
	var g := goal_bar.get_global_rect()
	var y := g.position.y + (g.size.y - pill.size.y) * 0.5
	pill.position = Vector2((size.x - pill.size.x) * 0.5, y + 24.0)
	pill.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pill, "modulate:a", 1.0, 0.18)
	tw.tween_property(pill, "position:y", y, 0.22)
	tw.chain().tween_interval(1.6 if _toast_queue.is_empty() else 1.0)
	tw.chain().tween_property(pill, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(func():
		pill.queue_free()
		_show_next_toast())

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
