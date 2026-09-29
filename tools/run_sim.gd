extends SceneTree
## godot --headless -s res://tools/run_sim.gd [-- minutes]
## Prints progression timing for three play styles. Does not touch saves.

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := float(args[0]) if args.size() > 0 else 60.0
	var gm := root.get_node("GameManager")
	var am := root.get_node("AchievementManager")
	var sm := root.get_node("SaveManager")
	sm.set_process(false)
	sm._loaded = false # never write the player's save from the simulator
	var sim = load("res://tools/economy_sim.gd")
	for style in [["Heavy tapper (5 taps/s)", 5.0], ["Casual (1.75 taps/s)", 1.75], ["Mostly passive (1.5 taps/s for 3 min, then 0.3)", Callable(sim, "passive_profile")]]:
		seed(42)
		var m: Dictionary = load("res://tools/economy_sim.gd").run(gm, am, style[1], minutes * 60.0)
		print(load("res://tools/economy_sim.gd").describe(style[0], m))
	quit()
