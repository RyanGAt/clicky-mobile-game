class_name KeycapTile
extends PanelContainer
## Keycap in the Collection grid. Keycaps are cosmetic only.

signal equip_requested(id: String)

var keycap_id: String
var _art: IconTile
var _button: Button
var _status: Label
var _last_state := ""

func _init(id: String) -> void:
	keycap_id = id

func _ready() -> void:
	var data: Dictionary = GameManager.keycaps.get(keycap_id, {})
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE_2, 30, 20))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_art = IconTile.new(data.get("asset_path", ""), data.get("name", keycap_id), 200, Color(1, 1, 1, 0.04))
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_art)
	var name_label := UIStyle.label(data.get("name", keycap_id), 30, UIStyle.TEXT, 800)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	_status = UIStyle.label("", 22, UIStyle.TEXT_FAINT, 600)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(0, 72)
	_button.add_theme_font_size_override("font_size", 26)
	_button.pressed.connect(func(): equip_requested.emit(keycap_id))
	col.add_child(_button)
	refresh()

func refresh() -> void:
	var data: Dictionary = GameManager.keycaps.get(keycap_id, {})
	var unlocked := GameManager.is_keycap_unlocked(keycap_id)
	var equipped := GameManager.equipped_keycap == keycap_id
	var state := "%s|%s" % [unlocked, equipped]
	if state == _last_state:
		return
	_last_state = state
	_art.set_locked(not unlocked)
	_button.visible = unlocked
	_button.disabled = equipped
	_button.text = "Equipped" if equipped else "Equip"
	if equipped:
		UIStyle.style_button(_button, Color(UIStyle.POSITIVE, 0.14), UIStyle.POSITIVE, 20)
	else:
		UIStyle.style_button(_button, UIStyle.SURFACE_3, UIStyle.TEXT, 20)
	_status.text = str(data.get("flavor", data.get("description", ""))) if unlocked else "Unlocks at %s lifetime Clicks" % GameManager.format_number(float(data.get("unlock_requirement_clicks", 0)))
