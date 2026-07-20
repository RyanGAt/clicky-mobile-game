extends Node

signal clicks_changed(total: float)
signal upgrade_purchased(id: String)

const UPGRADES_PATH := "res://data/upgrades.json"

var clicks: float = 0.0
var click_power: float = 1.0
var clicks_per_second: float = 0.0

var upgrades: Dictionary = {}
var owned: Dictionary = {
	"stronger_finger": 0,
	"automatic_finger": 0,
}

var _cps_accumulator: float = 0.0

func _ready() -> void:
	_load_upgrade_data()

func _process(delta: float) -> void:
	if clicks_per_second <= 0.0:
		return
	_cps_accumulator += clicks_per_second * delta
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

func add_clicks(amount: float) -> void:
	clicks += amount
	clicks_changed.emit(clicks)

func tap() -> float:
	var earned := click_power
	add_clicks(earned)
	return earned

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

	clicks_changed.emit(clicks)
	upgrade_purchased.emit(id)
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
