extends RefCounted
class_name QuarryTheme
## Shared cozy UI style, one typographic system for the whole game (all fonts are packaged in assets/fonts, SIL OFL 1.1; resources assets/fonts/qd_*.tres):
##   Pixelify Sans   display(), head()   titles, signs, stage and equipment names, major buttons, announcements
##   Silkscreen      hud()               HUD labels, day and time, minimap labels, short status and category labels
##   Nunito Sans     body(), bold()      everything that is read: dialogue, letters, tutorials, descriptions, upgrade text, settings
##   VT323           mono()              machine counters and digital readouts
## Sizes are in the 960x540 base canvas, which the window scales by 1.333 (1280x720) or 2 (1920x1080); the table gives the 1080p size:
##   TITLE 15 -> 30 px (major headings)   SECTION 11 -> 22 px   HEAD 12 -> 24 px   HUD 9 -> 18 px   BODY 9 -> 18 px   DIALOG 10 -> 20 px (dialogue and letters)   SMALL 8 -> 16 px
## Text is never shrunk below SMALL to fit: it wraps instead. Fonts are re-rasterised at the final window scale (canvas_items stretch), so text stays sharp at any DPI.

const TITLE := 15
const SECTION := 11
const HEAD := 12
const HERO := 18                 ## the main menu's name of the game
const BODY := 9
const HUD := 9
const DIALOG := 10
const SMALL := 8

const BG := Color(0.13, 0.1, 0.075, 0.95)
const BG_SOFT := Color(0.17, 0.13, 0.095, 0.93)
const BORDER := Color(0.5, 0.37, 0.23)
const BORDER_HI := Color(0.72, 0.56, 0.34)
const INK := Color(0.99, 0.95, 0.84)
const DIM := Color(0.8, 0.73, 0.6)
const ACCENT := Color(0.98, 0.76, 0.34)
const GOOD := Color(0.62, 0.86, 0.48)
const WARN := Color(1.0, 0.5, 0.38)
const MONEY := Color(0.99, 0.84, 0.42)
const RES_COLORS := {"limestone": Color(0.86, 0.83, 0.74), "coal": Color(0.62, 0.64, 0.68), "iron_ore": Color(0.92, 0.55, 0.42),
	"crushed_stone": Color(0.82, 0.8, 0.72), "copper_ore": Color(0.5, 0.86, 0.66), "gold_ore": Color(1.0, 0.82, 0.32), "topsoil": Color(0.62, 0.46, 0.32), "gravel": Color(0.74, 0.7, 0.62)}

static var _theme: Theme
static var _fonts := {}

static func _font(name: String) -> Font:
	if not _fonts.has(name):
		_fonts[name] = load("res://assets/fonts/%s.tres" % name)
	return _fonts[name] if _fonts[name] != null else ThemeDB.fallback_font

## Reading text (Nunito Sans) and its bold; titles and major buttons (Pixelify Sans); HUD labels (Silkscreen); machine readouts (VT323).
static func body() -> Font:
	return _font("qd_body")

static func bold() -> Font:
	return _font("qd_body_bold")

static func head() -> Font:
	return _font("qd_heading")

static func display() -> Font:
	return _font("qd_display")

static func hud() -> Font:
	return _font("qd_hud")

static func mono() -> Font:
	return _font("qd_mono")

static func panel_box(bg := BG, border := BORDER, margin := 8, radius := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.corner_detail = 2 # chunky, pixel-like rounding
	s.shadow_color = Color(0, 0, 0, 0.32)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin - 2
	s.content_margin_bottom = margin - 2
	s.anti_aliasing = false
	return s

static func bar_box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(1)
	s.anti_aliasing = false
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body()
	t.set_constant("line_spacing", "Label", 2)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.0))        # a text shadow is drawn glyph by glyph and is NOT batched (hundreds of draw calls on a busy HUD): plates give the contrast instead; floating text asks for one (label(..., shadow))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	var bn := panel_box(Color(0.27, 0.2, 0.13, 0.95), BORDER, 6, 2)
	var bh := panel_box(Color(0.36, 0.27, 0.16, 0.98), BORDER_HI, 6, 2)
	var bp := panel_box(Color(0.47, 0.34, 0.17, 1.0), ACCENT, 6, 2)
	var bd := panel_box(Color(0.18, 0.15, 0.12, 0.8), Color(0.32, 0.27, 0.22), 6, 2)
	for st in [bn, bh, bp, bd]:
		st.shadow_size = 0
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", panel_box(Color(0, 0, 0, 0), Color(1.0, 0.92, 0.55), 6, 3))      # a visible outline for keyboard / gamepad focus, distinct from hover
	t.set_font("font", "Button", head())                       # buttons are set in the heading face everywhere
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.82))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.42))
	t.set_stylebox("background", "ProgressBar", bar_box(Color(0.08, 0.06, 0.05, 0.9)))
	t.set_stylebox("fill", "ProgressBar", bar_box(ACCENT))
	t.set_font_size("font_size", "TooltipLabel", BODY)
	t.default_font_size = BODY                       # the HUD and the shop panels are laid out in canvas units: their text keeps its design size (reading text elsewhere follows the window)
	t.set_font_size("font_size", "Button", BODY)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_stylebox("panel", "TooltipPanel", panel_box(Color(0.1, 0.08, 0.06, 0.97), BORDER_HI, 5, 2))
	_theme = t
	return t

static func label(text: String, size := BODY, color := INK, heading := false, bold_face := false, shadow := false) -> Label:
	var l := Label.new()
	l.add_theme_constant_override("line_spacing", 2)
	l.text = text
	l.add_theme_font_override("font", head() if heading else (bold() if bold_face else body()))
	fit(l, size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))     # only for text that floats over the 3D scene (no plate behind it)
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	else:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## ---- Pixel fonts at any window size. Silkscreen and VT323 are true pixel fonts: they are only crisp when the on-screen glyph size is a whole multiple of their pixel
## grid (8 px for Silkscreen, 16 px for VT323). The window scales the 960x540 canvas by 1.33 (720p), 1.42 (768p), 1.67 (900p) or 2 (1080p), so a fixed base size lands
## between grid steps at most of them. Pixel-font labels therefore ask for a size in screen pixels (a base size x 2 = its 1080p size, rounded to the grid, never below
## 16 px) and are re-sized to base units whenever the window changes. Smooth fonts (Nunito Sans, Pixelify Sans) are rasterised at the final size by the stretch mode and
## stay sharp at every scale, so they keep plain base sizes. The text is never made smaller than 16 px on screen.
static func ui_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var win := Vector2(tree.root.size) if tree != null and tree.root != null else Vector2(DisplayServer.window_get_size())
	return maxf(0.5, minf(win.x / 960.0, win.y / 540.0))

static func snap_pixel_px(target: float, grid: int) -> int:
	return maxi(16, int(floor(target / float(grid) + 0.25)) * grid)

## Base-canvas font size for a pixel font whose 1080p design size is `base` x 2 px.
static func pixel_font_size(base: int, grid := 8) -> int:
	var snapped := maxi(6, roundi(float(snap_pixel_px(float(base) * 2.0, grid)) / ui_scale()))
	return mini(snapped, base + 2)            # HUD plates are laid out in canvas units: grid snapping may enlarge a label by 2 base units at most (then it is merely off-grid)

## ---- The readable floor. Every size token is a base-canvas size (x2 at 1080p). At 1280x720 the canvas scale is only 1.33, so a base 8 would be 10.7 px on screen:
## fit_size() raises a base size (by at most 1 base unit) so the text is not smaller than about MIN_PX (14 px) on screen, at whatever the window size is. At 1080p nothing changes.
const MIN_PX := 14.0
const MAX_GROW := 1          ## a size grows by at most 1 base unit: the HUD plates and shop panels are laid out in canvas units and must not burst
static func fit_size(base: int) -> int:
	return maxi(base, mini(ceili(MIN_PX / ui_scale() - 0.001), base + MAX_GROW))

static func fixed_fit(c: Control, base: int) -> void:
	c.add_theme_font_size_override("font_size", base)

## Registers a label (or button) whose size follows the window: `base` is its design size in canvas units.
static func fit(c: Control, base: int) -> void:
	c.set_meta("fit_base", base)
	c.add_to_group("fit_text")
	c.add_theme_font_size_override("font_size", fit_size(base))

static var _live_themes: Array = []
## Registers a Theme whose default and button sizes follow the window (base sizes in its metadata).
static func fit_theme(t: Theme, default_base: int, button_base: int, button_pixel_grid := 0) -> void:
	t.set_meta("default_base", default_base)
	t.set_meta("button_base", button_base)
	t.set_meta("button_grid", button_pixel_grid)
	_live_themes.append(weakref(t))
	_apply_theme(t)

static func _apply_theme(t: Theme) -> void:
	t.default_font_size = fit_size(int(t.get_meta("default_base")))
	var g := int(t.get_meta("button_grid"))
	t.set_font_size("font_size", "Button", pixel_font_size(int(t.get_meta("button_base")), g) if g > 0 else fit_size(int(t.get_meta("button_base"))))

## Re-sizes every registered label, button and theme (called when the window size changes).
static func refresh_pixel_text(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group("pixel_text"):
		var l := n as Label
		if l != null and l.has_meta("pixel_base"):
			l.add_theme_font_size_override("font_size", pixel_font_size(int(l.get_meta("pixel_base")), int(l.get_meta("pixel_grid"))))
	for n in tree.get_nodes_in_group("fit_text"):
		var c := n as Control
		if c != null and c.has_meta("fit_base") and not c.has_meta("pixel_base"):
			c.add_theme_font_size_override("font_size", fit_size(int(c.get_meta("fit_base"))))
	var alive := []
	for w in _live_themes:
		var t = (w as WeakRef).get_ref()
		if t != null:
			_apply_theme(t)
			alive.append(w)
	_live_themes = alive

static func _pixel(l: Label, base: int, grid: int) -> void:
	l.set_meta("pixel_base", base)
	l.set_meta("pixel_grid", grid)
	l.add_to_group("pixel_text")
	l.add_theme_font_size_override("font_size", pixel_font_size(base, grid))

## A Silkscreen HUD label (day and time, bag, minimap and category labels).
static func hud_label(text: String, size := HUD, color := INK, shadow := false) -> Label:
	var l := label(text, size, color, false, false, shadow)
	l.add_theme_font_override("font", hud())
	_pixel(l, size, 8)
	return l

## A VT323 readout label (digital counters).
static func mono_label(text: String, size := 14, color := INK) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", mono())
	_pixel(l, size, 16)
	return l

## The same label without the window-fitted growth: for the HUD plates and the shop panels, whose layouts are tight canvas-unit grids.
static func fixed_label(text: String, size := BODY, color := INK, heading := false, bold_face := false, shadow := false) -> Label:
	var l := label(text, size, color, heading, bold_face, shadow)
	l.remove_from_group("fit_text")
	l.remove_meta("fit_base")
	l.add_theme_font_size_override("font_size", size)
	return l

static func money_text(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if v < 0 else "$") + s + out
