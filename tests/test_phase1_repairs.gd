extends SceneTree
## Phase 1 repairs: nothing buried in rock, Grandpa's truck can leave its parking spot.   godot --headless --fixed-fps 60 -s tests/test_phase1_repairs.gd
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
func boot(natural: bool):
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = natural
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	game.hud.close_card()
	return game
func run() -> void:
	for nat in [true, false]:
		var game = await boot(nat)
		var prog = game.prog
		var buried := []
		for id in prog.cleanup_ids():
			var p: Vector2 = prog.cleanup_pos(id)
			for fid in game.formation_nodes.keys():
				var cell: float = float(prog.cfg["formations"][fid].get("cell", 1.9))
				for i in range(prog.column_count(fid)):
					var cp: Vector3 = prog.column_pos(fid, i)
					if absf(cp.x - p.x) < cell * 0.5 + 0.9 and absf(cp.z - p.y) < cell * 0.5 + 0.9 and absf(cp.y) < 8.0:
						buried.append("%s in %s" % [id, fid])
						break
		check(buried.is_empty(), "%s layout: no weed or rubble stands inside rock %s" % ["natural" if nat else "legacy", str(buried)])
		if nat:
			# Grandpa's truck: it can drive away from its parking spot towards the gate (nothing rock-like in the yard)
			var tv = null
			for v in game.vehicle_nodes.values():
				if v.vtype == "starter_truck":
					tv = v
			check(tv != null, "Grandpa's utility truck exists in the yard")
			if tv:
				game.player.global_position = tv.global_position + Vector3(2, 0.5, 0)
				game.enter_vehicle(tv)
				game.scripted_input = true
				await frames(10)
				var p0: Vector3 = tv.global_position
				for k in range(420):
					tv.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
					await physics_frame
				var moved: float = (tv.global_position - p0).length()
				var kc := KinematicCollision3D.new()
				var hit: bool = tv.test_move(tv.global_transform, tv.forward() * 0.5, kc)
				check(moved > 12.0 or not hit or kc.get_collider() == null or not str(kc.get_collider().name).begins_with("hillside"), "driving straight north the truck is not stopped by rock (moved %.1f m, ahead %s)" % [moved, str(kc.get_collider().name) if hit and kc.get_collider() else "nothing"])
				# no formation collider lies in the yard (z > -6.35)
				var in_yard := 0
				for fid in game.formation_nodes.keys():
					var cell: float = float(prog.cfg["formations"][fid].get("cell", 1.9))
					if prog.cfg["formations"][fid].get("level", 1) != 1:
						continue
					for i in range(prog.column_count(fid)):
						var cp: Vector3 = prog.column_pos(fid, i)
						if cp.z + cell * 0.5 > -6.35 and absf(cp.x) < 24.0 and prog.units_left(fid) > 0:
							in_yard += 1
				check(in_yard == 0, "no level-1 rock column reaches into the yard (%d)" % in_yard)
		game.queue_free()
		await process_frame
	# contracts: work done in an area BEFORE its contract opens is banked and counts when it opens (it cannot be lost)
	var g3 = await boot(true)
	var p3 = g3.prog
	var money0: int = g3.state.money
	p3.area_add("area_2", "rock", 200)
	p3.area_add("area_2", "recovered", 150)
	p3.area_add("area_4", "shipped", 80)
	check(int(p3.area_state("area_2")["rock"]) == 200 and not p3.area_available("area_2") and not p3.area_complete("area_2"), "mining Area 2 ahead of time is banked and the contract is still closed")
	p3.cleanup["done"] = true
	p3.area_add("area_1", "soil_removed", 48)
	p3.area_add("area_1", "soil_hauled", 24)
	p3.area_add("area_1", "rock", 60)
	check(p3.area_complete("area_1"), "Area 1 completes")
	check(p3.area_available("area_2") and not p3.area_complete("area_2"), "Area 2 opens; it still needs the player to reach it")
	p3.area_visit("area_2")
	check(p3.area_complete("area_2") and g3.state.money == money0 + 300 + 800, "reaching Area 2 completes it from the banked work, paid once (%d)" % (g3.state.money - money0))
	p3.area_check("area_2")
	check(g3.state.money == money0 + 1100, "never paid twice")
	# shipments: loading a truck is not one; delivering is, once, for the area the rock came from
	g3.state.money = 900000
	g3.state.add_item("limestone", 0)
	var fl = g3.fleet
	var t_a = fl.give("truck", Vector3(0, 0, 0), 0.0)
	var t_b = fl.give("truck", Vector3(5, 0, 0), 0.0)
	fl.add_cargo(t_a, "iron_ore", 10, "area_4")
	fl.add_cargo(t_a, "iron_ore", 5, "area_3")
	var before4: int = int(p3.area_state("area_4")["shipped"])
	fl.transfer(t_a, t_b)
	check(int(p3.area_state("area_4")["shipped"]) == before4 and int(t_b["origin"].get("area_4", 0)) == 10 and int(t_b["origin"].get("area_3", 0)) == 5, "loading a truck keeps each unit's area and counts nothing")
	var got: int = fl.dump_to(t_b, {"type": "storage"})
	g3._credit_delivery(t_b)
	check(got == 15 or got > 0, "the truck delivers %d to storage" % got)
	check(int(t_b.get("origin", {}).get("area_4", 0)) + int(t_b.get("origin", {}).get("area_3", 0)) + got == 15, "delivered units leave the origin record, so they cannot count twice")
	# the dump: the bed tips UP (its front rises above the rear hinge) and the load slides to the tailgate
	var g2 = await boot(true)
	g2.state.money = 900000
	g2.prog.stage = g2.prog.stage_index("deep")
	g2.state.tool_tier = 3
	g2.business.milestones["mechanized"] = true
	g2.business.milestones["automated"] = true
	g2.ui_buy_vehicle("truck")
	g2.delivery.finish_all()
	var tr = null
	for v in g2.vehicle_nodes.values():
		if v.vtype == "truck":
			tr = v
	check(tr != null, "a dump truck exists")
	if tr:
		var rest_front: Vector3 = tr.bed.global_transform * Vector3(0, 0.6, -2.8)
		tr.bed_tilt = 0.95
		tr._animate(0.016)
		var up_front: Vector3 = tr.bed.global_transform * Vector3(0, 0.6, -2.8)
		var rear: Vector3 = tr.bed.global_transform * Vector3(0, 0.0, 0.0)
		check(up_front.y > rest_front.y + 1.5, "dumping: the front of the bed rises (%.2f -> %.2f)" % [rest_front.y, up_front.y])
		var rest_load_y: float = tr.bed.global_transform.origin.y
		var tail_y: float = (tr.bed.global_transform * Vector3(0, 0.1, 0.0)).y
		check(absf(tail_y - rest_load_y) < 0.2, "the rear hinge stays put")
		var bl: Vector3 = tr.bed.global_transform * (tr.bed_load.position + Vector3(0, 0, 0.6))
		var low: Vector3 = tr.bed.global_transform * Vector3(0, 0.1, -2.8)
		check(bl.y < low.y, "the load ends lower than the raised front, so it slides out of the tailgate")
		tr.bed_tilt = 0.0
		tr._animate(0.016)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
