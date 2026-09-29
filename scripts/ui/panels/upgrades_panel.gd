class_name UpgradesPanel
extends TabPanel

signal upgrade_bought(card: UpgradeCard, id: String, amount: int)

const MODE_KEY := "buy_mode"

var _cards: Array[UpgradeCard] = []
var _mode_selector: SegmentedControl

func build() -> void:
	add_title("UPGRADES")
	_mode_selector = SegmentedControl.new()
	header.add_child(_mode_selector)
	var initial := int(SaveManager.settings.get(MODE_KEY, 1))
	_mode_selector.setup(["x1", "x10", "Max"], [1, 10, -1], initial)
	_mode_selector.selected.connect(_on_mode_selected)
	for id in GameManager.upgrades.keys():
		var card := UpgradeCard.new(id)
		card.purchase_mode = initial
		card.purchased.connect(func(uid, amount): upgrade_bought.emit(card, uid, amount))
		list.add_child(card)
		_cards.append(card)

func _on_mode_selected(mode: int) -> void:
	SaveManager.settings[MODE_KEY] = mode
	for card in _cards:
		card.set_purchase_mode(mode)

func refresh() -> void:
	for card in _cards:
		card.refresh()

func set_accent(color: Color) -> void:
	super(color)
	for card in _cards:
		card.set_accent(color)
