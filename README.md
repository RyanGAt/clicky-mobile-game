# Keyboard Clicker

A mobile incremental game about pressing mechanical keyboard switches, built in Godot 4.3.

- Balance and content: `data/*.json` (upgrades, switches, keycaps, achievements, balance, audio).
- Managers (autoloads): `scripts/managers/` (GameManager, SaveManager, AchievementManager, Feedback).
- UI components: `scripts/ui/components`, `panels`, `popups`.

## Tests
    godot --headless -s res://tests/test_runner.gd
These run against the real game and include a 10-minute pacing simulation. Any real save is moved aside during the run and restored afterwards.

## Economy simulation
    godot --headless -s res://tools/run_sim.gd -- 60
Prints unlock and purchase timing for heavy, casual and mostly-passive players. It never writes the player's save.

## Screenshots
    xvfb-run -a godot --rendering-driver opengl3 --resolution 1080x1920 -s res://tools/screenshot.gd -- /tmp/shots mid
