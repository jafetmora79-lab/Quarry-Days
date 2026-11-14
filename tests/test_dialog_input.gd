extends SceneTree
## Dialogue input: clicking NEXT or SKIP (or any click while a dialogue / cinematic runs) never swings the tool or mines; a click held through the end of the dialogue
## is ignored until released; mining works normally afterwards.   godot --headless --fixed-fps 60 -s tests/test_dialog_input.gd
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
func mouse(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = Vector2(400, 300)
	Input.parse_input_event(e)
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(30)
	game.player.locked = false
	var tv: QuarryToolView = game.player.tool_view
	# ---- A: normal gameplay: a click swings
	mouse(true)
	await frames(4)
	check(tv.is_busy() or game.mining_cooldown > 0.0, "in normal play a click swings the tool")
	mouse(false)
	await frames(60)
	check(not tv.is_busy(), "and the tool settles")
	# ---- B: a click while a dialogue is open
	game._open_walter_dialog([{"speaker": "GRANDPA WALTER", "text": "One.", "dur": 9.0}, {"speaker": "GRANDPA WALTER", "text": "Two.", "dur": 9.0}], func(_s): pass)
	await frames(10)
	var cd0: float = game.mining_cooldown
	mouse(true)
	await frames(10)
	check(not tv.is_busy() and game.mining_cooldown <= cd0 + 0.001, "a click while Grandpa talks does not swing the tool")
	game.walter_dialog.advance()                       # NEXT
	await frames(10)
	check(not tv.is_busy(), "pressing NEXT (mouse still held) does not swing it")
	game.walter_dialog.skip()                          # SKIP, mouse still held
	await frames(10)
	check(game.walter_dialog == null and not tv.is_busy() and not tv.operating, "closing the dialogue with the button still held does not swing it")
	game.player.locked = false
	await frames(30)
	check(not tv.is_busy(), "and it keeps ignoring that held press until it is released")
	mouse(false)
	await frames(10)
	mouse(true)
	await frames(4)
	check(tv.is_busy() or game.mining_cooldown > 0.0, "after releasing and clicking again, mining works")
	mouse(false)
	await frames(60)
	# ---- C: a cinematic (the opening shots)
	game.est_running = true
	mouse(true)
	await frames(8)
	if false: print("DBG C busy=", tv.is_busy(), " phase=", tv.phase, " allowed=", game.gameplay_input_allowed(), " latch=", game._mine_latch, " raw=", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), " cd=", game.mining_cooldown, " menu=", game.menu, " locked=", game.player.locked)
	check(not tv.is_busy(), "a click during the opening shots does not swing the tool")
	game.est_running = false
	mouse(false)
	await frames(10)
	# ---- D: a story card
	game.hud.show_card("TEST", "A story card.", func(): pass)
	await frames(5)
	mouse(true)
	await frames(8)
	check(not tv.is_busy(), "a click on a story card does not swing the tool")
	game.hud.close_card()
	mouse(false)
	await frames(10)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
