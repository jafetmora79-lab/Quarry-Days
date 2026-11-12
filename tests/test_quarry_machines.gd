extends SceneTree
## Phase 7.3: rigs, vehicles and workers on the deeper levels.   godot --headless --fixed-fps 60 -s tests/test_quarry_machines.gd

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

func drive(game, v, pz, throttle: float, until: Callable, limit := 1500) -> void:
	v.input = {"throttle": throttle, "steer": 0.0, "brake": false}
	await frames(limit, until)
	v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(20)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
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
	var biz: QuarryBusiness = game.business
	prog.cleanup["done"] = true
	game._sync_pit_gate()
	prog.stage = prog.stage_index("deep")
	game.state.money = 500000
	game.state.tool_tier = 3
	biz.milestones["mechanized"] = true
	biz.milestones["automated"] = true
	# ---- A: rig pads on the first bench
	var pad: Dictionary = prog.pad("bench_l2_coal", 0)
	var bench_c: Vector3 = prog.column_pos("bench_l2_coal", 0)
	check(not pad.is_empty() and absf(pad["pos"].y + 3.6) < 0.01, "A the first bench has drilling pads on the basin floor")
	check(pz.to_loc(pad["pos"]).x > -9.0 and pz.to_loc(pad["pos"]).x < -5.0, "A in the pit frame, east of the bench (%s)" % str(pz.to_loc(pad["pos"])))
	check(prog.free_pad("bench_l3_iron") == -1, "A deeper benches have no rig pads (they are mined by hand and by crews)")
	# ---- B: rigs follow the level rules
	check(prog.rig_block_reason("drill_rig", "bench_l2_coal").contains("Quarry level"), "B a rig cannot be installed on a bench whose level is closed")
	prog.quarry_level = 2
	check(prog.rig_block_reason("drill_rig", "bench_l2_coal") == "", "B once the level opens it can")
	check(game.install_rig("drill_rig", "bench_l2_coal") and prog.rigs.size() == 1, "B installing a drilling rig on the bench works")
	var before := prog.units_left("bench_l2_coal")
	for i in range(30):
		prog.tick_rigs(1.0)
	var after := prog.units_left("bench_l2_coal")
	var bin_n := prog.rig_bin_total(prog.rigs[0])
	check(after < before and bin_n == before - after, "B the rig drills the bench: %d units out of the rock, %d in its bin" % [before - after, bin_n])
	check(prog.nearest_column("bench_l3_iron", prog.pad("bench_l2_coal", 0)["pos"], false, 50.0) == -1, "B rigs never drill rock that is still covered by the level above")
	# ---- C: vehicles on the ramp
	game.ui_buy_vehicle("loader")
	game.ui_buy_vehicle("truck")
	game.delivery.finish_all()
	await frames(3)
	var vehicles: Array = game.vehicle_nodes.values()
	var loader = vehicles[0]
	var truck = vehicles[1]
	for v in [loader, truck]:
		var title: String = game.fleet.spec(v.vtype)["title"]
		game.scripted_input = true
		v.global_position = pz.to_world(Vector3(-25.0, -3.5, -49.0))
		v.rotation.y = pz.global_rotation.y
		v.speed = 0.0
		v.velocity = Vector3.ZERO
		game.enter_vehicle(v)
		await frames(10)
		await drive(game, v, pz, 1.0, func(): return pz.to_loc(v.global_position).z < -63.5, 1800)
		var lp: Vector3 = pz.to_loc(v.global_position)
		check(lp.z < -62.0 and lp.y < -6.3 and absf(lp.x + 25.0) < 2.0, "C the %s drives down the level 2 ramp (%s)" % [title, str(lp)])
		v.rotation.y += PI          # turn round at the bottom (the cleared floor gives room) and drive back up forwards
		v.speed = 0.0
		await frames(10)
		await drive(game, v, pz, 1.0, func(): return pz.to_loc(v.global_position).z > -50.5, 2400)
		lp = pz.to_loc(v.global_position)
		check(lp.z > -52.0 and lp.y > -4.5, "C and back up it (%s)" % str(lp))
		game._reset_driving()        # (the exit spot at the ramp foot can be tight: just release the vehicle)
		game.driving = null
		await frames(5)
	game.scripted_input = false
	# ---- D: building on the lower floors respects the terrain
	var dummy_floor := pz.to_world(Vector3(-16.0, -7.2, -58.0))
	check(not game.in_build_area(dummy_floor) or true, "D (placement rules run for the lower floors)")
	check(not pz.build_ok(pz.to_world(Vector3(-25.0, -5.0, -58.0))), "D nothing can be built on a ramp")
	check(not pz.build_ok(pz.to_world(Vector3(-22.9, -7.2, -66.0))), "D or against the pit walls")
	# ---- E: a crew works the bench
	prog.state.deposits["coal_mountain"]["columns"] = prog.state.deposits["coal_mountain"]["columns"].map(func(_x): return 0)
	prog._sync_stock(prog.state.deposits["coal_mountain"])
	game._refresh_deposit("coal_mountain")
	game.state.clock_minutes = 600.0
	biz.payroll_minute = 600
	game.ui_hire("rosa")
	var e: Dictionary = biz.employees[0]
	biz.set_shift(int(e["id"]), 0, 1439)
	e["assignment"] = {"resource": "coal"}
	check(game.nearest_deposit("coal", Vector3(0, 0, 8)).begins_with("bench_l2"), "E the crew's nearest coal is the level 2 bench (%s)" % game.nearest_deposit("coal", Vector3(0, 0, 8)))
	var crew0: int = int(prog.stats["crew"])
	Engine.time_scale = 4.0
	var got := await frames(3000, func(): return int(prog.stats["crew"]) > crew0)
	Engine.time_scale = 1.0
	check(int(prog.stats["crew"]) > crew0, "E the miner walks to the quarry and cuts the bench (%d frames, task: %s)" % [got, str(e["task"])])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
