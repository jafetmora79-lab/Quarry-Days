extends RefCounted
class_name QuarryTheme
## Shared cozy pixel UI style: Pixelify Sans (body) and Silkscreen (headings), both SIL OFL, rendered
## without antialiasing; warm muted panels with a 2 px border, small rounded corners and a soft drop shadow.
## Sizes are for the 960x540 base canvas (the window scales it to 1280x720 / 1920x1080).

const BG := Color(0.15, 0.115, 0.085, 0.88)
const BG_SOFT := Color(0.2, 0.155, 0.11, 0.82)
const BORDER := Color(0.5, 0.37, 0.23)
const BORDER_HI := Color(0.72, 0.56, 0.34)
const INK := Color(0.96, 0.9, 0.77)
const DIM := Color(0.7, 0.63, 0.5)
const ACCENT := Color(0.98, 0.76, 0.34)
const GOOD := Color(0.62, 0.86, 0.48)
const WARN := Color(1.0, 0.5, 0.38)
const MONEY := Color(0.99, 0.84, 0.42)
const RES_COLORS := {"limestone": Color(0.86, 0.83, 0.74), "coal": Color(0.62, 0.64, 0.68), "iron_ore": Color(0.92, 0.55, 0.42),
	"crushed_stone": Color(0.82, 0.8, 0.72), "copper_ore": Color(0.5, 0.86, 0.66), "gold_ore": Color(1.0, 0.82, 0.32)}

static var _body: FontFile
static var _head: FontFile
static var _theme: Theme

static func _pixel(path: String) -> FontFile:
	var f: FontFile = load(path)
	if f == null:
		return null
	f = f.duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	return f

static func body() -> Font:
	if _body == null:
		_body = _pixel("res://assets/fonts/PixelifySans.ttf")
	return _body if _body else ThemeDB.fallback_font

static func head() -> Font:
	if _head == null:
		_head = _pixel("res://assets/fonts/Silkscreen.ttf")
	return _head if _head else body()

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
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
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
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.82))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.42))
	t.set_stylebox("background", "ProgressBar", bar_box(Color(0.08, 0.06, 0.05, 0.9)))
	t.set_stylebox("fill", "ProgressBar", bar_box(ACCENT))
	_theme = t
	return t

static func label(text: String, size := 15, color := INK, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", head() if heading else body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func money_text(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if v < 0 else "$") + s + out
