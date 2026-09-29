class_name ModalCard
extends Control
## Dimmed overlay with a centred card that pops in. Tapping the scrim closes
## it (unless dismissable is false). Subclasses fill `content` in build().

signal closed

var dismissable := true
var card: PanelContainer
var content: VBoxContainer
var _closing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.02, 0.03, 0.62)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 96.0, 880.0), 0)
	var sb := UIStyle.box(UIStyle.SURFACE, 40, 48, UIStyle.BORDER)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 40
	sb.shadow_offset = Vector2(0, 16)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	card.add_child(content)
	build()

	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
	modulate.a = 0.0
	card.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(card, "scale", Vector2.ONE, 0.28)

func build() -> void:
	pass

func add_centered_label(text: String, size: int, color: Color = UIStyle.TEXT, weight: int = 700) -> Label:
	var l := UIStyle.label(text, size, color, weight)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)
	return l

func add_button(text: String, fill: Color, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 104)
	b.add_theme_font_size_override("font_size", 34)
	UIStyle.style_button(b, fill, UIStyle.on_color(fill), 28)
	b.pressed.connect(callback)
	content.add_child(b)
	return b

func _on_scrim_input(event: InputEvent) -> void:
	if dismissable and event is InputEventMouseButton and event.pressed:
		close()

func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_property(card, "scale", Vector2(0.95, 0.95), 0.14)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())
