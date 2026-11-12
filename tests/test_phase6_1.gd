extends SceneTree
## Phase 6.1 tests: the excavatable hillside (data, exposure, cut-stone blocks, mining, workers, persistence,
## old saves, regression). Headless, accelerated; no visual checks.
##   godot --headless --fixed-fps 60 -s tests/test_phase6_1.gd

const HID := "hillside_face_01"
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

func aim_at(game, pos: Vector3, look: Vector3) -> void:
	game.player.global_position = pos
	var d := look - (pos + Vector3(0, 1.58, 0))
	game.player.rotation.y = atan2(-d.x, -d.z)
	game.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	game.player.camera.rotation.x = game.player.pitch

## Columns as comparable text (JSON turns ints into floats).
func ints(a) -> String:
	var out := []
	for v in a:
		out.append(int(v))
	return str(out)

func run() -> void:
	test_data_and_mesh()
	await scene()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func front_cols(prog: QuarryProgression) -> Array:
	var out := []
	for i in range(prog.column_count(HID)):
		if prog.column_exposed(HID, i):
			out.append(i)
	return out

# ------------------------------------------------------------------ data, exposure rules, block mesh

func test_data_and_mesh() -> void:
	var pcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	var state := QuarryState.new(cfg)
	var prog := QuarryProgression.new(state, QuarryBusiness.new(state, JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))), pcfg)
	check(prog.is_formation(HID) and prog.dims(HID) == Vector2i(6, 12) and prog.column_count(HID) == 72, "A the hillside is a new formation: 6 deep x 12 wide = 72 columns")
	var f: Dictionary = prog.fdef(HID)
	check(float(f["cell"]) >= 1.8 and float(f["cell"]) <= 2.0 and absf(float(f["tier_h"]) - 1.2) < 0.01, "A cell about 2 m, tier 1.2 m")
	var tmax := 0
	var tmin := 99
	for i in range(72):
		tmax = maxi(tmax, prog.column_tiers(HID, i))
		tmin = maxi(1, mini(tmin, prog.column_tiers(HID, i)))
	check(tmax == 4 and tmin >= 1, "A the hill is 1-4 tiers high (profile steps down toward the open face)")
	# old formations keep their ids, dimensions and column counts (saves store columns by count)
	check(prog.dims("stone_mountain") == Vector2i(4, 3) and prog.dims("coal_mountain") == Vector2i(4, 2) and prog.dims("iron_mountain") == Vector2i(3, 3), "E the three original formations keep their grid dimensions")
	check(pcfg["starting_formations"] == ["stone_mountain", "coal_mountain", "iron_mountain"], "E stage progress still counts only the original formations")
	prog.init_formation(HID)
	var exposed := front_cols(prog)
	var all_front := true
	for i in exposed:
		all_front = all_front and (i % 6) == 5
	check(exposed.size() == 12 and all_front, "B only the 12 front-face columns are exposed at the start (%d)" % exposed.size())
	check(not prog.column_exposed(HID, 0) and not prog.column_exposed(HID, 6 * 11 + 0) and not prog.column_minable(HID, 6 * 5 + 2), "B back wall, side walls and buried columns are not minable")
	check(prog.nearest_column(HID, Vector3(-10, 0, -10), true) % 6 == 5, "B workers are only offered face columns")
	var dir := prog.column_open_dir(HID, 6 * 4 + 5, Vector3(-10, 0, -10))
	check(dir == Vector3(1, 0, 0), "C workers stand on the open (east) side of a face column")
	# cutting a face column exposes the one behind it, permanently
	var col := 6 * 4 + 5
	state.deposits[HID]["columns"][col] = 0
	check(prog.column_exposed(HID, 6 * 4 + 4) and not prog.column_exposed(HID, 6 * 4 + 3), "B emptying a face column exposes only the next one behind it")
	var dir2 := prog.column_open_dir(HID, 6 * 4 + 4, Vector3(-18, 0, -10))
	check(dir2 == Vector3(1, 0, 0), "C a worker stands in the cut, facing the newly exposed rock")
	# cut-stone block geometry: closed, outward, capped
	var ok_closed := true
	var ok_out := true
	for seed in [900, 917, 934, 951, 968]:
		var s := MeshKit.Soup.new()
		MeshKit.cut_block_into(s, Vector3.ZERO, Vector3(1.94, 1.21, 1.94), seed)
		var edges := {}
		var vol := 0.0
		for i in range(0, s.verts.size(), 3):
			var a := s.verts[i]
			var b := s.verts[i + 1]
			var c := s.verts[i + 2]
			vol += a.dot(b.cross(c)) / 6.0
			for e in [[a, b], [b, c], [c, a]]:
				var ka := "%d,%d,%d" % [roundi(e[0].x * 1000.0), roundi(e[0].y * 1000.0), roundi(e[0].z * 1000.0)]
				var kb := "%d,%d,%d" % [roundi(e[1].x * 1000.0), roundi(e[1].y * 1000.0), roundi(e[1].z * 1000.0)]
				var k := (ka + "|" + kb) if ka < kb else (kb + "|" + ka)
				edges[k] = int(edges.get(k, 0)) + 1
		for k in edges:
			if edges[k] != 2:
				ok_closed = false
		if vol > -2.5:
			ok_out = false
		if seed == 900:
			check(s.verts.size() == 96, "F a cut block is 32 triangles (lightweight)")
	check(ok_closed and ok_out, "F cut-stone blocks are closed solids with outward faces")

# ------------------------------------------------------------------ in the game

func scene() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	game.hud.close_card()
	game.tutorial_visible = false
	var st: QuarryState = game.state
	var prog: QuarryProgression = game.prog
	prog.cleanup["done"] = true # Phase 6.2: these tests are about cutting, so the site is already clean
	var node: QuarryFormation = game.formation_nodes.get(HID)
	check(node != null and node.cut and game.deposit_nodes.has(HID), "A new game builds the hillside as a cut-stone formation")
	var total_chunks := 0
	for i in range(prog.column_count(HID)):
		total_chunks += prog.column_tiers(HID, i)
	var visible_chunks := 0
	for stack in node.chunks:
		for mi in stack:
			if mi.visible:
				visible_chunks += 1
	check(visible_chunks == total_chunks, "A every chunk of the hill is standing at the start (%d)" % total_chunks)
	check(game.formation_nodes.has("stone_mountain") and game.deposit_nodes.has("limestone_face"), "A the tutorial rocks (original piles and the hand-mining face) are still there")
	check(game.hillside_retired.size() >= 3, "H the rim pieces in the hill's footprint were retired (%d)" % game.hillside_retired.size())
	# the hill is solid: boxes per column, standing height matches the chunks
	var solid_ok := true
	for i in range(prog.column_count(HID)):
		var cs: CollisionShape3D = node.shapes[i]
		var h := float(prog.column_tiers(HID, i)) * 1.2
		solid_ok = solid_ok and not cs.disabled and absf((cs.shape as BoxShape3D).size.y - h) < 0.01
	check(solid_ok, "B every standing column has a collider as tall as its chunks")
	# ---- mining from the front with the starting tool
	st.tool_tier = 0
	var face_col := 6 * 5 + 5
	var fp := prog.column_pos(HID, face_col)
	aim_at(game, Vector3(fp.x + 2.2, 0.05, fp.z), Vector3(fp.x, 1.0, fp.z))
	for i in range(3):
		await physics_frame
	var ray: Dictionary = game._mining_ray()
	check(not ray.is_empty() and ray["node"] == node and int(ray["column"]) == face_col, "A the crosshair resolves the face column in front of the player (col %s)" % str(ray.get("column", -1)))
	var units0 := prog.units_left(HID)
	var inv0: int = st.inventory["limestone"]
	for i in range(3):
		game._on_swing_impact()
	check(prog.units_left(HID) < units0 and int(st.inventory["limestone"]) - inv0 == units0 - prog.units_left(HID), "A the starting hammer cuts stone and every unit lands in the bag exactly once")
	# hidden sections cannot be mined through the wall
	var buried := 6 * 5 + 1
	var u_buried := prog.column_units(HID, buried)
	var got: int = game.player_mine(HID, buried, 500.0, prog.column_pos(HID, buried))
	check(prog.column_units(HID, buried) == u_buried, "B a buried column is not cut, even when targeted directly (got %d)" % got)
	# cut the face column away: collision follows, the next section is exposed
	st.tool_tier = 2
	st.upgrades["larger_backpack"] = true
	st.upgrades["hauling_harness"] = true
	var guard := 0
	while prog.column_units(HID, face_col) > 0 and guard < 80:
		for k in st.inventory:
			st.inventory[k] = 0
		game.player_mine(HID, face_col, 200.0, fp)
		guard += 1
	await frames(40) # the crumble animation takes ~0.45 s
	check(prog.column_units(HID, face_col) == 0 and (node.shapes[face_col] as CollisionShape3D).disabled, "B the face column is gone and its collider with it")
	check(prog.column_exposed(HID, face_col - 1) and prog.column_minable(HID, face_col - 1), "B the section behind it is now exposed")
	var hid_behind := 0
	for mi in node.chunks[face_col]:
		if mi.visible:
			hid_behind += 1
	check(hid_behind == 0, "B no chunk of the cut column is left standing")
	# the player can now mine the next section through the cut
	aim_at(game, Vector3(fp.x + 0.3, 0.05, fp.z), Vector3(fp.x - 1.9, 1.0, fp.z)) # standing in the cut
	for i in range(3):
		await physics_frame
	var ray2: Dictionary = game._mining_ray()
	check(not ray2.is_empty() and ray2["node"] == node and int(ray2["column"]) == face_col - 1, "B the next section behind the cut is what the crosshair now meets (col %s)" % str(ray2.get("column", -1)))
	# ---- navigation rebuilds while excavating
	var rebakes0: int = game.nav_rebakes
	var emptied := 0
	for r in [3, 4, 6, 7]:
		var c: int = 6 * r + 5
		fp = prog.column_pos(HID, c)
		var g2 := 0
		while prog.column_units(HID, c) > 0 and g2 < 80:
			for k in st.inventory:
				st.inventory[k] = 0
			game.player_mine(HID, c, 200.0, fp)
			g2 += 1
		emptied += 1
		await physics_frame
		await physics_frame
	var rebakes: int = game.nav_rebakes - rebakes0
	check(rebakes <= emptied + 1, "J navigation rebuilt %d times for %d emptied columns (at most one per column)" % [rebakes, emptied])
	# ---- persistence
	for k in st.inventory:
		st.inventory[k] = 0
	var cols_before: Array = (st.deposits[HID]["columns"] as Array).duplicate()
	var mined_cols := 0
	for v in cols_before:
		if int(v) == 0:
			mined_cols += 1
	check(mined_cols >= 5, "D several hillside sections have been cut (%d)" % mined_cols)
	var total_before := st.total(st.inventory)
	game._save()
	# damage the live state, then load: exactly the saved cut comes back
	for i in range(72):
		st.deposits[HID]["columns"][i] = prog.column_max(HID, i)
	game._load()
	await process_frame
	await physics_frame
	check(ints(st.deposits[HID]["columns"]) == ints(cols_before), "D loading restores exactly which sections were removed")
	var shown_ok := true
	for i in range(72):
		var want := prog.chunks_left(HID, i)
		var seen := 0
		for mi in node.chunks[i]:
			if mi.visible:
				seen += 1
		shown_ok = shown_ok and seen == want and (node.shapes[i] as CollisionShape3D).disabled == (want <= 0)
	node = game.formation_nodes[HID]
	await frames(40) # crumbling chunks finish their animation
	shown_ok = true
	for i in range(72):
		var want2 := prog.chunks_left(HID, i)
		var seen2 := 0
		for mi in node.chunks[i]:
			if mi.visible:
				seen2 += 1
		shown_ok = shown_ok and seen2 == want2 and (node.shapes[i] as CollisionShape3D).disabled == (want2 <= 0)
	var wrong := []
	for i in range(72):
		var seen3 := 0
		for mi in node.chunks[i]:
			if mi.visible:
				seen3 += 1
		if seen3 != prog.chunks_left(HID, i) or (node.shapes[i] as CollisionShape3D).disabled != (prog.chunks_left(HID, i) <= 0):
			wrong.append([i, seen3, prog.chunks_left(HID, i)])
	check(shown_ok, "D after loading, the meshes and colliders show the same cut %s" % str(wrong.slice(0, 4)))
	var money_after: int = st.money
	var inv_after: int = st.total(st.inventory)
	game._load()
	await process_frame
	check(st.money == money_after and st.total(st.inventory) == inv_after and ints(st.deposits[HID]["columns"]) == ints(cols_before), "D loading twice duplicates nothing")
	# advancing time never refills the hill
	st.clock_minutes += 3 * 1440.0
	st.regrow_deposits()
	for i in range(30):
		await physics_frame
	check(ints(st.deposits[HID]["columns"]) == ints(cols_before) and not bool(st.deposits[HID].get("infinite", false)) and float(st.deposits[HID]["regrow_at"]) < 0.0, "D three days later the cut is still there (no regrowth)")
	# ---- E old save: strip the hillside from the file, load, everything else intact
	var f := FileAccess.open("user://quarry_save.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data["deposits"].erase(HID)
	st.money = 777
	data["money"] = 777
	data["tool_tier"] = 2
	data["deposits"]["stone_mountain"]["columns"][0] = 3
	var stone_cols_saved: Array = (data["deposits"]["stone_mountain"]["columns"] as Array).duplicate()
	f = FileAccess.open("user://quarry_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game._load()
	await process_frame
	await physics_frame
	var full := true
	for i in range(72):
		full = full and int(st.deposits[HID]["columns"][i]) == prog.column_max(HID, i)
	check(full, "E a pre-Phase-6 save gets a full hillside, nothing else changes")
	var stone_now := ints(st.deposits["stone_mountain"]["columns"])
	check(st.money == 777 and st.tool_tier == 2 and stone_now == ints(stone_cols_saved), "E old saves keep money, tool and the old formations' depletion exactly")
	check(game.formation_nodes[HID].shown.size() == 72 and int(game.formation_nodes[HID].shown[0]) == prog.chunks_left(HID, 0), "E the hillside nodes match the fresh state")
	# ---- C workers on the hillside
	game.hud.close_card()
	prog.stage = prog.stage_index("large")
	st.money = 50000
	st.clock_minutes = 480.0
	game.business.payroll_minute = 480
	for i in range(prog.column_count("stone_mountain")):
		st.deposits["stone_mountain"]["columns"][i] = 0
	prog._sync_stock(st.deposits["stone_mountain"])
	game._sync_formations()
	for i in range(72):
		st.deposits[HID]["columns"][i] = prog.column_max(HID, i)
	prog._sync_stock(st.deposits[HID])
	game.formation_nodes[HID].refresh(true)
	game._rebake_nav()
	game.ui_hire("rosa")
	var miner: Dictionary = game.business.employees[0]
	game.business.set_shift(int(miner["id"]), 0, 1439)
	var w = game.worker_nodes[int(miner["id"])]
	var d0: int = prog.units_left(HID)
	var crew0: int = int(prog.stats["crew"])
	var bad := {"unexposed": 0, "inside": 0, "empty": 0, "deps": {}, "cols": {}}
	var rb0: int = game.nav_rebakes
	Engine.time_scale = 4.0
	await frames(9000, func():
		if w.anim == "work" and w.mine_col >= 0:
			bad["deps"][w.mine_dep] = true
			bad["cols"][w.mine_col] = true
			if prog.column_units(w.mine_dep, w.mine_col) <= 0:
				if bad.get("last_empty", -1) == w.mine_col:
					bad["empty"] += 1 # still swinging at it a frame after it emptied
				bad["last_empty"] = w.mine_col
			else:
				bad["last_empty"] = -1
				if not prog.column_exposed(w.mine_dep, w.mine_col):
					bad["unexposed"] += 1
		# never inside solid rock: the worker stays out of every standing hillside column's footprint
		if w.mine_dep == HID:
			for i in range(prog.column_count(HID)):
				if prog.column_units(HID, i) > 0:
					var p := prog.column_pos(HID, i)
					if absf(w.global_position.x - p.x) < 0.9 and absf(w.global_position.z - p.z) < 0.9 and w.global_position.y < 1.0:
						bad["inside"] += 1
		return int(game.state.storage["limestone"]) >= 6 and bad["cols"].size() >= 2)
	Engine.time_scale = 1.0
	check(bad["deps"].has(HID) and not bad["deps"].has("stone_mountain"), "C the miner chose the hillside when it was the nearest rock (%s)" % str(bad["deps"].keys()))
	check(int(prog.stats["crew"]) > crew0 and prog.units_left(HID) < d0 and int(game.state.storage["limestone"]) >= 6, "C the miner extracted real stone and delivered it (%d units)" % (d0 - prog.units_left(HID)))
	check(bad["empty"] == 0 and bad["unexposed"] == 0, "C the miner only swings at exposed, standing rock (empty %d, unexposed %d)" % [bad["empty"], bad["unexposed"]])
	check(bad["inside"] == 0, "C the miner never walks through the hill")
	check(bad["cols"].size() >= 2, "C the miner moved on to another section after one emptied (%d columns worked)" % bad["cols"].size())
	print("INFO rebakes during crew mining: ", game.nav_rebakes - rb0)
	# ---- a drilling rig can work the hillside from its pad, on exposed rock only
	st.money = 50000
	var why: String = prog.rig_block_reason("drill_rig", HID)
	check(why == "", "C a drilling rig can be installed on the hillside (%s)" % why)
	if why == "":
		var rig: Dictionary = prog.buy_rig("drill_rig", HID)
		var tcol: int = prog.rig_target(rig)
		check(tcol >= 0 and prog.column_exposed(HID, tcol), "C the rig targets an exposed face column (%d)" % tcol)
		var before: int = prog.units_left(HID)
		for i in range(40):
			prog.tick_rigs(0.5)
		check(prog.units_left(HID) < before, "C the rig extracts hillside stone into its bin (%d units)" % (before - prog.units_left(HID)))
	# ---- F regression: manual mining of an original formation and selling still work
	st.tool_tier = 0
	for k in st.inventory:
		st.inventory[k] = 0
	st.deposits["coal_mountain"]["columns"][0] = prog.column_max("coal_mountain", 0)
	prog._sync_stock(st.deposits["coal_mountain"])
	var got2: int = game.player_mine("iron_mountain", -1, 100.0)
	check(got2 == 0 and game.message.contains("Too hard"), "F the original hardness gate still works")
	var u2: int = prog.units_left("stone_mountain")
	st.deposits["stone_mountain"]["columns"][1] = 60
	prog._sync_stock(st.deposits["stone_mountain"])
	game.formation_nodes["stone_mountain"].refresh(true)
	var mined2: int = game.player_mine("stone_mountain", 1, 40.0)
	check(mined2 > 0 and int(st.inventory["limestone"]) == mined2, "F manual mining of the original stone pile still pays out")
	var m0: int = st.money
	game.sell_from_bag(["limestone"])
	check(st.money > m0 and int(st.inventory["limestone"]) == 0, "F selling still works")
	game.queue_free()
	await process_frame
