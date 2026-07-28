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
	GameManager.switch_unlocked.connect(func(_id): save_game())
	GameManager.switch_equipped.connect(func(_id): save_game())
	GameManager.keycap_unlocked.connect(func(_id): save_game())
	GameManager.keycap_equipped.connect(func(_id): save_game())
	AchievementManager.achievement_unlocked.connect(func(_id): save_game())
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
		"lifetime_clicks": GameManager.lifetime_clicks,
		"tap_count": GameManager.tap_count,
		"critical_click_count": GameManager.critical_click_count,
		"click_power": GameManager.click_power,
		"clicks_per_second": GameManager.clicks_per_second,
		"critical_chance": GameManager.critical_chance,
		"owned": GameManager.owned,
		"unlocked_switches": GameManager.unlocked_switches,
		"equipped_switch": GameManager.equipped_switch,
		"unlocked_keycaps": GameManager.unlocked_keycaps,
		"equipped_keycap": GameManager.equipped_keycap,
		"unlocked_achievements": AchievementManager.unlocked,
		"settings": settings,
		"last_active_unix": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file: %s" % FileAccess.get_open_error())
		return

	var raw_text := file.get_as_text()
	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		push_warning("Save file contains invalid JSON at line %d: %s. Starting safely without overwriting it." % [json.get_error_line(), json.get_error_message()])
		return

	var parsed = json.data
	if not (parsed is Dictionary):
		push_warning("Save file root is not a dictionary. Starting safely without overwriting it.")
		return

	var saved_version := int(parsed.get("version", 0))
	if saved_version > SAVE_VERSION:
		push_warning("Save version %d is newer than supported version %d. Starting safely without overwriting it." % [saved_version, SAVE_VERSION])
		return
	if saved_version < SAVE_VERSION:
		push_warning("Loading older save version %d with compatibility defaults." % saved_version)

	GameManager.clicks = maxf(float(parsed.get("clicks", 0.0)), 0.0)
	GameManager.lifetime_clicks = maxf(float(parsed.get("lifetime_clicks", GameManager.clicks)), GameManager.clicks)
	GameManager.tap_count = maxi(int(parsed.get("tap_count", 0)), 0)
	GameManager.critical_click_count = maxi(int(parsed.get("critical_click_count", 0)), 0)
	GameManager.click_power = maxf(float(parsed.get("click_power", 1.0)), 1.0)
	GameManager.clicks_per_second = maxf(float(parsed.get("clicks_per_second", 0.0)), 0.0)
	GameManager.critical_chance = clampf(float(parsed.get("critical_chance", 0.0)), 0.0, 1.0)

	var saved_owned = parsed.get("owned", {})
	if saved_owned is Dictionary:
		for id in saved_owned.keys():
			if GameManager.upgrades.has(id):
				GameManager.owned[id] = maxi(int(saved_owned[id]), 0)

	var saved_unlocked_switches = parsed.get("unlocked_switches", [])
	if saved_unlocked_switches is Array:
		var valid_switches: Array = ["office_membrane"]
		for id in saved_unlocked_switches:
			if GameManager.switches.has(String(id)) and not valid_switches.has(String(id)):
				valid_switches.append(String(id))
		GameManager.unlocked_switches = valid_switches

	var requested_switch := String(parsed.get("equipped_switch", "office_membrane"))
	GameManager.equipped_switch = requested_switch if GameManager.unlocked_switches.has(requested_switch) else "office_membrane"

	var saved_unlocked_keycaps = parsed.get("unlocked_keycaps", [])
	if saved_unlocked_keycaps is Array:
		var valid_keycaps: Array = ["plain_beige"]
		for id in saved_unlocked_keycaps:
			if GameManager.keycaps.has(String(id)) and not valid_keycaps.has(String(id)):
				valid_keycaps.append(String(id))
		GameManager.unlocked_keycaps = valid_keycaps

	var requested_keycap := String(parsed.get("equipped_keycap", "plain_beige"))
	GameManager.equipped_keycap = requested_keycap if GameManager.unlocked_keycaps.has(requested_keycap) else "plain_beige"

	var saved_achievements = parsed.get("unlocked_achievements", [])
	if saved_achievements is Array:
		AchievementManager.unlocked = saved_achievements

	var saved_settings = parsed.get("settings", {})
	if saved_settings is Dictionary:
		settings["master_volume"] = clampf(float(saved_settings.get("master_volume", 1.0)), 0.0, 1.0)
		settings["vibration_enabled"] = bool(saved_settings.get("vibration_enabled", true))

	var last_active := float(parsed.get("last_active_unix", 0.0))
	if last_active > 0.0 and GameManager.get_effective_cps() > 0.0:
		var elapsed := clampf(Time.get_unix_time_from_system() - last_active, 0.0, MAX_OFFLINE_SECONDS)
		if elapsed > 1.0:
			pending_offline_seconds = elapsed
			pending_offline_earnings = elapsed * GameManager.get_effective_cps() * OFFLINE_EFFICIENCY
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
	if bus_index < 0:
		push_warning("Master audio bus is unavailable.")
		return
	var volume: float = settings.get("master_volume", 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, volume <= 0.0001)
