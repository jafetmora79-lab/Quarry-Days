extends SceneTree
## The first shots of a new game are the drive in Walt's pickup (replacing the old two-shot flyover): they play in the real world on the player's own camera, can be skipped with Esc at any
## moment, hand the view back to the player, never replay once the intro is seen. (The full cinematic is covered by test_opening_cinematic.gd.)
##   godot --headless --fixed-fps 60 -s tests/test_intro_shots.gd
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
func make(seen: bool):
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = true
	root.add_child(game)
	return game
func run() -> void:
	var game = make(false)
	await process_frame
	await frames(8)
	check(game.opening_scene != null and game.opening_scene.phase == "drive" and game.player.camera.current, "the drive opens on the player's own camera")
	check(game.player.locked and game.walter_dialog != null and game.walter_intro_running, "the player is locked; the conversation runs on its own")
	var start: Vector3 = game.player.camera.global_position
	await frames(120)
	check(game.player.camera.global_position.distance_to(start) > 5.0, "the view is moving (the pickup drives)")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	game.walter_dialog._unhandled_key_input(ev)
	await frames(10)
	check(game.opening_scene == null or not game.opening_scene.active, "Esc skips the whole opening")
	game.hud.close_card()
	await frames(10)
	check(bool(game.prog.story["intro_seen"]) and not game.player.locked and game.player.camera.current, "after the skip the player has control with their own view")
	game.queue_free()
	await process_frame
	# an intro already seen never plays again
	var g3 = make(true)
	g3.prog.story["intro_seen"] = true
	await process_frame
	await frames(20)
	check(g3.opening_scene == null and not g3.est_running, "no replay once the intro has been seen")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
