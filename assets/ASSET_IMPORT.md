# Asset notes

## In use
- `assets/switches/office_membrane.png`, `budget_linear.png`: main switch and Switches tab.
- `assets/icons/automatic_finger.png`, `lucky_press.png`: upgrade cards.
- `assets/keycaps/*.png`: Collection tab and the top-left keycap badge.
- `assets/fonts/Manrope-Variable.ttf` (SIL OFL, see `OFL.txt`).

All PNGs import lossless with mipmaps, so transparency is kept and they downscale cleanly.

## Missing / needs follow-up

### Switch artwork (512x512 PNG, transparent, same isometric angle and framing as `office_membrane.png`)
Scratchy Tactile, Deafening Clicky and Creamy Linear have no art yet. `switches.json` leaves `asset_path` empty and declares a `placeholder` (an existing switch image plus a tint), and the UI labels these "TEMP ART". To finish one, add the file and set `asset_path`:
- `assets/switches/scratchy_tactile.png`: brown/tan stem, slightly rough matte housing
- `assets/switches/deafening_clicky.png`: blue stem, visible click jacket
- `assets/switches/creamy_linear.png`: cream/off-white premium housing, polished and luxurious

### Upgrade icons (512x512 PNG, transparent, same style as `automatic_finger.png`)
Upgrades with no art have an empty `icon_path` and an `icon_wanted` path in `upgrades.json`. The card shows initials until the file is added. Then move the path from `icon_wanted` to `icon_path`.
- **`assets/icons/stronger_finger.png`**: never uploaded. It is not in any branch or commit of this repository. Suggested art: a flexing/muscled fingertip pressing a beige keycap.
- `assets/icons/better_spring.png`: a gold-coloured coil spring
- `assets/icons/typing_cat.png`: a cat with paws on a keyboard
- `assets/icons/lubed_switch.png`: a tiny brush applying lube to a switch stem
- `assets/icons/angry_programmer.png`: a hunched figure hammering a keyboard
- **Keycaps can't be layered onto the main switch yet.** `plain_beige`, `retro_grey` and `smiley_face` are cap-only images, each at a different angle and scale, while `warning_symbol` is a full cap-on-membrane-housing composite. To show the equipped keycap on the switch itself we need:
  - one cap-only PNG per keycap, drawn at the same isometric angle, scale and 512x512 canvas position as the caps in the switch art;
  - each switch split into a `*_housing.png` layer and a `*_stem.png` layer.
  Until that art exists, keycaps stay cosmetic and appear in the Collection and the top-bar badge.

## Audio (optional)
Nothing ships yet. The Feedback autoload plays a sound only when a file exists (.ogg, .wav or .mp3, with the extension omitted in the data):
- Per switch: `press_audio` and `release_audio` in `switches.json` (e.g. `assets/audio/switches/clicky_down`)
- Events: `data/audio.json` (crit, perfect_press, hot_streak, purchase, unlock, mastery)
