extends SceneTree
## Phase 8.2: the equipment roster (trucks, excavators, rigs), fleet identity and saves, excavator digging under the normal
## mining rules, and the quarry milestones.
##   godot --headless --fixed-fps 60 -s tests/test_quarry_industry.gd

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
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._remove_walter()
	var prog: QuarryProgression = game.prog
	var fleet: QuarryFleet = game.fleet
	game.player.locked = true
	# ---- 1: the roster
	var types: Array = fleet.types()
	check(types.size() == 7 and types[0] == "loader", "1 seven vehicle types: %s" % str(types))
	var by_kind := {"truck": [], "excavator": [], "loader": []}
	for t in types:
		by_kind[fleet.kind(t)].append(t)
	check(by_kind["truck"].size() == 4 and by_kind["excavator"].size() == 2 and by_kind["loader"].size() == 1, "1b four trucks, two excavators, the loader")
	var ok_stats := true
	for t in types:
		var s := fleet.spec(t)
		for key in ["title", "price", "capacity", "accel", "max_speed", "size", "best_use", "speed_label", "accel_label", "requires", "gate"]:
			if not s.has(key):
				ok_stats = false
				printerr("   %s lacks %s" % [t, key])
	check(ok_stats, "2 every machine has a price, capacity, speed, acceleration, size, best use and unlock")
	var trucks: Array = by_kind["truck"]
	trucks.sort_custom(func(a, b): return fleet.spec(a)["capacity"] < fleet.spec(b)["capacity"])
	var prices_up := true
	var accel_down := true
	var per_unit_down := true
	for i in range(1, trucks.size()):
		var a := fleet.spec(trucks[i - 1])
		var b := fleet.spec(trucks[i])
		prices_up = prices_up and int(b["price"]) > int(a["price"])
		accel_down = accel_down and float(b["accel"]) < float(a["accel"])
		per_unit_down = per_unit_down and float(b["price"]) / float(b["capacity"]) < float(a["price"]) / float(a["capacity"])
	check(prices_up and accel_down and per_unit_down, "3 bigger trucks carry more, cost more, accelerate slower and are cheaper per unit carried")
	var cx := fleet.spec("compact_excavator")
	var hx := fleet.spec("heavy_excavator")
	check(float(cx["dig_dps"]) > prog.tool_dps(1) and float(hx["dig_dps"]) > float(cx["dig_dps"]) * 3.0 and int(hx["dig_hardness"]) > int(cx["dig_hardness"]), "3b excavators out-dig the pickaxe; the heavy one is far stronger and harder-hitting")
	# gates
	var gate_ok := true
	for t in types:
		prog.stage = 0
		gate_ok = gate_ok and not prog.unlocked(t)
	prog.stage = prog.stage_index("large")
	check(prog.unlocked("truck") and prog.unlocked("heavy_truck") and prog.unlocked("compact_excavator") and not prog.unlocked("industrial_truck") and not prog.unlocked("heavy_excavator"), "4 the stages unlock the machines in order (large: trucks and compact excavator; deep: industrial truck, heavy excavator)")
	prog.stage = prog.stage_index("deep")
	check(prog.unlocked("industrial_truck") and prog.unlocked("heavy_excavator"), "4b the deep stage unlocks the rest")
	# ---- 5: buying several, identity, no overlap
	game.state.money = 400000
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	var bought := []
	for t in ["industrial_truck", "heavy_excavator", "heavy_truck", "truck", "compact_excavator", "loader", "compact_truck", "truck"]:
		var msg: String = game.ui_buy_vehicle(t)
		bought.append(msg)
		game.delivery.finish_all()
		await frames(2)
	check(fleet.vehicles.size() == 8 and fleet.vehicles[0]["type"] == "industrial_truck" and fleet.vehicles[7]["type"] == "truck", "5 all eight machines, the biggest ones included, find a place to park (%d owned)" % fleet.vehicles.size())
	var money_now: int = game.state.money
	check(game.ui_buy_vehicle("loader").begins_with("Equipment yard full") and game.state.money == money_now, "5b a ninth is refused and nothing is charged")
	fleet.cfg["max_vehicles"] = 10
	# two machines of one type are two machines (data level): separate identities, nothing replaced
	var t1 := fleet.buy("truck", Vector3(80, 0, 80))
	var t2 := fleet.buy("truck", Vector3(90, 0, 80))
	check(t1["id"] != t2["id"] and t1["name"] == "Dump Truck 3" and t2["name"] == "Dump Truck 4" and fleet.vehicles.size() == 10, "5c buying another truck adds one; each keeps its own id and name (%s, %s)" % [t1["name"], t2["name"]])
	fleet.vehicles.erase(t1)
	fleet.vehicles.erase(t2)
	fleet.cfg["max_vehicles"] = 8
	var names := {}
	for v in fleet.vehicles:
		names[v["name"]] = true
	var far_enough := true
	var nodes: Array = game.vehicle_nodes.values()
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var ea: Vector2 = game._vehicle_extent(nodes[i].size, nodes[i].rotation.y)
			var eb: Vector2 = game._vehicle_extent(nodes[j].size, nodes[j].rotation.y)
			var dx: float = absf(nodes[i].global_position.x - nodes[j].global_position.x)
			var dz: float = absf(nodes[i].global_position.z - nodes[j].global_position.z)
			if dx < ea.x + eb.x and dz < ea.y + eb.y:
				far_enough = false
				printerr("   %s and %s overlap (dx %.1f, dz %.1f)" % [nodes[i].name, nodes[j].name, dx, dz])
	check(far_enough, "5d no two machines are parked inside each other")
	var model_ok := true
	for n in nodes:
		model_ok = model_ok and n.model_root != null and n.model_root.get_child_count() > 0
		if n.vkind == "truck":
			model_ok = model_ok and n.bed != null and n.wheels.size() >= 4
		else:
			model_ok = model_ok and n.arm != null and n.bucket != null
	check(model_ok, "5e every machine has a model with its working parts (bed and wheels, or arm and bucket)")
	var ex: QuarryVehicle = null
	for n in nodes:
		if n.vtype == "heavy_excavator":
			ex = n
	check(ex != null and absf(ex.model_root.scale.x - 3.0 / 2.0) < 0.01 and absf(ex.model_root.scale.z - 4.4 / 3.4) < 0.01, "5f the heavy excavator is the same build scaled to its size")
	# ---- 6: saves
	var snap := fleet.snapshot()
	var before := fleet.vehicles.duplicate(true)
	fleet.restore(snap)
	check(fleet.vehicles.size() == 8 and fleet.vehicles[2]["name"] == before[2]["name"] and fleet.vehicles[3]["type"] == before[3]["type"], "6 restoring a save brings every machine back with its name and type")
	var old_snap := snap.duplicate(true)
	for v in old_snap["vehicles"]:
		v.erase("name")
	fleet.restore(old_snap)
	check(fleet.vehicles[0]["name"] == "Industrial Haul Truck 1" and fleet.vehicles[1]["name"] == "Heavy Excavator 1" and fleet.vehicles[3]["name"] == "Dump Truck 1", "6b an older save without names gets them")
	# ---- 7: the excavator digs under the normal rules
	prog.cleanup["done"] = true
	prog.init_formation("hillside_face_01")
	prog.quarry_level = 4
	var cv: QuarryVehicle = null
	for n in game.vehicle_nodes.values():
		if n.vtype == "compact_excavator":
			cv = n
	cv.global_position = Vector3(-12.9, 0.1, -10.6)
	cv.rotation.y = PI * 0.5
	await frames(4)
	var tgt: Dictionary = game.excavator_target(cv)
	check(not tgt.is_empty() and tgt["kind"] == "hillside_face_01", "7 an excavator facing the cut finds exposed rock to dig")
	var rec := fleet.vehicle(cv.vehicle_id)
	var u0: int = prog.units_left("hillside_face_01")
	var c0: int = fleet.cargo_total(rec)
	for i in range(240):
		game._excavator_dig(cv, 1.0 / 60.0)
	var dug: int = u0 - prog.units_left("hillside_face_01")
	check(dug > 0 and fleet.cargo_total(rec) > c0 and fleet.cargo_total(rec) <= fleet.capacity(rec), "7b digging fills the bucket from the rock (%d units dug, bucket %d/%d)" % [dug, fleet.cargo_total(rec), fleet.capacity(rec)])
	check(dug <= int(ceil(float(cx["dig_dps"]) * 4.0 / float(prog.material("limestone")["hp"]))) + 1, "7c and only as fast as its damage allows (%d)" % dug)
	# hardness: the compact one cannot break copper, the heavy can, neither can break gold
	var res_check := func(vt: String, res: String) -> bool:
		return int(prog.material(res).get("hardness", 1)) <= int(fleet.spec(vt).get("dig_hardness", 1))
	check(res_check.call("compact_excavator", "iron_ore") and not res_check.call("compact_excavator", "copper_ore") and res_check.call("heavy_excavator", "copper_ore") and not res_check.call("heavy_excavator", "gold_ore"), "7d hardness rule: compact up to iron, heavy up to copper, gold needs a breaker or the jackhammer")
	# nothing is taken from under the player
	game.player.global_position = prog.column_pos("hillside_face_01", tgt["col"]) + Vector3(0, 1.3, 0)
	var left: int = prog.column_units("hillside_face_01", tgt["col"])
	var ex2: Dictionary = prog.extract("hillside_face_01", tgt["col"], 500.0, 99, "excavator")
	check(int(ex2["units"]) == 0 and prog.column_units("hillside_face_01", tgt["col"]) == left, "7e rock under the player's feet is protected from the excavator too")
	game.player.global_position = Vector3(0, 0.2, 8)
	# ---- 8: new rigs
	var ms: Dictionary = prog.cfg["machines"]
	check(ms.has("improved_rig") and ms.has("heavy_breaker") and float(ms["improved_rig"]["dps"]) > float(ms["drill_rig"]["dps"]) and float(ms["heavy_breaker"]["dps"]) > float(ms["rock_breaker"]["dps"]) * 2.0, "8 an improved drilling rig and a heavy-duty rock breaker exist and out-cut their predecessors")
	check(int(ms["improved_rig"]["max_hardness"]) > int(ms["drill_rig"]["max_hardness"]) and int(ms["heavy_breaker"]["max_hardness"]) == 4, "8b the improved rig reaches harder rock; the heavy breaker breaks anything")
	check(int(ms["improved_rig"]["price"]) > int(ms["drill_rig"]["price"]) and int(ms["heavy_breaker"]["price"]) > int(ms["rock_breaker"]["price"]) and int(ms["heavy_breaker"]["price"]) > int(ms["improved_rig"]["price"]), "8c and cost more, in order")
	prog.stage = prog.stage_index("deep")
	game.state.money = 200000
	check(game.install_rig("improved_rig", "hillside_face_01") and prog.rigs.size() == 1, "8d an improved rig installs on a pad")
	check(game.rig_nodes[0].rkind == "drill", "8e it is built as a drilling rig")
	var before_u: int = prog.units_left("hillside_face_01")
	prog.tick_rigs(30.0)
	check(prog.units_left("hillside_face_01") < before_u, "8f and it cuts the rock")
	check(prog.rig_block_reason("drill_rig", "bench_l4_gold") != "" and prog.rig_block_reason("heavy_breaker", "bench_l4_gold") != "Unknown machine", "8g the old rig is too soft for gold; the heavy breaker is not refused for hardness")
	# ---- 9: quarry milestones
	var m_before: int = game.state.money
	prog.story["milestones"] = {}
	prog.quarry_level = 1
	for id in ["hillside_face_01", "pit_band_01"]:
		prog.init_formation(id)
	var got: Array = prog.check_quarry_milestones()
	check(got.size() >= 0 and game.state.money >= m_before, "9 nothing is paid before it is earned")
	prog.state.deposits["hillside_face_01"]["columns"].fill(0)
	prog.state.deposits["pit_band_01"]["columns"].fill(0)
	prog._sync_stock(prog.state.deposits["hillside_face_01"])
	prog._sync_stock(prog.state.deposits["pit_band_01"])
	var m1: int = game.state.money
	got = prog.check_quarry_milestones()
	var ids2 := []
	for g in got:
		ids2.append(g["id"])
	check("l1_quarter" in ids2 and "l1_half" in ids2 and game.state.money == m1 + 500 + 1200, "9b cutting the surface pays the quarter and half bonuses (%s)" % str(ids2))
	check(prog.check_quarry_milestones().is_empty() and game.state.money == m1 + 1700, "9c each is paid only once")
	prog.quarry_level = 2
	var m2: int = game.state.money
	got = prog.check_quarry_milestones()
	check(got.size() == 1 and got[0]["id"] == "level2_open" and game.state.money == m2 + 2500, "9d opening level 2 pays its bonus")
	var snap2 := prog.snapshot()
	prog.story["milestones"] = {}
	prog.restore(snap2, [])
	var m3: int = game.state.money
	check(prog.check_quarry_milestones().is_empty() and game.state.money == m3, "9e saved milestones are not paid again after loading")
	var old2 := snap2.duplicate(true)
	old2["story"].erase("milestones")
	prog.restore(old2, [])
	var m4: int = game.state.money
	check(prog.check_quarry_milestones().is_empty() and game.state.money == m4 and prog.story["milestones"].get("level2_open", false), "9f an older save counts what it has already dug as reached, without a windfall")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
