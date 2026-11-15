extends VBoxContainer
class_name QuarrySettingsView
## The Settings panel, shared by the pause menu and the main menu: tabs for Audio (music, effects), Display (fullscreen, vertical sync) and Controls (the key
## reference that used to sit permanently along the bottom of the screen). Built from ordinary Godot controls; `controls` maps a name to each control so a
## menu (or a test) can reach them: music_vol, music_vol_mute, sfx_vol, fullscreen, vsync.

signal back

var game
var tab := "Audio"
var controls := {}
var _tabs_box: HBoxContainer
var _page: VBoxContainer

func setup(g, show_back := true) -> void:
	game = g
	add_theme_constant_override("separation", 8)
	GameSettings.load_all()
	var head := Label.new()
	head.text = "SETTINGS"
	head.add_theme_font_override("font", QuarryTheme.display())
	QuarryTheme.fit(head, QuarryTheme.HEAD)
	head.add_theme_color_override("font_color", QuarryTheme.ACCENT)
	add_child(head)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	add_child(_tabs_box)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 8)
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_page)
	if show_back:
		var b := _button("BACK")
		b.pressed.connect(func(): back.emit())
		controls["back"] = b
		add_child(b)
	_show_tab("Audio")

func _show_tab(t: String) -> void:
	tab = t
	for c in _tabs_box.get_children():
		_tabs_box.remove_child(c)
		c.queue_free()
	for nm in ["Audio", "Display", "Controls"]:
		var on: bool = nm == t
		var b := Button.new()
		b.text = nm
		b.name = "Tab_" + nm
		b.custom_minimum_size = Vector2(90, 26)
		b.focus_mode = Control.FOCUS_ALL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.30, 0.21, 0.08, 0.95) if on else Color(0.17, 0.13, 0.095, 0.95)
		sb.border_color = Color(1.0, 0.82, 0.36) if on else Color(0.5, 0.38, 0.22)
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(4)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45) if on else Color(0.82, 0.74, 0.58))
		b.add_theme_font_override("font", QuarryTheme.bold())
		var nm_copy: String = nm
		b.pressed.connect(func(): if nm_copy != tab: _show_tab(nm_copy))
		_tabs_box.add_child(b)
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	for k in ["music_vol", "music_vol_mute", "sfx_vol", "fullscreen", "vsync"]:
		controls.erase(k)
	match t:
		"Audio": _audio_page()
		"Display": _display_page()
		_: _controls_page()

func _label(text: String, dim := false) -> Label:
	var l := QuarryTheme.fixed_label(text, QuarryTheme.BODY, QuarryTheme.DIM if dim else QuarryTheme.INK)
	return l

func _slider_row(name_text: String, key: String, value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(name_text)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 22)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float): on_change.call(v))
	row.add_child(s)
	_page.add_child(row)
	controls[key] = s
	return s

func _check_row(text: String, key: String, on: bool, on_toggle: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = on
	cb.focus_mode = Control.FOCUS_ALL
	cb.add_theme_font_override("font", QuarryTheme.body())
	QuarryTheme.fit(cb, QuarryTheme.BODY)
	cb.toggled.connect(func(v: bool): on_toggle.call(v))
	_page.add_child(cb)
	controls[key] = cb
	return cb

func _audio_page() -> void:
	var music = game.music
	_slider_row("Music", "music_vol", music.volume, func(v: float): music.set_volume(v))
	var mute := CheckButton.new()                          # a Button the music test can press: it flips the music mute
	mute.text = "Mute music"
	mute.button_pressed = music.muted
	mute.focus_mode = Control.FOCUS_ALL
	QuarryTheme.fit(mute, QuarryTheme.BODY)
	mute.pressed.connect(func(): music.set_muted(not music.muted))
	_page.add_child(mute)
	controls["music_vol_mute"] = mute
	_slider_row("Effects", "sfx_vol", GameSettings.sfx_volume, func(v: float): GameSettings.set_sfx_volume(v))
	_page.add_child(_label("Music and effects are saved with your settings, not with the game.", true))

func _display_page() -> void:
	_check_row("Fullscreen", "fullscreen", GameSettings.fullscreen, func(v: bool): GameSettings.set_fullscreen(v))
	_check_row("Vertical sync", "vsync", GameSettings.vsync, func(v: bool): GameSettings.set_vsync(v))
	_page.add_child(_label("The picture always keeps the game's pixel look: only the window changes.", true))

func _controls_page() -> void:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 190)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 5)
	sc.add_child(grid)
	for row in GameSettings.CONTROLS:
		var cap := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.33, 0.25, 0.16, 0.95)
		s.border_color = Color(0.7, 0.55, 0.34)
		s.set_border_width_all(1)
		s.border_width_bottom = 3
		s.set_corner_radius_all(4)
		s.content_margin_left = 7
		s.content_margin_right = 7
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", s)
		cap.custom_minimum_size = Vector2(96, 0)
		var kl := QuarryTheme.fixed_label(str(row[0]), QuarryTheme.SMALL, Color(1.0, 0.92, 0.7), false, true)
		cap.add_child(kl)
		grid.add_child(cap)
		grid.add_child(_label(str(row[1])))
	_page.add_child(sc)

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	QuarryTheme.fit(b, QuarryTheme.BODY + 1)
	b.add_theme_font_override("font", QuarryTheme.head())
	if UiSkin.has("btn_main"):
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, preload("res://scripts/station_ui.gd")._style("main", st))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0.16, 0.1, 0.04))
	return b
