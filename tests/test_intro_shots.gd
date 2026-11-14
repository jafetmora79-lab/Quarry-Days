extends SceneTree
## Opening shots 1 and 2 (mountains, service yard) before the meeting with Grandpa: they play in the real world on a temporary camera, can be skipped,
## hand the view back to the player, never replay once the intro is seen, and the whole opening stays between 60 and 90 seconds.
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
	check(game.est_running and game.est_cam != null and game.est_cam.current, "the establishing shots run on their own camera")
	check(game.player.locked and game.walter_dialog == null, "the player is locked and Grandpa has not spoken yet")
	var start: Vector3 = game.est_cam.global_position
	await frames(120)
	check(game.est_cam.global_position.distance_to(start) > 0.5, "the camera is moving (a slow shot, not a still)")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	game._unhandled_input(ev)
	await frames(3)
	check(not game.est_running and game.est_cam == null and game.player.camera.current, "Esc skips the shots and the player's view comes back")
	await frames(10)
	check(game.walter_dialog != null and game.walter_intro_running, "the meeting with Grandpa follows")
	game.walter_dialog.skip()
	await frames(30)
	game.hud.close_card()
	await frames(5)
	check(bool(game.prog.story["intro_seen"]) and not game.player.locked, "after the intro the player has control")
	game.queue_free()
	await process_frame
	# unskipped: the shots end by themselves and flow into the dialogue
	var g2 = make(false)
	await process_frame
	await frames(8)
	var t := 0
	while g2.est_running and t < 60 * 30:
		await physics_frame
		t += 1
	var secs := float(t) / 60.0
	check(not g2.est_running and secs > 17.0 and secs < 26.0, "left alone the two shots take %.1f s and end by themselves" % secs)
	await frames(10)
	var dlg_total := 0.0
	for l in g2.prog.walter_cfg().get("cinematic", []):
		dlg_total += float(l["dur"])
	check(g2.walter_dialog != null and secs + dlg_total + 8.0 >= 60.0 and secs + dlg_total + 8.0 <= 92.0, "the whole opening is about %.0f s with the first-job shot (target 60-90)" % (secs + dlg_total + 8.0))
	# played to the end (not skipped): shot 4 shows the first job, then control returns smoothly
	var guard := 0
	while g2.walter_dialog != null and guard < 30:
		g2.walter_dialog.advance()
		await frames(2)
		guard += 1
	await frames(10)
	check(g2.est_running and g2.est_cam != null and g2.est_cam.current, "after the last line the camera shows the first job (shot 4)")
	var t2 := 0
	while g2.est_running and t2 < 60 * 14:
		await physics_frame
		t2 += 1
	check(not g2.est_running and g2.est_cam == null and g2.player.camera.current and float(t2) / 60.0 < 11.0, "shot 4 ends by itself in %.1f s and the player's view is back, no duplicate camera" % (float(t2) / 60.0))
	await frames(10)
	g2.hud.close_card()
	await frames(10)
	check(bool(g2.prog.story["intro_seen"]) and not g2.player.locked, "and the player has control with the intro marked as seen")
	g2.queue_free()
	await process_frame
	# an intro already seen never plays again
	var g3 = make(true)
	g3.prog.story["intro_seen"] = true
	await process_frame
	await frames(20)
	check(not g3.est_running and g3.est_cam == null, "no replay once the intro has been seen")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
