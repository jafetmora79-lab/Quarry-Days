extends SceneTree
## Connected quarry, Phase D: Areas 4-6 (levels 3 and 4 of the same pit). Chain of contracts, membership by floor and position, real truck
## loading counts as shipment, rewards once, stage gates up to the last stage, save/load.   godot --headless --fixed-fps 60 -s tests/test_areas456.gd
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
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	game.safety.enabled = false
	var pz = game.pit_zone
	pz.set_open(true)
	# ---- the chain: each contract waits for the one before it
	check(not prog.area_available("area_4"), "Area 4 is closed at the start")
	prog.cleanup["done"] = true
	for id in ["area_1", "area_2", "area_3"]:
		prog.area_state(id)["complete"] = true
		prog.area_state(id)["rewarded"] = true
	check(prog.area_available("area_4") and not prog.area_available("area_5") and not prog.area_available("area_6"), "after Area 3, only Area 4 opens")
	# ---- membership by floor and position in the pit frame
	var l3: Dictionary = pz.level_pits[1]
	var l4: Dictionary = pz.level_pits[2]
	var r3: Rect2 = l3["rect"]
	var r4: Rect2 = l4["rect"]
	var p4: Vector3 = pz.to_world(Vector3(r3.position.x + 16.0, l3["y_bot"], r3.position.y + 30.0))
	check(game.area_at(p4) == "area_4", "standing on the level-3 floor is Area 4")
	var p5: Vector3 = pz.to_world(Vector3(-26.0, l4["y_bot"], -105.0))
	var p6: Vector3 = pz.to_world(Vector3(-26.0, l4["y_bot"], -125.0))
	check(game.area_at(p5) == "area_5" and game.area_at(p6) == "area_6", "the level-4 floor splits into the copper side (Area 5) and the gold side (Area 6)")
	# ---- Area 4: contract parts, including a real truck loading
	var ex = game.fleet.give("compact_excavator", p4 + Vector3(0, 0.1, 0), 0.0)
	var tk = game.fleet.give("truck", p4 + Vector3(0, 0.1, 6.0), 0.0)
	await frames(10)
	var exn = null
	var tkn = null
	for nd in game.vehicle_nodes.values():
		if nd.vkind == "excavator":
			exn = nd
		if nd.vkind == "truck":
			tkn = nd
	check(exn != null and tkn != null, "an excavator and a truck stand on the level-3 floor")
	if exn != null and tkn != null:
		exn.global_position = p4 + Vector3(0, 0.05, 0)
		exn.rotation.y = 0.0
		tkn.global_position = exn.work_point() + Vector3(0, 0.05, 1.6)
		tkn.rotation.y = 0.0
		await frames(5)
		var rec: Dictionary = game.fleet.vehicle(exn.vehicle_id)
		rec["cargo"] = {}
		game.fleet.add_cargo(rec, "iron_ore", 6, "area_4")           # rock cut in Area 4 remembers where it came from
		var s0 := int(prog.area_state("area_4")["shipped"])
		var moved: int = game.vehicle_dump(exn)
		check(moved > 0 and int(prog.area_state("area_4")["shipped"]) == s0, "loading the bucket into a truck is NOT a shipment (%d loaded)" % moved)
		var trec: Dictionary = game.fleet.vehicle(tkn.vehicle_id)
		check(int(trec.get("origin", {}).get("area_4", 0)) == moved, "the truck's load remembers it came from Area 4")
		# delivered to a destination (the storage crate): only now does it count, once, for Area 4
		var got: int = game.fleet.dump_to(trec, {"type": "storage"})
		game._credit_delivery(trec)
		check(got > 0 and int(prog.area_state("area_4")["shipped"]) == s0 + got, "delivering it to storage counts as shipment (%d)" % got)
		game._credit_delivery(trec)
		check(int(prog.area_state("area_4")["shipped"]) == s0 + got, "and it cannot be counted twice")
		var s_other := int(prog.area_state("area_5")["shipped"])
		check(s_other == 0, "and does not count for Area 5")
	prog.area_add("area_4", "rock", 200)
	prog.area_add("area_4", "recovered", 150)
	prog.area_add("area_4", "visited", 1)
	var m0 := st.money
	prog.area_add("area_4", "shipped", 80)
	prog.area_check("area_4")
	check(prog.area_complete("area_4") and st.money == m0 + 6000, "Area 4 completes and pays $6,000 once (%d)" % (st.money - m0))
	prog.area_check("area_4")
	check(st.money == m0 + 6000, "never twice")
	check(prog.area_available("area_5") and not prog.area_available("area_6"), "Area 5 opens after Area 4")
	for k in ["rock", "recovered", "visited", "shipped"]:
		prog.area_add("area_5", k, 200 if k != "visited" else 1)
	check(prog.area_complete("area_5") and prog.area_available("area_6"), "Area 5 completes (the copper bench) and Area 6 opens")
	check(int(prog.area_progress("area_6")["pct"]) == 0, "the final cut starts at 0%")
	# gold can only be cut by the right machines: the final contract is not free
	check(int(prog.material("gold_ore")["hardness"]) >= 4 or int(prog.material("gold_ore")["hardness"]) > int(prog.material("copper_ore")["hardness"]), "gold is harder than copper: Area 6 needs the stronger machines")
	for k in ["rock", "recovered", "visited", "shipped"]:
		prog.area_add("area_6", k, 200 if k != "visited" else 1)
	check(prog.area_complete("area_6"), "Area 6 completes with its measured work")
	check(prog.units_left("q_l4_gold" if prog.filled_world() else "bench_l4_gold") > 0 and prog.units_left("q_l3_iron" if prog.filled_world() else "bench_l3_iron") > 0, "all that rock stays minable after the contracts")
	# ---- the stages
	var reqs := {}
	for s_ in prog.cfg["stages"]:
		reqs[str(s_["id"])] = s_["req"].get("milestones", [])
	check("area_4_complete" in reqs["mass_production"] and "area_5_complete" in reqs["beneath_mountain"] and "area_6_complete" in reqs["quarry_empire"], "the last three stages need Areas 4, 5 and 6")
	check(prog.milestone_done("area_6_complete"), "the final milestone is reached")
	game._save(true)
	var money_saved := st.money
	game._load(true)
	check(prog.area_complete("area_4") and prog.area_complete("area_5") and prog.area_complete("area_6") and st.money == money_saved, "save and load keep the contracts and pay nothing again")
	for path in [game.SAVE_PATH, game.SAVE_BACKUP]:
		DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
