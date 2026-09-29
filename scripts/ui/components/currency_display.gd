class_name CurrencyDisplay
extends VBoxContainer
## Big Click total plus per-tap / per-second stats. The total eases toward the
## real value so income reads as a smooth count-up instead of jumps.

const EASE_SPEED := 14.0

var _shown := 0.0
var _target := 0.0
var _value_label: Label
var _tap_value: Label
var _cps_value: Label

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_value_label = UIStyle.label("0", 124, UIStyle.TEXT, 800)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_value_label)

	var caption := UIStyle.label("CLICKS", 26, UIStyle.TEXT_FAINT, 700)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 16)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	_tap_value = _add_stat(stats, "per tap")
	_cps_value = _add_stat(stats, "per sec")

	_target = GameManager.clicks
	_shown = _target
	GameManager.clicks_changed.connect(func(total): _target = total)
	GameManager.stats_changed.connect(refresh_stats)
	GameManager.switch_equipped.connect(func(_id): refresh_stats())
	refresh_stats()
	_render()

func _add_stat(parent: Control, caption: String) -> Label:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.box(Color(1, 1, 1, 0.045), 30)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	chip.add_theme_stylebox_override("panel", sb)
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var value := UIStyle.label("0", 34, UIStyle.TEXT, 800)
	row.add_child(value)
	row.add_child(UIStyle.label(caption, 28, UIStyle.TEXT_DIM, 600))
	return value

func refresh_stats() -> void:
	_tap_value.text = GameManager.format_number(GameManager.get_effective_click_power())
	_cps_value.text = GameManager.format_number(GameManager.get_effective_cps())

func _process(delta: float) -> void:
	if is_equal_approx(_shown, _target):
		return
	_shown = lerpf(_shown, _target, 1.0 - exp(-delta * EASE_SPEED))
	if absf(_target - _shown) < maxf(0.5, absf(_target) * 0.0005):
		_shown = _target
	_render()

func _render() -> void:
	_value_label.text = GameManager.format_number(_shown)
