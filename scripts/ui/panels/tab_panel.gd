class_name TabPanel
extends VBoxContainer
## Base for the bottom-sheet tabs: an optional header row plus a touch-friendly
## scrolling list. Subclasses fill `list` and implement refresh().

var header: HBoxContainer
var list: VBoxContainer
var scroll: ScrollContainer
var accent := UIStyle.TEXT

func _ready() -> void:
	add_theme_constant_override("separation", 18)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	add_child(header)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 24
	add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	build()

func add_title(text: String) -> Label:
	var l := UIStyle.label(text, 30, UIStyle.TEXT_DIM, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(l)
	return l

func build() -> void:
	pass

func refresh() -> void:
	pass

func set_accent(color: Color) -> void:
	accent = color
