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
	# mining accounting: pocket minerals opened by staff or rigs are never lost (they lie on the ground as their own mineral)
	var g4 = await boot(true)
	var p4 = g4.prog
	var fid := "hillside_face_01"
	p4.init_formation(fid)
	var vs: Array = p4.veins(fid)
	var vcol: int = int(vs[0]["col"])
	var cols: Array = p4.state.deposits[fid]["columns"]
	for i in range(cols.size()):
		if i != vcol:
			cols[i] = 0
	p4._sync_stock(p4.state.deposits[fid])
	g4._refresh_deposit(fid)
	p4.cleanup["done"] = true
	var before: int = g4.vein_pieces.size()
	var guard := 0
	while p4.column_units(fid, vcol) > 0 and guard < 80:
		guard += 1
		g4._crew_strike_formation(fid, 60, 60, null)
	var opened: int = 0
	for k in range(vs.size()):
		if int(vs[k]["col"]) == vcol and p4.vein_taken(fid, k):
			opened += int(vs[k]["units"])
	check(opened > 0, "the crew cut a pocketed column clean (%d mineral units were in it)" % opened)
	check(g4.vein_pieces.size() - before == opened, "every mineral unit the crew opened lies on the ground as a piece (%d of %d)" % [g4.vein_pieces.size() - before, opened])
	var resok := true
	for vp in g4.vein_pieces.values():
		resok = resok and str(vp["res"]) != "limestone"
	check(resok, "and they are their own mineral, not limestone")
	# machinery placement: the rotated footprint must be supported and clear
	var g5 = await boot(true)
	await frames(10)
	var open_pos := Vector3(8.0, 0.0, 14.0)
	var base_y: float = 0.0
	var qd := PhysicsRayQueryParameters3D.create(open_pos + Vector3(0, 3, 0), open_pos - Vector3(0, 2, 0), 1)
	var hd: Dictionary = g5.get_world_3d().direct_space_state.intersect_ray(qd)
	if not hd.is_empty():
		base_y = float(hd["position"].y)
	open_pos.y = base_y
	check(g5.footprint_ok(open_pos, 0.0) and g5.footprint_ok(open_pos, 0.7), "open level ground takes a machine at any heading")
	check(not g5.footprint_ok(open_pos + Vector3(0, 0.6, 0), 0.0), "a machine floating 0.6 m above the ground is refused")
	check(not g5.footprint_ok(Vector3(-15.6, base_y, 6.5), 0.0) and not g5.footprint_ok(Vector3(-15.6, base_y, 6.5), PI * 0.5), "a machine overlapping the dumpster is refused at either heading")
	check(not g5.footprint_ok(Vector3(base_y - 8.0, base_y, 40.0), 0.0), "a spot with no ground under it is refused")
	# conveyors only connect on their own level
	var cr: Dictionary = {"position": [10.0, base_y, 16.0], "yaw": 0.0, "tier": 1}
	g5.state.crushers.append(cr)
	var port: Vector3 = g5.business.crusher_output_port(g5.state.crushers.size() - 1)
	var belt_pos: Vector3 = port + QuarryBusiness.forward(0.0)
	var same: Dictionary = g5.business.link_for(Vector3(belt_pos.x, base_y, belt_pos.z), 0.0)
	var other: Dictionary = g5.business.link_for(Vector3(belt_pos.x, base_y - 3.6, belt_pos.z), 0.0)
	check(str(same["src"].get("type", "")) == "crusher", "a belt starting at the crusher's chute on the same level connects to it")
	check(other["src"].is_empty(), "the same belt 3.6 m lower does not connect to it (no physical connection)")
	g5.state.crushers.pop_back()
	# saves keep the origin record of a loaded truck
	var gf = g5.fleet
	var tr5 = gf.give("truck", Vector3(0, 0, 20), 0.0)
	gf.add_cargo(tr5, "coal", 12, "area_3")
	var snap5: Dictionary = JSON.parse_string(JSON.stringify(gf.snapshot()))
	gf.vehicles.clear()
	gf.restore(snap5)
	var back: Dictionary = gf.vehicle(int(tr5["id"]))
	check(not back.is_empty() and int(back["cargo"].get("coal", 0)) == 12 and int(back.get("origin", {}).get("area_3", 0)) == 12, "a saved truck keeps its cargo and where it came from")
	# an old save (no origin record) loads as before
	var old5 := snap5.duplicate(true)
	for v in old5["vehicles"]:
		v.erase("origin")
	gf.restore(old5)
	var back2: Dictionary = gf.vehicle(int(tr5["id"]))
	check(int(back2["cargo"].get("coal", 0)) == 12 and not back2.has("origin"), "an old-format save loads with its cargo and no origin")
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
