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
	# darkened left panel so the writing reads over any scene
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.045, 0.03, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 360.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var edge := ColorRect.new()
	edge.color = QuarryTheme.BORDER
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = 358.0
	edge.offset_right = 360.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 36.0
	col.offset_right = 330.0
	col.offset_top = 70.0
	col.offset_bottom = -40.0
	add_child(col)
	col.add_child(_label("GRANDPA", 34, ACCENT, true))
	col.add_child(_label("WALT'S", 34, ACCENT, true))
	col.add_child(_label("QUARRY", 34, INK, true))
	col.add_child(_label("Cut the rock. Run the business. Keep the family quarry alive.", QuarryTheme.BODY, DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	col.add_child(gap)
	continue_btn = _button("CONTINUE", func(): chosen.emit("continue"))
	continue_btn.disabled = not has_save
	col.add_child(continue_btn)
	new_btn = _button("NEW GAME", _on_new)
	col.add_child(new_btn)
	col.add_child(_button("QUIT", func(): chosen.emit("quit")))
	note = _label("", QuarryTheme.BODY, DIM)
	col.add_child(note)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_label("A save is made every minute and when you close the game.", QuarryTheme.BODY, DIM))
	_refresh_note()

func _label(text: String, size: int, color: Color, heading := false) -> Label:
	var l := QuarryTheme.label(text, size, color, false, heading)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", QuarryTheme.bold() if heading else QuarryTheme.body())
	return l

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", QuarryTheme.HEAD)
	b.pressed.connect(action)
	return b

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
