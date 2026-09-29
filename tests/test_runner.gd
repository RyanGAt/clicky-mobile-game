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
	check(is_equal_approx(g.get_effective_cps(), 6.0), "3 Automatic Fingers = 6 CPS")
	g.unlocked_switches.append("budget_linear")
	g.equip_switch("budget_linear")
	check(is_equal_approx(g.get_effective_cps(), 12.0), "Budget Linear doubles CPS")

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
	check(is_equal_approx(g.get_base_cps(), 4.0), "cps derived from owned")
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
