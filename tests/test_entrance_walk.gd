extends SceneTree
## Walking through the quarry entrance and along its boundary with the real player physics: no snags, stalls or steps.
##   godot --headless --fixed-fps 60 -s tests/test_entrance_walk.gd
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
## Walks from `from` along `yaw` for `secs` and returns the anomalies: {"snags": [...], "max_dy": float, "min_speed_after_full": float}
func walk(game, from: Vector3, yaw: float, secs: float, label: String) -> Dictionary:
	var pl = game.player
	pl.global_position = from
	pl.velocity = Vector3.ZERO
	pl.rotation.y = yaw
	await frames(25)                                      # settle on the ground
	Input.action_press("move_forward", 1.0)
	var prev: Vector3 = pl.global_position
	var snags := []
	var max_dy := 0.0
	var worst_dip := 1.0
	var jitter := 0
	var prev_dir := Vector2.ZERO
	var frames_n := int(secs * 60.0)
	var vmax := 0.0
	for i in range(frames_n):
		await physics_frame
		var cur: Vector3 = pl.global_position
		var step := Vector2(cur.x - prev.x, cur.z - prev.z).length() * 60.0
		var dy := absf(cur.y - prev.y)
		max_dy = maxf(max_dy, dy)
		var mv := Vector2(cur.x - prev.x, cur.z - prev.z)
		if mv.length() > 0.01 and prev_dir.length() > 0.01 and absf(mv.angle_to(prev_dir)) > 0.35:
			jitter += 1                                      # the walking direction flipped by 20 degrees or more in one frame
		if mv.length() > 0.01:
			prev_dir = mv
		if i > 30:
			vmax = maxf(vmax, step)
			if vmax > 1.0 and step < vmax * 0.55:
				worst_dip = minf(worst_dip, step / vmax)
				snags.append("f%d at (%.1f, %.1f, %.1f) speed %.2f of %.2f" % [i, cur.x, cur.y, cur.z, step, vmax])
		prev = cur
	Input.action_release("move_forward")
	print("%s: top speed %.2f m/s, worst dip %.0f%%, largest vertical step %.3f m, %d snag frames, %d direction flips %s" % [label, vmax, worst_dip * 100.0, max_dy * 1.0, snags.size(), jitter, str(snags.slice(0, 2))])
	return {"snags": snags, "max_dy": max_dy, "jitter": jitter}
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
	game.safety.enabled = false
	await frames(30)
	game.player.locked = false
	for xs in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		var r: Dictionary = await walk(game, Vector3(xs, 0.2, 14.0), 0.0, 5.0, "gate lane x=%.0f (south to north)" % xs)
		check(r["snags"].size() == 0 and r["max_dy"] < 0.12, "walking through the entrance at x=%.0f is smooth" % xs)
	for zs in [-6.0, -10.0, -30.0]:
		for dirn in [[-1.0, PI * 0.5], [1.0, -PI * 0.5]]:
			var r2: Dictionary = await walk(game, Vector3(-dirn[0] * 12.0, 0.2, zs), float(dirn[1]), 4.0, "along z=%.0f toward x%s" % [zs, "-" if dirn[0] < 0 else "+"])
			check(r2["snags"].size() == 0 and r2["max_dy"] < 0.12, "walking along z=%.0f has no snags" % zs)
	# approaching the gate posts and the fence at an angle: the player should slide along them evenly, never jitter or stall
	for spec in [[-9.0, 6.0, -0.9], [9.0, 6.0, 0.9], [-7.0, 8.0, -0.55], [7.0, 8.0, 0.55], [-3.0, 8.0, -0.25], [3.0, 8.0, 0.25]]:
		var r3: Dictionary = await walk(game, Vector3(spec[0], 0.2, spec[1]), float(spec[2]), 5.0, "angled approach from (%.0f, %.0f) yaw %.2f" % [spec[0], spec[1], spec[2]])
		check(r3["jitter"] <= 2, "sliding along the fence / gate post from (%.0f, %.0f) is even (%d direction flips)" % [spec[0], spec[1], r3["jitter"]])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
