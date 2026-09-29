# Asset notes

## In use
- `assets/switches/office_membrane.png`, `budget_linear.png`: main switch and Switches tab.
- `assets/icons/automatic_finger.png`, `lucky_press.png`: upgrade cards.
- `assets/keycaps/*.png`: Collection tab and the top-left keycap badge.
- `assets/fonts/Manrope-Variable.ttf` (SIL OFL, see `OFL.txt`).

All PNGs import lossless with mipmaps, so transparency is kept and they downscale cleanly.

## Missing / needs follow-up
- **`assets/icons/stronger_finger.png` does not exist.** Its card shows an "SF" initials tile until the file is added at that path. No code change is needed.
- **Keycaps can't be layered onto the main switch yet.** `plain_beige`, `retro_grey` and `smiley_face` are cap-only images, each at a different angle and scale, while `warning_symbol` is a full cap-on-membrane-housing composite. To show the equipped keycap on the switch itself we need:
  - one cap-only PNG per keycap, drawn at the same isometric angle, scale and 512x512 canvas position as the caps in the switch art;
  - each switch split into a `*_housing.png` layer and a `*_stem.png` layer.
  Until that art exists, keycaps stay cosmetic and appear in the Collection and the top-bar badge.

## Audio (optional)
The Feedback autoload plays sounds only when a file exists (.ogg, .wav or .mp3):
- `assets/audio/switches/<sound_category>_down` and `_up` (`membrane`, `linear`)
- `assets/audio/ui/crit`, `purchase`, `unlock`
