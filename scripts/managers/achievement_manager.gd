extends Node

signal achievement_unlocked(id: String)

const ACHIEVEMENTS_PATH := "res://data/achievements.json"

var achievements: Dictionary = {}
var unlocked: Array = []

func _ready() -> void:
	_load_achievement_data()
	GameManager.clicks_changed.connect(func(_total): _check_achievements())
	GameManager.upgrade_purchased.connect(func(_id): _check_achievements())
	GameManager.switch_unlocked.connect(func(_id): _check_achievements())

func _load_achievement_data() -> void:
	var file := FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % ACHIEVEMENTS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		achievements = parsed

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func _check_achievements() -> void:
	for id in achievements.keys():
		if is_unlocked(id):
			continue
		if _condition_met(achievements[id]):
			unlocked.append(id)
			achievement_unlocked.emit(id)

func _condition_met(data: Dictionary) -> bool:
	var condition_type: String = data.get("condition_type", "")
	var condition_value: float = data.get("condition_value", 0.0)
	match condition_type:
		"tap_count":
			return GameManager.tap_count >= condition_value
		"lifetime_clicks":
			return GameManager.lifetime_clicks >= condition_value
		"clicks_per_second":
			return GameManager.get_effective_cps() >= condition_value
		"switches_unlocked":
			return GameManager.unlocked_switches.size() >= condition_value
		"owned_automatic_finger":
			return GameManager.owned.get("automatic_finger", 0) >= condition_value
		_:
			return false
