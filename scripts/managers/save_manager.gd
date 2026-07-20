extends Node

const SAVE_PATH := "user://save.dat"
const SAVE_VERSION := 1
const OFFLINE_EFFICIENCY := 0.5
const MAX_OFFLINE_SECONDS := 8.0 * 60.0 * 60.0
const AUTO_SAVE_INTERVAL := 30.0

var settings: Dictionary = {
	"master_volume": 1.0,
	"vibration_enabled": true,
}

var pending_offline_earnings: float = 0.0
var pending_offline_seconds: float = 0.0

func _ready() -> void:
	load_game()
	_apply_audio_settings()

	var auto_save_timer := Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(save_game)
	add_child(auto_save_timer)

	GameManager.upgrade_purchased.connect(func(_id): save_game())
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()
			get_tree().quit()

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"clicks": GameManager.clicks,
		"click_power": GameManager.click_power,
		"clicks_per_second": GameManager.clicks_per_second,
		"owned": GameManager.owned,
		"settings": settings,
		"last_active_unix": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file")
		return
	file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	GameManager.clicks = float(parsed.get("clicks", 0.0))
	GameManager.click_power = float(parsed.get("click_power", 1.0))
	GameManager.clicks_per_second = float(parsed.get("clicks_per_second", 0.0))

	var saved_owned = parsed.get("owned", {})
	if saved_owned is Dictionary:
		for id in saved_owned.keys():
			GameManager.owned[id] = int(saved_owned[id])

	var saved_settings = parsed.get("settings", {})
	if saved_settings is Dictionary:
		for key in saved_settings.keys():
			settings[key] = saved_settings[key]

	var last_active: float = float(parsed.get("last_active_unix", 0.0))
	if last_active > 0.0 and GameManager.clicks_per_second > 0.0:
		var elapsed: float = clampf(Time.get_unix_time_from_system() - last_active, 0.0, MAX_OFFLINE_SECONDS)
		if elapsed > 1.0:
			pending_offline_seconds = elapsed
			pending_offline_earnings = elapsed * GameManager.clicks_per_second * OFFLINE_EFFICIENCY
			GameManager.add_clicks(pending_offline_earnings)

func consume_pending_offline_earnings() -> Dictionary:
	var result := {
		"earnings": pending_offline_earnings,
		"seconds": pending_offline_seconds,
	}
	pending_offline_earnings = 0.0
	pending_offline_seconds = 0.0
	return result

func set_master_volume(value: float) -> void:
	settings["master_volume"] = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	save_game()

func set_vibration_enabled(enabled: bool) -> void:
	settings["vibration_enabled"] = enabled
	save_game()

func _apply_audio_settings() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	var volume: float = settings.get("master_volume", 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, volume <= 0.0001)
