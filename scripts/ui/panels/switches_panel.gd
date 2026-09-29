class_name SwitchesPanel
extends TabPanel

var _cards: Array[SwitchCard] = []

func build() -> void:
	add_title("SWITCHES")
	for id in GameManager.switches.keys():
		var card := SwitchCard.new(id)
		card.equip_requested.connect(func(sid): GameManager.equip_switch(sid))
		list.add_child(card)
		_cards.append(card)

func refresh() -> void:
	for card in _cards:
		card.refresh()
