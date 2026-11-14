# Quarry Days typography

All fonts are packaged in `assets/fonts` (SIL OFL 1.1, licences beside them) and used through `QuarryTheme` (`scripts/ui_theme.gd`) and the project default theme
`assets/ui/qd_theme.tres` (regenerate with `godot --headless -s tools/make_theme.gd`). The game's name is **QUARRY DAYS** (project name, window title, main menu,
computer header). "Grandpa's Legacy" remains a stage name; Grandpa Walt remains a character.

| Role | Face | Where |
|---|---|---|
| Game title, window titles, major buttons, stage and milestone headings, equipment and tool names, letter titles | Pixelify Sans (`QuarryTheme.head()/display()`) | smooth glyph rendering (gray AA, light hinting): sharp at any scale |
| HUD labels: day and time, bag, minimap letters, tool category labels, Quarry OS taskbar, desktop captions and window buttons | Silkscreen (`QuarryTheme.hud()`, `hud_label()`) | true pixel font, unfiltered, sized to its 8 px grid |
| Dialogue, letters, objectives, descriptions, tutorials, management pages, tooltips, settings | Nunito Sans (`body()/bold()`) | 18-20 px at 1080p |
| Machine counters and digital readouts | VT323 (`mono()`, `mono_label()`; 3D readouts through `PixelLabel.readout`) | true pixel font, 16 px grid |

## Scaling strategy
The canvas is 960x540 (`canvas_items`, aspect `expand`): the window scales it by 1.33 (1280x720), 1.42 (1366x768), 1.67 (1600x900), 2 (1920x1080).
* **Smooth fonts** are rasterised at the final size, so they stay sharp at any scale. They keep base sizes.
* **Pixel fonts** are crisp only when the on-screen glyph size is a multiple of their grid, so `pixel_font_size()` asks for a screen size (design base x 2, rounded to the grid, at
  least 16 px) and converts it to a base size for the current window. `refresh_pixel_text()` redoes it when the window changes (exact at 720p and 1080p, within one pixel at 768p and 900p).
* **The readable floor:** `fit_size()` raises any base size so nothing is under 15 px on screen (a base 8 is 10.7 px at 720p). All labels built through `QuarryTheme.label`/`fit` follow the window.
* Integer scaling of the whole UI is deliberately not forced: it would shrink the interface on 1366x768 and similar screens.
