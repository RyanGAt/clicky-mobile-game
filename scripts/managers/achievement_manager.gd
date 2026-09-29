extends Node
## Achievements are objectives; each one also grants a small permanent global
## bonus (balance.json "achievement_bonus"), applied in GameManager.

signal achievement_unlocked(id: String)

const ACHIEVEMENTS_PATH := "res://data/achievements.json"

var achievements: Dictionary = {}
var unlocked: Array = []
var _check_timer := 0.0

func _ready() -> void:
	achievements = GameManager._load_json(ACHIEVEMENTS_PATH)
	GameManager.upgrade_purchased.connect(func(_id, _n): check_now())
	GameManager.switch_unlocked.connect(func(_id): check_now())
	GameManager.mastery_reached.connect(func(_id, _l): check_now())
	GameManager.event_triggered.connect(func(_k): check_now())

## Tap/click-driven checks are throttled; state-change signals check at once.
func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.25
		check_now()

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func check_now() -> void:
	for id in achievements.keys():
		if not is_unlocked(id) and _condition_met(achievements[id]):
			unlocked.append(id)
			achievement_unlocked.emit(id)
			GameManager.stats_changed.emit()

func _condition_met(data: Dictionary) -> bool:
	var gm := GameManager
	var value = data.get("condition_value", 0)
	match String(data.get("condition_type", "")):
		"tap_count":
			return gm.tap_count >= float(value)
		"lifetime_clicks":
			return gm.lifetime_clicks >= float(value)
		"critical_click_count":
			return gm.critical_click_count >= float(value)
		"perfect_press_count":
			return gm.perfect_press_count >= float(value)
		"clicks_per_second":
			return gm.get_effective_cps() >= float(value)
		"switch_unlocked":
			return gm.is_switch_unlocked(str(value))
		"switches_unlocked":
			return gm.unlocked_switches.size() >= float(value)
		"upgrade_level_any":
			for id in gm.owned.keys():
				if int(gm.owned[id]) >= int(value):
					return true
			return false
		"total_upgrade_levels":
			var total := 0
			for id in gm.owned.keys():
				total += int(gm.owned[id])
			return total >= int(value)
		"mastery_level_any":
			for id in gm.switches.keys():
				if gm.get_mastery_level(id) >= int(value):
					return true
			return false
		_:
			return false
