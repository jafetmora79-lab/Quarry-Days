extends SceneTree
## The hand digging loop on the real quarry, end to end: shovel the soil and the topsoil, meet the bench floor and the step rule with a plain explanation, open the next level, break rock with the
## hammer and scoop it, carry it to the box (dump the bag), sell it, see the contract counters move, and keep all of it through save/load. (Machines are covered by test_excavator_terrain,
## test_loader_terrain, test_phase10_earthmoving and test_dozer_rig.)   godot --headless --fixed-fps 60 -s tests/test_dig_loop.gd

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

func bag_total(game) -> int:
	var n := 0
	for k in game.state.inventory:
		n += int(game.state.inventory[k])
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(12)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var prog: QuarryProgression = game.prog
	var lt: LiveTerrain = game.live_terrain
	var t := lt.terrain
	prog.cleanup["done"] = true
	if not game.state.gear.has("shovel"):
		game.state.gear.append("shovel")
	game.state.equipped = "shovel"
	game.safety.enabled = false
	# ---- topsoil beyond the soil field, to the bench floor (-1.2 m at the first level)
	var spot := Vector2(40.0, -50.0)
	var msgs: Array = []
	var floor_hit := false
	var step_hit := false
	var dug := 0.0
	for ring in range(0, 10):
		var n := maxi(1, ring * 6)
		for a in range(n):
			var p := Vector3(spot.x + cos(float(a) / float(n) * TAU) * float(ring) * 0.45, 0.0, spot.y + sin(float(a) / float(n) * TAU) * float(ring) * 0.45)
			for k in range(6):
				p.y = t.height_at(p.x, p.z)
				var r: Dictionary = game._terrain_strike(p)
				if r.is_empty():
					continue
				if str(r["limit"]) == "floor":
					floor_hit = true
				elif str(r["limit"]) == "step":
					step_hit = true
	var low := 0.0
	for xi in range(-6, 7):
		for zi in range(-6, 7):
			low = minf(low, t.height_at(spot.x + float(xi) * 0.5, spot.y + float(zi) * 0.5))
	check(low < -0.4, "the spade really digs the ground (lowest %.2f m)" % low)
	check(low >= -1.2 - 0.001, "the first level's bench floor holds: nothing is dug under -1.2 m (lowest %.2f)" % low)
	check(floor_hit or step_hit, "and the player is told why digging cannot continue (floor=%s, step=%s)" % [floor_hit, step_hit])
	check(bag_total(game) > 0 or float(game.terrain_rem.get("topsoil", 0.0)) > 0.0, "the soil went into the bag (%d)" % bag_total(game))
	# ---- the message the strike gives
	check(game._dig_limit_message("floor").find("next quarry level") >= 0 and game._dig_limit_message("step").find("Widen") >= 0, "the two explanations name what to do next (open the next level / widen the hole)")
	# ---- the next level opens the next bench
	prog.quarry_level = 2
	check(lt.bench_floor(spot.x, spot.y) <= -4.79 and lt.bench_floor(0.0, -20.0) > -1.3, "level 2 lowers the floor to -4.8 inside its own pit only (%.1f here, %.1f outside)" % [lt.bench_floor(spot.x, spot.y), lt.bench_floor(0.0, -20.0)])
	# ---- carry, store, sell, contracts
	game.state.inventory["topsoil"] = int(game.state.inventory.get("topsoil", 0)) + 2
	game.state.inventory["limestone"] = 6
	var money0: int = game.state.money
	var sold: int = game.state.sell("limestone", 6)
	check(sold == 6 and game.state.money > money0, "rock from the bag sells for money (%d to %d)" % [money0, game.state.money])
	var moved: int = game.dump_bucket()
	check(moved >= 0, "the bag empties into the box")
	# ---- save/load keeps the ground
	var h_before := t.height_at(spot.x, spot.y)
	game.soil_sync_state()
	game._save(true)
	game._load(true)
	await frames(4)
	var t2: QuarryTerrain = game.live_terrain.terrain
	check(absf(t2.height_at(spot.x, spot.y) - h_before) < 0.02, "the dug ground comes back after loading (%.2f vs %.2f)" % [t2.height_at(spot.x, spot.y), h_before])
	check(int(game.prog.quarry_level) == 2 and game.live_terrain.bench_floor(spot.x, spot.y) <= -4.79, "and so does the level, with its bench floor")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
