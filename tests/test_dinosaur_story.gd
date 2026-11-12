extends SceneTree
## Phase 8.6: the Ankylosaurus companion (anatomy, stages, gait, idle, rest, tail wind-up and strike with real contact), the
## fossil found by real mining, the reveal, Walter's visit camera, and the egg hatching.
##   godot --headless --fixed-fps 60 -s tests/test_dinosaur_story.gd

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
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._remove_walter()
	var prog: QuarryProgression = game.prog
	prog.stage = prog.stage_index("deep")
	prog.cleanup["done"] = true
	prog.quarry_level = 4
	prog.story["companion"] = {"state": "alive", "born_day": -40, "name": "Rex"}
	prog.current_day = 10
	game._spawn_companion()                       # the game's own one runs by itself; this test drives a second, separate dinosaur
	await frames(2)
	var c := QuarryCompanion.new()
	game.world.add_child(c)
	c.setup(game, "adult")
	c.global_position = Vector3(0, 0, 8)
	# ---- 1: anatomy
	var meshes := c.model.find_children("*", "MeshInstance3D", true, false)
	check(c.hips.size() == 4 and c.feet.size() == 4 and c.eyes.size() == 2, "1 four jointed legs with feet, and two eyes")
	check(c.plates.get_child_count() >= 15 and meshes.size() >= 70, "1b rows of armour plates down the back, flank spikes, horns and toes (%d plates, %d parts)" % [c.plates.get_child_count(), meshes.size()])
	check(c.club != null and c.club_tip != null and c.tail_mid != null and c.tail_tip != null and c.head != null and c.neck != null, "1c a three-jointed tail ending in a club, a neck and a head")
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi in meshes:
		var m: MeshInstance3D = mi
		var bb: AABB = c.model.global_transform.affine_inverse() * (m.global_transform * m.mesh.get_aabb())
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
	check((hi.x - lo.x) > 1.2 and (hi.z - lo.z) > 3.0 and (hi.y - lo.y) < 1.8 and lo.y > -0.2, "1d low, wide and long: a four-legged armoured body with a long tail (%s)" % str(hi - lo))
	# ---- 2: growth changes proportions
	c.set_stage("hatchling")
	await frames(40)
	var h_head: float = c.head.scale.x
	var h_club: float = c.club.scale.x
	var h_scale: float = c.scale.x
	c.set_stage("adult")
	await frames(40)
	check(h_head > c.head.scale.x and h_club < c.club.scale.x and h_scale < 0.5 and absf(c.scale.x - 1.25) < 0.02, "2 the young have big heads and small clubs; the adult is large with a full club")
	# ---- 3: gait
	c.global_position = Vector3(0, 0, 8)
	c.global_position.y = c.ground_y(c.global_position)
	var fl_signs := []
	var opposite_seen := false
	var lifted := false
	var lift_min := 99.0
	var lift_max := -99.0
	for i in range(160):
		c.phase += 0.12
		c._animate(1.0 / 60.0, true, false)
		var fl: float = c.hips[0].rotation.x
		var fr: float = c.hips[1].rotation.x
		var rl: float = c.hips[2].rotation.x
		var rr: float = c.hips[3].rotation.x
		if i > 60:
			if absf(fl) > 0.2:
				opposite_seen = opposite_seen or (signf(fl) != signf(fr) and signf(fl) == signf(rr) and signf(fr) == signf(rl))
			lift_min = minf(lift_min, c.hips[0].position.y)
			lift_max = maxf(lift_max, c.hips[0].position.y)
	check(opposite_seen, "3 it walks on diagonal pairs: front-left with rear-right, front-right with rear-left")
	check(lift_max - lift_min > 0.01, "3b feet lift off the ground as they swing (%.3f)" % (lift_max - lift_min))
	# ---- 4: idle and rest
	for i in range(120):
		c._animate(1.0 / 60.0, false, false)
	var still := true
	for h in c.hips:
		still = still and absf(h.rotation.x) < 0.05
	var s0: float = c.body.scale.y
	var seen_breath := false
	for i in range(120):
		c._t += 1.0 / 60.0
		c._animate(1.0 / 60.0, false, false)
		seen_breath = seen_breath or absf(c.body.scale.y - s0) > 0.004
	check(still and seen_breath and absf(c.head.rotation.y) <= 0.25, "4 standing still: legs rest, it breathes, the head looks about")
	var y_awake: float = c.body.position.y
	c.resting = true
	for i in range(150):
		c._animate(1.0 / 60.0, false, false)
	check(c.body.position.y < y_awake - 0.15 and c.eyes[0].scale.y < 0.4 and absf(c.hips[0].rotation.x) > 0.3, "4b asleep: it lies down, folds its legs and closes its eyes")
	c.resting = false
	for i in range(150):
		c._animate(1.0 / 60.0, false, false)
	# ---- 5: tail strike with real contact
	prog.init_formation("hillside_face_01")
	var kind := "hillside_face_01"
	var col: int = prog.nearest_column(kind, prog.formation_origin_world(kind), true, 100.0)
	var node: QuarryFormation = game.formation_nodes[kind]
	var top: Vector3 = node.column_top(col)
	c.global_position = top + Vector3(4.0, 0, 0)
	c.global_position.y = c.ground_y(c.global_position)
	var units0: int = prog.column_units(kind, col)
	check(c.command_smash(kind, col) == "" and c.busy(), "5 an adult takes the smash command")
	var yaw_min := 0.0
	var yaw_max := -9.0
	var contacts := []
	var units_at_windup_end := -1
	var hits_before := 0
	var order := []
	var last := ""
	for i in range(420):
		c.step(1.0 / 60.0, game.player.global_position)
		if c.strike != last and c.strike != "":
			order.append(c.strike)
		last = c.strike
		yaw_min = minf(yaw_min, c.tail_yaw)
		yaw_max = maxf(yaw_max, c.tail_yaw)
		if c.strike == "windup" and c.hits == 0:
			units_at_windup_end = prog.column_units(kind, col)
		if c.hits > hits_before:
			hits_before = c.hits
			var face: Dictionary = c._target_face()
			if not face.is_empty():
				var centre: Vector3 = face["centre"]
				var yawv: float = c._stand["yaw"]
				var r := Vector3(cos(yawv), 0, -sin(yawv))          # the direction it is turned toward: its right flank faces the rock
				var face_pt: Vector3 = centre - r * float(face["half"])
				contacts.append(c.last_contact.distance_to(face_pt))
		await physics_frame
	check(order.size() >= 4 and order[0] == "windup" and order[1] == "hold" and order[2] == "strike" and order[3] == "recover", "5b every blow runs wind-up, hold, strike, recover (%s)" % str(order.slice(0, 8)))
	check(yaw_min < -0.8 and yaw_max > 1.1, "5c the tail swings back first (%.2f) and then right through the target (%.2f)" % [yaw_min, yaw_max])
	check(contacts.size() >= 3 and contacts.max() < 0.35, "5d the club meets the rock face at every contact (worst miss %.2f m over %d blows)" % [contacts.max() if not contacts.is_empty() else -1.0, contacts.size()])
	check(units_at_windup_end == units0, "5e nothing is damaged during the wind-up: damage lands only at contact")
	check(prog.column_units(kind, col) < units0 and c.smash_left <= 0 or c.hits >= 3, "5f the blows take rock out (%d -> %d units)" % [units0, prog.column_units(kind, col)])
	# after the last blow it settles and goes back to the player
	for i in range(120):
		c.step(1.0 / 60.0, game.player.global_position)
		await physics_frame
	check(c.strike == "" and not c.busy(), "5g after the last swing it settles and stops working")
	# ---- 6: rules still apply
	prog.story["companion"]["born_day"] = 9           # one day old: a hatchling
	check(prog.companion_stage(prog.current_day) == "hatchling" and c.command_smash(kind, col) != "", "6 a hatchling is too small to smash")
	prog.story["companion"]["born_day"] = -40
	var gold := "bench_l4_gold"
	prog.init_formation(gold)
	var g0: int = prog.units_left(gold)
	prog.quarry_level = 4
	game.companion_strike(gold, 0, 5000.0, c)
	check(prog.units_left(gold) == g0, "6b it cannot break gold-bearing rock")
	# ---- 7: debris cleared with the tail
	var weeds: Array = game.world.find_children("Debris_w*", "StaticBody3D", true, false)
	if not weeds.is_empty():
		var w: Node3D = weeds[0]
		var wid := str(w.get_meta("debris_id", ""))
		c.global_position = w.global_position + Vector3(3, 0, 0)
		c.global_position.y = c.ground_y(c.global_position)
		var hits0: int = c.hits
		c.command_debris(w)
		for i in range(240):
			c.step(1.0 / 60.0, game.player.global_position)
			await physics_frame
		check(prog.cleanup["cleared"].get(wid, false) and c.hits > hits0, "7 weeds are cleared by a tail strike")
	# ---- 8: the fossil is found by really mining it out
	prog.story["fossil"] = ""
	prog.state.deposits.erase("bench_l4_gold")
	prog.init_formation("bench_l4_gold")
	var f: Dictionary = prog.fossil_cfg()
	for ci in f["columns"]:
		prog.extract("bench_l4_gold", int(ci), 99999.0, 1 << 20, "hand")
	check(prog.fossil_exposed(), "8 mining the two columns out with the normal mining code exposes the fossil")
	game.reveal_cinematic = true
	game.player.locked = false
	game._fossil_timer = 0.0
	await frames(3)
	check(prog.fossil_state() == "found" and game.fossil_node != null and game.fossil_reveal_active and game.player.locked, "8b the find triggers the reveal: control is taken, the fossil is in view")
	await frames(80)
	var to: Vector3 = game.fossil_node.global_position + Vector3(0, 0.4, 0) - game.player.camera.global_position
	check(absf(angle_difference(game.player.rotation.y, atan2(-to.x, -to.z))) < 0.2, "8c the view swings round to the bones")
	game._end_fossil_reveal()
	await frames(40)
	check(not game.fossil_reveal_active and not game.player.locked and absf(game.player.camera.rotation.x) < 0.03, "8d control comes back smoothly (and E skips it)")
	# ---- 9: Walter's visit: the view turns to him
	game.prog.story["visits"] = {}
	game._spawn_walter(game.walter_pos())
	game.walter_mode = "waiting"
	game.walter_visit = "first_crew"
	game.player.global_position = game.walter_pos() + Vector3(3.0, 0.2, 0.0)
	game.player.rotation.y = PI
	game._talk_to_walter()
	await frames(50)
	var wd: Vector3 = game.walter_node.global_position + Vector3(0, 1.5, 0) - game.player.global_position
	check(game.walter_dialog != null and absf(angle_difference(game.player.rotation.y, atan2(-wd.x, -wd.z))) < 0.2, "9 starting a visit turns the player's view to Walter")
	game.walter_dialog.skip()
	await frames(40)
	check(not game.player.locked and absf(game.player.camera.rotation.x) < 0.03, "9b and gives the view back afterwards")
	# ---- 10: the egg rocks before it hatches
	game._remove_companion()
	prog.story["companion"] = {"state": "egg", "egg_day": 0}
	prog.current_day = 5
	game._spawn_egg()
	game.hatch_wobble = true
	game._hatch_egg()
	await frames(30)
	check(game._hatching and game.egg_node != null and absf(game.egg_node.rotation.z) > 0.05, "10 the egg rocks from side to side before it opens")
	await frames(120)
	check(not game._hatching and prog.companion().get("state") == "alive" and game.companion_node != null, "10b and then the hatchling is there")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
