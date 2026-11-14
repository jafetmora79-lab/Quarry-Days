extends SceneTree
## Layout B of the auto crew: routing round the soil field.  (Layout A, open ground, is test_auto_crew.)
## Original description: Automatic excavator + truck loop on the real soil field: the excavator digs, swings and loads the truck; the truck drives to the spoil
## heap, backs up, tips and returns. Nothing is created or lost; running costs are charged; the flag survives a save.
##   godot --headless --fixed-fps 60 -s tests/test_auto_crew.gd
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
func total_soil(game) -> int:
	var n: int = game.soil.total() + game.state.soil_dumped
	for rec in game.fleet.vehicles:
		n += int(rec["cargo"].get("soil", 0))
	return n
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	game.safety.enabled = false
	var prog: QuarryProgression = game.prog
	prog.excavator_state().merge({"battery": true, "hose": true, "fuel": true, "started": true}, true)
	game._ensure_opening()
	var soil: QuarrySoil = game.soil
	var rec_ex: Dictionary = game.fleet.give("compact_excavator", Vector3(0, 0.2, 0), 0.0)
	game._sync_vehicles(true)
	await frames(4)
	var truck: QuarryVehicle
	for v in game.vehicle_nodes.values():
		if v.vtype == "starter_truck":
			truck = v
	var ex: QuarryVehicle = game.vehicle_nodes.get(int(rec_ex["id"]))
	check(ex != null and ex.vkind == "excavator" and truck != null, "setup: a bought-type excavator and a truck exist")
	check(game.crew.eligible(ex) == "" and game.crew.eligible(truck) == "", "both can run an auto crew")
	var starter = game._starter_vehicle()
	check(game.crew.eligible(starter) != "", "Grandpa's hand excavator cannot")
	# park the excavator in front of soil, the truck beside it
	# layout B: the excavator stands against the SOUTH edge of the field and the truck beside it, the spoil heap lies across the field to the north-east:
	# the straight nav route runs into standing soil, so the truck must be routed round it
	var cx0 := 0.0
	var n0 := 0
	for i in range(soil.units.size()):
		if int(soil.active[i]) == 1:
			cx0 += soil.cell_center(i).x
			n0 += 1
	cx0 /= float(maxi(1, n0))
	var target_cell := -1
	var best_z := -1e9
	for i in range(soil.units.size()):
		if int(soil.active[i]) == 1 and absf(soil.cell_center(i).x - cx0) < 3.0 and soil.cell_center(i).z > best_z:
			best_z = soil.cell_center(i).z
			target_cell = i
	var cc: Vector3 = soil.cell_center(target_cell)
	ex.global_position = Vector3(cc.x, 0.3, cc.z + 4.2)
	ex.rotation.y = 0.0
	ex.velocity = Vector3.ZERO
	for off in [Vector3(-4.5, 0, 6.0), Vector3(4.5, 0, 6.0), Vector3(-4.5, 0, 9.0), Vector3(4.5, 0, 9.0), Vector3(0, 0, 10.0)]:
		truck.global_position = Vector3(cc.x + off.x, 0.3, cc.z + off.z)
		truck.rotation.y = 0.0
		truck.velocity = Vector3.ZERO
		await frames(25)
		if truck.global_position.y < 0.4:
			break
	print("truck placed at ", truck.global_position, " excavator at ", ex.global_position, " soil south edge cell ", cc)
	await frames(5)
	# the planner itself: the route to the spoil heap never crosses standing soil
	var dest: Vector3 = game.spoil_node.global_position
	var route: PackedVector3Array = game.crew.soil_route(truck.global_position, dest)
	check(route.size() >= 2, "the planner finds a way round the field (%d waypoints)" % route.size())
	var hits := 0
	for k in range(route.size() - 1):
		for j in range(21):
			var pnt: Vector3 = route[k].lerp(route[k + 1], float(j) / 20.0)
			var ci: int = soil.cell_at(Vector3(pnt.x, 0, pnt.z))
			if ci >= 0 and soil.height(ci) >= 0.3:
				hits += 1
	check(hits == 0, "and that route never runs through standing soil (%d samples inside)" % hits)
	var straight := PackedVector3Array([truck.global_position, dest])
	check(game.crew._path_hits_soil(straight), "(the straight line to the heap does run through the field, so the detour matters)")
	var all0: int = total_soil(game)
	var money0: float = game.state.money
	game.state.money = 500
	money0 = 500
	var home := truck.global_position
	game.crew.toggle(ex)
	game.crew.toggle(truck)
	var rec_t: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	check(bool(rec_ex["auto"]) and bool(rec_t["auto"]), "toggle: both records are on auto crew")
	# run the loop
	var saw := {}
	var max_truck_cargo := 0
	var dumped0: int = game.state.soil_dumped
	var cons_ok := true
	var peak_vib := 0.0
	for f in range(60 * 240):
		await physics_frame
		saw["e_" + game.crew.phase_of(ex)] = true
		saw["t_" + game.crew.phase_of(truck)] = true
		max_truck_cargo = maxi(max_truck_cargo, game.fleet.cargo_total(rec_t))
		if f % 240 == 0 and f < 6000 and game.crew.phase_of(truck) != "wait":
			var rr: Dictionary = game.crew.rt[truck.vehicle_id]
			print("T f=%d %s pos=%s yaw=%.2f spd=%.2f goal=%s dest=%s path=%d pi=%d fails=%d" % [f, rr["phase"], str(truck.global_position.snapped(Vector3(0.1,0.1,0.1))), truck.rotation.y, truck.speed, str(rr.get("goal")), str(rr.get("dest", {}).get("pos")), (rr["path"] as PackedVector3Array).size(), rr["pi"], rr["fails"]])
		if f == 1000:
			var sp := truck.get_world_3d().direct_space_state
			for off in [Vector3(0, 0.6, 0), Vector3(0, 1.4, 0)]:
				var q := PhysicsRayQueryParameters3D.create(truck.global_position + off, truck.global_position + off + truck.forward() * 4.0)
				q.exclude = [truck.get_rid()]
				var h := sp.intersect_ray(q)
				print("RAY ", off, " -> ", h.get("collider"), " ", h.get("collider").get_meta("kind", "?") if h.has("collider") else "", " at ", h.get("position"))
		if f % 300 == 0:
			print("f=%d e=%s/%s t=%s/%s cargo e=%d t=%d soil_dumped=%d" % [f, game.crew.phase_of(ex), game.crew.status_of(ex), game.crew.phase_of(truck), game.crew.status_of(truck), game.fleet.cargo_total(rec_ex), game.fleet.cargo_total(rec_t), game.state.soil_dumped])
		if f % 30 == 0 and total_soil(game) != all0:
			cons_ok = false
		if game.state.soil_dumped > dumped0 + 0 and str(game.crew.phase_of(truck)) == "wait" and f > 600:
			break
	print("phases seen: ", saw.keys())
	print("truck max cargo %d, dumped %d, money %s, truck at %s home %s, status e=%s t=%s" % [max_truck_cargo, game.state.soil_dumped - dumped0, str(game.state.money), str(truck.global_position), str(home), game.crew.status_of(ex), game.crew.status_of(truck)])
	var sp2 := truck.get_world_3d().direct_space_state
	var to_home: Vector3 = (home - truck.global_position) * Vector3(1, 0, 1)
	for hh in [0.25, 0.7, 1.3]:
		var q2 := PhysicsRayQueryParameters3D.create(truck.global_position + Vector3(0, hh, 0), truck.global_position + Vector3(0, hh, 0) + to_home.normalized() * 6.0)
		q2.exclude = [truck.get_rid()]
		var h2 := sp2.intersect_ray(q2)
		print("HOMERAY h=", hh, " -> ", h2.get("collider"), " kind=", h2.get("collider").get_meta("kind", "?") if h2.has("collider") else "", " name=", h2.get("collider").name if h2.has("collider") else "", " at ", h2.get("position"), " truck=", truck.global_position, " home=", home)
	check(saw.has("e_dig") and saw.has("e_turn_dump") and saw.has("e_dump"), "the excavator went through dig, swing and dump")
	check(max_truck_cargo >= 3, "soil dug by the excavator ended up in the truck bed (%d)" % max_truck_cargo)
	check(cons_ok and total_soil(game) == all0, "soil is conserved through the whole loop (%d)" % all0)
	check(saw.has("t_go_dest") and saw.has("t_reverse") and saw.has("t_tip"), "the truck drove out, backed up and tipped")
	check(game.state.soil_dumped > dumped0, "the truck delivered soil to the spoil heap (%d)" % (game.state.soil_dumped - dumped0))
	check(game.state.money < money0 and money0 - game.state.money < 100, "running costs were charged, once per bucket / trip ($%d)" % int(money0 - game.state.money))
	check(game.crew.phase_of(truck) == "wait" and truck.global_position.distance_to(home) < 4.0, "the truck came back to its loading spot")
	# saving keeps the flag
	var snap: Dictionary = game.fleet.snapshot()
	var f2 := QuarryFleet.new(game.business, game.fleet.cfg)
	f2.restore(snap)
	print("SAVE ids ", snap["vehicles"].map(func(x): return [x["id"], x["type"], x.get("auto")]), " restored ", f2.vehicles.map(func(x): return [x["id"], x["type"], x.get("auto")]))
	check(bool(f2.vehicle(ex.vehicle_id).get("auto", false)), "the auto crew flag survives a save")
	# switching off stops the machine
	game.crew.toggle(ex)
	game.crew.toggle(truck)
	await frames(30)
	check(not ex.digging and not truck.auto_drive and absf(truck.speed) < 0.05, "switched off: no digging, truck parked")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
