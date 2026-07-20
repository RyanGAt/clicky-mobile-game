extends Node

signal clicks_changed(total: float)
signal upgrade_purchased(id: String)
signal switch_unlocked(id: String)
signal switch_equipped(id: String)
signal keycap_unlocked(id: String)
signal keycap_equipped(id: String)

const UPGRADES_PATH := "res://data/upgrades.json"
const SWITCHES_PATH := "res://data/switches.json"
const KEYCAPS_PATH := "res://data/keycaps.json"

const CRITICAL_CLICK_MULTIPLIER := 3.0

var clicks: float = 0.0
var lifetime_clicks: float = 0.0
var tap_count: int = 0
var critical_click_count: int = 0
var click_power: float = 1.0
var clicks_per_second: float = 0.0
var critical_chance: float = 0.0

var upgrades: Dictionary = {}
var owned: Dictionary = {
	"stronger_finger": 0,
	"automatic_finger": 0,
}

var switches: Dictionary = {}
var unlocked_switches: Array = ["office_membrane"]
var equipped_switch: String = "office_membrane"

var keycaps: Dictionary = {}
var unlocked_keycaps: Array = ["plain_beige"]
var equipped_keycap: String = "plain_beige"

var _cps_accumulator: float = 0.0

func _ready() -> void:
	_load_upgrade_data()
	_load_switch_data()
	_load_keycap_data()

func _process(delta: float) -> void:
	var effective_cps := get_effective_cps()
	if effective_cps <= 0.0:
		return
	_cps_accumulator += effective_cps * delta
	if _cps_accumulator >= 1.0:
		var whole := floor(_cps_accumulator)
		_cps_accumulator -= whole
		add_clicks(whole)

func _load_upgrade_data() -> void:
	var file := FileAccess.open(UPGRADES_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % UPGRADES_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		upgrades = parsed

func _load_switch_data() -> void:
	var file := FileAccess.open(SWITCHES_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % SWITCHES_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		switches = parsed

func _load_keycap_data() -> void:
	var file := FileAccess.open(KEYCAPS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % KEYCAPS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		keycaps = parsed

func add_clicks(amount: float) -> void:
	clicks += amount
	lifetime_clicks += amount
	clicks_changed.emit(clicks)
	_check_unlocks()

func tap() -> Dictionary:
	var earned := get_effective_click_power()
	var is_crit := randf() < critical_chance
	if is_crit:
		earned *= CRITICAL_CLICK_MULTIPLIER
		critical_click_count += 1
	tap_count += 1
	add_clicks(earned)
	return {"amount": earned, "is_crit": is_crit}

func get_equipped_switch_data() -> Dictionary:
	return switches.get(equipped_switch, {})

func get_effective_click_power() -> float:
	var multiplier: float = get_equipped_switch_data().get("click_power_multiplier", 1.0)
	return click_power * multiplier

func get_effective_cps() -> float:
	var multiplier: float = get_equipped_switch_data().get("cps_multiplier", 1.0)
	return clicks_per_second * multiplier

func get_upgrade_cost(id: String) -> float:
	var data: Dictionary = upgrades.get(id, {})
	var base_cost: float = data.get("base_cost", 0.0)
	var growth_rate: float = data.get("growth_rate", 1.0)
	var count: int = owned.get(id, 0)
	return base_cost * pow(growth_rate, count)

func can_afford(id: String) -> bool:
	return clicks >= get_upgrade_cost(id)

func buy_upgrade(id: String) -> bool:
	if not can_afford(id):
		return false
	var cost := get_upgrade_cost(id)
	clicks -= cost
	owned[id] = owned.get(id, 0) + 1

	var data: Dictionary = upgrades.get(id, {})
	if data.has("click_power_bonus"):
		click_power += float(data["click_power_bonus"])
	if data.has("cps_bonus"):
		clicks_per_second += float(data["cps_bonus"])
	if data.has("crit_chance_bonus"):
		critical_chance = clampf(critical_chance + float(data["crit_chance_bonus"]), 0.0, 1.0)

	clicks_changed.emit(clicks)
	upgrade_purchased.emit(id)
	return true

func _check_unlocks() -> void:
	for id in switches.keys():
		if unlocked_switches.has(id):
			continue
		var requirement: float = switches[id].get("unlock_requirement_clicks", 0.0)
		if lifetime_clicks >= requirement:
			unlocked_switches.append(id)
			switch_unlocked.emit(id)

	for id in keycaps.keys():
		if unlocked_keycaps.has(id):
			continue
		var requirement: float = keycaps[id].get("unlock_requirement_clicks", 0.0)
		if lifetime_clicks >= requirement:
			unlocked_keycaps.append(id)
			keycap_unlocked.emit(id)

func is_switch_unlocked(id: String) -> bool:
	return unlocked_switches.has(id)

func equip_switch(id: String) -> bool:
	if not is_switch_unlocked(id):
		return false
	equipped_switch = id
	switch_equipped.emit(id)
	return true

func is_keycap_unlocked(id: String) -> bool:
	return unlocked_keycaps.has(id)

func equip_keycap(id: String) -> bool:
	if not is_keycap_unlocked(id):
		return false
	equipped_keycap = id
	keycap_equipped.emit(id)
	return true

func format_number(value: float) -> String:
	var abs_value := absf(value)
	if abs_value < 1000.0:
		return str(int(round(value)))

	var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var tier := int(floor(log(abs_value) / log(1000.0)))
	tier = clampi(tier, 1, suffixes.size())
	var scaled := value / pow(1000.0, tier)
	return "%.2f%s" % [scaled, suffixes[tier - 1]]
