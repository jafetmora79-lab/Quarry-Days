extends SceneTree
## Phase 8.7: the open-pit quarry. One terraced mass with four working levels, a haul road that reaches all of them, permanent
## excavation, an explicit save migration. Mines a route through the quarry and drives it.
##   godot --headless --fixed-fps 60 -s tests/test_open_pit.gd

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

func frames(n: int, until := Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func ground_y(game, lx: float, lz: float, y_from := 6.0) -> float:
	var w: Vector3 = game.pit_zone.to_world(Vector3(lx, y_from, lz))
	var q := PhysicsRayQueryParameters3D.create(w, w + Vector3(0, -40.0, 0), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else -99.0

func zero_formation(game, id: String, pattern := 0) -> void:
	var prog: QuarryProgression = game.prog
	prog.init_formation(id)
	var d: Dictionary = prog.state.deposits[id]
	for i in range(d["columns"].size()):
		var dim: Vector2i = prog.dims(id)
		var kill := pattern == 0 or (pattern == 1 and ((i % dim.x) + (i / dim.x)) % 2 == 0) or (pattern == 2 and (i / dim.x) < dim.y / 2)
		if kill:
			d["columns"][i] = 0
	prog._sync_stock(d)
	game._refresh_deposit(id)

## Drives a machine through pit-local waypoints (x, z) with the real controls, slow enough to take the corners.
func drive_route(game, v, route: Array, max_frames: int, cap := 3.2) -> bool:
	var pz = game.pit_zone
	var st := {"i": 0}
	var done := await frames(max_frames, func():
		var target: Vector3 = pz.to_world(Vector3(route[st["i"]].x, 0.0, route[st["i"]].y))
		var d: Vector3 = target - v.global_position
		if Vector2(d.x, d.z).length() < 2.2:
			st["i"] += 1
			if st["i"] >= route.size():
				v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
				return true
			return false
		var want := atan2(-d.x, -d.z)
		var diff := wrapf(want - v.rotation.y, -PI, PI)
		var thr := 0.7 if absf(diff) < 0.5 else 0.3
		if v.speed > cap or (absf(diff) > 0.5 and v.speed > 1.8):
			thr = 0.0
		v.input = {"throttle": thr, "steer": clampf(-diff * 2.5, -1.0, 1.0), "brake": false}
		return false)
	return done < max_frames

## The haul road, down and back: pit-local (x, z) waypoints.
const DOWN := [Vector2(-54.5, -62.0), Vector2(-54.5, -80.0), Vector2(-54.5, -110.0), Vector2(-54.5, -143.0), Vector2(-30.0, -143.0), Vector2(-15.5, -143.0), Vector2(-15.5, -132.0),
	Vector2(-15.5, -112.0), Vector2(-15.5, -95.0), Vector2(-26.0, -92.0), Vector2(-36.5, -92.0), Vector2(-36.5, -100.0), Vector2(-36.5, -112.0), Vector2(-36.5, -130.0)]

func walk(game, route: Array, label: String) -> bool:
	var pz = game.pit_zone
	var pl = game.player
	for wp in route:
		var gl: Vector3 = pz.to_world(Vector3(wp.x, 0.0, wp.y))
		var t := 0
		while t < 1800:
			var d := Vector3(gl.x - pl.global_position.x, 0, gl.z - pl.global_position.z)
			if d.length() < 0.5:
				break
			pl.drive_wish = d
			await physics_frame
			t += 1
		pl.drive_wish = Vector3.ZERO
		if t >= 1800:
			var kc := KinematicCollision3D.new()
			var dd := Vector3(gl.x - pl.global_position.x, 0, gl.z - pl.global_position.z).normalized()
			var hit: bool = pl.test_move(pl.global_transform, dd * 0.3, kc)
			pl.drive_wish = Vector3.INF
			printerr("   %s: stuck before %s at %s; blocked by %s %s" % [label, str(wp), str(pz.to_loc(pl.global_position)), (kc.get_collider().name if hit and kc.get_collider() else "nothing"), str(kc.get_normal()) if hit else ""])
			return false
	pl.drive_wish = Vector3.INF
	return true

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
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
	game._sync_pit_gate()
	game.safety.enabled = false      # this test checks the geometry itself; the stuck-player safeguard has its own test
	# ---- A: the untouched quarry is one intact mass with a stepped shell
	check(pz.level_pits.size() == 3, "A the pit zone has the shells of levels 2, 3 and 4")
	var ok_w := true
	var ok_slope := true
	for lp in pz.level_pits:
		ok_w = ok_w and float(lp["rw"]) >= 8.0 and (lp["strip"] as Rect2).size.x >= 8.0
		var run: float = float(lp["run"])
		ok_slope = ok_slope and rad_to_deg(atan2(float(lp["y_top"]) - float(lp["y_bot"]), run)) <= 12.0
	check(ok_w, "A every haul road is at least 8 m wide")
	check(ok_slope, "A every ramp is gentler than 12 degrees")
	check(is_equal_approx(pz.deepest_y, -14.4), "A four levels: the floors are -3.6, -7.2, -10.8, -14.4")
	var intact := true
	for id in ["bench_l2_coal", "bench_l2_iron", "bench_l3_iron", "bench_l3_copper", "bench_l4_copper", "bench_l4_gold"]:
		intact = intact and prog.units_left(id) == prog.max_units(id) and game.formation_nodes.has(id)
	check(intact, "A all six benches start whole")
	var rock_top: float = ground_y(game, -30.0, -120.0)
	check(absf(rock_top + 3.6) < 0.2, "A the level 2 rock is flush with the basin floor, no pre-cut pit (%.2f)" % rock_top)
	check(absf(ground_y(game, -54.5, -66.0) + 3.6) < 0.6 and absf(ground_y(game, -54.5, -95.0) + 7.2) < 0.15, "A the first ramp descends from -3.6 to -7.2 at the pit's edge")
	var gaps := 0
	var lattice := 0
	var gx := -49.5
	while gx < -5.5:
		var gz := -149.5
		while gz < -69.5:
			lattice += 1
			if absf(ground_y(game, gx, gz) + 3.6) > 0.15:
				gaps += 1
			gz += 1.3
		gx += 1.3
	check(lattice > 1500 and gaps == 0, "A the level 2 rock is one gap-free mass: %d of %d ray samples across it are not at its top" % [gaps, lattice])
	var big := 0
	for id in ["bench_l2_coal", "bench_l2_iron"]:
		big += prog.column_count(id)
	check(big >= 300, "A level 2 is one large block of rock (%d columns)" % big)
	var skin_ok := true
	for id in ["bench_l2_coal", "bench_l3_iron", "bench_l4_gold"]:
		skin_ok = skin_ok and game.formation_nodes[id].skin and (game.formation_nodes[id].skin_mi.mesh.get_surface_count() > 0)
	check(skin_ok, "A the benches are one continuous rock surface, not a stack of blocks")
	# ---- B: levels open in turn, each cutting its own haul road
	for id in ["hillside_face_01", "pit_band_01"]:
		zero_formation(game, id)
	var road_before: int = prog.units_left("bench_l2_iron")
	prog.check_levels()
	check(prog.quarry_level == 2, "B clearing level 1 opens level 2 only (%d)" % prog.quarry_level)
	check(prog.units_left("bench_l2_iron") < road_before and absf(ground_y(game, -30.0, -143.0) + 7.2) < 0.2, "B opening level 2 cuts its haul road through the rock (%.2f)" % ground_y(game, -30.0, -143.0))
	var again: int = prog.open_roads(2)
	check(again == 0, "B cutting the road twice does nothing")
	check(prog.formation_locked("bench_l3_iron") != "", "B level 3 rock stays locked and covered")
	check(ground_y(game, -30.0, -120.0) > -3.8 and ground_y(game, -15.5, -120.0) < -8.0, "B only the road is cut: the rest of level 2 stands, the level 3 ramp is open (%.2f, %.2f)" % [ground_y(game, -30.0, -120.0), ground_y(game, -15.5, -120.0)])
	# partial excavation: a chequerboard of level 2, then half of it
	zero_formation(game, "bench_l2_coal", 1)
	zero_formation(game, "bench_l2_iron", 2)
	await frames(2)
	var void_found := 0
	var samples := 0
	for id in ["bench_l2_coal", "bench_l2_iron"]:
		var node = game.formation_nodes[id]
		for i in range(prog.column_count(id)):
			var cp := prog.column_pos(id, i)
			var l: Vector3 = pz.to_loc(cp)
			var want := -7.2 + float(prog.chunks_left(id, i)) * 1.2 if prog.column_units(id, i) > 0 else -7.2
			var got := ground_y(game, l.x, l.z, 4.0)
			samples += 1
			var strip3: bool = l.x > -20.0 and l.x < -11.0 and l.z < -87.0 and l.z > -135.0     # the opened ramp of level 3 lies under here
			if got < -7.4 and not strip3:
				void_found += 1          # fell through to a lower floor or the void
			elif strip3:
				pass
			elif absf(got - want) > 0.45 and not (prog.column_units(id, i) <= 0 and got > -7.3):
				void_found += 1
	check(samples > 300 and void_found == 0, "B a half-excavated level 2 has no holes (%d columns sampled, %d wrong)" % [samples, void_found])
	check(prog.units_left("bench_l2_coal") < prog.max_units("bench_l2_coal") and prog.units_left("bench_l2_coal") > 0, "B the cut is partial: the rest of the rock is still there")
	# ---- C: levels 3 and 4
	zero_formation(game, "bench_l2_coal")
	zero_formation(game, "bench_l2_iron")
	prog.check_levels()
	check(prog.quarry_level == 3, "C clearing level 2 opens level 3 (%d)" % prog.quarry_level)
	zero_formation(game, "bench_l3_iron", 2)
	zero_formation(game, "bench_l3_copper", 2)
	prog.check_levels()
	check(prog.quarry_level == 4, "C cutting level 3 opens level 4 (%d)" % prog.quarry_level)
	for id in ["bench_l3_iron", "bench_l3_copper"]:
		game._refresh_deposit(id)
	await frames(4)
	var f3 := ground_y(game, -15.5, -100.0)
	var f4 := ground_y(game, -36.5, -125.0)
	check(absf(ground_y(game, -15.5, -112.0) + 10.8) < 0.2 and absf(f4 + 14.4) < 0.2, "C the level 3 and level 4 roads are open (%.2f, %.2f)" % [ground_y(game, -15.5, -112.0), f4])
	check(absf(ground_y(game, -30.0, -92.0, -4.0) + 10.8) < 0.3, "C the landing at the foot of the level 3 ramp is at the level floor (%.2f)" % ground_y(game, -30.0, -92.0, -4.0))
	# ---- D: a truck drives down all four levels and back up
	prog.stage = prog.stage_index("deep")
	game.state.money = 900000
	game.state.tool_tier = 3
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	game.ui_buy_vehicle("industrial_truck")
	game.delivery.finish_all()
	var trucks: Array = game.vehicle_nodes.values()
	check(trucks.size() >= 1, "D the biggest haul truck is bought")
	var truck = trucks[0]
	game.player.global_position = pz.to_world(Vector3(-40.0, 0.2, -60.0))
	game.enter_vehicle(truck)
	game.scripted_input = true
	var start := Vector3(-54.5, -3.6, -58.0)
	truck.global_position = pz.to_world(start + Vector3(0, 0.2, 0))
	truck.rotation.y = pz.global_rotation.y
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	truck.settled_frames = 0
	truck.safe_position = truck.global_position
	var low := 0.0
	var seen := {2: false, 3: false, 4: false}
	var route_ok := true
	for wp in DOWN:
		var ok := await drive_route(game, truck, [wp], 2400)
		route_ok = route_ok and ok
		var ly: float = pz.to_loc(truck.global_position).y
		low = minf(low, ly)
		if ly < -6.8: seen[2] = true
		if ly < -10.4: seen[3] = true
		if ly < -14.0: seen[4] = true
		if not ok:
			var kc := KinematicCollision3D.new()
			var fwd: Vector3 = truck.forward()
			var hit: bool = truck.test_move(truck.global_transform, fwd * 0.4, kc)
			printerr("   truck stopped before %s at %s yaw %.2f speed %.2f floor %s; ahead: %s %s %s" % [str(wp), str(pz.to_loc(truck.global_position)), truck.rotation.y, truck.speed, str(truck.is_on_floor()), (str(kc.get_collider().name) + " " + str(kc.get_collider().get_parent().name) if hit and kc.get_collider() else "nothing"), str(kc.get_normal()) if hit else "", str(kc.get_position()) if hit else ""])
			break
	check(route_ok and seen[2] and seen[3] and seen[4], "D the heavy truck drives down to level 4 (lowest %.2f)" % low)
	var back := DOWN.duplicate()
	back.reverse()
	back.remove_at(0)        # the end of the road: the truck is turned round there (a dead end), then climbs
	truck.rotation.y += PI
	var up_ok := true
	for wp in back:
		# reverse the route by turning round first
		var ok := await drive_route(game, truck, [wp], 2400)
		up_ok = up_ok and ok
		if not ok:
			var kc := KinematicCollision3D.new()
			var hit: bool = truck.test_move(truck.global_transform, truck.forward() * 0.4, kc)
			printerr("   truck stopped (up) before %s at %s speed %.2f; ahead: %s" % [str(wp), str(pz.to_loc(truck.global_position)), truck.speed, (str(kc.get_collider().name) + " n=" + str(kc.get_normal()) + " at " + str(pz.to_loc((kc.get_collider() as Node3D).global_position)) + " " + str(((kc.get_collider() as Node).get_child(0) as CollisionShape3D).shape.size) + " rot " + str((kc.get_collider() as Node3D).rotation) if hit and kc.get_collider() else "nothing")])
			break
	check(up_ok and pz.to_loc(truck.global_position).y > -4.0, "D and back up out of the pit (y %.2f)" % pz.to_loc(truck.global_position).y)
	truck.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	game._reset_driving()
	game.player.locked = false
	truck.global_position = pz.to_world(Vector3(-20.0, 0.2, -56.0))      # park it out of the walkers' way
	truck.speed = 0.0
	await frames(5)
	game.scripted_input = false
	# ---- E: a person walks the same road
	game.player.global_position = pz.to_world(Vector3(-44.0, -3.4, -58.0))
	await frames(10)
	var walk_route := []
	for wp in DOWN:
		walk_route.append(wp)
	var walked: bool = await walk(game, walk_route, "walk down")
	var pl_y: float = pz.to_loc(game.player.global_position).y
	check(walked and pl_y < -13.5, "E the player walks to level 4 (y %.2f)" % pl_y)
	var rev := DOWN.duplicate()
	rev.reverse()
	var walked_up: bool = await walk(game, rev, "walk up")
	check(walked_up and pz.to_loc(game.player.global_position).y > -4.0, "E and back up to the rim")
	# ---- F: crews can reach what is exposed
	pz.request_bake()
	var waited := 0
	while (pz.is_baking() or pz.bake_count < 1) and waited < 2400:
		await physics_frame
		waited += 1
	await frames(5)
	var a_w: Vector3 = pz.to_world(Vector3(-54.5, -3.6, -60.0))
	var b_w: Vector3 = pz.to_world(Vector3(-36.5, -14.4, -130.0))
	var path: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, a_w, b_w, true)
	check(path.size() > 2 and path[path.size() - 1].distance_to(b_w) < 1.6, "F a walkable path leads from the rim to the level 4 floor (%d points, bake %d frames)" % [path.size(), waited])
	var exposed_l4 := 0
	for i in range(prog.column_count("bench_l4_gold")):
		if prog.column_exposed("bench_l4_gold", i) and prog.column_minable("bench_l4_gold", i):
			exposed_l4 += 1
	check(exposed_l4 > 0, "F the gold bench has columns a miner can reach once level 3 is cut (%d)" % exposed_l4)
	# ---- G: permanence, no duplication
	var snap: Dictionary = prog.snapshot()
	var money0: int = game.state.money
	var cols_before := {}
	for id in prog.formation_ids():
		if prog.state.deposits.has(id):
			cols_before[id] = (prog.state.deposits[id]["columns"] as Array).duplicate()
	var inv_before: Dictionary = game.state.inventory.duplicate()
	prog.restore(snap, ["industrial_truck"])
	game._sync_formations()
	await frames(3)
	var same := true
	for id in cols_before:
		same = same and prog.state.deposits[id]["columns"] == cols_before[id]
	check(same and prog.quarry_level == 4, "G excavation and the opened level survive a save and load")
	check(game.state.money == money0 and game.state.inventory == inv_before, "G loading pays out nothing and duplicates nothing")
	var wide_after: float = ground_y(game, -30.0, -143.0)
	check(absf(wide_after + 7.2) < 0.2, "G the cut haul road is still open after loading (%.2f)" % wide_after)
	# ---- H: old saves migrate by cleared fraction
	var legacy_ids := ["bench_l2_coal", "bench_l2_iron", "bench_l3_iron", "bench_l3_copper", "bench_l4_copper", "bench_l4_gold"]
	var mig_ok := true
	var detail := ""
	for id in legacy_ids:
		var lg: Dictionary = prog.cfg["legacy_formations"][id]
		var old_cols := []
		var old_cell_max := int(lg["units"]) / int(lg["columns"])
		for i in range(int(lg["columns"])):
			old_cols.append(old_cell_max if i % 4 != 0 else 0)          # a quarter of the old rock mined
		var left_old := 0
		for v in old_cols:
			left_old += int(v)
		var mined_old := 1.0 - float(left_old) / float(lg["units"])
		prog.state.deposits[id] = {"columns": old_cols, "formation": true, "resource": str(prog.fdef(id)["resource"]), "stock": left_old, "mined": 100}
		var d := prog.init_formation(id)
		var mined_new := 1.0 - float(prog.units_left(id)) / float(prog.max_units(id))
		var right_count: bool = (d["columns"] as Array).size() == prog.column_count(id)
		if not right_count or absf(mined_new - mined_old) > 0.02 or int(d["mined"]) != 100:
			mig_ok = false
			detail += " %s(%.3f vs %.3f)" % [id, mined_new, mined_old]
		var snapshot_cols: Array = (d["columns"] as Array).duplicate()
		prog.init_formation(id)
		mig_ok = mig_ok and prog.state.deposits[id]["columns"] == snapshot_cols      # converting twice changes nothing
	check(mig_ok, "H an old-layout save keeps its excavated share in the new layout, exactly once%s" % detail)
	var fresh_untouched := {"columns": [], "formation": true}
	prog.state.deposits["bench_l2_coal"] = fresh_untouched
	prog.init_formation("bench_l2_coal")
	check(prog.units_left("bench_l2_coal") == prog.max_units("bench_l2_coal"), "H a save with no rock mined starts the new bench whole")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
