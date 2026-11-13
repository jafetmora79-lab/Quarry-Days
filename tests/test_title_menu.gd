extends SceneTree
## The main menu: opens paused over a film camera, Continue / New Game (asks twice over a save) / Quit, Esc does nothing there, and the
## pause menu can return to it.   godot --headless --fixed-fps 60 -s tests/test_title_menu.gd
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
func boot(with_title: bool, autosave: bool):
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = with_title
	game.autosave_enabled = autosave
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	return game
func run() -> void:
	var g = await boot(true, false)
	check(g.menu == "title" and g.title != null, "the game opens on the main menu")
	check(not g.hud.visible and g.player.locked, "the HUD is hidden and the player cannot move behind it")
	var cam: Camera3D = g.get_viewport().get_camera_3d()
	check(cam != null and cam.name == "TitleCamera", "a film camera shows the quarry behind the menu")
	var p0: Vector3 = cam.global_position
	await frames(60)
	check(cam.global_position.distance_to(p0) > 0.01, "and it moves slowly")
	var clock0: float = g.state.clock_minutes
	await frames(60)
	check(is_equal_approx(g.state.clock_minutes, clock0), "the world is paused behind the menu")
	check(g.title.continue_btn.disabled, "with no save, CONTINUE is greyed out")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	g._unhandled_input(esc)
	check(g.menu == "title", "Esc does nothing on the main menu (no pause menu over it)")
	g._title_chosen("new")
	await frames(3)
	check(g.menu == "" and g.title == null and g.hud.visible and (not g.player.locked or g.walter_intro_running), "NEW GAME with no save starts the game, Walt's opening begins (menu %s title %s hud %s locked %s)" % [g.menu, str(g.title), str(g.hud.visible), str(g.player.locked)])
	check(g.get_viewport().get_camera_3d() == g.player.camera, "the player's own camera is back")
	g._open_menu("pause")
	await frames(2)
	check(g.panel.buttons.has("main_menu"), "the pause menu has a MAIN MENU button")
	g.queue_free()
	await process_frame
	# with a save: CONTINUE works, NEW GAME asks twice
	var g2 = await boot(false, true)
	g2._save(true)
	g2.queue_free()
	await process_frame
	var g3 = await boot(true, true)
	check(g3.title != null and not g3.title.continue_btn.disabled, "with a save, CONTINUE is available")
	g3.title._on_new()
	check(g3.title.confirm_new and g3.menu == "title" and g3.title.new_btn.text.begins_with("ERASE"), "NEW GAME over a save asks first and does nothing yet")
	g3._title_chosen("continue")
	await frames(3)
	check(g3.menu == "" and g3.title == null, "CONTINUE enters the game")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
