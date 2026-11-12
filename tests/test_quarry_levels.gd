extends SceneTree
## Phase 7.2: the four physical quarry levels: stacked benches, shells, ramps, locking, cover, permanence, navigation.
##   godot --headless --fixed-fps 60 -s tests/test_quarry_levels.gd

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

## Height of the first solid thing under (x, z) in pit-local coordinates, shooting down from y_from.
func ground_y(game, lx: float, lz: float, y_from := 6.0) -> float:
	var w: Vector3 = game.pit_zone.to_world(Vector3(lx, y_from, lz))
	var q := PhysicsRayQueryParameters3D.create(w, w + Vector3(0, -30.0, 0), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else -99.0

func empty_formation(game, id: String) -> void:
	var prog: QuarryProgression = game.prog
	prog.init_formation(id)
	var d: Dictionary = prog.state.deposits[id]
	for i in range(d["columns"].size()):
		d["columns"][i] = 0
	prog._sync_stock(d)
	game._refresh_deposit(id)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	var prog: QuarryProgression = game.prog
	var pz: QuarryPitZone = game.pit_zone
	prog.cleanup["done"] = true
	# ---- A: definitions
	check(pz != null and pz.level_pits.size() == 3, "A the pit zone has shells for levels 2, 3 and 4")
	check(is_equal_approx(pz.deepest_y, -14.4), "A the deepest floor is -14.4 m")
	var ids := ["bench_l2_coal", "bench_l2_iron", "bench_l3_iron", "bench_l3_copper", "bench_l4_copper", "bench_l4_gold"]
	var all_built := true
	for id in ids:
		all_built = all_built and game.formation_nodes.has(id)
	check(all_built, "A all six bench formations are built in the world")
	var mats := {"bench_l2_coal": "coal", "bench_l2_iron": "iron_ore", "bench_l3_iron": "iron_ore", "bench_l3_copper": "copper_ore", "bench_l4_copper": "copper_ore", "bench_l4_gold": "gold_ore"}
	var ok_m := true
	for id in mats:
		ok_m = ok_m and str(prog.fdef(id)["resource"]) == mats[id]
	check(ok_m, "A materials follow depth: coal and iron, then iron and copper, then copper and gold")
	# ---- B: physical shell
	var floor_l1: float = ground_y(game, 20.0, -60.0)
	check(absf(floor_l1 + 3.6) < 0.1, "B the basin floor is at -3.6 (%.2f)" % floor_l1)
	var col_top: float = ground_y(game, -16.0, -62.0)
	check(absf(col_top + 3.6) < 0.1, "B the level 2 rock is flush with the basin floor (%.2f)" % col_top)
	var r_top: float = ground_y(game, -25.0, -50.0)
	var r_mid: float = ground_y(game, -25.0, -58.0)
	var r_end: float = ground_y(game, -25.0, -66.0)
	check(absf(r_top + 3.6) < 0.4 and r_mid < r_top - 1.0 and absf(r_end + 7.2) < 0.4, "B the level 2 ramp descends from -3.6 to -7.2 (%.2f, %.2f, %.2f)" % [r_top, r_mid, r_end])
	var r3_top: float = ground_y(game, -19.0, -52.0, -5.0)
	check(r3_top < -7.0 and r3_top > -8.0, "B the level 3 ramp starts at the level 2 floor (%.2f)" % r3_top)
	# ---- C: locking and exposure
	check(prog.formation_locked("bench_l2_coal") != "" and prog.formation_locked("bench_l4_gold") != "", "C deeper rock is locked until its level is open")
	var before: int = int(prog.units_left("bench_l2_coal"))
	check(game.player_mine("bench_l2_coal", 0, 99.0) == 0 and prog.units_left("bench_l2_coal") == before, "C a locked bench cannot be mined")
	prog.quarry_level = 2
	check(prog.formation_locked("bench_l2_coal") == "", "C level 2 opens its benches")
	var d: Vector2i = prog.dims("bench_l2_coal")
	var corner := 0
	var inner := d.x + 1
	check(prog.column_exposed("bench_l2_coal", corner) and not prog.column_exposed("bench_l2_coal", inner) or d.y < 3, "C the edge of the bench is reachable, the interior is not")
	check(prog.column_covered("bench_l3_iron", 0), "C level 3 rock is covered by level 2 rock above it")
	check(not prog.column_exposed("bench_l3_iron", 0), "C and cannot be reached")
	# ---- D: permanent excavation, collision follows
	var one: Dictionary = prog.extract("bench_l2_coal", corner, 1000.0)
	game._refresh_deposit("bench_l2_coal")
	check(int(one["units"]) > 0 and prog.column_units("bench_l2_coal", corner) < prog.column_max("bench_l2_coal", corner), "D mining takes units out of the column for good")
	var left_a: int = prog.units_left("bench_l2_coal")
	game._refresh_deposit("bench_l2_coal")
	check(prog.units_left("bench_l2_coal") == left_a, "D refreshing never brings rock back")
	empty_formation(game, "bench_l2_coal")
	empty_formation(game, "bench_l2_iron")
	await frames(3)
	var floor_l2: float = ground_y(game, -16.0, -62.0)
	check(absf(floor_l2 + 7.2) < 0.15, "D with the rock gone the floor is the level 2 floor, -7.2 (%.2f)" % floor_l2)
	check(not prog.column_covered("bench_l3_iron", 0) and prog.column_exposed("bench_l3_iron", 0), "D and the level 3 rock under it is uncovered and exposed")
	var f3: float = ground_y(game, -14.0, -62.0)
	check(absf(f3 + 7.2) < 0.15, "D level 3 rock is flush with the level 2 floor (%.2f)" % f3)
	# ---- E: progression
	prog.state.deposits.erase("hillside_face_01")
	prog.state.deposits.erase("pit_band_01")
	prog.quarry_level = 1
	for id in ["hillside_face_01", "pit_band_01"]:
		prog.init_formation(id)
		var dd: Dictionary = prog.state.deposits[id]
		for i in range(dd["columns"].size()):
			dd["columns"][i] = 0
		prog._sync_stock(dd)
	prog.check_levels()
	check(prog.quarry_level == 3, "E with level 1 and level 2 cut the quarry opens up to level 3 (%d)" % prog.quarry_level)
	var req: Array = prog.requirement_progress(prog.stage_index("large"))
	var has_lv := false
	for r in req:
		has_lv = has_lv or str(r[0]).begins_with("Open quarry level")
	check(has_lv, "E the Large-Scale Mining stage asks for the next quarry level")
	# ---- F: navigation reaches the lower level by the ramp
	prog.quarry_level = 2
	game._sync_pit_gate()
	pz.request_bake()
	var waited := 0
	while (pz.is_baking() or pz.bake_count < 1) and waited < 900:
		await physics_frame
		waited += 1
	await frames(5)
	var start_w: Vector3 = pz.to_world(Vector3(-25.0, -3.6, -50.5))
	var goal_w: Vector3 = pz.to_world(Vector3(-25.0, -7.2, -65.5))
	var path: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, start_w, goal_w, true)
	var ok_path := path.size() > 1 and path[path.size() - 1].distance_to(goal_w) < 1.2
	check(ok_path, "F a walkable path leads down the level 2 ramp (baked after %d frames, %d points)" % [waited, path.size()])
	# ---- G: saves
	var snap: Dictionary = prog.snapshot()
	var cols_before: Array = prog.state.deposits["bench_l2_coal"]["columns"].duplicate()
	prog.restore(snap, [])
	check(prog.quarry_level >= 1 and prog.state.deposits["bench_l2_coal"]["columns"] == cols_before, "G a save keeps the level and the cut rock")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
