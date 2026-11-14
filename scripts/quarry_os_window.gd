extends Control
class_name QuarryOSWindow
## One window of QUARRY OS: a raised frame, a dark-blue title bar (drag it to move the window) with minimise and close squares, and a sunken client
## area that holds one page of the management UI. Position is always clamped to the desktop so a window can never be dragged out of reach.

var os: QuarryOS
var app_id := ""
var title_text := ""
var icon_tex: Texture2D
var page: Control
var title_bar: PanelContainer
var title_label: Label
var client: PanelContainer
var _drag := false
var _drag_off := Vector2.ZERO
var _active := false

var min_size := Vector2(380, 260)
var _resize := false
var _resize_from := Vector2.ZERO
var _resize_mouse := Vector2.ZERO

func setup(os_node: QuarryOS, id: String, title: String, icon: Texture2D, sz: Vector2, min_sz := Vector2(380, 260)) -> void:
	min_size = min_sz
	os = os_node
	app_id = id
	title_text = title
	icon_tex = icon
	name = "Window_" + id
	custom_minimum_size = min_size
	size = sz
	mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", os.box("raised", 3))
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	frame.add_child(v)
	title_bar = PanelContainer.new()
	title_bar.custom_minimum_size = Vector2(0, QuarryOS.TITLE_H)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_title_input)
	v.add_child(title_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	title_bar.add_child(hb)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.custom_minimum_size = Vector2(16, 16)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", QuarryTheme.head())
	QuarryTheme.fit(title_label, QuarryTheme.BODY + 1)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(title_label)
	hb.add_child(_square("min", func(): os.minimize(self), "Minimise"))
	hb.add_child(_square("close", func(): os.close_window(self), "Close"))
	client = PanelContainer.new()
	client.size_flags_vertical = Control.SIZE_EXPAND_FILL
	client.add_theme_stylebox_override("panel", os.box("sunken", 5))
	v.add_child(client)
	_make_grip()
	set_active(true)

## A corner grip: drag to resize between the app's minimum size and the desktop.
func _make_grip() -> void:
	var g := Control.new()
	g.name = "ResizeGrip"
	g.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	g.offset_left = -15
	g.offset_top = -15
	g.offset_right = -2
	g.offset_bottom = -2
	g.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	g.tooltip_text = "Drag to resize"
	g.draw.connect(func():
		for k in range(3):
			g.draw_line(Vector2(12 - k * 4, 12), Vector2(12, 12 - k * 4), Color(0.4, 0.4, 0.42))
			g.draw_line(Vector2(12 - k * 4 + 1, 12), Vector2(12, 12 - k * 4 + 1), Color(1, 1, 1)))
	g.gui_input.connect(_grip_input)
	add_child(g)

func _grip_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_resize = e.pressed
		_resize_from = size
		_resize_mouse = get_global_mouse_position()
		os.raise_window(self)
		accept_event()
	elif e is InputEventMouseMotion and _resize:
		resize_to(_resize_from + (get_global_mouse_position() - _resize_mouse))
		accept_event()

## Sets the size within [minimum, what is left of the desktop from the window's corner].
func resize_to(sz: Vector2) -> void:
	var room := Vector2(os.size.x - position.x, os.size.y - QuarryOS.TASKBAR_H - position.y)
	size = Vector2(clampf(sz.x, min_size.x, maxf(min_size.x, room.x)), clampf(sz.y, min_size.y, maxf(min_size.y, room.y)))

func _square(kind: String, action: Callable, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(18, 16)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.name = "Btn_" + kind
	var g := os.tex("glyph_%s.png" % ("close" if kind == "close" else "min"))
	if g != null:
		b.icon = g
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		b.text = "x" if kind == "close" else "_"
	b.pressed.connect(func():
		os.click()
		action.call())
	return b

func set_page(p: Control) -> void:
	page = p
	client.add_child(p)

func set_active(on: bool) -> void:
	_active = on
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.0, 0.5) if on else Color(0.5, 0.5, 0.5)
	s.set_content_margin_all(2)
	s.content_margin_left = 3
	title_bar.add_theme_stylebox_override("panel", s)
	var t: Texture2D = os.tex("title_active.png" if on else "title_inactive.png")
	if t != null:
		var st := StyleBoxTexture.new()
		st.texture = t
		st.set_texture_margin_all(0)
		st.set_content_margin_all(2)
		st.content_margin_left = 3
		title_bar.add_theme_stylebox_override("panel", st)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1) if on else Color(0.82, 0.82, 0.82))

## A short fade-in so a window appears without a hard pop (0.14 s).
func pop_in() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.14)

func _title_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		_drag_off = get_global_mouse_position() - global_position
		os.raise_window(self)
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		move_to(os.area.get_global_transform().affine_inverse() * (get_global_mouse_position() - _drag_off))
		accept_event()

func move_to(p: Vector2) -> void:
	position = os.clamp_pos(p, size)

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_drag = false
		_resize = false                           # released outside the title bar: the drag ends
