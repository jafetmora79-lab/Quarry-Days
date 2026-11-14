extends SceneTree
## Grandpa Walt's letter: a compact sheet of paper that unfolds, is paginated instead of shrunk, ends in a signature, blocks mining and swings while it is open,
## advances with E or a click, closes with Esc, and gives the player back their controls.
##   godot --headless --fixed-fps 60 -s tests/test_letter.gd
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
func key(game, action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	game._unhandled_input(e)
func click(game) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(400, 300)
	game._unhandled_input(e)
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	await frames(5)
	var hud = game.hud
	var L: QuarryLetter = hud.letter
	# ---- the real letter: pages, signature, size
	var text: String = str(game.prog.cleanup_cfg().get("gift_text", ""))
	var r := QuarryLetter.paginate(text)
	check(r["signed"] and r["pages"].size() >= 1 and not "Grandpa Walt" in str(r["pages"][r["pages"].size() - 1]), "the closing '- Grandpa Walt' becomes a drawn signature, not typed text (%d pages)" % r["pages"].size())
	var long_text := text + "\\n\\n" + text + "\\n\\n- Grandpa Walt"
	long_text = long_text.replace("\\\\n", "\\n")
	var rl := QuarryLetter.paginate(text + "\\n\\n" + text)
	check(rl["pages"].size() >= 2, "a long letter runs over several pages instead of shrinking the type (%d pages)" % rl["pages"].size())
	check(QuarryLetter.FONT >= 10, "the type stays at %d base px (%d px at 1280x720, %d px at 1920x1080)" % [QuarryLetter.FONT, int(QuarryLetter.FONT * 1280.0 / 960.0), int(QuarryLetter.FONT * 2)])
	# ---- opening: from the story trigger, with a short unfold
	game.player.locked = true
	var opened := [false]
	var closed := [false]
	var money0: int = game.state.money
	game._on_site_cleared()                            # the story trigger: the site is clean, Walt's letter arrives with the money
	closed[0] = false
	await process_frame
	check(L.visible and hud.card_open(), "the letter opens and counts as an open card")
	check(L.paper.size.x == QuarryLetter.W and L.paper.size.y <= 500.0, "the sheet is compact: %d x %d of the 960 x 540 canvas" % [int(L.paper.size.x), int(L.paper.size.y)])
	check(L.paper.scale.y < 0.5, "it starts folded and unfolds")
	var fcount := 0
	while L._opening and fcount < 120:
		await physics_frame
		fcount += 1
	var took := float(fcount) / 60.0
	check(took > 0.3 and took < 0.8 and absf(L.paper.scale.y - 1.0) < 0.01, "the unfolding takes %.2f s (0.4 to 0.7 s) and ends at full size" % took)
	# ---- no mining, no swings while it is open
	check(not game.gameplay_input_allowed(), "mining and tool swings are blocked while the letter is open")
	var swung := false
	var tv: QuarryToolView = game.player.tool_view
	click(game)
	await frames(2)
	check(not tv.is_busy() and not swung, "a click that turns the page does not swing the tool")
	# ---- pages: E and click advance; the last one closes
	var pages: int = L.pages.size()
	var page0: int = L.page
	if pages > 1:
		check(L.page == 1 or L.page == page0 + 1, "a click turned the page")
		key(game, "interact")
		await frames(15)
	await frames(30)
	var guard := 0
	while L.visible and guard < 5:
		key(game, "interact")
		await frames(40)
		guard += 1
	check(not L.visible, "E on the last page closes the letter")
	check(not game.player.locked and not hud.card_open(), "the player is given their controls back")
	check(game.state.money == money0 + int(game.prog.cleanup_cfg().get("gift", 0)), "the gift still arrives with the letter")
	# ---- Esc puts it away at once, and a click during the unfold is not a page turn
	hud.show_letter("A LETTER", text)
	await frames(5)
	click(game)
	check(L.page == 0, "a click while the sheet is still unfolding does nothing")
	key(game, "ui_cancel")
	await frames(30)
	check(not L.visible, "Esc folds the letter away")
	check(game.gameplay_input_allowed() or game.player.locked, "after closing, input rules are back to normal")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
