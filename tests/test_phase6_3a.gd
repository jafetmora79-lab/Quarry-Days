extends SceneTree
## Phase 6.3a tests: the north-east gate, the pit zone (plateau, basin, ramp), navigation regions, build zones.
##   godot --headless --fixed-fps 60 -s tests/test_phase6_3a.gd

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

func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func ring_gaps(game) -> Array:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var gaps := []
	for deg in range(0, 360, 2):
		var a := deg_to_rad(float(deg))
		var hit := false
		for y in [0.5, 2.0, 4.0]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(cos(a) * 22.0, y, sin(a) * 22.0), Vector3(cos(a) * 33.0, y, sin(a) * 33.0))
			q.collision_mask = 1
			if not space.intersect_ray(q).is_empty():
				hit = true
		if not hit:
			gaps.append(deg)
	return gaps

func nav_end(game, from: Vector3, to: Vector3) -> Vector3:
	var p: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, from, to, true)
	return p[p.size() - 1] if p.size() > 0 else Vector3(1e6, 1e6, 1e6)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await process_frame
	for i in range(5):
		await physics_frame
	game.hud.close_card()
	var prog: QuarryProgression = game.prog
	var pz: QuarryPitZone = game.pit_zone
	check(pz != null and pz.is_inside_tree(), "A the pit zone is built")
	check(game.pit_retired.size() >= 1, "A the ring pieces in the gate mouth were retired (%s)" % str(game.pit_retired))
	# ---- closed at the start of a new game
	check(not pz.is_open and pz.barrier.collision_layer == 1 and pz.barrier.visible, "B a new game starts with the north gate barrier in place")
	var gaps: Array = ring_gaps(game)
	check(gaps.is_empty(), "B the cliff ring has no gaps while the gate is closed %s" % str(gaps.slice(0, 6)))
	check(not game.in_build_area(pz.to_world(Vector3(20, 0, -45))) and not game.in_build_area(pz.to_world(Vector3(0, -3.6, -75))), "B the pit zone is not a build area while the gate is closed")
	check(game.in_build_area(Vector3(0, 0, 10)) and not game.in_build_area(Vector3(0, 0, -10)) and not game.in_build_area(Vector3(-22.0, 0, -1.0), 2.0), "B the yard's build area is unchanged")
	await frames(600, func(): return pz.nav_ready and not pz.is_baking())
	check(pz.nav_ready and pz.bake_ms < 30.0, "C the pit region baked in the background (collecting its sources took %.1f ms on the main thread)" % pz.bake_ms)
	var basin := pz.to_world(Vector3(0, -3.6, -75))
	var from := Vector3(0, 0.1, 8)
	var e1 := nav_end(game, from, basin)
	check(Vector2(e1.x, e1.z).distance_to(Vector2(basin.x, basin.z)) > 20.0, "C staff cannot path to the basin while the gate is closed")
	# ---- open (the site is clean)
	prog.cleanup["done"] = true
	game._spawn_cleanup()
	await process_frame
	check(pz.is_open and pz.barrier.collision_layer == 0 and not pz.barrier.visible, "D finishing the tutorial opens the gate")
	var bakes0: int = pz.bake_count
	await frames(600, func(): return pz.bake_count > bakes0 and not pz.is_baking())
	check(pz.bake_count > bakes0, "D opening the gate rebuilds only the pit region, in the background (%d bakes)" % pz.bake_count)
	var open_gaps: Array = ring_gaps(game)
	var all_in_gate := true
	for g in open_gaps:
		all_in_gate = all_in_gate and absf(angle_difference(deg_to_rad(float(g)), deg_to_rad(306.0))) < deg_to_rad(10.0)
	check(not open_gaps.is_empty() and all_in_gate, "D the only opening in the ring is the gate (angles %s)" % str(open_gaps))
	await frames(10)
	for pt in [pz.nav_link.start_position, pz.nav_link.end_position]:
		var cp: Vector3 = NavigationServer3D.map_get_closest_point(game.nav_map, pt)
		print("INFO link point ", pt.snapped(Vector3(0.1, 0.1, 0.1)), " closest nav ", cp.snapped(Vector3(0.1, 0.1, 0.1)), " enabled ", pz.nav_link.enabled, " regions ", NavigationServer3D.map_get_regions(game.nav_map).size())
	print("INFO links ", NavigationServer3D.map_get_links(game.nav_map).size(), " radius ", NavigationServer3D.map_get_link_connection_radius(game.nav_map), " margin ", NavigationServer3D.map_get_edge_connection_margin(game.nav_map), " link rid enabled ", NavigationServer3D.link_get_enabled(pz.nav_link.get_rid()))
	var pl := pz.to_world(Vector3(25, 0, -45))
	print("INFO corridor->plateau end ", nav_end(game, pz.to_world(Vector3(0, 0.1, -16)), pl).snapped(Vector3(0.1, 0.1, 0.1)), " target ", pl.snapped(Vector3(0.1, 0.1, 0.1)))
	print("INFO plateau->basin end ", nav_end(game, pl, basin).snapped(Vector3(0.1, 0.1, 0.1)), " target ", basin.snapped(Vector3(0.1, 0.1, 0.1)))
	print("INFO yard->corridor end ", nav_end(game, from, pz.to_world(Vector3(0, 0.1, -16))).snapped(Vector3(0.1, 0.1, 0.1)), " target ", pz.to_world(Vector3(0, 0.1, -16)).snapped(Vector3(0.1, 0.1, 0.1)))
	var e2 := nav_end(game, from, basin)
	check(Vector2(e2.x, e2.z).distance_to(Vector2(basin.x, basin.z)) < 2.5 and e2.y < -2.8, "D staff can path from the yard to the basin floor (%s)" % str(e2.snapped(Vector3(0.1, 0.1, 0.1))))
	var plateau := pz.to_world(Vector3(25, 0, -45))
	var e3 := nav_end(game, from, plateau)
	check(Vector2(e3.x, e3.z).distance_to(Vector2(plateau.x, plateau.z)) < 2.5, "D staff can path onto the plateau")
	# ---- build zones
	check(game.in_build_area(pz.to_world(Vector3(25, 0, -45))) and game.in_build_area(pz.to_world(Vector3(0, -3.6, -80))), "E the plateau and the basin floor are build areas once open")
	check(not game.in_build_area(pz.to_world(Vector3(0, 0, -60))) and not game.in_build_area(pz.to_world(Vector3(0, 0, -15))) and not game.in_build_area(pz.to_world(Vector3(79, 0, -45))), "E the basin rim, the corridor and the wall edges are not")
	check(game.in_build_area(Vector3(0, 0, 10)) and not game.in_build_area(Vector3(0, 0, -10)), "E yard zones behave as before")
	# ---- a loader drives through the gate and down the ramp
	game.business.milestones["mechanized"] = true
	prog.stage = prog.stage_index("large")
	game.state.money = 50000
	game.ui_buy_vehicle("loader")
	game.delivery.finish_all()
	check(game.vehicle_nodes.size() > 0, "F a loader can be bought")
	if game.vehicle_nodes.is_empty():
		quit(1)
		return
	var loader = game.vehicle_nodes.values()[0]
	var yaw: float = pz.global_rotation.y
	loader.global_position = pz.to_world(Vector3(0, 0.1, 8.0))
	loader.rotation.y = yaw
	loader.speed = 0.0
	game.enter_vehicle(loader)
	game.scripted_input = true
	loader.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	await frames(2600, func(): return pz.to_loc(loader.global_position).z < -52.0)
	var lz: float = pz.to_loc(loader.global_position).z
	check(lz < -50.0 and absf(pz.to_loc(loader.global_position).x) < 4.5, "F the loader drives out of the yard, through the gate, along the corridor and onto the plateau (local z %.1f)" % lz)
	loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(40)
	loader.global_position = pz.to_world(Vector3(0, 0.1, pz.basin_zs() + 3.0))
	loader.rotation.y = yaw
	loader.speed = 0.0
	loader.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	await frames(900, func(): return pz.to_loc(loader.global_position).z < pz.basin_zs() - 24.0)
	var ll: Vector3 = pz.to_loc(loader.global_position)
	check(ll.y < -3.0 and ll.z < pz.basin_zs() - 20.0, "F the loader drives down the basin ramp onto the floor (local %s)" % str(ll.snapped(Vector3(0.1, 0.1, 0.1))))
	loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	game.scripted_input = false
	# ---- the yard's own navigation rebuild stays quick
	var t0 := Time.get_ticks_usec()
	game._rebake_nav()
	var yard_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	check(yard_ms < 60.0, "G the yard navigation rebuild takes %.1f ms" % yard_ms)
	# ---- saves: the gate follows the tutorial
	game._save()
	game._load()
	await process_frame
	check(pz.is_open, "H a saved game with the site clean loads with the gate open")
	prog.cleanup["done"] = false
	game._save()
	game._load()
	await process_frame
	check(not pz.is_open and prog.cleanup_active(), "H a saved game with the site not yet clean loads with the gate closed")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
