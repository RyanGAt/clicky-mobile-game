extends Control

const FLOAT_TEXT_SCENE_DURATION := 0.6
const TAP_SCALE := 0.92
const TAP_VIBRATION_MS := 15

const SettingsScreenScene := preload("res://scenes/screens/settings_screen.tscn")
const OfflineEarningsPopupScene := preload("res://scenes/screens/offline_earnings_popup.tscn")
const CollectionScreenScene := preload("res://scenes/screens/collection_screen.tscn")

@onready var switch_button: Button = %SwitchButton
@onready var switch_audio: AudioStreamPlayer = %SwitchAudio
@onready var floating_text_layer: Control = %FloatingTextLayer
@onready var clicks_label: Label = %ClicksLabel
@onready var cpt_label: Label = %CPTLabel
@onready var cps_label: Label = %CPSLabel
@onready var stronger_finger_button: Button = %StrongerFingerButton
@onready var automatic_finger_button: Button = %AutomaticFingerButton
@onready var lucky_press_button: Button = %LuckyPressButton
@onready var settings_button: Button = %SettingsButton
@onready var collection_button: Button = %CollectionButton
@onready var popup_layer: CanvasLayer = %PopupLayer

var _tap_tween: Tween
var _onboarding_hint: Label

func _ready() -> void:
	GameManager.clicks_changed.connect(_on_clicks_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
	GameManager.switch_equipped.connect(func(_id): _refresh_all_labels())

	switch_button.button_down.connect(_on_switch_pressed)
	switch_button.button_up.connect(_on_switch_released)
	stronger_finger_button.pressed.connect(func(): _buy("stronger_finger"))
	automatic_finger_button.pressed.connect(func(): _buy("automatic_finger"))
	lucky_press_button.pressed.connect(func(): _buy("lucky_press"))
	settings_button.pressed.connect(_on_settings_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	GameManager.keycap_equipped.connect(func(_id): _apply_keycap_tint())

	_apply_keycap_tint()
	_refresh_all_labels()
	_show_offline_earnings_if_pending()
	_show_onboarding_hint_if_first_launch()

func _process(_delta: float) -> void:
	cps_label.text = "CPS: %s" % GameManager.format_number(GameManager.get_effective_cps())
	_refresh_upgrade_buttons()

func _on_switch_pressed() -> void:
	var result := GameManager.tap()
	_play_press_animation()
	_play_tap_sound()
	_play_tap_vibration()
	_spawn_floating_text(float(result["amount"]), bool(result["is_crit"]))
	_dismiss_onboarding_hint()

func _on_switch_released() -> void:
	_play_release_animation()

func _play_press_animation() -> void:
	if _tap_tween and _tap_tween.is_valid():
		_tap_tween.kill()
	switch_button.pivot_offset = switch_button.size / 2.0
	_tap_tween = create_tween()
	_tap_tween.set_trans(Tween.TRANS_QUAD)
	_tap_tween.set_ease(Tween.EASE_OUT)
	_tap_tween.tween_property(switch_button, "scale", Vector2(TAP_SCALE, TAP_SCALE), 0.035)

func _play_release_animation() -> void:
	if _tap_tween and _tap_tween.is_valid():
		_tap_tween.kill()
	switch_button.pivot_offset = switch_button.size / 2.0
	_tap_tween = create_tween()
	_tap_tween.set_trans(Tween.TRANS_BACK)
	_tap_tween.set_ease(Tween.EASE_OUT)
	_tap_tween.tween_property(switch_button, "scale", Vector2.ONE, 0.11)

func _play_tap_sound() -> void:
	if switch_audio.stream == null:
		return
	switch_audio.pitch_scale = randf_range(0.95, 1.05)
	switch_audio.play()

func _play_tap_vibration() -> void:
	if SaveManager.settings.get("vibration_enabled", true):
		Input.vibrate_handheld(TAP_VIBRATION_MS)

func _on_settings_pressed() -> void:
	popup_layer.add_child(SettingsScreenScene.instantiate())

func _on_collection_pressed() -> void:
	popup_layer.add_child(CollectionScreenScene.instantiate())

func _apply_keycap_tint() -> void:
	var data: Dictionary = GameManager.keycaps.get(GameManager.equipped_keycap, {})
	var hex: String = data.get("color", "#ffffff")
	switch_button.self_modulate = Color(hex)

func _on_achievement_unlocked(id: String) -> void:
	var data: Dictionary = AchievementManager.achievements.get(id, {})
	_spawn_toast("Achievement Unlocked: %s" % data.get("name", id))

func _make_centered_overlay_label(text: String, font_size: int, top_ratio: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.anchor_top = top_ratio
	label.anchor_bottom = top_ratio
	label.offset_left = 40.0
	label.offset_right = -40.0
	label.offset_top = -35.0
	label.offset_bottom = 35.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _spawn_toast(message: String) -> void:
	var label := _make_centered_overlay_label(message, 32, 0.18)
	floating_text_layer.add_child(label)

	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _show_offline_earnings_if_pending() -> void:
	var offline := SaveManager.consume_pending_offline_earnings()
	if float(offline["earnings"]) <= 0.0:
		return
	var popup: Control = OfflineEarningsPopupScene.instantiate()
	popup_layer.add_child(popup)
	popup.setup(float(offline["earnings"]), float(offline["seconds"]))

func _show_onboarding_hint_if_first_launch() -> void:
	if GameManager.tap_count > 0:
		return
	_onboarding_hint = _make_centered_overlay_label("Tap the switch to earn Clicks!", 32, 0.30)
	floating_text_layer.add_child(_onboarding_hint)

func _dismiss_onboarding_hint() -> void:
	if _onboarding_hint == null:
		return
	var hint := _onboarding_hint
	_onboarding_hint = null
	var tween := create_tween()
	tween.tween_property(hint, "modulate:a", 0.0, 0.3)
	tween.tween_callback(hint.queue_free)

func _spawn_floating_text(amount: float, is_crit: bool) -> void:
	var label := Label.new()
	var formatted_amount := GameManager.format_number(amount)
	label.text = "CRIT! +%s" % formatted_amount if is_crit else "+%s" % formatted_amount
	label.add_theme_font_size_override("font_size", 64 if is_crit else 48)
	label.add_theme_color_override("font_color", Color("#ffd700") if is_crit else Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start_pos := switch_button.global_position + switch_button.size / 2.0
	start_pos += Vector2(randf_range(-40.0, 40.0), -20.0)
	label.global_position = start_pos
	floating_text_layer.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", start_pos.y - 120.0, FLOAT_TEXT_SCENE_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TEXT_SCENE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _buy(id: String) -> void:
	GameManager.buy_upgrade(id)

func _on_clicks_changed(_total: float) -> void:
	_refresh_all_labels()

func _on_upgrade_purchased(_id: String) -> void:
	_refresh_all_labels()

func _refresh_all_labels() -> void:
	clicks_label.text = GameManager.format_number(GameManager.clicks)
	cpt_label.text = "Per Tap: %s" % GameManager.format_number(GameManager.get_effective_click_power())
	cps_label.text = "CPS: %s" % GameManager.format_number(GameManager.get_effective_cps())
	var switch_data := GameManager.get_equipped_switch_data()
	switch_button.text = "%s\nTAP" % switch_data.get("name", "Switch")
	_refresh_upgrade_buttons()

func _refresh_upgrade_buttons() -> void:
	_refresh_upgrade_button(stronger_finger_button, "stronger_finger")
	_refresh_upgrade_button(automatic_finger_button, "automatic_finger")
	_refresh_upgrade_button(lucky_press_button, "lucky_press")

func _refresh_upgrade_button(button: Button, id: String) -> void:
	var data: Dictionary = GameManager.upgrades.get(id, {})
	var cost := GameManager.get_upgrade_cost(id)
	var owned: int = GameManager.owned.get(id, 0)
	button.text = "%s (x%d)\n%s\nCost: %s" % [
		data.get("name", id),
		owned,
		data.get("description", ""),
		GameManager.format_number(cost),
	]
	button.disabled = not GameManager.can_afford(id)
