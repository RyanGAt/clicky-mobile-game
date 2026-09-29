class_name SettingsPopup
extends ModalCard

func build() -> void:
	add_centered_label("Settings", 48, UIStyle.TEXT, 800)

	var vol_row := VBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	content.add_child(vol_row)
	vol_row.add_child(UIStyle.label("Volume", 30, UIStyle.TEXT, 700))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 64)
	slider.value = SaveManager.settings.get("master_volume", 1.0)
	slider.value_changed.connect(SaveManager.set_master_volume)
	vol_row.add_child(slider)

	var vib_row := HBoxContainer.new()
	content.add_child(vib_row)
	var vib_label := UIStyle.label("Vibration", 30, UIStyle.TEXT, 700)
	vib_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vib_row.add_child(vib_label)
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.custom_minimum_size = Vector2(170, 76)
	toggle.add_theme_font_size_override("font_size", 28)
	var paint := func(on: bool):
		toggle.text = "On" if on else "Off"
		UIStyle.style_button(toggle, UIStyle.POSITIVE if on else UIStyle.SURFACE_3, UIStyle.on_color(UIStyle.POSITIVE) if on else UIStyle.TEXT_DIM, 38)
	toggle.button_pressed = SaveManager.settings.get("vibration_enabled", true)
	paint.call(toggle.button_pressed)
	toggle.toggled.connect(func(on: bool):
		paint.call(on)
		SaveManager.set_vibration_enabled(on))
	vib_row.add_child(toggle)

	var note := add_centered_label("Sound effects will arrive in a later update.\nProgress saves automatically.", 24, UIStyle.TEXT_FAINT, 500)
	note.custom_minimum_size.y = 60
	add_button("Done", UIStyle.SURFACE_3, close)

func close() -> void:
	SaveManager.save_game()
	super()
