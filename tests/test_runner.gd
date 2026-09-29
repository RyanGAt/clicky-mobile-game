extends SceneTree
## Headless smoke/regression tests.
##   godot --headless -s res://tests/test_runner.gd
## Uses the real autoloads and main scene. Backs up and restores any existing
## user save so running tests never destroys a player's progress.

const SAVE := "user://save.dat"
const BACKUP := "user://save.dat.testbackup"

var failures := 0
var passes := 0

func _initialize() -> void:
	_run.call_deferred()

func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: ", what)

func frames(n: int = 1) -> void:
	for i in n:
		await process_frame

func gm() -> Node:
	return root.get_node("GameManager")

func sm() -> Node:
	return root.get_node("SaveManager")

func touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	root.push_input(ev, true)

func reset_state() -> void:
	gm().reset_progress()
	gm().game_time = 0.0
	root.get_node("AchievementManager").unlocked = []
	sm().consume_pending_offline_earnings()
	sm().last_load_problem = ""
	sm().seen_hints = {}

func _run() -> void:
	# Autoloads already loaded any real save; move it aside and start clean.
	if FileAccess.file_exists(SAVE):
		DirAccess.rename_absolute(SAVE, BACKUP)
	await frames(2)
	var tests: Array = get_script().get_script_method_list().filter(func(m): return String(m.name).begins_with("test_"))
	for m in tests:
		reset_state()
		print("- ", m.name)
		await call(m.name)
	_clear_saves()
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------

func _spawn_main() -> Control:
	var scene: PackedScene = load("res://scenes/main/main_game.tscn")
	var main: Control = scene.instantiate()
	root.add_child(main)
	await frames(3)
	return main

func _switch_center(main: Control) -> Vector2:
	var view: Control = main.find_child("SwitchView", true, false)
	return view.get_global_rect().get_center()

func test_touch_taps_switch() -> void:
	var main := await _spawn_main()
	var center := _switch_center(main)
	for i in 30:
		touch(center, true)
		touch(center, false)
	await frames(1)
	check(gm().tap_count == 30, "30 rapid taps register (got %d)" % gm().tap_count)
	check(gm().clicks >= 30.0, "taps earn clicks")
	main.queue_free()
	await frames(1)

func test_multitouch_hold_and_tap() -> void:
	var main := await _spawn_main()
	var center := _switch_center(main)
	touch(center, true, 0) # hold
	for i in 5:
		touch(center + Vector2(40, 0), true, 1)
		touch(center + Vector2(40, 0), false, 1)
	touch(center, false, 0)
	await frames(1)
	check(gm().tap_count == 6, "held finger + 5 second-finger taps = 6 taps (got %d)" % gm().tap_count)
	main.queue_free()
	await frames(1)

func test_finger_on_sheet_does_not_block_switch() -> void:
	var main := await _spawn_main()
	var sheet: Control = main.find_child("Sheet", true, false)
	var on_sheet := sheet.get_global_rect().get_center()
	touch(on_sheet, true, 0) # thumb resting on the upgrades list
	var center := _switch_center(main)
	for i in 3:
		touch(center, true, 1)
		touch(center, false, 1)
	touch(on_sheet, false, 0)
	await frames(1)
	check(gm().tap_count == 3, "switch taps register while another finger is on the sheet (got %d)" % gm().tap_count)
	main.queue_free()
	await frames(1)

func test_modal_blocks_switch() -> void:
	var main := await _spawn_main()
	main._open_popup(load("res://scripts/ui/popups/settings_popup.gd").new())
	await frames(2)
	touch(_switch_center(main), true)
	touch(_switch_center(main), false)
	await frames(1)
	check(gm().tap_count == 0, "an open popup stops taps reaching the switch")
	main.queue_free()
	await frames(1)

# --- Economy ------------------------------------------------------------------

func test_bulk_cost_matches_single_purchases() -> void:
	var g := gm()
	var bulk: float = g.get_upgrade_cost("stronger_finger", 10)
	var total := 0.0
	for i in 10:
		total += g.get_upgrade_cost("stronger_finger")
		g.owned["stronger_finger"] += 1
	check(absf(bulk - total) < 0.01 * total, "x10 cost equals ten single costs (%f vs %f)" % [bulk, total])

func test_buy_max() -> void:
	var g := gm()
	g.add_clicks(5000)
	var n: int = g.get_max_affordable("stronger_finger")
	check(n > 1, "can afford several levels with 5000")
	check(g.get_upgrade_cost("stronger_finger", n) <= g.clicks, "max amount is affordable")
	check(g.get_upgrade_cost("stronger_finger", n + 1) > g.clicks, "max amount is maximal")
	check(g.buy_upgrade("stronger_finger", n), "buy max succeeds")
	check(g.clicks >= 0.0, "clicks never negative")
	check(int(g.owned["stronger_finger"]) == n, "owned count updated")

func test_cannot_overspend_or_exceed_cap() -> void:
	var g := gm()
	check(not g.buy_upgrade("automatic_finger"), "can't buy with 0 clicks")
	g.add_clicks(1e12)
	check(g.get_purchase_amount("lucky_press", -1) == 10, "Lucky Press max is capped at 10")
	g.buy_upgrade("lucky_press", 10)
	check(not g.buy_upgrade("lucky_press"), "can't exceed max_owned")
	check(g.get_crit_chance() <= float(g.balance["max_crit_chance"]), "crit chance capped")

func test_stats_and_milestones() -> void:
	var g := gm()
	g.owned["stronger_finger"] = 10
	check(is_equal_approx(g.get_base_click_power(), 1.0 + 10 * 2), "10 Stronger Fingers doubles to +20 per tap")
	g.owned["automatic_finger"] = 3
	check(is_equal_approx(g.get_effective_cps(), 9.0), "3 Automatic Fingers = 9 CPS")
	g.unlocked_switches.append("budget_linear")
	g.equip_switch("budget_linear")
	check(is_equal_approx(g.get_effective_cps(), 18.0), "Budget Linear doubles CPS")

func test_equip_locked_switch_fails() -> void:
	check(not gm().equip_switch("budget_linear"), "locked switch can't be equipped")
	check(gm().equipped_switch == "office_membrane", "default switch stays equipped")

func test_budget_linear_unlocks_from_lifetime_clicks() -> void:
	var g := gm()
	var fired := []
	var cb := func(id): fired.append(id)
	g.switch_unlocked.connect(cb)
	g.add_clicks(float(g.switches["budget_linear"]["unlock_requirement_clicks"]))
	g.switch_unlocked.disconnect(cb)
	check(fired.has("budget_linear"), "Budget Linear unlocks at its lifetime threshold")

## Simulates an active player (4 taps/s, greedily buying the cheapest upgrade)
## against the real GameManager to check the first-10-minutes pacing targets.
func test_pacing_first_ten_minutes() -> void:
	var g := gm()
	seed(1234)
	var t := 0.0
	var dt := 0.25
	var marks := {}
	while t < 600.0:
		g.tap() # one tap per 0.25s step = 4 taps per second
		g.add_clicks(g.get_effective_cps() * dt)
		g.game_time += dt
		t += dt
		if not marks.has("bl") and g.is_switch_unlocked("budget_linear"):
			marks["bl"] = t
			g.equip_switch("budget_linear")
		var bought := true
		while bought:
			bought = false
			var cheapest := ""
			for id in g.upgrades.keys():
				if g.can_afford(id) and (cheapest == "" or g.get_upgrade_cost(id) < g.get_upgrade_cost(cheapest)):
					cheapest = id
			if cheapest != "":
				g.buy_upgrade(cheapest)
				bought = true
				if not marks.has(cheapest):
					marks[cheapest] = t
		if not marks.has("cps10") and g.get_effective_cps() >= 10.0:
			marks["cps10"] = t
	print("    pacing: ", marks, "  final tap=%s cps=%s" % [g.format_number(g.get_effective_click_power()), g.format_number(g.get_effective_cps())])
	check(marks.get("stronger_finger", 0) >= 8.0 and marks.get("stronger_finger", 999) <= 20.0, "first upgrade in ~10-20s")
	check(marks.get("automatic_finger", 0) >= 40.0 and marks.get("automatic_finger", 999) <= 90.0, "first Automatic Finger in ~45-90s")
	check(marks.get("cps10", 999) <= 150.0, "passive income noticeable (10/s) within ~2 min")
	check(marks.get("bl", 0) >= 150.0 and marks.get("bl", 999) <= 330.0, "Budget Linear unlocks around 3-5 min (got %s)" % marks.get("bl"))
	check(g.get_effective_cps() < 1e5, "no runaway numbers by 10 minutes")

# --- Saving -------------------------------------------------------------------

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _clear_saves() -> void:
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("save.") and not f.ends_with("testbackup"):
			DirAccess.remove_absolute("user://" + f)

func _preserved_files(kind: String) -> Array:
	return Array(DirAccess.get_files_at("user://")).filter(func(f): return f.begins_with("save.%s." % kind))

func test_save_roundtrip() -> void:
	_clear_saves()
	var g := gm()
	g.add_clicks(123456)
	g.owned["stronger_finger"] = 7
	g.owned["lucky_press"] = 2
	g.equip_switch("budget_linear")
	g.equip_keycap("smiley_face")
	sm().settings["vibration_enabled"] = false
	sm().save_game()
	g.reset_progress()
	sm().settings["vibration_enabled"] = true
	sm().load_game()
	sm().consume_pending_offline_earnings()
	check(g.equipped_switch == "budget_linear", "equipped switch persists")
	check(g.equipped_keycap == "smiley_face", "equipped keycap persists")
	check(int(g.owned["stronger_finger"]) == 7 and int(g.owned["lucky_press"]) == 2, "owned upgrades persist")
	check(g.clicks >= 123456.0 - g.get_upgrade_cost("stronger_finger", 0), "clicks persist")
	check(sm().settings["vibration_enabled"] == false, "settings persist")
	sm().save_game()
	check(FileAccess.file_exists("user://save.dat.bak"), "previous save kept as .bak")

func test_corrupt_save_is_preserved_not_wiped() -> void:
	_clear_saves()
	_write("user://save.dat", "{ this is not json")
	sm().last_load_problem = ""
	sm().load_game()
	check(_preserved_files("corrupt").size() == 1, "corrupt save copied aside")
	check(sm().last_load_problem != "", "problem reported to UI")
	check(gm().clicks == 0.0, "fresh state after unreadable save")
	sm().save_game()
	check(_preserved_files("corrupt").size() == 1, "later saves don't touch the preserved copy")

func test_corrupt_save_falls_back_to_backup() -> void:
	_clear_saves()
	_write("user://save.dat", "[1, 2")
	_write("user://save.dat.bak", JSON.stringify({"version": 2, "clicks": 777, "lifetime_clicks": 777, "owned": {"stronger_finger": 3}}))
	sm().load_game()
	check(gm().clicks == 777.0, "backup restored when main save is corrupt")
	check(int(gm().owned["stronger_finger"]) == 3, "backup upgrades restored")

func test_newer_version_save_preserved() -> void:
	_clear_saves()
	_write("user://save.dat", JSON.stringify({"version": 99, "clicks": 5}))
	sm().load_game()
	check(_preserved_files("unsupported").size() == 1, "unsupported-version save copied aside")
	check(gm().clicks == 0.0, "unsupported save not half-loaded")

func test_v1_save_migrates_to_derived_stats() -> void:
	_clear_saves()
	_write("user://save.dat", JSON.stringify({
		"version": 1, "clicks": 50, "lifetime_clicks": 900, "click_power": 9999,
		"clicks_per_second": 9999, "critical_chance": 1.0,
		"owned": {"stronger_finger": 4, "automatic_finger": 2, "bogus": 3},
		"unlocked_switches": ["office_membrane", "not_a_switch"], "equipped_switch": "not_a_switch",
		"unlocked_keycaps": ["plain_beige", "transparent"], "equipped_keycap": "transparent",
		"unlocked_achievements": ["first_click", 42]}))
	sm().load_game()
	var g := gm()
	check(is_equal_approx(g.get_base_click_power(), 5.0), "click power derived from owned, not stale saved value")
	check(is_equal_approx(g.get_base_cps(), 6.0), "cps derived from owned")
	check(g.equipped_switch == "office_membrane", "invalid equipped switch falls back")
	check(g.equipped_keycap == "plain_beige", "removed keycap falls back")
	check(not g.owned.has("bogus"), "unknown upgrades ignored")
	check(root.get_node("AchievementManager").unlocked == ["first_click"], "achievement ids validated")

func test_offline_uses_live_cps() -> void:
	_clear_saves()
	var g := gm()
	g.owned["automatic_finger"] = 5
	g.unlocked_switches.append("budget_linear")
	g.equip_switch("budget_linear")
	var data: Dictionary = sm().build_save_data()
	data["last_active_unix"] = Time.get_unix_time_from_system() - 3600.0
	_write("user://save.dat", JSON.stringify(data))
	var live_cps: float = g.get_effective_cps()
	g.reset_progress()
	sm().consume_pending_offline_earnings()
	sm().load_game()
	var got: Dictionary = sm().consume_pending_offline_earnings()
	var expected := 3600.0 * live_cps * float(g.balance["offline_efficiency"])
	check(absf(float(got["earnings"]) - expected) <= expected * 0.01, "offline = elapsed * live CPS * efficiency (%f vs %f)" % [got["earnings"], expected])

func test_offline_capped_and_clock_rollback_safe() -> void:
	_clear_saves()
	var g := gm()
	g.owned["automatic_finger"] = 1
	var cps: float = g.get_effective_cps()
	var cap_s := float(g.balance["max_offline_hours"]) * 3600.0
	check(is_equal_approx(sm().calculate_offline_earnings(cap_s * 10.0), cap_s * cps * float(g.balance["offline_efficiency"])), "offline earnings capped")
	check(sm().calculate_offline_earnings(-5000.0) == 0.0, "clock moved backwards gives nothing")

func test_background_resume_grants_offline() -> void:
	var g := gm()
	g.owned["automatic_finger"] = 2
	sm().consume_pending_offline_earnings()
	sm()._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	sm()._paused_at_unix -= 600.0 # pretend 10 minutes passed in the background
	sm()._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var got: Dictionary = sm().consume_pending_offline_earnings()
	check(float(got["earnings"]) > 0.0, "resume after background grants offline earnings")

# --- Missing content -------------------------------------------------------------

func test_missing_audio_and_art_are_safe() -> void:
	var fb := root.get_node("Feedback")
	for s in fb.Sound.values():
		fb.play(s)
	check(true, "playing every sound with no audio files does not crash")
	var tile: Control = load("res://scripts/ui/components/icon_tile.gd").new("res://assets/does_not_exist.png", "Ghost Item", 64)
	root.add_child(tile)
	await frames(1)
	check(tile.get_child_count() == 1, "missing art falls back to initials")
	tile.queue_free()

# --- Milestone 2: switches, upgrades, mastery, events, collection -------------

const ALL_SWITCHES := ["office_membrane", "budget_linear", "scratchy_tactile", "deafening_clicky", "creamy_linear"]

func test_five_switch_progression_order() -> void:
	var g := gm()
	check(g.switches.keys() == ALL_SWITCHES, "exactly the five planned switches, in tier order")
	var last := -1.0
	for id in ALL_SWITCHES:
		var req := float(g.switches[id]["unlock_requirement_clicks"])
		check(req > last, "%s requirement increases with tier" % id)
		last = req
		check(g.switches[id].has("press_audio") and g.switches[id].has("release_audio"), "%s defines press/release audio hooks" % id)
		var art: Dictionary = load("res://scripts/ui/ui_style.gd").switch_art(id)
		check(art["texture"] != null, "%s has art or a declared placeholder" % id)
	for id in ALL_SWITCHES:
		g.add_clicks(maxf(float(g.switches[id]["unlock_requirement_clicks"]) - g.lifetime_clicks, 0.0))
		check(g.is_switch_unlocked(id), "%s unlocks at its threshold" % id)
		check(g.equip_switch(id), "%s can be equipped once unlocked" % id)

func test_switch_personalities() -> void:
	var g := gm()
	g.unlocked_switches = ALL_SWITCHES.duplicate()
	g.owned["stronger_finger"] = 5
	g.owned["automatic_finger"] = 5
	var stats := {}
	for id in ALL_SWITCHES:
		g.equip_switch(id)
		stats[id] = {"tap": g.get_effective_click_power(), "cps": g.get_effective_cps(), "crit_m": g.get_crit_multiplier(), "crit_c": g.get_crit_chance()}
	check(stats["scratchy_tactile"]["tap"] > stats["budget_linear"]["tap"] * 1.5, "Scratchy Tactile is much stronger for tapping")
	check(stats["scratchy_tactile"]["cps"] < stats["budget_linear"]["cps"], "Scratchy Tactile is weaker for passive than Budget Linear")
	check(stats["deafening_clicky"]["crit_m"] > stats["scratchy_tactile"]["crit_m"] and stats["deafening_clicky"]["crit_c"] > stats["scratchy_tactile"]["crit_c"], "Deafening Clicky boosts crits")
	check(stats["creamy_linear"]["cps"] > stats["deafening_clicky"]["cps"] * 2.0, "Creamy Linear is the passive switch")

func test_new_upgrade_maths() -> void:
	var g := gm()
	check(g.upgrades.size() >= 6 and g.upgrades.size() <= 8, "6-8 upgrades (got %d)" % g.upgrades.size())
	g.owned["stronger_finger"] = 4 # base 5 per tap
	var base: float = g.get_effective_click_power()
	g.owned["better_spring"] = 3
	check(is_equal_approx(g.get_effective_click_power(), base * (1.0 + 3.0 * g.upgrades["better_spring"]["tap_percent_bonus"])), "Better Spring is a % tap multiplier")
	g.owned["typing_cat"] = 10
	check(is_equal_approx(g.get_base_cps(), 10.0 * g.upgrades["typing_cat"]["cps_bonus"] * 2.0), "Typing Cat doubles at 10 levels")
	var tap_before: float = g.get_effective_click_power()
	var cps_before: float = g.get_effective_cps()
	g.owned["lubed_switch"] = 2
	var k := 1.0 + 2.0 * float(g.upgrades["lubed_switch"]["global_percent_bonus"])
	check(is_equal_approx(g.get_effective_click_power(), tap_before * k) and is_equal_approx(g.get_effective_cps(), cps_before * k), "Lubed Switch multiplies taps and passive")
	check(g.get_max_owned("lubed_switch") > 0, "Lubed Switch is capped")
	check(g.get_upgrade_cost("typing_cat", 10) > 9.0 * g.get_upgrade_cost("typing_cat"), "bulk cost grows geometrically for new upgrades")

func test_mastery_tracking() -> void:
	var g := gm()
	var reached := []
	var cb := func(id, level): reached.append([id, level])
	g.mastery_reached.connect(cb)
	var t: Array = g.get_mastery_thresholds()
	for i in int(t[0]) - 1:
		g.tap()
	check(g.get_mastery_level("office_membrane") == 0, "no mastery before first threshold")
	var tap_before: float = g.get_effective_click_power()
	g.tap()
	check(g.get_mastery_level("office_membrane") == 1, "mastery 1 at %d presses" % int(t[0]))
	check(reached == [["office_membrane", 1]], "mastery signal fired once")
	check(g.get_effective_click_power() > tap_before, "mastery gives a small permanent bonus")
	g.unlocked_switches.append("budget_linear")
	g.equip_switch("budget_linear")
	g.tap()
	check(int(g.presses_by_switch.get("budget_linear", 0)) == 1 and g.get_mastery_level("budget_linear") == 0, "presses count per equipped switch")
	g.presses_by_switch["budget_linear"] = int(t[-1])
	check(g.get_mastery_level("budget_linear") == t.size() and g.get_mastered_count() == 1, "full mastery counted")
	check(g.get_mastery_multiplier("budget_linear") <= 1.15, "mastery bonus stays modest")
	g.mastery_reached.disconnect(cb)

func test_perfect_press() -> void:
	var g := gm()
	var chance = g.balance["perfect_press_chance"]
	var crit = g.balance["max_crit_chance"]
	g.balance["perfect_press_chance"] = 1.0
	g.balance["max_crit_chance"] = 0.0
	var fired := []
	var cb := func(k): fired.append(k)
	g.event_triggered.connect(cb)
	var result: Dictionary = g.tap()
	g.event_triggered.disconnect(cb)
	g.balance["perfect_press_chance"] = chance
	g.balance["max_crit_chance"] = crit
	check(result["is_perfect"] and is_equal_approx(result["amount"], float(g.balance["perfect_press_multiplier"])), "Perfect Press multiplies the tap")
	check(g.perfect_press_count == 1 and fired.has("perfect_press"), "Perfect Press counted and announced")
	check(float(chance) > 0.0 and float(chance) < 0.02, "Perfect Press is rare")

func test_hot_streak() -> void:
	var g := gm()
	var needed := int(g.balance["streak_taps"])
	for i in needed - 1:
		g.tap()
		g.game_time += 0.1
	check(not g.is_streak_active(), "no streak before enough quick taps")
	g.tap()
	check(g.is_streak_active(), "streak starts after %d quick taps" % needed)
	var normal: float = g.get_effective_click_power()
	g.balance["max_crit_chance"] = 0.0
	var chance = g.balance["perfect_press_chance"]
	g.balance["perfect_press_chance"] = 0.0
	var r: Dictionary = g.tap()
	check(is_equal_approx(r["amount"], normal * float(g.balance["streak_multiplier"])), "streak multiplies taps")
	g.game_time += float(g.balance["streak_duration"]) + 0.1
	check(not g.is_streak_active(), "streak ends after its duration")
	for i in needed:
		g.tap()
	check(not g.is_streak_active(), "cooldown prevents an immediate new streak")
	g.balance["perfect_press_chance"] = chance
	g.balance["max_crit_chance"] = 0.4

func test_slow_taps_never_streak() -> void:
	var g := gm()
	for i in 200:
		g.tap()
		g.game_time += 0.5 # 2 taps/sec
	check(not g.is_streak_active() and g.game_time > 0.0, "casual tapping doesn't trigger Hot Streak")

func test_achievements_and_bonus() -> void:
	var g := gm()
	var am := root.get_node("AchievementManager")
	check(am.achievements.size() >= 20, "at least 20 achievements")
	g.tap()
	am.check_now()
	check(am.is_unlocked("first_click"), "first_click triggers")
	g.owned["automatic_finger"] = 1
	am.check_now()
	check(am.is_unlocked("first_passive"), "first passive income triggers")
	g.unlocked_switches.append("scratchy_tactile")
	am.check_now()
	check(am.is_unlocked("unlock_scratchy_tactile") and not am.is_unlocked("unlock_creamy_linear"), "per-switch unlock achievements")
	g.owned["stronger_finger"] = 30
	g.owned["typing_cat"] = 20
	am.check_now()
	check(am.is_unlocked("ten_levels") and am.is_unlocked("fifty_levels"), "upgrade level achievements")
	var n: int = am.unlocked.size()
	check(is_equal_approx(g.get_global_multiplier(), 1.0 + n * float(g.balance["achievement_bonus"])), "each achievement adds a small global bonus")

func test_collection_counts() -> void:
	var g := gm()
	var c: Dictionary = load("res://scripts/ui/panels/collection_panel.gd").completion()
	check(c["switches"] == [1, 5] and c["keycaps"] == [1, 4], "fresh collection 1/5 switches, 1/4 keycaps (got %s)" % [c])
	g.add_clicks(float(g.switches["budget_linear"]["unlock_requirement_clicks"]))
	c = load("res://scripts/ui/panels/collection_panel.gd").completion()
	check(c["switches"][0] == 2 and c["keycaps"][0] >= 3, "counts update with unlocks (got %s)" % [c])

func test_save_v3_roundtrip_and_v2_migration() -> void:
	_clear_saves()
	var g := gm()
	g.unlocked_switches = ALL_SWITCHES.duplicate()
	g.equip_switch("deafening_clicky")
	g.presses_by_switch = {"office_membrane": 150, "deafening_clicky": 1200}
	g.perfect_press_count = 3
	g.owned["lubed_switch"] = 2
	sm().save_game()
	g.reset_progress()
	sm().load_game()
	sm().consume_pending_offline_earnings()
	check(g.equipped_switch == "deafening_clicky" and g.is_switch_unlocked("creamy_linear"), "new switches persist")
	check(int(g.presses_by_switch["deafening_clicky"]) == 1200 and g.get_mastery_level("deafening_clicky") == 2, "mastery persists")
	check(g.perfect_press_count == 3 and int(g.owned["lubed_switch"]) == 2, "event counters and new upgrades persist")

	_clear_saves()
	_write("user://save.dat", JSON.stringify({"version": 2, "clicks": 10, "lifetime_clicks": 40000, "tap_count": 450,
		"owned": {"stronger_finger": 3}, "unlocked_switches": ["office_membrane", "budget_linear"], "equipped_switch": "budget_linear"}))
	g.reset_progress()
	sm().load_game()
	check(g.equipped_switch == "budget_linear", "v2 save keeps equipped switch")
	check(int(g.presses_by_switch.get("office_membrane", 0)) == 450 and g.get_mastery_level("office_membrane") == 1, "v2 taps credited to Office Membrane mastery")
	check(int(g.owned["typing_cat"]) == 0, "new upgrades default to 0")
	sm().save_game()
	var f := FileAccess.open("user://save.dat", FileAccess.READ)
	check(int(JSON.parse_string(f.get_as_text())["version"]) == 3, "migrated save is written as v3")

func test_offline_includes_all_multipliers() -> void:
	_clear_saves()
	var g := gm()
	g.unlocked_switches = ALL_SWITCHES.duplicate()
	g.equip_switch("creamy_linear")
	g.owned["typing_cat"] = 4
	g.owned["lubed_switch"] = 3
	g.presses_by_switch["creamy_linear"] = 1000
	root.get_node("AchievementManager").unlocked = ["first_click", "hundred_taps"]
	var live: float = g.get_effective_cps()
	var data: Dictionary = sm().build_save_data()
	data["last_active_unix"] = Time.get_unix_time_from_system() - 600.0
	_write("user://save.dat", JSON.stringify(data))
	g.reset_progress()
	root.get_node("AchievementManager").unlocked = []
	sm().load_game()
	var got: Dictionary = sm().consume_pending_offline_earnings()
	var expected := 600.0 * live * float(g.balance["offline_efficiency"])
	check(absf(float(got["earnings"]) - expected) <= expected * 0.01, "offline uses switch, mastery, Lubed and achievement multipliers (%f vs %f)" % [got["earnings"], expected])

## Full 60-minute simulation for three play styles against the real JSON.
func test_economy_sim_play_styles() -> void:
	var sim = load("res://tools/economy_sim.gd")
	var am := root.get_node("AchievementManager")
	var styles := {"heavy": 5.0, "casual": 1.75, "passive": Callable(sim, "passive_profile")}
	var r := {}
	for name in styles.keys():
		seed(7)
		r[name] = sim.run(gm(), am, styles[name], 3600.0)
		print("    ", sim.describe(name, r[name]).replace("\n", "\n    "))
	var cu: Dictionary = r["casual"]["unlock"]
	check(cu.get("budget_linear", 999) <= 480, "casual: Budget Linear by 8 min")
	check(cu.get("scratchy_tactile", 0) >= 300 and cu.get("scratchy_tactile", 9999) <= 900, "casual: Scratchy Tactile in 5-15 min")
	check(cu.get("deafening_clicky", 0) >= 720 and cu.get("deafening_clicky", 9999) <= 1800, "casual: Deafening Clicky in 12-30 min")
	check(cu.get("creamy_linear", 0) >= 1500 and cu.get("creamy_linear", 9999) <= 2700, "casual: Creamy Linear in 25-45 min")
	check(r["passive"]["unlock"].has("creamy_linear"), "mostly-passive player reaches Creamy Linear within an hour")
	check(r["heavy"]["unlock"].get("creamy_linear", 0) >= 600, "heavy tapper doesn't finish all switches in 10 min")
	for name in r.keys():
		check(r[name]["longest_wait"] <= 180.0, "%s: never more than 3 min without an affordable purchase" % name)
	gm().reset_progress()
	am.unlocked = []
