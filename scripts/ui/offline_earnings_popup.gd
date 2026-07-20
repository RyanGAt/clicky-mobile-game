extends Control

signal closed

@onready var message_label: Label = %MessageLabel
@onready var collect_button: Button = %CollectButton

func setup(earnings: float, seconds: float) -> void:
	var minutes := int(seconds / 60.0)
	message_label.text = "While you were away for %d minutes,\nyour switches earned you %s Clicks." % [
		minutes,
		GameManager.format_number(earnings),
	]

func _ready() -> void:
	collect_button.pressed.connect(_on_collect_pressed)

func _on_collect_pressed() -> void:
	closed.emit()
	queue_free()
