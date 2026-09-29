class_name SwitchView
extends Control
## The main keyboard switch. The whole control is the (generous, invisible)
## touch area; the artwork is a child that is animated by a spring so rapid
## and multi-finger taps never wait on an animation.

signal pressed(local_position: Vector2)
signal released

const SPRING_STIFFNESS := 1400.0
const SPRING_DAMPING := 24.0 # slightly under critical -> small overshoot on release
const PRESS_SNAP_DEPTH := 0.75 # depth applied instantly on touch so it never feels late
const SQUASH := Vector2(0.035, -0.075)
const PRESS_DROP := 0.035 # fraction of art height
const MAX_TILT := 0.045 # radians, leans toward the tapped side
const FLOAT_POOL_SIZE := 28
const FLOAT_LIFETIME := 0.75
const RING_LIFETIME := 0.35

var accent := Color("#d9cfb5")

var _art: TextureRect
var _particles: CPUParticles2D
var _float_layer: Control
var _float_pool: Array[Label] = []
var _float_state: Array[Dictionary] = []
var _next_float := 0

var _active_touches: Dictionary = {}
var _depth := 0.0
var _velocity := 0.0
var _tilt_target := 0.0
var _tilt := 0.0
var _pop := 0.0 # extra scale pulse for equip/crit
var _ring_age := RING_LIFETIME
var _ring_color := Color.WHITE
var _idle_time := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false

func _ready() -> void:
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 0.95
	_particles.amount = 18
	_particles.lifetime = 0.55
	_particles.direction = Vector2.UP
	_particles.spread = 75.0
	_particles.gravity = Vector2(0, 1400)
	_particles.initial_velocity_min = 420.0
	_particles.initial_velocity_max = 820.0
	_particles.scale_amount_min = 0.35
	_particles.scale_amount_max = 0.7
	_particles.local_coords = false
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	_particles.color_ramp = fade
	var dot := GradientTexture2D.new()
	var dot_grad := Gradient.new()
	dot_grad.set_color(0, Color(1, 1, 1, 1))
	dot_grad.set_color(1, Color(1, 1, 1, 0))
	dot_grad.add_point(0.55, Color(1, 1, 1, 0.9))
	dot.gradient = dot_grad
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	_particles.texture = dot
	add_child(_particles)

	_float_layer = Control.new()
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_float_layer)
	for i in FLOAT_POOL_SIZE:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06, 0.85))
		label.visible = false
		_float_layer.add_child(label)
		_float_pool.append(label)
		_float_state.append({"age": FLOAT_LIFETIME, "velocity": Vector2.ZERO, "crit": false})

	resized.connect(_layout_art)
	_layout_art()

func set_switch_texture(texture: Texture2D, new_accent: Color, animate: bool = true, tint: Color = Color.WHITE) -> void:
	_art.texture = texture
	_art.modulate = tint
	accent = new_accent
	_particles.color = accent.lightened(0.2)
	if animate:
		_pop = 0.12
	queue_redraw()

func _art_rect() -> Rect2:
	# Square art area, centred, leaving headroom for floating numbers.
	# The art has ~20% transparent padding, so it may overflow the control a little.
	var side := minf(size.x * 0.92, size.y * 1.18)
	return Rect2((size - Vector2(side, side)) * 0.5 + Vector2(0, size.y * 0.04), Vector2(side, side))

func _layout_art() -> void:
	if _art == null:
		return
	var rect := _art_rect()
	_art.position = rect.position
	_art.size = rect.size
	# Pivot near the bottom of the housing so the cap appears to sink.
	_art.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y * 0.72)
	_particles.position = rect.get_center() + Vector2(0, -rect.size.y * 0.12)

# --- Input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	# Only touch events: with emulate_touch_from_mouse the desktop mouse also
	# arrives here as touch, and handling mouse too would double-count.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _active_touches.has(touch.index):
				return
			_active_touches[touch.index] = true
			_on_touch_down(touch.position)
		else:
			if _active_touches.erase(touch.index):
				_on_touch_up()
		accept_event()

func _notification(what: int) -> void:
	# Losing focus mid-press (app switch, popup) must not leave the key stuck.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all_touches()

func release_all_touches() -> void:
	if not _active_touches.is_empty():
		_active_touches.clear()
		released.emit()

func _on_touch_down(pos: Vector2) -> void:
	var rect := _art_rect()
	var offset := clampf((pos.x - rect.get_center().x) / (rect.size.x * 0.5), -1.0, 1.0)
	_tilt_target = offset * MAX_TILT
	_depth = maxf(_depth, PRESS_SNAP_DEPTH)
	_velocity = maxf(_velocity, 6.0)
	pressed.emit(pos)

func _on_touch_up() -> void:
	if _active_touches.is_empty():
		released.emit()
	else:
		# Another finger is still down: give a small re-press so every tap reads.
		_velocity = -3.0

# --- Feedback ---------------------------------------------------------------

## Called by the owner after the economy resolves the tap.
## kind: "normal", "crit", "perfect"; `hot` tints numbers during a Hot Streak.
func show_tap_result(text: String, is_crit: bool, pos: Vector2, kind: String = "", hot: bool = false) -> void:
	if kind == "":
		kind = "crit" if is_crit else "normal"
	_spawn_float(text, kind, pos, hot)
	if kind == "perfect":
		_ring_age = -0.12 # hold the ring a moment longer
		_ring_color = Color.WHITE
		_pop = maxf(_pop, 0.12)
		_depth = 1.15
		_particles.amount = 36
		_particles.color = Color.WHITE
		_particles.restart()
		_particles.emitting = true
		_particles_reset_pending = true
	elif is_crit:
		_ring_age = 0.0
		_ring_color = Color("#ffd35a")
		_pop = maxf(_pop, 0.07)
		_depth = 1.0
		_particles.restart()
		_particles.emitting = true

func pulse(amount: float = 0.06) -> void:
	_pop = maxf(_pop, amount)

var _particles_reset_pending := false

func _spawn_float(text: String, kind: String, pos: Vector2, hot: bool) -> void:
	var is_crit := kind != "normal"
	var label := _float_pool[_next_float]
	var state := _float_state[_next_float]
	_next_float = (_next_float + 1) % FLOAT_POOL_SIZE
	label.text = text
	var size_px := 96 if kind == "perfect" else (76 if is_crit else 52)
	var color := Color.WHITE if kind == "perfect" else (Color("#ffd35a") if is_crit else (Color("#ffb27a") if hot else Color(1, 1, 1, 0.95)))
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#b8860b") if kind == "perfect" else Color(0.05, 0.05, 0.06, 0.85))
	label.reset_size()
	var rect := _art_rect()
	var start := Vector2(
		clampf(pos.x, rect.position.x + rect.size.x * 0.15, rect.end.x - rect.size.x * 0.15),
		rect.position.y + rect.size.y * 0.34
	) + Vector2(randf_range(-90, 90), randf_range(-30, 30))
	label.position = start - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.visible = true
	state["age"] = 0.0
	state["crit"] = is_crit
	state["velocity"] = Vector2(randf_range(-60, 60), -360.0 if is_crit else -300.0)

func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 20.0)
	_idle_time += delta

	var target := 1.0 if not _active_touches.is_empty() else 0.0
	var accel := SPRING_STIFFNESS * (target - _depth) - SPRING_DAMPING * _velocity
	_velocity += accel * delta
	_depth = clampf(_depth + _velocity * delta, -0.35, 1.15)
	_tilt = lerpf(_tilt, _tilt_target if target > 0.0 else 0.0, 1.0 - exp(-delta * 30.0))
	_pop = move_toward(_pop, 0.0, delta * 0.6)

	if _art:
		var breathe := sin(_idle_time * 1.6) * 0.006 * (1.0 - clampf(absf(_depth), 0.0, 1.0))
		var pop_scale := 1.0 + _pop * sin(clampf(_pop * 25.0, 0.0, PI))
		_art.scale = Vector2(1.0 + SQUASH.x * _depth, 1.0 + SQUASH.y * _depth + breathe) * pop_scale
		_art.rotation = _tilt * clampf(_depth, 0.0, 1.0)
		_art.position.y = _art_rect().position.y + _art.size.y * PRESS_DROP * _depth

	for i in FLOAT_POOL_SIZE:
		var state := _float_state[i]
		if state["age"] >= FLOAT_LIFETIME:
			continue
		var label := _float_pool[i]
		state["age"] += delta
		var t: float = state["age"] / FLOAT_LIFETIME
		var vel: Vector2 = state["velocity"]
		vel *= exp(-delta * 3.5)
		state["velocity"] = vel
		label.position += vel * delta
		label.modulate.a = 1.0 - t * t
		var s := 1.0 + (0.35 if state["crit"] else 0.12) * maxf(0.0, 1.0 - t * 6.0)
		label.scale = Vector2(s, s)
		if state["age"] >= FLOAT_LIFETIME:
			label.visible = false

	if _ring_age < RING_LIFETIME:
		_ring_age += delta
	if _particles_reset_pending and not _particles.emitting:
		_particles_reset_pending = false
		_particles.amount = 18
		_particles.color = accent.lightened(0.2)
	queue_redraw()

func _draw() -> void:
	var rect := _art_rect()
	# Soft contact shadow that tightens as the key goes down.
	var shadow_center := rect.get_center() + Vector2(0, rect.size.y * 0.3)
	var shadow_w := rect.size.x * (0.40 - 0.02 * _depth)
	for i in 5:
		var f := float(i) / 5.0
		var radius := shadow_w * (1.0 - f * 0.45)
		draw_set_transform(shadow_center, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.07))
	draw_set_transform(Vector2.ZERO)

	if _ring_age < RING_LIFETIME:
		var t := clampf(_ring_age, 0.0, RING_LIFETIME) / RING_LIFETIME
		var ring_center := rect.get_center() + Vector2(0, -rect.size.y * 0.05)
		draw_arc(ring_center, rect.size.x * (0.3 + 0.25 * t), 0.0, TAU, 64,
			Color(_ring_color, (1.0 - t) * 0.45), 8.0 * (1.0 - t) + 2.0, true)
