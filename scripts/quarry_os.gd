extends Control
class_name QuarryOS
## QUARRY OS: the office computer's desktop. A small early-90s style windowed desktop built from Godot Controls: a patterned wallpaper, desktop shortcuts
## (double-click to open), a taskbar with a start button, one button per open window and the in-game clock, and a real window manager (drag by the title bar,
## minimise, restore, close, raise on click, several windows at once, everything kept inside the desktop). Every window hosts one page of the existing
## management UI, so the applications work on the real game state; nothing here keeps its own economy.
## All artwork is loaded from assets/ui/os (made by tools/make_os_art.py, replaceable) and falls back to drawn graphics when a file is missing.
## Text is always live Labels: no number, price or name is baked into an image.

const ART := "res://assets/ui/os/"
const TASKBAR_H := 26.0
const TITLE_H := 18.0
const ICON_W := 84.0
const ICON_H := 66.0
const APPS := [      ## id, title, icon, first tab of the page, window size
	["employees", "Employees", "employees", "staff", Vector2(640, 410)],
	["machinery", "Machinery", "machinery", "equipment", Vector2(700, 430)],
	["sales", "Sales", "sales", "sales", Vector2(600, 380)],
	["plan", "Quarry Plan", "plan", "plan", Vector2(620, 410)],
	["production", "Production", "production", "production", Vector2(640, 410)],
	["upgrades", "Upgrades", "upgrades", "upgrades", Vector2(640, 410)],
	["milestones", "Milestones", "milestones", "milestones", Vector2(640, 410)],
	["stats", "Stats", "stats", "stats", Vector2(480, 330)]]

var game
var shell                       ## the ManagementUI that owns this desktop (it keeps the old API: tab, content, refresh)
var windows: Array = []         ## open QuarryOSWindow, bottom to top
var active: Control = null
var area: Control               ## the windows live here
var icons := {}                 ## app id -> desktop icon Control
var selected_icon := ""
var task_buttons := {}          ## window -> taskbar Button
var task_box: HBoxContainer
var clock_label: Label
var money_label: Label
var start_menu: PanelContainer
var start_button: Button
var _tex_cache := {}
var _clock_t := 0.0
var _last_click := {"id": "", "ms": 0}
var _cascade := 0

# ------------------------------------------------------------------ click sound

static var _tick: AudioStreamWAV
var _tick_player: AudioStreamPlayer

## A very short, quiet synthesized tick for presses on the desktop (no audio file): the whole desktop shares one.
func click() -> void:
	if _tick_player == null or not is_inside_tree():
		return
	if _tick == null:
		var rate := 22050
		var n := int(rate * 0.03)
		var data := PackedByteArray()
		data.resize(n * 2)
		for i in range(n):
			var t := float(i) / float(rate)
			data.encode_s16(i * 2, int(sin(TAU * 1500.0 * t) * exp(-t * 150.0) * 14000.0))
		_tick = AudioStreamWAV.new()
		_tick.format = AudioStreamWAV.FORMAT_16_BITS
		_tick.mix_rate = rate
		_tick.data = data
	_tick_player.stream = _tick
	_tick_player.play()

# ------------------------------------------------------------------ art

func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var path := ART + name
		_tex_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[name]

## A 9-patch style from a bevel texture, or a flat fallback drawn in the same colours.
func box(kind: String, margin := 3) -> StyleBox:
	var t := tex(kind + ".png")
	if t != null:
		var s := StyleBoxTexture.new()
		s.texture = t
		s.set_texture_margin_all(3)
		s.set_content_margin_all(margin)
		return s
	var f := StyleBoxFlat.new()
	f.bg_color = {"raised": Color(0.75, 0.75, 0.75), "pressed": Color(0.69, 0.69, 0.69), "sunken": Color(0.09, 0.14, 0.17)}.get(kind, Color(0.75, 0.75, 0.75))
	f.border_color = Color(0.5, 0.5, 0.5)
	f.set_border_width_all(2)
	f.set_content_margin_all(margin)
	f.anti_aliasing = false
	return f

func os_theme() -> Theme:
	var t := Theme.new()
	t.default_font = QuarryTheme.body()
	t.default_font_size = QuarryTheme.BODY
	t.set_font("font", "Button", QuarryTheme.hud())
	t.set_font_size("font_size", "Button", QuarryTheme.HUD)
	for st in ["normal", "hover"]:
		t.set_stylebox(st, "Button", box("raised", 4))
	t.set_stylebox("pressed", "Button", box("pressed", 4))
	t.set_stylebox("hover_pressed", "Button", box("pressed", 4))
	t.set_stylebox("disabled", "Button", box("raised", 4))
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0, 0, 0, 0)
	fb.border_color = Color(0.1, 0.1, 0.5)
	fb.set_border_width_all(1)
	t.set_stylebox("focus", "Button", fb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color(0.05, 0.05, 0.08))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.47))
	return t

# ------------------------------------------------------------------ build

func setup(main_node, shell_ui) -> void:
	game = main_node
	shell = shell_ui
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = os_theme()
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST        # every bevel, icon and the cursor stay crisp pixels
	# wallpaper: the tile repeated, with nearest filtering so the pattern stays crisp at any window size
	var wp := TextureRect.new()
	wp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wp.texture = tex("wallpaper_tile.png")
	wp.stretch_mode = TextureRect.STRETCH_TILE
	wp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wp)
	if wp.texture == null:
		var cr := ColorRect.new()
		cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cr.color = Color(0.0, 0.5, 0.5)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cr)
		move_child(cr, 0)
	var bg := Control.new()                             # clicking the bare desktop deselects the icons and closes the start menu
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_select("")
			_close_start())
	add_child(bg)
	var col := 0
	var row := 0
	for a in APPS:
		var ic := _make_icon(a)
		ic.position = Vector2(10 + col * (ICON_W + 4), 10 + row * (ICON_H + 6))
		add_child(ic)
		icons[str(a[0])] = ic
		row += 1
		if row >= 6:
			row = 0
			col += 1
	area = Control.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.offset_bottom = -TASKBAR_H
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)
	_tick_player = AudioStreamPlayer.new()
	_tick_player.volume_db = -20.0
	add_child(_tick_player)
	_build_taskbar()
	_build_start_menu()
	set_process(false)

func _make_icon(a: Array) -> Control:
	var id := str(a[0])
	var c := Control.new()
	c.custom_minimum_size = Vector2(ICON_W, ICON_H)
	c.size = Vector2(ICON_W, ICON_H)
	c.set_meta("app", id)
	var sel := ColorRect.new()                           # the selected-state plate behind the caption
	sel.name = "Sel"
	sel.color = Color(0.0, 0.0, 0.5, 0.0)
	sel.position = Vector2(2, 36)
	sel.size = Vector2(ICON_W - 4, 24)
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(sel)
	var img := TextureRect.new()
	img.name = "Img"
	img.texture = tex("icon_%s.png" % str(a[2]))
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.custom_minimum_size = Vector2(32, 32)
	img.size = Vector2(32, 32)
	img.position = Vector2((ICON_W - 32.0) * 0.5, 2)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(img)
	if img.texture == null:                              # fallback: a plain tile so the shortcut still exists
		var fb := ColorRect.new()
		fb.color = Color(0.75, 0.75, 0.75)
		fb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(fb)
	var l := Label.new()
	l.name = "Caption"
	l.text = str(a[1])
	l.add_theme_font_override("font", QuarryTheme.hud())
	l.add_theme_font_size_override("font_size", QuarryTheme.BODY)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(2, 38)
	l.size = Vector2(ICON_W - 4, 24)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	c.tooltip_text = "%s  (double-click to open)" % str(a[1])
	c.gui_input.connect(_icon_input.bind(id))
	return c

func _icon_input(e: InputEvent, id: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	_close_start()
	_select(id)
	click()
	var now := Time.get_ticks_msec()
	if str(_last_click["id"]) == id and now - int(_last_click["ms"]) < 450 or e.double_click:
		_last_click = {"id": "", "ms": 0}
		open_app(id)
	else:
		_last_click = {"id": id, "ms": now}
	accept_event()

func _select(id: String) -> void:
	selected_icon = id
	for k in icons:
		var sel: ColorRect = icons[k].get_node("Sel")
		sel.color = Color(0.0, 0.0, 0.5, 0.95) if k == id else Color(0, 0, 0, 0)

func _build_taskbar() -> void:
	var bar := PanelContainer.new()
	bar.name = "Taskbar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TASKBAR_H
	bar.add_theme_stylebox_override("panel", box("raised", 2))
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	bar.add_child(hb)
	start_button = Button.new()
	start_button.text = "QUARRY OS"
	start_button.custom_minimum_size = Vector2(92, 0)
	start_button.focus_mode = Control.FOCUS_ALL        # with no window open the keyboard / gamepad lands here
	start_button.pressed.connect(_toggle_start)
	hb.add_child(start_button)
	task_box = HBoxContainer.new()
	task_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_box.add_theme_constant_override("separation", 3)
	hb.add_child(task_box)
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", box("sunken", 3))
	hb.add_child(tray)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	tray.add_child(th)
	money_label = _tray_label(Color(0.99, 0.84, 0.42))
	th.add_child(money_label)
	clock_label = _tray_label(Color(0.75, 0.95, 0.85))
	th.add_child(clock_label)

func _tray_label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", QuarryTheme.hud())
	l.add_theme_font_size_override("font_size", QuarryTheme.BODY)
	l.add_theme_color_override("font_color", color)
	return l

func _build_start_menu() -> void:
	start_menu = PanelContainer.new()
	start_menu.visible = false
	start_menu.add_theme_stylebox_override("panel", box("raised", 4))
	start_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	start_menu.offset_left = 2
	start_menu.offset_bottom = -TASKBAR_H
	start_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(start_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	start_menu.add_child(v)
	for a in APPS:
		var b := Button.new()
		b.text = " " + str(a[1])
		b.icon = tex("icon_%s.png" % str(a[2]))
		b.expand_icon = false
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(170, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			_close_start()
			open_app(str(a[0])))
		v.add_child(b)
	var leave := Button.new()
	leave.text = " Leave computer"
	leave.custom_minimum_size = Vector2(170, 26)
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(func(): game._close_menu())
	v.add_child(leave)

func _toggle_start() -> void:
	click()
	start_menu.visible = not start_menu.visible

func _close_start() -> void:
	if start_menu != null:
		start_menu.visible = false

# ------------------------------------------------------------------ windows

func app_def(id: String) -> Array:
	for a in APPS:
		if str(a[0]) == id:
			return a
	return []

func app_for_tab(tab_id: String) -> String:
	if tab_id in ["staff", "hire", "payroll"]:
		return "employees"
	for a in APPS:
		if str(a[3]) == tab_id or str(a[0]) == tab_id:
			return str(a[0])
	return ""

func window_of(id: String) -> Control:
	for w in windows:
		if str(w.app_id) == id:
			return w
	return null

## Opens (or restores and raises) the window of an app. `tab_id` picks the page inside it (for example "hire" inside Employees).
func open_app(id: String, tab_id := "") -> Control:
	var def := app_def(id)
	if def.is_empty():
		return null
	var w := window_of(id)
	if w == null:
		w = QuarryOSWindow.new()
		var sz: Vector2 = def[4]
		sz.x = minf(sz.x, size.x - 8.0)
		sz.y = minf(sz.y, size.y - TASKBAR_H - 8.0)
		w.setup(self, id, str(def[1]), tex("icon_%s.png" % str(def[2])), sz)
		var page = shell.make_page(str(def[3]) if tab_id == "" else tab_id)
		w.set_page(page)
		area.add_child(w)
		page.refresh()
		windows.append(w)
		w.position = clamp_pos(Vector2(110 + 26 * (_cascade % 6), 24 + 22 * (_cascade % 6)), w.size)
		_cascade += 1
		_add_task_button(w)
		w.pop_in()
	elif tab_id != "":
		w.page._set_tab(tab_id)
	restore(w)
	raise_window(w)
	return w

func _add_task_button(w: Control) -> void:
	var b := Button.new()
	b.text = str(w.title_text)
	b.toggle_mode = false
	b.clip_text = true
	b.custom_minimum_size = Vector2(110, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		click()
		if w == active and w.visible:
			minimize(w)
		else:
			restore(w)
			raise_window(w))
	task_box.add_child(b)
	task_buttons[w] = b

func raise_window(w: Control) -> void:
	if w == null or not is_instance_valid(w):
		return
	area.move_child(w, -1)
	windows.erase(w)
	windows.append(w)
	active = w
	for x in windows:
		x.set_active(x == w)
	_sync_tasks()
	shell.on_focus(w.page)
	w.page.call_deferred("_ensure_focus")

func minimize(w: Control) -> void:
	w.visible = false
	if active == w:
		active = null
		for i in range(windows.size() - 1, -1, -1):
			if windows[i].visible:
				raise_window(windows[i])
				break
		if active == null:
			shell.on_focus(null)
			start_button.grab_focus()
	_sync_tasks()

func restore(w: Control) -> void:
	if not w.visible:
		w.visible = true
		w.position = clamp_pos(w.position, w.size)
	_sync_tasks()

func close_window(w: Control) -> void:
	windows.erase(w)
	if task_buttons.has(w):
		task_buttons[w].queue_free()
		task_buttons.erase(w)
	if active == w:
		active = null
	w.queue_free()
	for i in range(windows.size() - 1, -1, -1):
		if windows[i].visible:
			raise_window(windows[i])
			break
	if active == null:
		shell.on_focus(null)
		start_button.grab_focus()
	_sync_tasks()

func close_all() -> void:
	for w in windows.duplicate():
		close_window(w)

func _sync_tasks() -> void:
	for w in task_buttons:
		var b: Button = task_buttons[w]
		b.add_theme_stylebox_override("normal", box("pressed", 4) if (w == active and w.visible) else box("raised", 4))
		b.text = str(w.title_text)

## Keeps a window of `sz` inside the desktop (above the taskbar).
func clamp_pos(p: Vector2, sz: Vector2) -> Vector2:
	var room := Vector2(maxf(0.0, size.x - sz.x), maxf(0.0, size.y - TASKBAR_H - sz.y))
	return Vector2(clampf(p.x, 0.0, room.x), clampf(p.y, 0.0, room.y))

## The window under a screen point, topmost first.
func window_at(p: Vector2) -> Control:
	for i in range(windows.size() - 1, -1, -1):
		var w: Control = windows[i]
		if w.visible and w.get_global_rect().has_point(p):
			return w
	return null

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventMouseButton and e.pressed:
		var w := window_at(e.position)
		if w != null and w != active:
			raise_window(w)                         # a click anywhere on a window brings it to the front before the click is handled
		if start_menu.visible and not start_menu.get_global_rect().has_point(e.position) and not start_button.get_global_rect().has_point(e.position):
			_close_start()

# ------------------------------------------------------------------ clock and state

## The taskbar reads the game's own clock (state.clock_minutes, the same value the HUD shows); it never touches the Windows clock.
func refresh_tray() -> void:
	if game == null:
		return
	var clock := int(game.state.clock_minutes)
	clock_label.text = "DAY %d  %s" % [clock / 1440 + 1, game.fmt_time(clock)]
	money_label.text = QuarryTheme.money_text(game.state.money)

func refresh_all() -> void:
	refresh_tray()
	for w in windows:
		if is_instance_valid(w.page):
			w.page.refresh()

func _process(delta: float) -> void:
	_clock_t += delta
	if _clock_t >= 0.25:
		_clock_t = 0.0
		refresh_tray()

func open_desktop() -> void:
	visible = true
	set_process(true)
	_select("")
	_close_start()
	refresh_tray()
	if active == null:
		start_button.call_deferred("grab_focus")
	Input.warp_mouse(Vector2(DisplayServer.window_get_size()) * 0.5)       # the cursor appears in the middle of the screen, on the desktop
	for w in windows:
		w.position = clamp_pos(w.position, w.size)
	var img: Image = tex("cursor.png").get_image() if tex("cursor.png") != null else null
	if img != null:
		var k := clampi(int(round(float(DisplayServer.window_get_size().y) / 540.0)), 1, 4)     # whole-number scale: the cursor stays crisp
		if k > 1:
			img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2.ZERO)

func close_desktop() -> void:
	visible = false
	set_process(false)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
