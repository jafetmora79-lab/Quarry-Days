extends SceneTree
## Touch controls (Android / --touch). Run:  godot --headless --fixed-fps 60 -s tests/test_touch.gd -- --touch
var checks := 0
var failures := []
func check(c: bool, l: String) -> void:
	checks += 1
	if not c:
		failures.append(l)
		printerr("FAIL: " + l)
	else:
		print("PASS: " + l)
func _initialize() -> void:
	call_deferred("run")
func tap(t, p: Vector2, idx: int, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = p
	e.pressed = down
	t._input(e)
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	root.size = Vector2i(1280, 720)
	for i in 5: await process_frame
	game.hud.close_card()
	check(game.touch_mode, "touch mode is on with --touch")
	var t: QuarryTouchControls = null
	for c in game.ui.get_children():
		if c is QuarryTouchControls:
			t = c
	check(t != null, "on-screen controls exist")
	await process_frame
	check(t.visible, "controls show during play")
	# stick drives the movement actions
	tap(t, t.stick_center, 1, true)
	var d := InputEventScreenDrag.new()
	d.index = 1
	d.position = t.stick_center + Vector2(0, -50)
	d.relative = Vector2(0, -50)
	t._input(d)
	check(Input.get_action_strength("move_forward") > 0.5 and Input.get_action_strength("move_back") == 0.0, "pushing the stick forward walks forward")
	tap(t, t.stick_center, 1, false)
	check(Input.get_action_strength("move_forward") == 0.0, "releasing the stick stops")
	# look drag
	game.player.locked = false          # the opening conversation locks the player; this test is about the drag
	var yaw0: float = game.player.rotation.y
	tap(t, Vector2(600, 200), 2, true)
	var d2 := InputEventScreenDrag.new()
	d2.index = 2
	d2.position = Vector2(640, 200)
	d2.relative = Vector2(40, 0)
	t._input(d2)
	check(absf(game.player.rotation.y - yaw0) > 0.1, "dragging on the right looks around")
	tap(t, Vector2(600, 200), 2, false)
	# MINE hold
	var mine_pos: Vector2 = t._pos(QuarryTouchControls.BUTTONS[0])
	tap(t, mine_pos, 3, true)
	check(game.touch_mine, "MINE button holds the mining swing")
	tap(t, mine_pos, 3, false)
	check(not game.touch_mine, "releasing MINE stops")
	# emulated screen taps do nothing in the world
	var before: bool = game.touch_mine
	var me := InputEventMouseButton.new()
	me.button_index = MOUSE_BUTTON_LEFT
	me.pressed = true
	game._unhandled_input(me)
	check(game.touch_mine == before, "emulated mouse clicks from touch are ignored in the world")
	# menus hide the controls and keep working with taps
	game._open_menu("sell", -1)
	await process_frame
	check(not t.visible and game.panel.visible, "controls hide while a menu is open")
	game._close_menu()
	await process_frame
	check(t.visible, "controls return when the menu closes")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
