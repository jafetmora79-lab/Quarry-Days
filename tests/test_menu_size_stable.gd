extends SceneTree
## Station menus keep their size however often they are opened (the pause menu used to keep a stale, too-wide size on later opens and ran off the window).
##   godot --headless --fixed-fps 60 -s tests/test_menu_size_stable.gd
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
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(10)
	var sizes := []
	for round in range(4):
		game._open_menu("pause")
		await frames(3)
		sizes.append(game.panel.size)
		var centred: bool = absf((game.panel.position.x + game.panel.size.x * 0.5) - game.panel.get_parent_area_size().x * 0.5) < 1.0
		check(centred, "open %d: the pause menu is centred" % (round + 1))
		game._close_menu()
		await frames(2)
		if round == 1:
			game._open_menu("sell")
			await frames(3)
			game._close_menu()
			await frames(2)
	var same := true
	for sz in sizes:
		if (sz as Vector2).distance_to(sizes[0]) > 1.0:
			same = false
	check(same and (sizes[0] as Vector2).x < 420.0, "the pause menu is the same compact size every time (%s)" % str(sizes))
	game._open_menu("pause")
	await frames(3)
	check(game.panel.get_rect().end.x <= game.panel.get_parent_area_size().x and game.panel.position.x >= 0.0, "and it sits inside the window")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
