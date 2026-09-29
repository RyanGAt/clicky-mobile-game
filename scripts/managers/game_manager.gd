extends Node
## Game state and economy rules. All balance numbers live in data/*.json.
## Tap power, CPS and crit chance are derived from owned upgrade counts, so a
## rebalance of the JSON applies cleanly to existing saves.

signal clicks_changed(total: float)
signal stats_changed
signal upgrade_purchased(id: String, amount: int)
signal switch_unlocked(id: String)
signal switch_equipped(id: String)
signal keycap_unlocked(id: String)
signal keycap_equipped(id: String)

const UPGRADES_PATH := "res://data/upgrades.json"
const SWITCHES_PATH := "res://data/switches.json"
const KEYCAPS_PATH := "res://data/keycaps.json"
const BALANCE_PATH := "res://data/balance.json"

const DEFAULT_SWITCH := "office_membrane"
const DEFAULT_KEYCAP := "plain_beige"

var clicks: float = 0.0
var lifetime_clicks: float = 0.0
var tap_count: int = 0
var critical_click_count: int = 0

var balance: Dictionary = {}
var upgrades: Dictionary = {}
var owned: Dictionary = {}

var switches: Dictionary = {}
var unlocked_switches: Array = [DEFAULT_SWITCH]
var equipped_switch: String = DEFAULT_SWITCH

var keycaps: Dictionary = {}
var unlocked_keycaps: Array = [DEFAULT_KEYCAP]
var equipped_keycap: String = DEFAULT_KEYCAP

var _cps_accumulator: float = 0.0

func _ready() -> void:
	balance = _load_json(BALANCE_PATH)
	upgrades = _load_json(UPGRADES_PATH)
	switches = _load_json(SWITCHES_PATH)
	keycaps = _load_json(KEYCAPS_PATH)
	for id in upgrades.keys():
		owned[id] = 0

func _process(delta: float) -> void:
	var effective_cps := get_effective_cps()
	if effective_cps <= 0.0:
		return
	# Accumulate fractional income and pay out a few times a second so the
	# counter ticks smoothly without emitting a signal every frame.
	_cps_accumulator += effective_cps * delta
	if _cps_accumulator >= maxf(1.0, effective_cps * 0.1):
		var payout := _cps_accumulator
		_cps_accumulator = 0.0
		add_clicks(payout)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Invalid JSON in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		push_error("%s must contain a JSON object" % path)
		return {}
	return json.data

func reset_progress() -> void:
	clicks = 0.0
	lifetime_clicks = 0.0
	tap_count = 0
	critical_click_count = 0
	_cps_accumulator = 0.0
	for id in upgrades.keys():
		owned[id] = 0
	unlocked_switches = [DEFAULT_SWITCH]
	equipped_switch = DEFAULT_SWITCH
	unlocked_keycaps = [DEFAULT_KEYCAP]
	equipped_keycap = DEFAULT_KEYCAP
	clicks_changed.emit(clicks)
	stats_changed.emit()

# --- Economy ----------------------------------------------------------------

func add_clicks(amount: float) -> void:
	if amount <= 0.0:
		return
	clicks += amount
	lifetime_clicks += amount
	clicks_changed.emit(clicks)
	_check_unlocks()

func tap() -> Dictionary:
	var earned := get_effective_click_power()
	var is_crit := randf() < get_crit_chance()
	if is_crit:
		earned *= get_crit_multiplier()
		critical_click_count += 1
	tap_count += 1
	add_clicks(earned)
	return {"amount": earned, "is_crit": is_crit}

## Multiplier from "milestone" levels: every N owned doubles that upgrade.
func get_milestone_multiplier(id: String) -> float:
	var data: Dictionary = upgrades.get(id, {})
	var every := int(data.get("milestone_every", 0))
	if every <= 0:
		return 1.0
	return pow(float(data.get("milestone_multiplier", 2.0)), floorf(float(owned.get(id, 0)) / every))

func _upgrade_total(stat: String) -> float:
	var total := 0.0
	for id in upgrades.keys():
		var data: Dictionary = upgrades[id]
		if data.has(stat):
			total += float(data[stat]) * float(owned.get(id, 0)) * get_milestone_multiplier(id)
	return total

func get_base_click_power() -> float:
	return float(balance.get("base_click_power", 1.0)) + _upgrade_total("click_power_bonus")

func get_base_cps() -> float:
	return _upgrade_total("cps_bonus")

func get_crit_chance() -> float:
	var total := 0.0
	for id in upgrades.keys():
		total += float(upgrades[id].get("crit_chance_bonus", 0.0)) * float(owned.get(id, 0))
	return clampf(total, 0.0, float(balance.get("max_crit_chance", 0.5)))

func get_crit_multiplier() -> float:
	return float(balance.get("crit_multiplier", 3.0))

func get_equipped_switch_data() -> Dictionary:
	return switches.get(equipped_switch, {})

func get_effective_click_power() -> float:
	return get_base_click_power() * float(get_equipped_switch_data().get("click_power_multiplier", 1.0))

## The single CPS formula used by both live income and offline earnings.
func get_effective_cps() -> float:
	return get_base_cps() * float(get_equipped_switch_data().get("cps_multiplier", 1.0))

## Current per-level benefit of an upgrade, including milestone doubling.
func get_upgrade_benefit(id: String) -> Dictionary:
	var data: Dictionary = upgrades.get(id, {})
	var m := get_milestone_multiplier(id)
	for stat in ["click_power_bonus", "cps_bonus", "crit_chance_bonus"]:
		if data.has(stat):
			var per_level := float(data[stat]) * (1.0 if stat == "crit_chance_bonus" else m)
			return {"stat": stat, "per_level": per_level, "total": per_level * float(owned.get(id, 0))}
	return {}

func get_max_owned(id: String) -> int:
	return int(upgrades.get(id, {}).get("max_owned", -1))

func is_upgrade_maxed(id: String) -> bool:
	var cap := get_max_owned(id)
	return cap >= 0 and int(owned.get(id, 0)) >= cap

## Cost of buying `amount` levels starting at the current level (geometric sum).
func get_upgrade_cost(id: String, amount: int = 1) -> float:
	var data: Dictionary = upgrades.get(id, {})
	var base_cost := float(data.get("base_cost", 0.0))
	var r := float(data.get("growth_rate", 1.0))
	var first := base_cost * pow(r, float(owned.get(id, 0)))
	if amount <= 1:
		return first
	if is_equal_approx(r, 1.0):
		return first * amount
	return first * (pow(r, amount) - 1.0) / (r - 1.0)

## How many levels are affordable right now (respecting max_owned).
func get_max_affordable(id: String) -> int:
	var data: Dictionary = upgrades.get(id, {})
	var r := float(data.get("growth_rate", 1.0))
	var first := get_upgrade_cost(id)
	if first <= 0.0 or clicks < first:
		return 0
	var n: int
	if is_equal_approx(r, 1.0):
		n = int(floorf(clicks / first))
	else:
		n = int(floorf(log(clicks * (r - 1.0) / first + 1.0) / log(r)))
		# Guard float rounding at the boundary.
		while n > 0 and get_upgrade_cost(id, n) > clicks:
			n -= 1
	var cap := get_max_owned(id)
	if cap >= 0:
		n = mini(n, cap - int(owned.get(id, 0)))
	return maxi(n, 0)

## Levels a purchase in the given mode would buy (0 = can't buy). mode: 1, 10 or -1 (max).
func get_purchase_amount(id: String, mode: int) -> int:
	if is_upgrade_maxed(id):
		return 0
	if mode < 0:
		return get_max_affordable(id)
	var amount := mode
	var cap := get_max_owned(id)
	if cap >= 0:
		amount = mini(amount, cap - int(owned.get(id, 0)))
	return amount

func can_afford(id: String, amount: int = 1) -> bool:
	return amount > 0 and not is_upgrade_maxed(id) and clicks >= get_upgrade_cost(id, amount)

func buy_upgrade(id: String, amount: int = 1) -> bool:
	if not upgrades.has(id) or not can_afford(id, amount):
		return false
	clicks -= get_upgrade_cost(id, amount)
	owned[id] = int(owned.get(id, 0)) + amount
	clicks_changed.emit(clicks)
	stats_changed.emit()
	upgrade_purchased.emit(id, amount)
	return true

# --- Switches and keycaps ---------------------------------------------------

func _check_unlocks() -> void:
	for id in switches.keys():
		if not unlocked_switches.has(id) and lifetime_clicks >= float(switches[id].get("unlock_requirement_clicks", 0.0)):
			unlocked_switches.append(id)
			switch_unlocked.emit(id)
	for id in keycaps.keys():
		if not unlocked_keycaps.has(id) and lifetime_clicks >= float(keycaps[id].get("unlock_requirement_clicks", 0.0)):
			unlocked_keycaps.append(id)
			keycap_unlocked.emit(id)

func is_switch_unlocked(id: String) -> bool:
	return unlocked_switches.has(id)

func equip_switch(id: String) -> bool:
	if not is_switch_unlocked(id):
		return false
	equipped_switch = id
	switch_equipped.emit(id)
	stats_changed.emit()
	return true

func is_keycap_unlocked(id: String) -> bool:
	return unlocked_keycaps.has(id)

func equip_keycap(id: String) -> bool:
	if not is_keycap_unlocked(id):
		return false
	equipped_keycap = id
	keycap_equipped.emit(id)
	return true

# --- Formatting -------------------------------------------------------------

func format_number(value: float) -> String:
	var abs_value := absf(value)
	if abs_value < 1000.0:
		if abs_value < 10.0 and not is_equal_approx(value, roundf(value)):
			return "%.1f" % value
		return str(int(floorf(value)))
	var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var tier := clampi(int(floorf(log(abs_value) / log(1000.0))), 1, suffixes.size())
	var scaled := value / pow(1000.0, tier)
	# Truncate (not round) so 999.99K never displays as "1000K".
	if scaled < 10.0:
		return "%.2f%s" % [floorf(scaled * 100.0) / 100.0, suffixes[tier - 1]]
	if scaled < 100.0:
		return "%.1f%s" % [floorf(scaled * 10.0) / 10.0, suffixes[tier - 1]]
	return "%d%s" % [int(scaled), suffixes[tier - 1]]
