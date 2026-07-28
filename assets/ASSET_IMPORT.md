# Generated asset import map

The generated PNG artwork should be added to these exact repository paths:

## Switches

- `assets/switches/office_membrane.png`
- `assets/switches/budget_linear.png`

## Upgrade icons

- `assets/icons/upgrades/stronger_finger.png`
- `assets/icons/upgrades/automatic_finger.png`
- `assets/icons/upgrades/lucky_press.png`

## Keycaps

- `assets/keycaps/plain_beige.png`
- `assets/keycaps/retro_grey.png`
- `assets/keycaps/warning_symbol.png`
- `assets/keycaps/smiley_face.png`

The switch data already references the two switch asset paths. Do not add resource preloads until the PNG files exist, because missing preloaded resources will prevent the Godot project from loading.

Audio is intentionally omitted for this milestone. The current interaction code safely does nothing when `SwitchAudio.stream` is empty.
