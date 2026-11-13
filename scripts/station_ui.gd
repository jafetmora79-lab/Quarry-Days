extends PanelContainer
class_name QuarryStationUI
## Clickable station menu (sales, tool upgrades, storage, machinery orders, crusher, rigs, pause).
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
const FS := QuarryTheme.BODY

var game
var title_label: Label
var money_label: Label
var scroll: ScrollContainer
var list: VBoxContainer
var foot: Label
var bar_box: HBoxContainer          ## the action buttons of a menu (Sell all, Office computer ...): docked under the scrolling list so they are never cut off
var pane: QuarryOfferPane            # the preview pane (shown when a menu offers things to buy)
var offers := {}
var selected_offer := ""
var _pane_menu := ""
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
	money_label = QuarryTheme.label("", FS + 2, MONEY, false, true)
	top.add_child(money_label)
	var close := Button.new()
	close.text = "CLOSE [Esc]"
	close.custom_minimum_size = Vector2(110, 28)
	close.pressed.connect(func(): game.ui_click("close", func(): game._close_menu(), close))
	top.add_child(close)
	root.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	pane = QuarryOfferPane.new()
	pane.setup(g)
	pane.visible = false
	pane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(pane)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	bar_box = HBoxContainer.new()
	bar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_box.add_theme_constant_override("separation", 8)
	root.add_child(bar_box)
	foot = QuarryTheme.label("", FS, DIM)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(660, 0)
	root.add_child(foot)

## Resizes the centred panel (base-canvas px); small menus such as Pause should not be a huge empty box.
func fit(w: float, h: float) -> void:
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = -h * 0.5
	offset_bottom = h * 0.5
	foot.custom_minimum_size.x = w - 40.0

func begin(title: String, money := -1, hint := "") -> void:
	if title != _pane_menu:
		selected_offer = ""          # a different menu: its own first item is shown
		_pane_menu = title
	offers.clear()
	if pane:
		pane.visible = false
		fit(700, 470)
	_scroll_keep = scroll.scroll_vertical
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for c in bar_box.get_children():
		bar_box.remove_child(c)
		c.queue_free()
	buttons.clear()
	_row_n = 0
	title_label.text = title
	money_label.text = ("CASH " + QuarryTheme.money_text(money)) if money >= 0 else ""
	foot.text = hint
	foot.visible = hint != ""
	scroll.set_deferred("scroll_vertical", _scroll_keep)
	call_deferred("_ensure_focus")

## A menu always has one control focused once it is drawn (a pad or keyboard user is never stranded): the first usable button of the list, else the action bar.
func _ensure_focus() -> void:
	if not is_inside_tree() or not visible:
		return
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and is_instance_valid(fo) and is_ancestor_of(fo) and fo.is_visible_in_tree() and not fo.is_queued_for_deletion() and not (fo is BaseButton and (fo as BaseButton).disabled):
		return
	var cands: Array = []
	cands.append_array(list.find_children("*", "BaseButton", true, false))
	cands.append_array(bar_box.find_children("*", "BaseButton", true, false))
	cands.append_array(find_children("*", "BaseButton", true, false))
	for c in cands:
		var bt := c as BaseButton
		if not bt.disabled and bt.focus_mode != Control.FOCUS_NONE and bt.is_visible_in_tree() and not bt.is_queued_for_deletion():
			bt.grab_focus()
			return

func text(t: String, color := DIM, centered := false) -> Label:
	var l := QuarryTheme.label(t, FS, color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(300, 0)
	list.add_child(l)
	return l

func _box(bg: Color, border: Color, margin := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var s := QuarryTheme.panel_box(bg, border, margin, 2)
	s.shadow_size = 0
	p.add_theme_stylebox_override("panel", s)
	list.add_child(p)
	return p

static var _styles := {}

## Button looks: "primary" (gold-green: Sell / Buy / Order), "toggle" (quiet outline: clerk on/off), default (brown).
static func _style(kind: String, state: String) -> StyleBoxFlat:
	var k := kind + state
	if _styles.has(k):
		return _styles[k]
	var bg := Color(0.27, 0.2, 0.13)
	var border := QuarryTheme.BORDER
	if kind == "primary":
		bg = Color(0.27, 0.4, 0.2)
		border = Color(0.62, 0.86, 0.48)
	elif kind == "toggle":
		bg = Color(0.16, 0.13, 0.1)
		border = Color(0.55, 0.47, 0.34)
	if state == "hover":
		bg = bg.lightened(0.18)
		border = border.lightened(0.2)
	elif state == "pressed":
		bg = bg.darkened(0.15)
		border = QuarryTheme.ACCENT
	elif state == "disabled":
		bg = Color(0.15, 0.125, 0.105, 0.9)
		border = Color(0.3, 0.26, 0.21)
	var sb := QuarryTheme.panel_box(bg, border, 6, 2)
	sb.shadow_size = 0
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_styles[k] = sb
	return sb

func make_button(key: String, label: String, enabled: bool, action: Callable, min_w := 96.0, kind := "") -> Button:
	var b := Button.new()
	if kind != "":
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _style(kind, st))
		if kind == "toggle":
			b.add_theme_font_override("font", QuarryTheme.body())
			b.add_theme_font_size_override("font_size", QuarryTheme.SMALL)
		b.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.42))
	b.text = label
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(min_w, 40 if game.touch_mode else 24)       # a finger needs a taller target
	b.focus_mode = Control.FOCUS_ALL                  # reachable with the d-pad / arrow keys, A / Enter presses
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
	left.add_child(QuarryTheme.label(title, FS + 1, ACCENT if locked_note == "" else DIM, false, true))
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
		var pc := _cell(QuarryTheme.money_text(price) if price > 0 else "FREE", GOOD if affordable else WARN, 130, HORIZONTAL_ALIGNMENT_RIGHT)
		pc.add_theme_font_override("font", QuarryTheme.bold())
		pc.add_theme_font_size_override("font_size", FS + 1)
		mid.add_child(pc)
	if level_text != "":
		mid.add_child(_cell(level_text, DIM, 130, HORIZONTAL_ALIGNMENT_RIGHT))
	var b := make_button(key, btn_text, can_buy and locked_note == "" and affordable, action, 96.0, "primary")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b

## A shop card that shows its model in the pane when clicked. `offer` comes from PurchaseOffers; the first card of a menu is
## shown at once. The card's button only selects; BUY is in the pane, so you see the thing before you decide.
func offer_item(key: String, title: String, desc: String, price: int, level_text: String, offer: Dictionary, locked_note := "") -> Button:
	offers[key] = offer
	if selected_offer == "":
		selected_offer = key
	var is_sel := key == selected_offer
	var affordable: bool = game.state.money >= price
	var card := _box(Color(0.24, 0.18, 0.12, 0.98) if is_sel else Color(0.19, 0.145, 0.1, 0.96), QuarryTheme.ACCENT if is_sel else Color(0.4, 0.31, 0.2))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(left)
	left.add_child(QuarryTheme.label(title, FS + 1, ACCENT if locked_note == "" else DIM, false, true))
	var d := QuarryTheme.label(desc, FS - 1, DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(150, 0)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(d)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(86, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mid)
	if locked_note != "":
		var n := _cell(locked_note, WARN, 86)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(n)
	else:
		var pc := _cell(QuarryTheme.money_text(price) if price > 0 else "FREE", GOOD if affordable else WARN, 86, HORIZONTAL_ALIGNMENT_RIGHT)
		pc.add_theme_font_override("font", QuarryTheme.bold())
		mid.add_child(pc)
	if level_text != "":
		mid.add_child(_cell(level_text, DIM, 86, HORIZONTAL_ALIGNMENT_RIGHT))
	var pick := func():
		if selected_offer != key:
			selected_offer = key
			game._draw_menu()
	var b := make_button("pick_" + key, "SHOWING" if is_sel else "VIEW", not is_sel, pick, 70.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pick.call())
	if is_sel and pane:
		pane.visible = true
		fit(860, 470)
		pane.show_offer(key, offer)
		pane.resume()
	return b

var _row_n := 0

## Table row: a swatch + cells (text, colour, width[, align[, bold]]) and trailing buttons
## [key, label, enabled, action, min_width, kind]. Rows alternate background shades; `header` rows are flat
## captions that keep the swatch column so headings line up with the values below.
func row(cells: Array, btns: Array, swatch := Color(0, 0, 0, 0), header := false) -> void:
	var card: PanelContainer
	if header:
		card = _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 5) # same margins as a row, so columns line up
		_row_n = 0
	else:
		card = _box(Color(0.21, 0.16, 0.11, 0.97) if _row_n % 2 == 0 else Color(0.16, 0.12, 0.085, 0.97), Color(0.36, 0.28, 0.19), 5)      # compact rows: eight of them plus the buttons fit the panel
		_row_n += 1
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var sw := ColorRect.new()
	sw.color = swatch
	sw.custom_minimum_size = Vector2(8, 20)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	for c in cells:
		var cell := _cell(str(c[0]), c[1], float(c[2]), c[3] if c.size() > 3 else HORIZONTAL_ALIGNMENT_LEFT)
		if header:
			cell.add_theme_font_size_override("font_size", QuarryTheme.SMALL)
		elif c.size() > 4 and bool(c[4]):
			cell.add_theme_font_override("font", QuarryTheme.bold())
		h.add_child(cell)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	for bd in btns:
		h.add_child(make_button(str(bd[0]), str(bd[1]), bool(bd[2]), bd[3], float(bd[4]) if bd.size() > 4 else 96.0, str(bd[5]) if bd.size() > 5 else ""))

func button_bar(btns: Array) -> void:
	var h := bar_box
	for bd in btns:
		h.add_child(make_button(str(bd[0]), str(bd[1]), bool(bd[2]), bd[3], float(bd[4]) if bd.size() > 4 else 150.0, str(bd[5]) if bd.size() > 5 else "primary"))
