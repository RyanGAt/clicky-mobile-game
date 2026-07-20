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
@onready var settings_button: Button = %SettingsButton
@onready var collection_button: Button = %CollectionButton
@onready var popup_layer: CanvasLayer = %PopupLayer

var _tap_tween: Tween

func _ready() -> void:
	GameManager.clicks_changed.connect(_on_clicks_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

	switch_button.button_down.connect(_on_switch_pressed)
	switch_button.button_up.connect(_on_switch_released)
	stronger_finger_button.pressed.connect(func(): _buy("stronger_finger"))
	automatic_finger_button.pressed.connect(func(): _buy("automatic_finger"))
	settings_button.pressed.connect(_on_settings_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

	_refresh_all_labels()
	_show_offline_earnings_if_pending()

func _process(_delta: float) -> void:
	cps_label.text = "CPS: %s" % GameManager.format_number(GameManager.get_effective_cps())
	_refresh_upgrade_buttons()

func _on_switch_pressed() -> void:
	var earned := GameManager.tap()
	_play_press_animation()
	_play_tap_sound()
	_play_tap_vibration()
	_spawn_floating_text(earned)

func _on_switch_released() -> void:
	pass

func _play_press_animation() -> void:
	if _tap_tween:
		_tap_tween.kill()
	switch_button.pivot_offset = switch_button.size / 2.0
	switch_button.scale = Vector2.ONE
	_tap_tween = create_tween()
	_tap_tween.tween_property(switch_button, "scale", Vector2(TAP_SCALE, TAP_SCALE), 0.05)
	_tap_tween.tween_property(switch_button, "scale", Vector2.ONE, 0.12)

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

func _on_achievement_unlocked(id: String) -> void:
	var data: Dictionary = AchievementManager.achievements.get(id, {})
	_spawn_toast("Achievement Unlocked: %s" % data.get("name", id))

func _spawn_toast(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.position = Vector2(-260, 220)
	label.size = Vector2(520, 60)
	floating_text_layer.add_child(label)

	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _show_offline_earnings_if_pending() -> void:
	var offline := SaveManager.consume_pending_offline_earnings()
	if offline["earnings"] <= 0.0:
		return
	var popup: Control = OfflineEarningsPopupScene.instantiate()
	popup_layer.add_child(popup)
	popup.setup(offline["earnings"], offline["seconds"])

func _spawn_floating_text(amount: float) -> void:
	var label := Label.new()
	label.text = "+%s" % GameManager.format_number(amount)
	label.add_theme_font_size_override("font_size", 48)
	var start_pos := switch_button.global_position + switch_button.size / 2.0
	start_pos += Vector2(randf_range(-40.0, 40.0), -20.0)
	label.global_position = start_pos
	floating_text_layer.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", start_pos.y - 120.0, FLOAT_TEXT_SCENE_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TEXT_SCENE_DURATION)
	tween.chain().tween_callback(label.queue_free)

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
	_refresh_upgrade_buttons()

func _refresh_upgrade_buttons() -> void:
	_refresh_upgrade_button(stronger_finger_button, "stronger_finger")
	_refresh_upgrade_button(automatic_finger_button, "automatic_finger")

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
