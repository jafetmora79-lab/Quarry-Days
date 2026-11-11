extends PanelContainer
class_name QuarryStationUI
## Clickable station menu (sales booth, upgrade board, storage, machinery orders, crusher, rigs, pause).
## One cozy panel with a header (title, cash, Close), a scrolling list of cards / rows, and a footer hint.
## Every action is a visible button; the number-key shortcuts stay as optional extras (see the footer hint).
## Buttons report through game.ui_click(), which debounces rapid clicks and shows the money pop-up.
## Sized for the 960x540 base canvas.

const INK := QuarryTheme.INK
const DIM := QuarryTheme.DIM
const ACCENT := QuarryTheme.ACCENT
const GOOD := QuarryTheme.GOOD
const WARN := QuarryTheme.WARN
const MONEY := QuarryTheme.MONEY
const FS := 15 # body size: a whole multiple of the pixel font's grid at 1280x720 and 1920x1080

var game
var title_label: Label
var money_label: Label
var scroll: ScrollContainer
var list: VBoxContainer
var foot: Label
var buttons := {}   # key -> Button (the current menu's buttons; also used by tests)
var _scroll_keep := 0

func setup(g) -> void:
	game = g
	visible = false
	add_theme_stylebox_override("panel", QuarryTheme.panel_box(Color(0.13, 0.1, 0.075, 0.96), QuarryTheme.BORDER_HI, 12, 4))
	set_anchors_preset(Control.PRESET_CENTER)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -350
	offset_right = 350
	offset_top = -235
	offset_bottom = 235
	clip_contents = true
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	title_label = QuarryTheme.label("", 12, ACCENT, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	money_label = QuarryTheme.label("", FS, MONEY)
	top.add_child(money_label)
	var close := Button.new()
	close.text = "CLOSE [Esc]"
	close.custom_minimum_size = Vector2(110, 28)
	close.pressed.connect(func(): game.ui_click("close", func(): game._close_menu(), close))
	top.add_child(close)
	root.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	foot = QuarryTheme.label("", FS, DIM)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(660, 0)
	root.add_child(foot)

func begin(title: String, money := -1, hint := "") -> void:
	_scroll_keep = scroll.scroll_vertical
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	buttons.clear()
	title_label.text = title
	money_label.text = ("CASH " + QuarryTheme.money_text(money)) if money >= 0 else ""
	foot.text = hint
	foot.visible = hint != ""
	scroll.set_deferred("scroll_vertical", _scroll_keep)

func text(t: String, color := DIM) -> Label:
	var l := QuarryTheme.label(t, FS, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(300, 0)
	list.add_child(l)
	return l

func _box(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := QuarryTheme.panel_box(bg, border, 8, 2)
	s.shadow_size = 0
	p.add_theme_stylebox_override("panel", s)
	list.add_child(p)
	return p

func make_button(key: String, label: String, enabled: bool, action: Callable, min_w := 96.0) -> Button:
	var b := Button.new()
	b.text = label
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(min_w, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	b.pressed.connect(func(): game.ui_click(key, action, b))
	buttons[key] = b
	return b

func _cell(t: String, color: Color, min_w: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := QuarryTheme.label(t, FS, color)
	l.custom_minimum_size = Vector2(min_w, 0)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Shop / upgrade card: name + description on the left, price + ownership in the middle, one button on the right.
## An unaffordable card shows its price in red and a disabled button. `locked` shows `locked_note` instead of a price.
func item(key: String, title: String, desc: String, price: int, level_text: String, btn_text: String, can_buy: bool, action: Callable, locked_note := "") -> Button:
	var affordable: bool = game.state.money >= price
	var card := _box(Color(0.19, 0.145, 0.1, 0.96), Color(0.4, 0.31, 0.2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	h.add_child(left)
	left.add_child(QuarryTheme.label(title, FS, ACCENT if locked_note == "" else DIM))
	var d := QuarryTheme.label(desc, FS, DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(250, 0)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(d)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(130, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(mid)
	if locked_note != "":
		var n := _cell(locked_note, WARN, 130)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(n)
	else:
		mid.add_child(_cell(QuarryTheme.money_text(price) if price > 0 else "FREE", GOOD if affordable else WARN, 130, HORIZONTAL_ALIGNMENT_RIGHT))
	if level_text != "":
		mid.add_child(_cell(level_text, DIM, 130, HORIZONTAL_ALIGNMENT_RIGHT))
	var b := make_button(key, btn_text, can_buy and locked_note == "" and affordable, action)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b

## Table row: a swatch + cells (text, colour, width) and trailing buttons [key, label, enabled, action].
func row(cells: Array, btns: Array, swatch := Color(0, 0, 0, 0)) -> void:
	var card := _box(Color(0.19, 0.145, 0.1, 0.96), Color(0.36, 0.28, 0.19))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	if swatch.a > 0.0:
		var sw := ColorRect.new()
		sw.color = swatch
		sw.custom_minimum_size = Vector2(10, 22)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
	for c in cells:
		h.add_child(_cell(str(c[0]), c[1], float(c[2]), c[3] if c.size() > 3 else HORIZONTAL_ALIGNMENT_LEFT))
	for bd in btns:
		h.add_child(make_button(str(bd[0]), str(bd[1]), bool(bd[2]), bd[3], float(bd[4]) if bd.size() > 4 else 96.0))

func button_bar(btns: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	list.add_child(h)
	for bd in btns:
		h.add_child(make_button(str(bd[0]), str(bd[1]), bool(bd[2]), bd[3], float(bd[4]) if bd.size() > 4 else 150.0))
