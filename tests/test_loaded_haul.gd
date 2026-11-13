extends SceneTree
## Connected quarry, Phase E: a FULLY LOADED haul truck drives down through all four levels and climbs back out with its load, and the
## load is still on board at the top (nothing lost on the ramps).   godot --headless --fixed-fps 60 -s tests/test_loaded_haul.gd

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
	game.ui_buy_vehicle(OS.get_environment("HAUL_TRUCK") if OS.get_environment("HAUL_TRUCK") != "" else "heavy_truck")
	game.delivery.finish_all()
	var trucks: Array = game.vehicle_nodes.values()
	check(trucks.size() >= 1, "the biggest haul truck is bought")
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
	var trec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	var cap: int = game.fleet.capacity(trec)
	trec["cargo"] = {"copper_ore": cap}
	check(game.fleet.cargo_total(trec) == cap and cap > 0, "the truck is loaded to capacity (%d units)" % cap)
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
	check(route_ok and seen[2] and seen[3] and seen[4], "loaded: the truck drives down to level 4 (lowest %.2f)" % low)
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
	check(up_ok and pz.to_loc(truck.global_position).y > -4.0, "loaded: and climbs back out of the pit (y %.2f)" % pz.to_loc(truck.global_position).y)
	check(game.fleet.cargo_total(trec) == cap and int(trec["cargo"].get("copper_ore", 0)) == cap, "the whole load is still on board at the top: nothing was lost on the ramps")
	# on to the yard: across the basin floor, up the 20 m basin ramp, along the corridor and out of the gate, still loaded
	var zs: float = pz.basin_zs()
	# the ramp foot is at z = zs - 20 (x -4..4): the truck turns onto it through the open stretch at the foot (no rail for the first 6 m)
	# The basin ramp stands at x 0 but the level-2 haul road comes out at the pit's south-west corner (x -54.5), and the pit lies between
	# them: the way is round the pit - west edge corridor, north end, east side, then south to the ramp foot.
	var to_yard := [Vector2(-61.5, -62.0), Vector2(-61.5, -100.0), Vector2(-61.5, -158.0), Vector2(2.0, -158.0), Vector2(2.0, -110.0), Vector2(2.0, -74.0), Vector2(0.0, zs - 15.0), Vector2(0.0, zs + 2.0), Vector2(0.0, -12.0), Vector2(0.0, 2.0)]
	truck.input = {"throttle": 0.0, "steer": 0.0, "brake": false}
	var yard_ok := true
	for wp in to_yard:
		var ok2 := await drive_route(game, truck, [wp], 2400)
		yard_ok = yard_ok and ok2
		if not ok2:
			var kc2 := KinematicCollision3D.new()
			var hit2: bool = truck.test_move(truck.global_transform, truck.forward() * 0.4, kc2)
			printerr("   loaded truck stopped before %s at %s speed %.2f yaw %.2f floor %s ahead: %s n=%s" % [str(wp), str(pz.to_loc(truck.global_position)), truck.speed, truck.rotation.y, str(truck.is_on_floor()), (str(kc2.get_collider().name) + " " + str(kc2.get_collider().get_parent().name)) if hit2 and kc2.get_collider() else "nothing", str(kc2.get_normal()) if hit2 else ""])
			if hit2 and kc2.get_collider():
				var col := kc2.get_collider() as Node3D
				var shp = (col.get_child(0) as CollisionShape3D).shape
				printerr("   obstacle: pos %s rot %s size %s curb %s ramp %s fill_skip %s" % [str(pz.to_loc(col.global_position)), str(col.rotation), str(shp.size) if shp is BoxShape3D else str(shp), str(col.has_meta("curb")), str(col.has_meta("ramp")), str(col.has_meta("nav_skip"))])
			break
	var gl: Vector3 = pz.to_loc(truck.global_position)
	check(yard_ok and gl.z > -6.0 and gl.y > -0.5, "loaded: it climbs the basin ramp, drives the corridor and reaches the quarry gate (z %.1f, y %.2f)" % [gl.z, gl.y])
	check(int(trec["cargo"].get("copper_ore", 0)) == cap, "and arrives with its full load")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
