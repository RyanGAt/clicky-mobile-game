class_name EconomySim
extends RefCounted
## Plays the real GameManager for N seconds with a simple "sensible player":
## taps at a fixed rate, always equips the switch that earns most for its
## style, and buys the upgrade with the best income gain per Click spent.
## Used by tests and by `godot --headless -s res://tools/run_sim.gd`.

static func income(gm: Node, tps: float) -> float:
	var crit: float = gm.get_crit_chance() * (gm.get_crit_multiplier() - 1.0)
	return gm.get_effective_click_power() * tps * (1.0 + crit) + gm.get_effective_cps()

static func best_switch(gm: Node, tps: float) -> String:
	var keep: String = gm.equipped_switch
	var best := keep
	var best_income := -1.0
	for id in gm.unlocked_switches:
		gm.equipped_switch = id
		var v := income(gm, tps)
		if v > best_income:
			best_income = v
			best = id
	gm.equipped_switch = keep
	return best

## Best income-per-cost among upgrades reachable within ~20s of income
## (a real player buys what's nearly affordable rather than saving forever).
static func best_upgrade(gm: Node, tps: float) -> String:
	var base := income(gm, tps)
	var reach: float = gm.clicks + base * 20.0
	var best := ""
	var best_ratio := 0.0
	for id in gm.upgrades.keys():
		if gm.is_upgrade_maxed(id):
			continue
		var cost: float = gm.get_upgrade_cost(id)
		if cost > reach:
			continue
		gm.owned[id] += 1
		var gain := income(gm, tps) - base
		gm.owned[id] -= 1
		var ratio := gain / cost
		if ratio > best_ratio:
			best_ratio = ratio
			best = id
	return best

## tps may be a float or a Callable(t) -> float for profiles that change over time.
static func run(gm: Node, am: Node, tps_profile, seconds: float, dt: float = 0.25) -> Dictionary:
	gm.reset_progress()
	am.unlocked = []
	var marks := {"unlock": {}, "first_buy": {}, "per_minute": [], "longest_wait": 0.0}
	var t := 0.0
	var tap_budget := 0.0
	var last_buy := 0.0
	var lifetime_by_minute: Array = []
	while t < seconds:
		var tps: float = tps_profile.call(t) if tps_profile is Callable else float(tps_profile)
		tap_budget += tps * dt
		while tap_budget >= 1.0:
			tap_budget -= 1.0
			gm.tap()
		gm.add_clicks(gm.get_effective_cps() * dt)
		gm.game_time += dt
		t += dt
		for id in gm.unlocked_switches:
			if not marks["unlock"].has(id):
				marks["unlock"][id] = t
		var sw := best_switch(gm, tps)
		if sw != gm.equipped_switch:
			gm.equip_switch(sw)
		var target := best_upgrade(gm, tps)
		while target != "" and gm.can_afford(target):
			gm.buy_upgrade(target)
			if not marks["first_buy"].has(target):
				marks["first_buy"][target] = t
			if t - last_buy > marks["longest_wait"]:
				marks["longest_wait"] = t - last_buy
				marks["longest_wait_ends"] = t
			last_buy = t
			target = best_upgrade(gm, tps)
		if fmod(t, 1.0) < dt * 0.5:
			am.check_now()
		if fmod(t, 60.0) < dt * 0.5:
			marks["per_minute"].append(income(gm, tps))
			lifetime_by_minute.append(gm.lifetime_clicks)
	marks["achievements"] = am.unlocked.size()
	marks["lifetime_by_minute"] = lifetime_by_minute
	marks["final_income"] = gm.get_effective_cps() + gm.get_effective_click_power()
	marks["taps"] = gm.tap_count
	return marks

static func describe(name: String, m: Dictionary) -> String:
	var parts: Array = []
	for id in ["budget_linear", "scratchy_tactile", "deafening_clicky", "creamy_linear"]:
		parts.append("%s %s" % [id, _mmss(m["unlock"].get(id, -1.0))])
	var buys: Array = []
	for id in m["first_buy"].keys():
		buys.append("%s %s" % [id, _mmss(m["first_buy"][id])])
	return "%s\n  unlocks: %s\n  first buys: %s\n  longest gap between purchases: %ss (ending %s), achievements: %d, income/s at end: %s\n  lifetime @5/10/20/30/45/60m: %s" % [
		name, ", ".join(parts), ", ".join(buys), int(m["longest_wait"]), _mmss(m.get("longest_wait_ends", -1.0)), m["achievements"], String.num_scientific(m["final_income"]), _lifetimes(m)]

static func _mmss(t: float) -> String:
	if t < 0.0:
		return "--"
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

static func _lifetimes(m: Dictionary) -> String:
	var out: Array = []
	for minute in [5, 10, 20, 30, 45, 60]:
		if minute - 1 < m["lifetime_by_minute"].size():
			out.append(String.num_scientific(snappedf(m["lifetime_by_minute"][minute - 1], 1.0)))
	return " / ".join(out)

## Mostly passive: taps to get going for 3 minutes, then barely touches it.
static func passive_profile(t: float) -> float:
	return 1.5 if t < 180.0 else 0.3
