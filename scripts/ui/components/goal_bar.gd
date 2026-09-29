class_name GoalBar
extends VBoxContainer
## "Next goal" strip under the switch: the nearest locked switch, otherwise
## the nearest locked keycap, otherwise the equipped switch's next mastery level.

var _label: Label
var _value: Label
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _timer := 0.0

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_label = UIStyle.label("", 26, UIStyle.TEXT_DIM, 700)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	_value = UIStyle.label("", 26, UIStyle.TEXT_FAINT, 700)
	row.add_child(_value)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", UIStyle.box(Color(1, 1, 1, 0.06), 6))
	_fill = UIStyle.box(UIStyle.TEXT, 6)
	_bar.add_theme_stylebox_override("fill", _fill)
	add_child(_bar)
	refresh()

func set_accent(color: Color) -> void:
	_fill.bg_color = color

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.2
		refresh()

func _find_goal() -> Dictionary:
	var best := {}
	for id in GameManager.switches.keys():
		if GameManager.is_switch_unlocked(id):
			continue
		var req := float(GameManager.switches[id].get("unlock_requirement_clicks", 0.0))
		if best.is_empty() or req < best["target"]:
			best = {"text": "Next switch: %s" % GameManager.switches[id].get("name", id), "target": req, "value": GameManager.lifetime_clicks}
	if not best.is_empty():
		return best
	for id in GameManager.keycaps.keys():
		if GameManager.is_keycap_unlocked(id):
			continue
		var req := float(GameManager.keycaps[id].get("unlock_requirement_clicks", 0.0))
		if best.is_empty() or req < best["target"]:
			best = {"text": "Next keycap: %s" % GameManager.keycaps[id].get("name", id), "target": req, "value": GameManager.lifetime_clicks}
	if not best.is_empty():
		return best
	# Everything unlocked: work toward mastering the equipped switch.
	var id := GameManager.equipped_switch
	var level: int = GameManager.get_mastery_level(id)
	var thresholds: Array = GameManager.get_mastery_thresholds()
	if level < thresholds.size():
		return {"text": "%s mastery %d" % [GameManager.switches[id].get("name", id), level + 1], "target": float(thresholds[level]), "value": float(GameManager.presses_by_switch.get(id, 0))}
	return best

func refresh() -> void:
	var goal := _find_goal()
	modulate.a = 0.0 if goal.is_empty() else 1.0
	if goal.is_empty():
		return
	_label.text = goal["text"]
	_value.text = "%s / %s" % [GameManager.format_number(minf(goal["value"], goal["target"])), GameManager.format_number(goal["target"])]
	_bar.max_value = maxf(goal["target"], 1.0)
	_bar.value = goal["value"]
