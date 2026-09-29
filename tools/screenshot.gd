extends SceneTree
## Renders the main screen to PNGs for visual review (needs a GPU/Xvfb):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1080x1920 -s res://tools/screenshot.gd -- <out_dir> [scenario]
## Scenarios: fresh, mid, unlocked, equipped, popups. Temporarily moves any real save aside.

func _initialize() -> void:
	_go.call_deferred()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shots"
	var scenario := args[1] if args.size() > 1 else "fresh"
	DirAccess.make_dir_recursive_absolute(out)
	var gm: Node = root.get_node("GameManager")
	gm.reset_progress()
	match scenario:
		"mid":
			gm.owned["stronger_finger"] = 12
			gm.owned["automatic_finger"] = 6
			gm.owned["lucky_press"] = 1
			gm.add_clicks(4200)
		"unlocked", "equipped":
			gm.owned["stronger_finger"] = 18
			gm.owned["automatic_finger"] = 14
			gm.owned["lucky_press"] = 3
			gm.add_clicks(12000)
	var main: Control = load("res://scenes/main/main_game.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	if scenario == "unlocked":
		gm.add_clicks(30000)
		for i in 40:
			await process_frame
	if scenario == "equipped":
		gm.add_clicks(30000)
		gm.equip_switch("budget_linear")
		for c in main.get_node("PopupLayer").get_children():
			c.queue_free()
		for i in 20:
			await process_frame
	var view = main.find_child("SwitchView", true, false)
	await _shot("%s/%s_idle.png" % [out, scenario])
	if scenario == "fresh":
		return quit()
	if scenario == "popups":
		main._open_popup(load("res://scripts/ui/popups/settings_popup.gd").new())
		for f in 25:
			await process_frame
		await _shot("%s/settings.png" % out)
		for c in root.get_node("MainGame/PopupLayer").get_children():
			c.queue_free()
		main._open_popup(load("res://scripts/ui/popups/offline_earnings_popup.gd").new(48250.0, 7980.0))
		for f in 25:
			await process_frame
		await _shot("%s/offline.png" % out)
		return quit()
	# Mid-press with floating numbers and a crit.
	var c := view.get_global_rect().get_center()
	for i in 4:
		var ev := InputEventScreenTouch.new()
		ev.position = c + Vector2(i * 30 - 45, 0)
		ev.pressed = true
		root.push_input(ev, true)
		for f in 3:
			await process_frame
		ev = ev.duplicate()
		ev.pressed = false
		root.push_input(ev, true)
	view.show_tap_result("CRIT +185", true, c)
	var ev2 := InputEventScreenTouch.new()
	ev2.position = c
	ev2.pressed = true
	root.push_input(ev2, true)
	for f in 3:
		await process_frame
	await _shot("%s/%s_press.png" % [out, scenario])
	for tab in [1, 2]:
		main._select_tab(tab)
		for f in 5:
			await process_frame
		await _shot("%s/%s_tab%d.png" % [out, scenario, tab])
	quit()
