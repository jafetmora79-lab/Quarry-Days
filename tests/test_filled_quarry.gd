extends SceneTree
## The filled quarry: flat layered start, centred nested levels, layered geology with rising hardness, permanent physical excavation,
## roads cut on level open, navigation, old-save migration.   godot --headless --fixed-fps 60 -s tests/test_filled_quarry.gd
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
func ground_y(game, lx: float, lz: float) -> float:
	var w: Vector3 = game.pit_zone.to_world(Vector3(lx, 8.0, lz))
	var q := PhysicsRayQueryParameters3D.create(w, w + Vector3(0, -40.0, 0), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else -99.0
func boot():
	for path in ["user://quarry_save.json", "user://quarry_save.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	game.hud.close_card()
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(15)
	game.hud.close_card()
	game._remove_walter()
	game.prog.cleanup["done"] = true
	game._sync_pit_gate()
	game.safety.enabled = false
	return game
func clear_formation(game, id: String, pattern := 0) -> void:
	var prog: QuarryProgression = game.prog
	prog.init_formation(id)
	var d: Dictionary = prog.state.deposits[id]
	var dim: Vector2i = prog.dims(id)
	for i in range(d["columns"].size()):
		if pattern == 0 or (pattern == 1 and ((i % dim.x) + (i / dim.x)) % 2 == 0):
			d["columns"][i] = 0
	prog._sync_stock(d)
	game._refresh_deposit(id)
func run() -> void:
	var game = await boot()
	var prog: QuarryProgression = game.prog
	var pz: QuarryPitZone = game.pit_zone
	# ---- A: flat, filled start
	check(prog.filled_world() and prog.levels().size() == 4, "a new game is the filled quarry with four levels")
	var surface := 0
	var other := 0
	var void_pts := 0
	var lattice := 0
	var gx := -70.0
	while gx < 70.0:
		var gz := -166.0
		while gz < -50.0:
			lattice += 1
			var y := ground_y(game, gx, gz)
			var in_lane := gx > -54.0 and gx < 14.0 and gz > -82.0 and gz < -66.0
			var in_ramp := absf(gx) < 6.0 and gz > -70.0
			if absf(y) < 0.3:
				surface += 1
			elif not (in_lane or in_ramp):
				other += 1
			if y < -20.0:
				void_pts += 1
			gz += 4.0
		gx += 4.0
	check(lattice > 900 and void_pts == 0, "no holes anywhere in the basin (%d samples, %d with no ground)" % [lattice, void_pts])
	check(other == 0 and surface > lattice * 0.8, "the quarry starts as one flat surface level with the plateau (%d of %d samples at y 0, %d elsewhere)" % [surface, lattice, other])
	check(ground_y(game, -48.0, -120.0) > -0.3 and ground_y(game, 40.0, -120.0) > -0.3 and ground_y(game, -24.0, -115.0) > -0.3, "the level 2, 3 and 4 strips are buried: nothing is pre-dug")
	# ---- B: centred nested levels with terraces
	var rects := []
	for lp in pz.level_pits:
		rects.append(lp["rect"])
	var basin := Rect2(-72.0, -168.0, 144.0, 120.0)
	var nested := true
	var centred := true
	var prev: Rect2 = basin
	var margins := []
	for k in range(rects.size()):
		var r: Rect2 = rects[k]
		var cx := r.position.x + r.size.x * 0.5
		centred = centred and absf(cx) <= 6.0
		var inner: Rect2 = prev if k == 0 else (pz.level_pits[k - 1]["cols"] as Rect2)
		var m := minf(minf(r.position.x - inner.position.x, inner.end.x - r.end.x), minf(r.position.y - inner.position.y, inner.end.y - r.end.y))
		margins.append(m)
		nested = nested and m >= 7.9 and r.size.x < prev.size.x and r.size.y < prev.size.y
		prev = r
	check(nested and centred, "levels 2, 3 and 4 are centred, each smaller than the last, with terraces of at least 8 m (margins %s)" % str(margins))
	# ---- C: layered geology, hardness rises with depth
	var order := ["topsoil", "gravel", "limestone", "coal", "iron_ore", "copper_ore", "gold_ore"]
	var hs := []
	for r in order:
		hs.append(int(prog.material(r).get("hardness", 1)))
	var rising := true
	for i in range(1, hs.size()):
		rising = rising and hs[i] >= hs[i - 1]
	check(rising and hs[0] == 0 and hs[hs.size() - 1] >= 4, "hardness rises with depth: %s" % str(hs))
	var col := 0
	var found := false
	for i in range(prog.column_count("q_l1_top")):
		var l: Vector3 = pz.to_loc(prog.column_pos("q_l1_top", i))
		if prog.column_units("q_l1_top", i) > 0 and absf(l.x + 20.0) < 2.5 and absf(l.z + 110.0) < 2.5:
			col = i
			found = true
			break
	check(found, "a column of the surface layer stands at the middle of the level-2 rock")
	var p: Vector3 = prog.column_pos("q_l1_top", col)
	var cg: int = prog.cell_index_at("q_l1_gravel", p)
	var cr: int = prog.cell_index_at("q_l1_rock", p)
	var c2: int = prog.cell_index_at("q_l2_coal", p)
	if c2 < 0:
		c2 = prog.cell_index_at("q_l2_iron", p)
	check(not prog.column_covered("q_l1_top", col) and prog.column_covered("q_l1_gravel", cg) and prog.column_covered("q_l1_rock", cr), "the layers are stacked: gravel is under the topsoil, the limestone under both")
	check(prog.extraction_block("q_l1_gravel", cg) != "" and prog.extraction_block("q_l1_top", col) == "", "only the top layer can be cut first")
	# ---- D: the pit is made by digging: terrain, collision, quantities all change, and it is permanent
	var y0 := ground_y(game, pz.to_loc(p).x, pz.to_loc(p).z)
	var units0: int = prog.units_left("q_l1_top")
	var ex := prog.extract("q_l1_top", col, 1.0e6, 1 << 30, "hand")
	game._refresh_deposit("q_l1_top")
	await frames(4)
	var y1 := ground_y(game, pz.to_loc(p).x, pz.to_loc(p).z)
	check(int(ex["units"]) > 0 and y1 < y0 - 1.0 and prog.units_left("q_l1_top") == units0 - int(ex["units"]), "cutting the topsoil lowers the ground by one layer (%.2f -> %.2f) and the stock by what was cut" % [y0, y1])
	check(prog.extraction_block("q_l1_gravel", cg) == "" and prog.column_covered("q_l1_rock", cr), "the gravel under it is now open, the limestone is still covered")
	var decor_ok := true
	var top_node = game.formation_nodes["q_l1_top"]
	for dc in top_node.decor:
		decor_ok = decor_ok and ((dc[0] as MeshInstance3D).visible == (prog.chunks_left("q_l1_top", int(dc[1])) > 0))
	check(top_node.decor.size() > 100 and decor_ok, "scrub, weeds and stones stand on the topsoil and go with it (%d placed)" % top_node.decor.size())
	prog.extract("q_l1_gravel", cg, 1.0e6, 1 << 30, "hand")
	prog.extract("q_l1_rock", cr, 1.0e6, 1 << 30, "hand")
	game._refresh_deposit("q_l1_gravel")
	game._refresh_deposit("q_l1_rock")
	await frames(4)
	check(absf(ground_y(game, pz.to_loc(p).x, pz.to_loc(p).z) + 3.6) < 0.3 and not prog.column_covered("q_l2_coal", c2) if c2 >= 0 else true, "dug right down, the floor of level 1 (y -3.6) is bared and the level-2 rock below is uncovered")
	game._save(true)
	var snap := (prog.state.deposits["q_l1_top"]["columns"] as Array).duplicate()
	game._load(true)
	await frames(6)
	check((prog.state.deposits["q_l1_top"]["columns"] as Array) == snap and absf(ground_y(game, pz.to_loc(p).x, pz.to_loc(p).z) + 3.6) < 0.3, "the excavation is permanent: it survives a save and load, collision included")
	# ---- E: navigation over the surface and into the cut
	game._rebake_nav()
	await frames(30)
	var np: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, pz.to_world(Vector3(0, 0, -36)), pz.to_world(Vector3(30, 0, -100)), true)
	check(np.size() > 3 and Vector2(np[np.size() - 1].x - pz.to_world(Vector3(30, 0, -100)).x, np[np.size() - 1].z - pz.to_world(Vector3(30, 0, -100)).z).length() < 2.5, "workers can path across the quarry surface (%d points)" % np.size())
	# ---- F: opening level 2: the survey cuts its road, deeper levels stay buried
	for id in ["q_l1_top", "q_l1_gravel", "q_l1_rock"]:
		clear_formation(game, id)
	prog.check_levels()
	await frames(8)
	check(prog.quarry_level == 2, "digging the surface level out opens level 2")
	var yr := ground_y(game, -48.0, -148.0)
	var yb := ground_y(game, 40.0, -120.0)
	check(absf(yr + 7.2) < 0.4 and yb > -3.9, "level 2's road is open to its floor (y %.2f, want -7.2); level 3's strip is still under the level-2 rock (y %.2f)" % [yr, yb])
	# ---- G: an old save (the pre-dug pit) is migrated, not reset
	var g2 = await boot()
	var pr2: QuarryProgression = g2.prog
	var money_before: int = g2.state.money
	var inv_before := str(g2.state.inventory)
	pr2.story["quarry_world"] = ""
	pr2.quarry_level = 3
	pr2.init_formation("bench_l2_coal")
	var oc: Dictionary = pr2.state.deposits["bench_l2_coal"]
	var half := pr2.max_units("bench_l2_coal") / 2
	var cut := 0
	for i in range(oc["columns"].size()):
		if cut < half:
			cut += int(oc["columns"][i])
			oc["columns"][i] = 0
	pr2._sync_stock(oc)
	pr2.migrate_filled_world()
	var l1_left: int = pr2.units_left("q_l1_top")
	var new_cut: int = pr2.max_units("q_l2_coal") - pr2.units_left("q_l2_coal")
	check(str(pr2.story["quarry_world"]) == "filled" and l1_left < pr2.max_units("q_l1_top") and new_cut > 0, "an old save is migrated: the surface over its opened levels is cleared and level 2's cut share carries over (%d units)" % new_cut)
	check(g2.state.money == money_before and str(g2.state.inventory) == inv_before, "migration pays nothing and adds nothing to the inventory")
	var again: int = pr2.units_left("q_l1_top")
	pr2.migrate_filled_world()
	check(pr2.units_left("q_l1_top") == again, "and it runs only once")
	check(pr2.quarry_level == 3, "the old save keeps its quarry level")
	# ---- H: a hired miner digs the overburden of the filled quarry (navigation over the surface, the stacked layers, the new materials)
	var g3 = await boot()
	var pr3: QuarryProgression = g3.prog
	g3.state.money = 90000
	pr3.stage = pr3.stage_index("first_employee")
	g3.state.clock_minutes = 600.0
	g3.business.payroll_minute = 600
	g3.ui_hire("rosa")
	var miner: Dictionary = g3.business.employees[0]
	check(g3.ui_assign(int(miner["id"]), {"resource": "topsoil"}) == "Assignment updated", "a miner can be assigned to dig topsoil")
	g3.business.set_shift(int(miner["id"]), 0, 1439)
	var top0: int = pr3.units_left("q_l1_top")
	var got := 0
	for k in range(5400):
		await physics_frame
		if pr3.units_left("q_l1_top") < top0 - 5:
			got = k
			break
	check(got > 0, "the miner walked out over the surface and dug topsoil (%d units gone after %d frames)" % [top0 - pr3.units_left("q_l1_top"), got])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
