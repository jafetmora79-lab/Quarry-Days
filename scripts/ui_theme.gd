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
	t.default_font_size = BODY
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
	t.set_font_size("font_size", "Button", BODY)
	t.set_font("font", "Button", head())                       # buttons are set in the heading face everywhere
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.82))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.42))
	t.set_stylebox("background", "ProgressBar", bar_box(Color(0.08, 0.06, 0.05, 0.9)))
	t.set_stylebox("fill", "ProgressBar", bar_box(ACCENT))
	_theme = t
	return t

static func label(text: String, size := BODY, color := INK, heading := false, bold_face := false, shadow := false) -> Label:
	var l := Label.new()
	l.add_theme_constant_override("line_spacing", 2)
	l.text = text
	l.add_theme_font_override("font", head() if heading else (bold() if bold_face else body()))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))     # only for text that floats over the 3D scene (no plate behind it)
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	else:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A Silkscreen HUD label (day and time, bag, minimap and category labels).
static func hud_label(text: String, size := HUD, color := INK, shadow := false) -> Label:
	var l := label(text, size, color, false, false, shadow)
	l.add_theme_font_override("font", hud())
	return l

## A VT323 readout label (digital counters).
static func mono_label(text: String, size := 14, color := INK) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", mono())
	return l

static func money_text(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if v < 0 else "$") + s + out
