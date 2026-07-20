extends Control

signal closed

@onready var volume_slider: HSlider = %VolumeSlider
@onready var vibration_toggle: CheckButton = %VibrationToggle
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	volume_slider.value = SaveManager.settings.get("master_volume", 1.0)
	vibration_toggle.button_pressed = SaveManager.settings.get("vibration_enabled", true)

	volume_slider.value_changed.connect(_on_volume_changed)
	vibration_toggle.toggled.connect(_on_vibration_toggled)
	close_button.pressed.connect(_on_close_pressed)

func _on_volume_changed(value: float) -> void:
	SaveManager.set_master_volume(value)

func _on_vibration_toggled(enabled: bool) -> void:
	SaveManager.set_vibration_enabled(enabled)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
