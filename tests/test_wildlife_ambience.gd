extends SceneTree
## Wildlife and ambience: two deer and four rabbits exist (a small number, never more out at once), appear at forest edges only (never on the yard, a road, the tunnel approach,
## the quarry or the east extension), animate their hinges (walk, graze, look, breathe, hop), flee from the player and from machines, keep clear of vehicles and leave. The
## ambience synthesises its sounds, birds sing only in daylight and never near the player, and the beds follow the clock.
##   godot --headless --fixed-fps 60 -s tests/test_wildlife_ambience.gd

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

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 6:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var w: QuarryWildlife = game.wildlife
	check(w != null and w.enabled and w.animals.size() == 6, "six animals exist")
	var deer := 0
	var rabbits := 0
	for b in w.animals:
		if b.kind == "deer":
			deer += 1
		else:
			rabbits += 1
	check(deer == 2 and rabbits == 4, "two deer and four rabbits (a small number)")
	w.enabled = false                         # driven by hand from here (the live loop would also step them)
	# park the player far from everything so nothing flees during the walk-about
	game.player.global_position = Vector3(0, 1.0, 14.0)
	var bad_spot := 0
	var max_out := 0
	var seen_states := {}
	var moved := false
	var legs_moved := false
	var head_moved := false
	var hopped := false
	for step in 9000:
		w.step(1.0 / 20.0)
		max_out = maxi(max_out, w.active_count())
		for b in w.animals:
			seen_states[b.state] = true
			if b.root.visible:
				var p := Vector2(b.root.global_position.x, b.root.global_position.z)
				if game.landscape.forest_blocked(p):
					bad_spot += 1
				if absf(p.x) > 210.0 or p.y < -135.0 or p.y > 80.0:
					bad_spot += 1
				if b.kind == "deer":
					if absf((b.parts["LegFL"] as Node3D).rotation.x) > 0.2:
						legs_moved = true
					if (b.parts["Head"] as Node3D).rotation.x < -0.5:
						head_moved = true
				elif b.root.global_position.y > 0.05:
					hopped = true
	check(max_out <= 6 and max_out >= 1, "animals appear and leave: never more than the six exist, %d were out at once at most" % max_out)
	check(bad_spot == 0, "they never stood on the yard, a road, the tunnel approach, the quarry or beyond the strips (%d bad samples)" % bad_spot)
	check(seen_states.has("walk") and seen_states.has("graze") and seen_states.has("idle") and seen_states.has("leave"), "deer idle, graze, walk and leave (%s)" % str(seen_states.keys()))
	check(legs_moved and head_moved, "the deer's legs swing when walking and its head goes down to graze")
	check(hopped, "a rabbit hops (it leaves the ground)")
	# ---- fleeing: put the player near an out deer and a rabbit
	var d_b = null
	var r_b = null
	for i in 4000:
		w.step(1.0 / 20.0)
		for b in w.animals:
			if b.root.visible and b.state in ["idle", "graze", "look", "walk"]:
				if b.kind == "deer" and d_b == null:
					d_b = b
				if b.kind == "rabbit" and r_b == null:
					r_b = b
		if d_b != null and r_b != null:
			break
	check(d_b != null and r_b != null, "a deer and a rabbit are out to test")
	if d_b != null:
		game.player.global_position = d_b.root.global_position + Vector3(8.0, 1.0, 0)
		w.step(1.0 / 20.0)
		check(d_b.state == "flee", "the deer flees when the player comes within 17 m (%s)" % d_b.state)
		var d0: float = d_b.root.global_position.distance_to(game.player.global_position)
		for i in 60:
			w.step(1.0 / 20.0)
		check(d_b.root.global_position.distance_to(game.player.global_position) > d0 + 8.0 or not d_b.root.visible, "and runs away from the player")
	r_b = null
	for i in 4000:
		w.step(1.0 / 20.0)
		for b in w.animals:
			if b.kind == "rabbit" and b.root.visible and b.state == "idle":
				r_b = b
		if r_b != null:
			break
	if r_b != null:
		game.player.global_position = r_b.root.global_position + Vector3(3.0, 1.0, 0)
		w.step(1.0 / 20.0)
		check(r_b.state == "flee", "the rabbit flees when the player is within 7 m (%s)" % r_b.state)
	# ---- machines: a vehicle near a grazing animal scares it too, and an animal is never placed near a vehicle
	game.player.global_position = Vector3(0, 1.0, 14.0)
	var rec: Dictionary = game.fleet.give("truck", Vector3(0, 0.3, 14.0), 0.0)
	game._sync_vehicles()
	await physics_frame
	var near_veh := false
	for b in w.animals:
		if b.root.visible and w._nearest_threat(b, w._threats())[0] < 3.0:
			near_veh = true
	check(not near_veh, "no animal stands within 3 m of a person or a machine")
	# ---- ambience
	var a: QuarryAmbience = game.ambience
	check(a != null and a.wind.playing and a.rustle.playing and a.crickets.playing, "the ambience beds play (wind, rustle, crickets)")
	check(a.wind.stream.get_length() > 5.0 and a.crickets.stream.get_length() > 2.0 and a.chirps.size() == 5 and a.chirps[0].get_length() > 0.15, "the sounds are synthesised (wind %.1f s, five bird calls)" % a.wind.stream.get_length())
	check(QuarryAmbience.birds_allowed(11.0) and QuarryAmbience.birds_allowed(17.0) and not QuarryAmbience.birds_allowed(2.0) and not QuarryAmbience.birds_allowed(23.0), "birds sing by day only")
	a.update(5.0, 2.0)
	for i in 200:
		a.update(0.1, 2.0)
	check(a.crickets.volume_db > a.rustle.volume_db and a.wind.volume_db < -28.0, "at night the crickets lead and the wind is softer (crickets %.0f dB, rustle %.0f dB)" % [a.crickets.volume_db, a.rustle.volume_db])
	for i in 300:
		a.update(0.1, 12.0)
	check(a.rustle.volume_db > a.crickets.volume_db and a.crickets.volume_db < -55.0, "by day the rustle returns and the crickets fade (rustle %.0f dB, crickets %.0f dB)" % [a.rustle.volume_db, a.crickets.volume_db])
	var sang := 0
	game.player.global_position = Vector3(0, 1.0, 14.0)
	for i in 4000:
		a.update(0.1, 11.0)
		if a.bird.playing or a.bird_count > 0:
			sang += 1
			var d: float = a.bird.global_position.distance_to(game.player.global_position)
			if d < 44.0:
				sang = -100000
	check(a.bird_count >= 3 and sang > 0, "birds sing now and then by day, always far off (%d calls)" % a.bird_count)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
