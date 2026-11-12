extends SceneTree
## Day cycle: sun and moon follow the clock, the curfew sends the player to bed, workers go home and come back.
##   godot --headless --fixed-fps 60 -s tests/test_daycycle.gd

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
	root.add_child(game)
	await process_frame
	await frames(4)
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	var ls: QuarryLandscape = game.landscape
	check(ls.sun != null and ls.moon != null, "A the sky has a sun and a moon")
	ls.set_time(12.0 * 60.0)
	check(ls.sun.visible and ls.sun.position.y > 300.0 and not ls.moon.visible, "A at noon the sun is high and the moon is down")
	ls.set_time(6.0 * 60.0)
	check(ls.sun.visible and absf(ls.sun.position.y) < 60.0 and ls.sun.position.x > 300.0, "A at 06:00 the sun rises in the east")
	ls.set_time(18.0 * 60.0)
	check(ls.sun.position.x < -300.0, "A at 18:00 it sets in the west")
	ls.set_time(0.0)
	check(ls.moon.visible and ls.moon.position.y > 300.0 and not ls.sun.visible, "A at midnight the moon is high and the sun is down")
	# curfew
	game.state.clock_minutes = 21.0 * 60.0 + 59.0
	game.player.global_position = Vector3(5, 0.2, 5)
	await frames(200)
	check(game.sleeping, "B at the curfew the player is sent to bed")
	check(game.player.locked, "B and cannot act while it happens")
	await frames(400)
	var h: float = fposmod(game.state.clock_minutes, 1440.0) / 60.0
	check(not game.sleeping and absf(h - 7.0) < 0.2, "B they wake at 07:00 (%.2f)" % h)
	check(game.player.global_position.distance_to(game.HOME_POS) < 3.0, "B at home, by the bed")
	check(not game.player.locked, "B and free to play again")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
