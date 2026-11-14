extends SceneTree
## Phase 9.5: the terraced open-pit quarry (8.7) together with the twelve-stage progression and tools (9).
##   godot --headless --fixed-fps 60 -s tests/test_integration95.gd

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

func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func zero_formation(game, id: String) -> void:
	var prog: QuarryProgression = game.prog
	prog.init_formation(id)
	var d: Dictionary = prog.state.deposits[id]
	for i in range(d["columns"].size()):
		d["columns"][i] = 0
	prog._sync_stock(d)
	game._refresh_deposit(id)

func fresh_prog(money := 0) -> QuarryProgression:
	var s := QuarryState.new(load_json("res://data/economy.json"))
	s.money = money
	var b := QuarryBusiness.new(s, load_json("res://data/business.json"))
	return QuarryProgression.new(s, b, load_json("res://data/progression.json"))

## A save written by the Phase 8.6 / Phase 9 builds: the old column layout of the six re-laid pit benches, part of it excavated.
func old_layout_deposits(prog: QuarryProgression, mined_fraction: float) -> Dictionary:
	var out := {}
	for id in prog.cfg["legacy_formations"]:
		var lg: Dictionary = prog.cfg["legacy_formations"][id]
		var cols := []
		var per := int(lg["units"]) / int(lg["columns"])
		var to_cut := int(float(lg["units"]) * mined_fraction)
		for i in range(int(lg["columns"])):
			var take := mini(per, to_cut)
			cols.append(per - take)
			to_cut -= take
		out[id] = {"columns": cols, "formation": true, "resource": str(prog.fdef(id)["resource"]), "stock": 0, "mined": int(float(lg["units"]) * mined_fraction)}
	return out

func run() -> void:
	# ---- A: the merged data is one consistent configuration
	var p0 := fresh_prog()
	var cfg: Dictionary = p0.cfg
	var stage_ids := []
	for s in p0.stages():
		stage_ids.append(str(s["id"]))
	var expected := ["grandpa", "better_tools", "workshop", "breaking_ground", "first_employee", "power_pressure", "moving_mountains", "industrial_quarry", "deeper_ground", "mass_production", "beneath_mountain", "quarry_empire"]
	check(stage_ids == expected, "A all twelve stages are there in order")
	var earn_ok := true
	var last := -1
	for s in p0.stages():
		earn_ok = earn_ok and int(s["req"].get("earned", 0)) > last
		last = int(s["req"].get("earned", 0))
	check(earn_ok and int(p0.stages()[11]["req"]["earned"]) == 450000, "A earnings run from $0 to $450,000 without gaps or repeats")
	var refs_ok := true
	var ids: Dictionary = cfg["formations"]
	for lv in cfg["quarry_levels"]:
		for f in lv["formations"]:
			refs_ok = refs_ok and ids.has(f)
	for f in ids:
		for c in ids[f].get("cover", []):
			refs_ok = refs_ok and ids.has(c)
		refs_ok = refs_ok and cfg["materials"].has(str(ids[f]["resource"]))
	refs_ok = refs_ok and ids.has(str(cfg["fossil"]["formation"]))
	for k in cfg["vehicle_gates"]:
		refs_ok = refs_ok and str(cfg["vehicle_gates"][k]) in stage_ids
	for k in cfg["machines"]:
		refs_ok = refs_ok and str(cfg["machines"][k].get("stage_id", "")) in stage_ids
	for k in cfg["unlocks"]:
		refs_ok = refs_ok and str(cfg["unlocks"][k].get("stage", "grandpa")) in stage_ids
	check(refs_ok, "A every formation, cover, material, fossil, machine, vehicle and unlock reference exists")
	check(cfg["legacy_formations"].size() == 6 and cfg["pit_zone"]["plateau_width"] == 160.0 and cfg["quarry_levels"][1]["roads"].size() > 0, "A the open-pit layout, haul roads and migration table are present beside the Phase 9 data")
	check(cfg["materials"]["limestone"]["hp"] == 30 and cfg["gear"].size() == 14, "A Phase 9 rock hit points and the extra tools are present")
	# ---- B: a new game
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
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
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	var pz: QuarryPitZone = game.pit_zone
	prog.cleanup["done"] = true
	game.safety.enabled = false
	check(prog.stage == 0 and prog.quarry_level == 1 and st.tool_tier == 0 and pz != null and pz.level_pits.size() == 3, "B a new game starts at Stage 1, level 1, with the hammer, in the four-level pit")
	var all_whole := true
	for id in ["hillside_face_01", "pit_band_01", "bench_l2_coal", "bench_l2_iron", "bench_l3_iron", "bench_l3_copper", "bench_l4_copper", "bench_l4_gold"]:
		all_whole = all_whole and prog.units_left(id) == prog.max_units(id)
	check(all_whole, "B every formation of the quarry starts whole")
	# the hammer cuts the beginner material
	var hid := "hillside_face_01"
	var col := -1
	for i in range(prog.column_count(hid)):
		if prog.column_minable(hid, i):
			col = i
			break
	var before: int = prog.units_left(hid)
	st.inventory["limestone"] = 0
	var got: int = game.player_mine(hid, col, 90.0)
	check(col >= 0 and got >= 1 and prog.units_left(hid) == before - got and st.inventory["limestone"] == got, "B the starting hammer mines stone from the first face and the units arrive in the bag (%d)" % got)
	check(prog.can_mine("limestone") and prog.can_mine("coal") and not prog.can_mine("iron_ore") and not prog.can_mine("copper_ore") and not prog.can_mine("gold_ore"), "B the hammer breaks stone and coal only")
	# ---- C: levels open in turn; harder rock needs the right tool
	zero_formation(game, hid)
	zero_formation(game, "pit_band_01")
	prog.check_levels()
	check(prog.quarry_level == 2, "C clearing level 1 opens level 2")
	var iron_id := "bench_l2_iron"
	var coal_id := "bench_l2_coal"
	var icol := -1
	for i in range(prog.column_count(iron_id)):
		if prog.column_minable(iron_id, i):
			icol = i
			break
	var ccol := -1
	for i in range(prog.column_count(coal_id)):
		if prog.column_minable(coal_id, i):
			ccol = i
			break
	var i0: int = prog.units_left(iron_id)
	check(icol >= 0 and game.player_mine(iron_id, icol, 500.0) == 0 and prog.units_left(iron_id) == i0, "C the hammer cannot cut iron even with huge damage: nothing is taken")
	st.gear.append("pointed_chisel")
	st.equipped = "pointed_chisel"
	check(game.player_mine(iron_id, icol, 500.0) == 0 and prog.units_left(iron_id) == i0, "C a chisel cannot cut iron either")
	st.equipped = "sledgehammer"
	st.gear.append("sledgehammer")
	check(game.player_mine(iron_id, icol, 500.0) > 0, "C a sledgehammer (hardness 2) cuts iron")
	st.equipped = ""
	st.gear.clear()
	var c0: int = prog.units_left(coal_id)
	check(ccol >= 0 and game.player_mine(coal_id, ccol, 120.0) > 0 and prog.units_left(coal_id) < c0, "C the hammer cuts coal on level 2")
	# copper (level 3) and gold (level 4)
	zero_formation(game, coal_id)
	zero_formation(game, iron_id)
	prog.check_levels()
	check(prog.quarry_level == 3, "C level 3 opens when level 2 is cut")
	var copper_id := "bench_l3_copper"
	var cuc := -1
	for i in range(prog.column_count(copper_id)):
		if prog.column_minable(copper_id, i):
			cuc = i
			break
	st.tool_tier = 2
	var cu0: int = prog.units_left(copper_id)
	check(cuc >= 0 and game.player_mine(copper_id, cuc, 900.0) == 0 and prog.units_left(copper_id) == cu0, "C the reinforced pickaxe cannot cut copper")
	st.gear.append("steel_pickaxe")
	st.equipped = "steel_pickaxe"
	check(game.player_mine(copper_id, cuc, 900.0) > 0, "C a steel pickaxe cuts copper")
	st.equipped = ""
	zero_formation(game, "bench_l3_iron")
	zero_formation(game, copper_id)
	prog.check_levels()
	check(prog.quarry_level == 4, "C level 4 opens when level 3 is cut")
	var gold_id := "bench_l4_gold"
	var gcol := -1
	for i in range(prog.column_count(gold_id)):
		if prog.column_minable(gold_id, i):
			gcol = i
			break
	st.gear.append("hardened_pickaxe")
	st.equipped = "hardened_pickaxe"
	var g0: int = prog.units_left(gold_id)
	check(gcol >= 0 and game.player_mine(gold_id, gcol, 5000.0) == 0 and prog.units_left(gold_id) == g0, "C gold cannot be cut with any hand pick, even the hardened one")
	st.equipped = ""
	st.tool_tier = 4
	check(game.player_mine(gold_id, gcol, 5000.0) > 0, "C the heavy jackhammer cuts gold")
	st.tool_tier = 0
	# an impact tool cannot reach harder rock through its neighbours either
	st.gear = ["sledgehammer"]
	st.equipped = "sledgehammer"
	var g1: int = prog.units_left(gold_id)
	var dummy: int = game.player_mine(gold_id, gcol, 5000.0)
	check(dummy == 0 and prog.units_left(gold_id) == g1, "C the sledgehammer's area blow cannot break gold either")
	st.equipped = ""
	st.gear.clear()
	# ---- D: workers and haul roads
	game.state.money = 100000
	prog.stage = prog.stage_index("first_employee")
	game.business.milestones["first_employee"] = true
	st.tool_tier = 0
	check(game.nearest_deposit("iron_ore", Vector3(0, 0, 8)) == "" or not game.formation_nodes.has(game.nearest_deposit("iron_ore", Vector3(0, 0, 8))), "D staff do not mine iron while the company owns only the hammer")
	st.tool_tier = 1
	check(game.nearest_deposit("iron_ore", Vector3(0, 0, 8)) != "", "D with a pickaxe owned, staff look for iron")
	st.tool_tier = 0
	st.gear = ["steel_pickaxe"]
	check(prog.crew_can_mine("copper_ore") and not prog.can_mine("copper_ore"), "D the company's best tool counts for staff, not the one in hand")
	st.gear.clear()
	# fresh benches for the worker test: re-open them in a new, simple state
	prog.init_formation("bench_l2_coal")
	var wd: Dictionary = prog.state.deposits["bench_l2_coal"]
	for i in range(wd["columns"].size()):
		wd["columns"][i] = prog.column_max("bench_l2_coal", i)
	prog._sync_stock(wd)
	prog.open_roads(2)                              # the opened level's haul road is never rock (cut when the level opened)
	game._refresh_deposit("bench_l2_coal")
	check(game.pit_zone.level_pits.size() == 3 and absf(pz.deepest_y + 14.4) < 0.01, "D the haul roads of all four levels exist (deepest floor %.1f m)" % pz.deepest_y)
	var ex_before: int = prog.units_left("bench_l2_coal")
	var ecol: int = prog.nearest_column("bench_l2_coal", pz.to_world(Vector3(-30, -3.6, -60)), true)
	game.worker_strike("bench_l2_coal", 4, 0, null)
	check(ecol >= 0 and prog.units_left("bench_l2_coal") < ex_before, "D a hired miner's strike takes rock from an exposed column of the level 2 bench")
	# ---- E: permanence through the save file, repeated
	st.money = 777
	var rock_total := 0
	for id in prog.formation_ids():
		if st.deposits.has(id):
			rock_total += prog.units_left(id)
	var snapshot_cols := {}
	for id in prog.formation_ids():
		if st.deposits.has(id):
			snapshot_cols[id] = (st.deposits[id]["columns"] as Array).duplicate()
	game._save(true)
	for round in range(3):
		game._load(true)
		await frames(3)
	var same := true
	for id in snapshot_cols:
		same = same and st.deposits[id]["columns"] == snapshot_cols[id]
	var rock_after := 0
	for id in prog.formation_ids():
		if st.deposits.has(id):
			rock_after += prog.units_left(id)
	print("   E detail: same %s rock %d -> %d money %d level %d" % [str(same), rock_total, rock_after, st.money, prog.quarry_level])
	check(same and rock_after == rock_total and st.money == 777 and prog.quarry_level == 4, "E excavation, money and the four opened levels survive three save/load rounds with nothing duplicated")
	var shape_ok := true
	for id in ["bench_l2_coal", "bench_l3_copper"]:
		var node = game.formation_nodes[id]
		for i in range(prog.column_count(id)):
			shape_ok = shape_ok and (node.shapes[i] as CollisionShape3D).disabled == (prog.column_units(id, i) <= 0)
	check(shape_ok, "E collision follows the saved rock: every emptied column has no collider, every standing one has")
	# ---- F: saves written by the source branches
	var oldp := fresh_prog(500)
	var old_dep := old_layout_deposits(oldp, 0.25)
	var legacy_ids: Array = oldp.cfg["legacy_formations"].keys()
	oldp.state.deposits = old_dep.duplicate(true)
	oldp.state.tool_tier = 2
	oldp.state.earned = 30000
	var snap86 := {"schema": 2, "quarry_level": 2, "stage": 4, "level_unlocked": 1, "rigs": [], "next_rig_id": 1}     # a Phase 8.6 progression block
	oldp.restore(snap86, ["truck", "loader"])
	var mined_ok := true
	var detail := ""
	for id in legacy_ids:
		oldp.ensure_formation(id)
		var f := 1.0 - float(oldp.units_left(id)) / float(oldp.max_units(id))
		var floor_f := 0.25 - 0.02
		var ceil_f := 0.25 + (0.5 if int(oldp.fdef(id)["quarry_level"]) <= 2 else 0.02)       # the opened level also had its haul road cut
		if f < floor_f or f > ceil_f:
			mined_ok = false
			detail += " %s %.3f" % [id, f]
		mined_ok = mined_ok and (oldp.state.deposits[id]["columns"] as Array).size() == oldp.column_count(id)
	check(oldp.legacy_migrated and oldp.stage == oldp.stage_index("large") and oldp.state.tool_tier == 2 and oldp.state.earned == 30000 and oldp.state.money == 500 and oldp.state.gear.is_empty(), "F and its stage, tool, earnings and money; nothing is invented")
	check(oldp.quarry_level == 2 and absf(float(oldp.level_cleared_fraction(2))) < 0.5, "F its opened level is still open")
	var cols_snapshot := {}
	for id in legacy_ids:
		cols_snapshot[id] = (oldp.state.deposits[id]["columns"] as Array).duplicate()
	var again_state := oldp.state.snapshot()
	oldp.state.restore(again_state)                 # a second load of what the first load produced
	oldp.restore(oldp.snapshot(), ["truck", "loader"])
	var again := true
	for id in legacy_ids:
		oldp.ensure_formation(id)
		again = again and oldp.state.deposits[id]["columns"] == cols_snapshot[id]
	check(again, "F saving and loading the migrated state again changes nothing")
	# a Phase 9 save: new stage ladder and gear, but the old pit layout
	var p9 := fresh_prog(1234)
	p9.state.deposits = old_layout_deposits(p9, 0.4).duplicate(true)
	p9.state.gear = ["pointed_chisel", "hand_cart"]
	p9.state.carts = ["hand_cart"]
	p9.state.tool_tier = 1
	p9.state.earned = 700
	var snap9 := {"schema": 3, "quarry_level": 1, "stage": 2, "rigs": []}
	p9.restore(snap9, [])
	for id in p9.cfg["legacy_formations"]:
		p9.ensure_formation(id)
	var f9 := 1.0 - float(p9.units_left("bench_l3_iron")) / float(p9.max_units("bench_l3_iron"))
	check(p9.stage == 2 and not p9.legacy_migrated and absf(f9 - 0.4) < 0.02 and p9.state.gear == ["pointed_chisel", "hand_cart"] and p9.state.money == 1234 and p9.state.tool_tier == 1, "F a Phase 9 save keeps its stage, gear, tool and money, and its excavation moves to the new layout")
	# an 8.7 save: new layout, six-stage numbering
	var p87 := fresh_prog(300)
	for id in p87.formation_ids():
		p87.init_formation(id)
	var mined_cols: Array = p87.state.deposits["bench_l2_iron"]["columns"]
	for i in range(30):
		mined_cols[i] = 0
	p87.state.tool_tier = 2
	var cols87 := (mined_cols as Array).duplicate()
	p87.restore({"schema": 2, "quarry_level": 3, "stage": 5, "level_unlocked": 2, "rigs": []}, ["truck"])
	var kept := true
	var after87: Array = p87.state.deposits["bench_l2_iron"]["columns"]
	for i in range(cols87.size()):
		kept = kept and int(after87[i]) <= int(cols87[i])         # rock already cut stays cut (only the haul road may take more)
	for i in range(30):
		kept = kept and int(after87[i]) == 0
	check(kept and p87.stage == p87.stage_index("deep") and p87.quarry_level == 3 and p87.state.tool_tier == 2, "F an 8.7 save keeps its excavation (nothing comes back), its levels and tool; its stage lands on the matching new stage")
	# ---- G: the previews of every new item are built from real models
	var prev_ok := true
	for id in prog.gear_ids():
		if bool(prog.gear_def(str(id)).get("starter", false)):
			continue                                   # the shovel is owned from the start, never sold
		var offer: Dictionary = PurchaseOffers.gear(game, str(id), func(): pass)
		var pm: Node3D = QuarryPreview.build_model(game, offer["model"])
		var vcount := 0
		for mi in pm.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			if m and m.get_surface_count() > 0:
				vcount += (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		prev_ok = prev_ok and vcount >= 100 and int(offer["price"]) > 0
		pm.free()
	check(prev_ok, "G every extra tool, cart and the compressor opens its own 3D preview")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
