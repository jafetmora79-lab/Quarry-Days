extends SceneTree
## Gamepad and touch support: pad bindings per situation, generated key / mouse events, analog look, hint glyphs, focus in the shop menus, safe-area insets,
## touch buttons clear of the map and finger-sized menu buttons.   godot --headless --fixed-fps 60 -s tests/test_input_devices.gd

var checks := 0
var failures := []

func check(c: bool, label: String) -> void:
	checks += 1
	if not c:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func has_joy_motion(act: String, axis: int, sign_: float) -> bool:
	for e in InputMap.action_get_events(act):
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == axis and signf((e as InputEventJoypadMotion).axis_value) == sign_:
			return true
	return false

func has_joy_button(act: String, idx: int) -> bool:
	for e in InputMap.action_get_events(act):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == idx:
			return true
	return false

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(20)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var pad: QuarryGamepad = game.gamepad
	check(pad != null, "the game has a gamepad handler")
	# ---- InputMap: the project's own actions read the pad
	check(has_joy_motion("move_forward", JOY_AXIS_LEFT_Y, -1.0) and has_joy_motion("move_back", JOY_AXIS_LEFT_Y, 1.0) and has_joy_motion("move_left", JOY_AXIS_LEFT_X, -1.0) and has_joy_motion("move_right", JOY_AXIS_LEFT_X, 1.0), "the left stick moves (analog) through the move actions")
	check(has_joy_button("interact", QuarryGamepad.A) and has_joy_button("sprint", QuarryGamepad.LB) and has_joy_button("rotate_machine", QuarryGamepad.X) and has_joy_button("ui_cancel", QuarryGamepad.START), "A uses, LB sprints, X rotates, START pauses / cancels")
	# ---- bindings per situation
	check(QuarryGamepad.binding(QuarryGamepad.Y, "walk").get("key", 0) == KEY_M and QuarryGamepad.binding(QuarryGamepad.DDOWN, "walk").get("key", 0) == KEY_B, "on foot: Y opens management, d-pad down is build mode")
	check(QuarryGamepad.binding(QuarryGamepad.RB, "drive").get("mouse", 0) == MOUSE_BUTTON_RIGHT and bool(QuarryGamepad.binding(QuarryGamepad.DUP, "drive").get("hold", false)) and QuarryGamepad.binding(QuarryGamepad.DUP, "drive").get("key", 0) == KEY_UP, "driving: RB dumps, the d-pad works the boom (held)")
	check(QuarryGamepad.binding(QuarryGamepad.R3, "walk").get("key", 0) == KEY_J and QuarryGamepad.binding(QuarryGamepad.R3, "drive").get("key", 0) == KEY_J, "R3 toggles the auto crew, on foot and driving")
	check(QuarryGamepad.binding(QuarryGamepad.L3, "walk").get("key", 0) == KEY_K and QuarryGamepad.binding(QuarryGamepad.L3, "drive").get("key", 0) == KEY_K, "L3 skips a delivery, on foot and driving")
	check(QuarryGamepad.binding(QuarryGamepad.R3, "menu").is_empty() and QuarryGamepad.binding(QuarryGamepad.L3, "place").is_empty(), "the stick clicks do nothing in menus or while placing")
	check(QuarryGamepad.pad_hints([["J", "auto crew"], ["K", "skip delivery"]]) == [["R3", "auto crew"], ["L3", "skip delivery"]], "the hint bar names them in pad terms")
	check(QuarryGamepad.binding(QuarryGamepad.A, "place").get("mouse", 0) == MOUSE_BUTTON_LEFT, "placing: A places")
	check(QuarryGamepad.binding(QuarryGamepad.Y, "menu").is_empty(), "in a menu nothing is generated (the menu's own focus navigation handles the pad)")
	check(pad.context() == "walk", "context on foot")
	# ---- right stick looks, RT mines
	var yaw0: float = game.player.rotation.y
	game.player.locked = false
	pad.feed_axis(JOY_AXIS_RIGHT_X, 1.0)
	pad._process(0.1)
	var turned: float = yaw0 - game.player.rotation.y
	check(turned > 0.2, "the right stick turns the view (%.2f rad in 0.1 s)" % turned)
	pad.feed_axis(JOY_AXIS_RIGHT_X, 0.1)
	var yaw1: float = game.player.rotation.y
	pad._process(0.1)
	check(absf(game.player.rotation.y - yaw1) < 0.0001, "and a stick resting inside the dead zone does nothing")
	pad.feed_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	pad._process(0.016)
	Input.flush_buffered_events()
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "holding RT holds the mine click")
	pad.feed_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	pad._process(0.016)
	Input.flush_buffered_events()
	check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "and releasing it lets go")
	# ---- generated keys: held while the button is held
	var ex_ctx := {"menu": "", "driving": null}
	pad.feed_button(QuarryGamepad.DUP, true)       # on foot: nothing bound
	check(not Input.is_physical_key_pressed(KEY_UP), "an unbound button does nothing on foot")
	# fake a driving situation
	game.fleet.give("compact_excavator", Vector3(30.0, 0.1, 50.0), 0.0)
	game._sync_vehicles()
	await frames(5)
	var ex = null
	for v in game.vehicle_nodes.values():
		if v.vtype == "compact_excavator":
			ex = v
	check(ex != null, "an excavator to drive")
	ex.speed = 0.0
	game.enter_vehicle(ex)
	await frames(3)
	check(pad.context() == "drive", "context while driving")
	pad.feed_button(QuarryGamepad.DUP, true)
	Input.flush_buffered_events()
	check(Input.is_physical_key_pressed(KEY_UP), "driving: d-pad up holds the boom key")
	pad.feed_button(QuarryGamepad.DUP, false)
	Input.flush_buffered_events()
	check(not Input.is_physical_key_pressed(KEY_UP), "and letting go releases it")
	var sw0: float = ex.swing
	pad.feed_axis(JOY_AXIS_RIGHT_X, 1.0)
	pad._process(0.1)
	check(absf(angle_difference(ex.swing, sw0)) > 0.1, "the right stick spins the cab (%.2f rad)" % absf(angle_difference(ex.swing, sw0)))
	pad.feed_axis(JOY_AXIS_RIGHT_X, 0.0)
	pad.feed_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	pad._process(0.016)
	Input.flush_buffered_events()
	check(Input.is_physical_key_pressed(KEY_SPACE), "LT is the brake while driving")
	pad.feed_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	pad._process(0.016)
	Input.flush_buffered_events()
	check(not Input.is_physical_key_pressed(KEY_SPACE), "and lets go")
	v_exit(game, ex)
	await frames(5)
	# ---- hint glyphs follow the device
	var kb := [["W A S D", "Move"], ["SHIFT", "Sprint"], ["LEFT CLICK", "Mine"], ["E", "Interact"], ["B", "Build mode"], ["M", "Management"], ["ESC", "Pause"]]
	var pb := QuarryGamepad.pad_hints(kb)
	check(pb[0][0] == "L STICK" and pb[2][0] == "RT" and pb[3][0] == "A" and pb[5][0] == "Y" and pb[6][0] == "START", "the hint bar shows pad glyphs (%s)" % str(pb))
	var ev := InputEventJoypadButton.new()
	ev.button_index = QuarryGamepad.A
	ev.pressed = true
	pad._input(ev)
	check(pad.active, "touching the pad switches the hints to the pad")
	var kev := InputEventKey.new()
	kev.keycode = KEY_W
	kev.pressed = true
	pad._input(kev)
	check(not pad.active, "and the keyboard switches them back")
	# ---- shop menus can be driven with the pad: something is focused when they open
	game.state.inventory["limestone"] = 5
	game._open_menu("sell")
	await frames(5)
	var fo: Control = game.panel.get_viewport().gui_get_focus_owner()
	check(fo != null and game.panel.is_ancestor_of(fo), "the sales menu opens with a button focused for the d-pad / A")
	game._close_menu()
	game._open_menu("storage")
	await frames(5)
	fo = game.panel.get_viewport().gui_get_focus_owner()
	check(fo != null and game.panel.is_ancestor_of(fo), "so does the storage menu")
	game._close_menu()
	# ---- touch: safe-area insets, buttons clear of the map, finger-sized menu buttons
	var ins := QuarryHUD.safe_insets(Rect2i(Vector2i(60, 30), Vector2i(2280, 1000)), Vector2i(2400, 1080), Vector2(960.0, 540.0))
	check(absf(ins.x - 24.0) < 0.01 and absf(ins.y - 15.0) < 0.01 and absf(ins.z - 24.0) < 0.01 and absf(ins.w - 25.0) < 0.01, "a phone's notch insets are converted to canvas units (%s)" % str(ins))
	check(QuarryHUD.safe_insets(Rect2i(Vector2i.ZERO, Vector2i.ZERO), Vector2i(1280, 720), Vector2(960.0, 540.0)) == Vector4.ZERO, "and a desktop gets none")
	var tc := QuarryTouchControls.new()
	tc.game = game
	tc.size = Vector2(960, 540)
	var map_rect: Rect2 = game.hud.map_plate.get_rect()
	var clear := true
	for b in QuarryTouchControls.BUTTONS:
		if b.get("top", false):
			var p := tc._pos(b)
			if map_rect.grow(4.0).intersects(Rect2(p - Vector2(float(b["r"]), float(b["r"])), Vector2(float(b["r"]), float(b["r"])) * 2.0)):
				clear = false
	check(clear, "the touch MENU / MGR / BUILD buttons sit below the corner map, not on it")
	tc.free()
	game.touch_mode = true
	game._open_menu("manage")
	await frames(3)
	var tb: Button = game.management._button("Test", func(): pass)
	check(tb.custom_minimum_size.y >= 40.0, "menu buttons are finger-sized on a touch device (%.0f px)" % tb.custom_minimum_size.y)
	tb.free()
	game.touch_mode = false
	game._close_menu()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

func v_exit(game, ex) -> void:
	ex.speed = 0.0
	game.exit_vehicle()
