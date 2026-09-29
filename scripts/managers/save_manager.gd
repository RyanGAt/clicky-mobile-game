extends Node
## Local save/load, settings and offline earnings.
##
## Reliability rules:
## - Writes go to a temp file and are then swapped in; the previous save is kept
##   as save.dat.bak.
## - A save that can't be read (bad JSON, wrong shape, newer version) is never
##   overwritten silently: it is copied to save.<reason>.<timestamp>.dat first,
##   the backup is tried, and only then does the game start fresh.

signal offline_earnings_ready(earnings: float, seconds: float)
signal load_problem(message: String)

const SAVE_PATH := "user://save.dat"
const BACKUP_PATH := "user://save.dat.bak"
const TEMP_PATH := "user://save.dat.tmp"
const SAVE_VERSION := 2
const AUTO_SAVE_INTERVAL := 15.0

var settings: Dictionary = {
	"master_volume": 1.0,
	"vibration_enabled": true,
}
var seen_hints: Dictionary = {}

var pending_offline_earnings: float = 0.0
var pending_offline_seconds: float = 0.0
var last_load_problem: String = ""

var _paused_at_unix: float = 0.0
var _loaded := false

func _ready() -> void:
	load_game()
	_apply_audio_settings()

	var auto_save_timer := Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(save_game)
	add_child(auto_save_timer)

	GameManager.upgrade_purchased.connect(func(_id, _n): save_game())
	GameManager.switch_unlocked.connect(func(_id): save_game())
	GameManager.switch_equipped.connect(func(_id): save_game())
	GameManager.keycap_unlocked.connect(func(_id): save_game())
	GameManager.keycap_equipped.connect(func(_id): save_game())
	AchievementManager.achievement_unlocked.connect(func(_id): save_game())
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# Mobile backgrounding: the process stops ticking, so remember when.
			_paused_at_unix = Time.get_unix_time_from_system()
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at_unix > 0.0:
				_grant_offline_earnings(Time.get_unix_time_from_system() - _paused_at_unix)
				_paused_at_unix = 0.0
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_game()
			get_tree().quit()

# --- Saving -----------------------------------------------------------------

func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"clicks": GameManager.clicks,
		"lifetime_clicks": GameManager.lifetime_clicks,
		"tap_count": GameManager.tap_count,
		"critical_click_count": GameManager.critical_click_count,
		"owned": GameManager.owned,
		"unlocked_switches": GameManager.unlocked_switches,
		"equipped_switch": GameManager.equipped_switch,
		"unlocked_keycaps": GameManager.unlocked_keycaps,
		"equipped_keycap": GameManager.equipped_keycap,
		"unlocked_achievements": AchievementManager.unlocked,
		"settings": settings,
		"seen_hints": seen_hints,
		"last_active_unix": Time.get_unix_time_from_system(),
	}

func save_game() -> void:
	if not _loaded:
		return # never write before we've tried to read what's there
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(build_save_data()))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
		DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
	var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Could not finalise save file: %s" % error_string(err))

# --- Loading ----------------------------------------------------------------

func load_game() -> void:
	_loaded = true
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var result := _read_save(path)
		if result.has("data"):
			if path == BACKUP_PATH:
				_report_problem("Your last save couldn't be read, so the previous backup was restored.")
			_apply_save(result["data"])
			return
		_preserve_bad_file(path, result.get("reason", "corrupt"))
		_report_problem(result.get("message", "Save could not be read."))
	# No readable save: fresh start (bad files were preserved above).

func _read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"reason": "unreadable", "message": "Could not open %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"reason": "corrupt", "message": "%s has invalid JSON at line %d: %s" % [path, json.get_error_line(), json.get_error_message()]}
	if not (json.data is Dictionary):
		return {"reason": "corrupt", "message": "%s root is not an object" % path}
	var version := int(json.data.get("version", 0))
	if version > SAVE_VERSION:
		return {"reason": "unsupported", "message": "%s is version %d, newer than supported %d" % [path, version, SAVE_VERSION]}
	return {"data": json.data}

func _preserve_bad_file(path: String, reason: String) -> void:
	var stamp := int(Time.get_unix_time_from_system())
	var dest := "user://save.%s.%d.dat" % [reason, stamp]
	var n := 1
	while FileAccess.file_exists(dest):
		dest = "user://save.%s.%d-%d.dat" % [reason, stamp, n]
		n += 1
	var err := DirAccess.copy_absolute(path, dest)
	if err == OK:
		DirAccess.remove_absolute(path)
		push_warning("Preserved unreadable save %s as %s" % [path, dest])
	else:
		push_error("Could not preserve unreadable save %s: %s" % [path, error_string(err)])

func _report_problem(message: String) -> void:
	push_warning(message)
	last_load_problem = message
	load_problem.emit(message)

func _apply_save(parsed: Dictionary) -> void:
	var gm := GameManager
	if int(parsed.get("version", 0)) < SAVE_VERSION:
		print("Migrating save from version %d to %d" % [int(parsed.get("version", 0)), SAVE_VERSION])

	gm.clicks = maxf(_num(parsed.get("clicks"), 0.0), 0.0)
	gm.lifetime_clicks = maxf(_num(parsed.get("lifetime_clicks"), gm.clicks), gm.clicks)
	gm.tap_count = maxi(int(_num(parsed.get("tap_count"), 0)), 0)
	gm.critical_click_count = maxi(int(_num(parsed.get("critical_click_count"), 0)), 0)
	# v1 also stored click_power/clicks_per_second/critical_chance; those are
	# now derived from `owned`, so they are intentionally ignored.

	var saved_owned = parsed.get("owned", {})
	if saved_owned is Dictionary:
		for id in saved_owned.keys():
			if gm.upgrades.has(id):
				var count := maxi(int(_num(saved_owned[id], 0)), 0)
				var cap: int = gm.get_max_owned(id)
				gm.owned[id] = mini(count, cap) if cap >= 0 else count

	gm.unlocked_switches = _valid_ids(parsed.get("unlocked_switches", []), gm.switches, GameManager.DEFAULT_SWITCH)
	var requested_switch := str(parsed.get("equipped_switch", GameManager.DEFAULT_SWITCH))
	gm.equipped_switch = requested_switch if gm.unlocked_switches.has(requested_switch) else GameManager.DEFAULT_SWITCH

	gm.unlocked_keycaps = _valid_ids(parsed.get("unlocked_keycaps", []), gm.keycaps, GameManager.DEFAULT_KEYCAP)
	var requested_keycap := str(parsed.get("equipped_keycap", GameManager.DEFAULT_KEYCAP))
	gm.equipped_keycap = requested_keycap if gm.unlocked_keycaps.has(requested_keycap) else GameManager.DEFAULT_KEYCAP

	var achievements: Array = []
	var saved_achievements = parsed.get("unlocked_achievements", [])
	if saved_achievements is Array:
		for id in saved_achievements:
			if AchievementManager.achievements.has(str(id)) and not achievements.has(str(id)):
				achievements.append(str(id))
	AchievementManager.unlocked = achievements

	var saved_settings = parsed.get("settings", {})
	if saved_settings is Dictionary:
		settings["master_volume"] = clampf(_num(saved_settings.get("master_volume"), 1.0), 0.0, 1.0)
		settings["vibration_enabled"] = bool(saved_settings.get("vibration_enabled", true))
		var mode := int(_num(saved_settings.get("buy_mode"), 1))
		settings["buy_mode"] = mode if mode in [1, 10, -1] else 1
	var saved_hints = parsed.get("seen_hints", {})
	if saved_hints is Dictionary:
		seen_hints = saved_hints

	gm.clicks_changed.emit(gm.clicks)
	gm.stats_changed.emit()

	var last_active := _num(parsed.get("last_active_unix"), 0.0)
	if last_active > 0.0:
		_grant_offline_earnings(Time.get_unix_time_from_system() - last_active)

func _valid_ids(saved, table: Dictionary, default_id: String) -> Array:
	var result: Array = [default_id]
	if saved is Array:
		for id in saved:
			var key := str(id)
			if table.has(key) and not result.has(key):
				result.append(key)
	return result

func _num(value, fallback: float) -> float:
	if value is float or value is int:
		return float(value) if is_finite(float(value)) else fallback
	return fallback

# --- Offline earnings -------------------------------------------------------

## Offline rate uses GameManager.get_effective_cps(), the same formula as live income.
func calculate_offline_earnings(elapsed_seconds: float) -> float:
	var b := GameManager.balance
	var max_seconds := float(b.get("max_offline_hours", 8.0)) * 3600.0
	var elapsed := clampf(elapsed_seconds, 0.0, max_seconds)
	return elapsed * GameManager.get_effective_cps() * float(b.get("offline_efficiency", 0.5))

func _grant_offline_earnings(elapsed_seconds: float) -> void:
	if elapsed_seconds < float(GameManager.balance.get("min_offline_seconds", 30.0)):
		return
	var earnings := calculate_offline_earnings(elapsed_seconds)
	if earnings <= 0.0:
		return
	var max_seconds := float(GameManager.balance.get("max_offline_hours", 8.0)) * 3600.0
	GameManager.add_clicks(earnings)
	pending_offline_earnings += earnings
	pending_offline_seconds = minf(elapsed_seconds, max_seconds)
	offline_earnings_ready.emit(pending_offline_earnings, pending_offline_seconds)
	save_game()

func consume_pending_offline_earnings() -> Dictionary:
	var result := {"earnings": pending_offline_earnings, "seconds": pending_offline_seconds}
	pending_offline_earnings = 0.0
	pending_offline_seconds = 0.0
	return result

# --- Settings ---------------------------------------------------------------

func set_master_volume(value: float) -> void:
	settings["master_volume"] = clampf(value, 0.0, 1.0)
	_apply_audio_settings()

func set_vibration_enabled(enabled: bool) -> void:
	settings["vibration_enabled"] = enabled
	save_game()

func mark_hint_seen(id: String) -> void:
	seen_hints[id] = true

func _apply_audio_settings() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		push_warning("Master audio bus is unavailable.")
		return
	var volume: float = settings.get("master_volume", 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, volume <= 0.0001)
