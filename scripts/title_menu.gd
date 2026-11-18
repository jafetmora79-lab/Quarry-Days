extends Control
class_name QuarryTitleMenu
## The main menu: the real quarry, filmed live by a slow camera, behind a dark panel with the game's name and three buttons
## (CONTINUE, NEW GAME, QUIT). The world is paused while it is open (Main.menu == "title").

signal chosen(what: String)

const INK := QuarryTheme.INK
const DIM := QuarryTheme.DIM
const ACCENT := QuarryTheme.ACCENT
const WARN := QuarryTheme.WARN

var game
var cam: Camera3D
var t := 0.0
var has_save := false
var confirm_new := false
var col: VBoxContainer
var settings_box: VBoxContainer
var continue_btn: Button
var new_btn: Button
var note: Label
var _prev_cam: Camera3D

func setup(main_node, save_exists: bool) -> void:
	game = main_node
	has_save = save_exists
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# the camera film of the real world
	_prev_cam = game.get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "TitleCamera"
	cam.fov = 58.0
	game.add_child(cam)
	cam.current = true
	_aim(0.0)
	# a dark fade down the left so the panel reads over any scene
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 452.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if UiSkin.has("panel_main"):                    # the signboard everything sits on: steel rim, hazard-striped corners (drawn by tools/build_hud_frames.py)
		var frame := Panel.new()
		frame.add_theme_stylebox_override("panel", UiSkin.box("panel_main", null, [0, 0, 0, 0]))
		frame.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		frame.offset_left = 18.0
		frame.offset_right = 430.0
		frame.offset_top = 18.0
		frame.offset_bottom = -18.0
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 50.0
	col.offset_right = 398.0
	col.offset_top = 32.0
	col.offset_bottom = -32.0
	add_child(col)
	# the mark: the range and the sun, then the name in two lines, then a hazard bar
	var logo := TextureRect.new()
	logo.texture = UiSkin.tex("menu_logo")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.custom_minimum_size = Vector2(348, 66)
	col.add_child(logo)
	var q := _label("QUARRY", 36, ACCENT, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dd := _label("DAYS", 36, INK, true)
	dd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nm := VBoxContainer.new()                                              # the two lines of the name sit close together
	nm.add_theme_constant_override("separation", -12)
	nm.add_child(q)
	nm.add_child(dd)
	col.add_child(nm)
	var bar := TextureRect.new()
	bar.texture = UiSkin.tex("hazard_bar")
	bar.stretch_mode = TextureRect.STRETCH_TILE
	bar.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.custom_minimum_size = Vector2(348, 8)
	col.add_child(bar)
	var tag := _label("Cut the rock. Run the business. Keep the family quarry alive.", QuarryTheme.BODY, DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	col.add_child(gap)
	continue_btn = _menu_button("CONTINUE", "play", true)
	continue_btn.pressed.connect(func(): chosen.emit("continue"))
	continue_btn.disabled = not has_save
	col.add_child(continue_btn)
	if has_save and game != null and game.state != null:                       # what is waiting in the save, on the button itself
		var sv := Label.new()
		sv.text = "DAY %d   $%s" % [int(game.state.clock_minutes / 1440.0) + 1, QuarryTheme.money_text(int(game.state.money)).trim_prefix("$")]
		sv.add_theme_font_override("font", QuarryTheme.hud())
		sv.add_theme_font_size_override("font_size", QuarryTheme.SMALL)
		sv.add_theme_color_override("font_color", Color(0.12, 0.07, 0.02))
		sv.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		sv.offset_left = -120.0
		sv.offset_right = -16.0
		sv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		continue_btn.add_child(sv)
	new_btn = _menu_button("NEW GAME", "plus", false)
	new_btn.pressed.connect(_on_new)
	col.add_child(new_btn)
	var sb := _menu_button("SETTINGS", "gear", false)
	sb.pressed.connect(_show_settings)
	col.add_child(sb)
	var qb := _menu_button("QUIT", "power", false)
	qb.pressed.connect(func(): chosen.emit("quit"))
	col.add_child(qb)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 2)
	col.add_child(gap2)
	var info := PanelContainer.new()                                           # a little inset note at the bottom: what the save is doing
	info.add_theme_stylebox_override("panel", UiSkin.box("panel_inset", QuarryTheme.panel_box(), [12, 5, 12, 5]))
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 10)
	info.add_child(ih)
	var ic := TextureRect.new()
	ic.texture = UiSkin.tex("menu_info")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(28, 28)
	ih.add_child(ic)
	var iv := VBoxContainer.new()
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(iv)
	note = _label("", QuarryTheme.BODY, DIM)
	iv.add_child(note)
	iv.add_child(_label("A save is made every minute and when you close the game.", QuarryTheme.SMALL, DIM))
	col.add_child(info)
	_refresh_note()

func _label(text: String, size: int, color: Color, heading := false) -> Label:
	var l := QuarryTheme.label(text, size, color, false, heading)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", QuarryTheme.display() if heading else QuarryTheme.body())
	return l

## A menu button drawn from the plate art: steel (or the orange primary one) with an icon at the left. Hover lifts it, a press darkens it, disabled greys it.
func _menu_button(text: String, icon_name: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(348, 46 if primary else 38)
	QuarryTheme.fit(b, QuarryTheme.HEAD)
	b.add_theme_font_override("font", QuarryTheme.head())
	var art := "btn_primary" if primary else "btn_main"
	var content := [16, 4, 16, 6]
	b.add_theme_stylebox_override("normal", UiSkin.box(art, QuarryTheme.panel_box(), content))
	b.add_theme_stylebox_override("hover", UiSkin.box(art, QuarryTheme.panel_box(), content, Color(1.22, 1.22, 1.22)))
	b.add_theme_stylebox_override("focus", UiSkin.box(art, QuarryTheme.panel_box(), content, Color(1.22, 1.22, 1.22)))
	b.add_theme_stylebox_override("pressed", UiSkin.box(art, QuarryTheme.panel_box(), content, Color(0.78, 0.78, 0.78)))
	b.add_theme_stylebox_override("disabled", UiSkin.box("btn_disabled", QuarryTheme.panel_box(), content))
	var ink := Color(0.14, 0.08, 0.02) if primary else Color(0.96, 0.93, 0.84)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.6))
	if UiSkin.has("menu_" + icon_name):
		b.icon = UiSkin.tex("menu_" + icon_name)
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 14)
		b.add_theme_color_override("icon_normal_color", Color.WHITE)
		b.add_theme_color_override("icon_disabled_color", Color(0.6, 0.6, 0.6))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.focus_entered.connect(func(): _pop(b, 1.02))
	b.button_down.connect(func(): _pop(b, 0.98))
	return b

## Hover, focus and click feedback shared by every button: a quick size pop.
func _pop(b: Control, to: float) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * to, 0.06)
	tw.tween_property(b, "scale", Vector2.ONE, 0.10)

## The Settings panel takes the place of the buttons on the plate; BACK brings them back.
func _show_settings() -> void:
	col.visible = false
	settings_box = VBoxContainer.new()
	settings_box.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	settings_box.offset_left = 50.0
	settings_box.offset_right = 398.0
	settings_box.offset_top = 40.0
	settings_box.offset_bottom = -40.0
	add_child(settings_box)
	var sv := QuarrySettingsView.new()
	sv.setup(game)
	sv.back.connect(func():
		settings_box.queue_free()
		settings_box = null
		col.visible = true)
	settings_box.add_child(sv)

func _on_new() -> void:
	if has_save and not confirm_new:
		confirm_new = true
		new_btn.text = "ERASE SAVE & START"
		_refresh_note()
		return
	chosen.emit("new")

func _refresh_note() -> void:
	if confirm_new:
		note.text = "This erases your saved quarry. Click again to confirm, or press CONTINUE to keep it."
		note.add_theme_color_override("font_color", WARN)
	else:
		note.text = "Your saved quarry is ready." if has_save else "No saved quarry yet: start a new game."
		note.add_theme_color_override("font_color", DIM)

## The camera drifts in a slow arc across the yard, with the gate and the quarry behind.
func _aim(time: float) -> void:
	var a := sin(time * 0.07) * 0.7
	var c := Vector3(1.0, 1.8, -2.0)
	cam.global_position = c + Vector3(sin(a) * 26.0, 8.0 + sin(time * 0.05) * 1.5, cos(a) * 26.0)
	cam.look_at(c + Vector3(0.0, 1.5, -4.0), Vector3.UP)

func _process(delta: float) -> void:
	t += delta
	if cam != null and is_instance_valid(cam):
		_aim(t)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and has_save:
			chosen.emit("continue")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()      # Esc does nothing here: there is no game to pause yet

## Gives the player's camera back and removes the film camera.
func release() -> void:
	if cam != null and is_instance_valid(cam):
		cam.queue_free()
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.current = true
