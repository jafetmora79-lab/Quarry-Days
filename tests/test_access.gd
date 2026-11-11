extends SceneTree
## Focused regression for worker facing and walkable building thresholds.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await process_frame
	game.hud.close_card() # Phase 5: a new game opens with grandpa's letter
	game.scripted_input = true
	var failures := 0
	for x in [-14.0, 14.0]:
		game.player.global_position = Vector3(x, 0.05, 8.4)
		game.player.rotation.y = PI
		game.player.velocity = Vector3.ZERO
		Input.action_press("move_forward")
		for i in range(100):
			await physics_frame
		Input.action_release("move_forward")
		var reached: bool = game.player.global_position.z > 10.3 and game.player.global_position.y > 0.10
		print("%s entrance: %s at %s" % ["Office" if x < 0 else "Shed", "PASS" if reached else "FAIL", game.player.global_position])
		if not reached:
			failures += 1
	# An instantiated worker's model must face along its body's forward (-Z).
	var w := QuarryWorker.new()
	w.setup(game, game.business, {"id": 99, "profession": "miner"})
	game.add_child(w)
	var faces_forward: bool = w.model.transform.basis * Vector3.FORWARD == Vector3.FORWARD
	print("Worker model direction: %s" % ("PASS" if faces_forward else "FAIL"))
	if not faces_forward:
		failures += 1
	w.queue_free()
	game.queue_free()
	await process_frame
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
