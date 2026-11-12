extends SceneTree
## Phase 6.3b tests: the curved bench (arc layout), MultiMesh chunks, exposed-only navigation sources, staff and saves.
##   godot --headless --fixed-fps 60 -s tests/test_phase6_3b.gd

const BID := "pit_band_01"
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

func ints(a) -> String:
	var out := []
	for v in a:
		out.append(int(v))
	return str(out)

func aim_at(game, pos: Vector3, look: Vector3) -> void:
	game.player.global_position = pos
	var d := look - (pos + Vector3(0, 1.58, 0))
	game.player.rotation.y = atan2(-d.x, -d.z)
	game.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	game.player.camera.rotation.x = game.player.pitch

func nav_end(game, from: Vector3, to: Vector3) -> Vector3:
	var p: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, from, to, true)
	return p[p.size() - 1] if p.size() > 0 else Vector3(1e6, 1e6, 1e6)

func exposed_count(prog: QuarryProgression, all_pit := false) -> int:
	var n := 0
	for id in prog.formation_ids():          # the basin bench, or (all_pit) every formation of the pit zone incl. the level 2-4 benches
		if str(prog.fdef(id).get("frame", "")) != "pit" or (not all_pit and id != BID):
			continue
		for i in range(prog.column_count(id)):
			if prog.column_exposed(id, i) and prog.column_units(id, i) > 0:
				n += 1
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for i in range(5):
		await physics_frame
	game.hud.close_card()
	game.tutorial_visible = false
	var st: QuarryState = game.state
	var prog: QuarryProgression = game.prog
	var pz: QuarryPitZone = game.pit_zone
	prog.cleanup["done"] = true
	game._spawn_cleanup()
	# ---- A layout maths
	var f: Dictionary = prog.fdef(BID)
	check(prog.is_arc(BID) and prog.dims(BID) == Vector2i(16, 6) and prog.column_count(BID) == 96, "A the bench is an arc formation: 16 slices x 6 rings = 96 columns")
	var center: Vector3 = prog.formation_origin_world(BID)
	check(center.distance_to(pz.to_world(Vector3(0, -3.6, -75))) < 0.01, "A its frame is the pit zone's: the centre is the basin centre")
	var ring_ok := true
	var spacing_ok := true
	for i in range(96):
		var x := i % 16
		var y := i / 16
		var l: Vector3 = pz.to_loc(prog.column_pos(BID, i)) - Vector3(0, -3.6, -75)
		var r := Vector2(l.x, l.z).length()
		ring_ok = ring_ok and absf(r - (6.0 + (float(y) + 0.5) * 1.9)) < 0.01
		if x > 0:
			var d := prog.column_pos(BID, i).distance_to(prog.column_pos(BID, i - 1))
			var want := prog.column_size(BID, i).y
			spacing_ok = spacing_ok and absf(d - 2.0 * (r * sin(prog.arc_step(BID) * 0.5))) < 0.02 and absf(want - r * prog.arc_step(BID)) < 0.001
	check(ring_ok, "A every column sits on its ring (radius 6 + 1.9 per ring)")
	check(spacing_ok, "A neighbouring slices are one slice width apart and the box width matches")
	# ---- B exposure
	prog.init_formation(BID)
	var exp0 := exposed_count(prog)
	var only_inner := true
	for i in range(96):
		if prog.column_exposed(BID, i) and i / 16 != 0:
			only_inner = false
	check(exp0 == 16 and only_inner, "B only the inner ring (the working face) is exposed at the start (%d)" % exp0)
	check(prog.column_open_dir(BID, 8, Vector3.ZERO).dot((center - prog.column_pos(BID, 8)).normalized()) > 0.95, "B workers stand on the inner side of a face column")
	check(not prog.column_minable(BID, 16 * 3 + 8), "B a buried column cannot be mined")
	# ---- C the node and its draw cost
	var node = game.formation_nodes.get(BID)
	check(node is QuarryArcFormation and pz.formations.has(node), "C the bench is built as a curved formation of the pit zone")
	var mm_nodes: Array = node.find_children("*", "MultiMeshInstance3D", false, false)
	var total := 0
	for m in mm_nodes:
		total += (m as MultiMeshInstance3D).multimesh.instance_count
	var mesh_nodes: Array = node.find_children("*", "MeshInstance3D", false, false)
	check(mm_nodes.size() == 5 and total == 96 * 3 and mesh_nodes.size() <= 3, "C 288 chunks are drawn by 5 MultiMeshes (%d instances, %d other mesh nodes)" % [total, mesh_nodes.size()])
	var stand := true
	for i in range(96):
		stand = stand and node.standing_count(i) == 3 and not (node.shapes[i] as CollisionShape3D).disabled
	check(stand, "C every chunk is standing and every column has a collider")
	var tang_ok := true
	for i in range(96):
		var bx: BoxShape3D = node.shapes[i].shape
		var sz := prog.column_size(BID, i)
		tang_ok = tang_ok and absf(bx.size.x - sz.x) < 0.01 and absf(bx.size.z - sz.y) < 0.01 and absf(bx.size.y - 3.6) < 0.01
	check(tang_ok, "C colliders are as wide as their slice and as tall as their chunks")
	# ---- D mining at the face
	st.tool_tier = 0
	var col := 8
	var cp: Vector3 = prog.column_pos(BID, col)
	var inward: Vector3 = (center - cp)
	inward.y = 0.0
	inward = inward.normalized()
	var stand_pos: Vector3 = cp + inward * 2.4
	stand_pos.y = -3.55
	aim_at(game, stand_pos, cp + Vector3(0, 1.0, 0))
	for i in range(4):
		await physics_frame
	var ray: Dictionary = game._mining_ray()
	check(not ray.is_empty() and ray["node"] == node and int(ray["column"]) == col, "D the crosshair resolves the face column (%s)" % str(ray.get("column", -1)))
	var u0: int = prog.units_left(BID)
	var inv0: int = st.inventory["limestone"]
	for i in range(3):
		game._on_swing_impact()
	check(prog.units_left(BID) < u0 and int(st.inventory["limestone"]) - inv0 == u0 - prog.units_left(BID), "D the hammer cuts the face and each unit lands in the bag once")
	var buried_before: int = prog.column_units(BID, 16 * 3 + 8)
	var got: int = game.player_mine(BID, 16 * 3 + 8, 500.0, prog.column_pos(BID, 16 * 3 + 8))
	check(prog.column_units(BID, 16 * 3 + 8) == buried_before, "D a buried column is not cut even when targeted (%d)" % got)
	# cut the whole face column
	st.tool_tier = 2
	st.upgrades["larger_backpack"] = true
	st.upgrades["hauling_harness"] = true
	var guard := 0
	while prog.column_units(BID, col) > 0 and guard < 80:
		for k in st.inventory:
			st.inventory[k] = 0
		game.player_mine(BID, col, 200.0, cp)
		guard += 1
	await frames(40)
	check(node.standing_count(col) == 0 and (node.shapes[col] as CollisionShape3D).disabled, "D the cut column's chunks are gone and its collider is off")
	var ref: Vector2i = node.chunks[col][0]
	var others_ok := true
	for i in range(96):
		if i != col and prog.column_units(BID, i) == prog.column_max(BID, i) - (prog.column_max(BID, i) - prog.column_units(BID, i)):
			others_ok = others_ok and node.standing_count(i) == prog.chunks_left(BID, i)
	check(node.standing_count(col) == 0 and node.standing_count(col + 1) == 3 and others_ok, "D only the cut column's instances were hidden; every other column still shows its chunks")
	check(prog.column_exposed(BID, 16 + col) and prog.column_minable(BID, 16 + col) and prog.column_cut_exposed(BID, 16 + col), "D the ring behind the cut is now exposed and freshly cut")
	check(node.fresh_col[16 + col] == true, "D freshly cut stone is tinted brighter")
	# ---- E navigation: only exposed columns are sources; rebuilds are background and rate limited
	await frames(400, func(): return not pz.is_baking())
	var bakes0: int = pz.bake_count
	for r in [3, 4, 5, 6]:
		var c2: int = r
		var p2: Vector3 = prog.column_pos(BID, c2)
		var g2 := 0
		while prog.column_units(BID, c2) > 0 and g2 < 80:
			for k in st.inventory:
				st.inventory[k] = 0
			game.player_mine(BID, c2, 200.0, p2)
			g2 += 1
		await frames(70)
	await frames(400, func(): return not pz.is_baking())
	var new_bakes: int = pz.bake_count - bakes0
	check(new_bakes >= 1 and new_bakes <= 5, "E cutting 4 columns triggered %d background rebuilds of the pit region (at most one per second)" % new_bakes)
	check(pz.last_source_boxes == exposed_count(prog, true) and pz.last_source_boxes < 96 + 63 + 21 + 14, "E navigation uses only the exposed columns (%d of %d)" % [pz.last_source_boxes, 96 + 63 + 21 + 14])
	check(pz.bake_ms < 30.0, "E collecting the sources takes %.1f ms on the main thread" % pz.bake_ms)
	var front := prog.column_pos(BID, 9) + (center - prog.column_pos(BID, 9)).normalized() * 2.5
	front.y = -3.6
	var e1 := nav_end(game, Vector3(0, 0.1, 8), front)
	check(Vector2(e1.x, e1.z).distance_to(Vector2(front.x, front.z)) < 2.5, "E staff can path from the yard to the face")
	var hillside_ms := 0.0
	var t0 := Time.get_ticks_usec()
	game._rebake_nav()
	hillside_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	check(hillside_ms < 60.0, "E the yard's rebuild (now skipping buried hillside columns) takes %.1f ms" % hillside_ms)
	# ---- G persistence
	var cols_before: Array = (st.deposits[BID]["columns"] as Array).duplicate()
	game._save()
	for i in range(96):
		st.deposits[BID]["columns"][i] = prog.column_max(BID, i)
	game._load()
	await process_frame
	node = game.formation_nodes[BID]
	await frames(40)
	check(ints(st.deposits[BID]["columns"]) == ints(cols_before), "G loading restores exactly which sections were removed")
	var same := true
	for i in range(96):
		same = same and node.standing_count(i) == prog.chunks_left(BID, i) and (node.shapes[i] as CollisionShape3D).disabled == (prog.chunks_left(BID, i) <= 0)
	check(same, "G after loading, chunks and colliders show the same cut")
	var live := 0
	for c in game.world.get_children():
		if c is QuarryArcFormation and not c.is_queued_for_deletion():
			live += 1
	game._load()
	await process_frame
	var live2 := 0
	for c in game.world.get_children():
		if c is QuarryArcFormation and not c.is_queued_for_deletion():
			live2 += 1
	check(live == 1 and live2 == 1 and ints(st.deposits[BID]["columns"]) == ints(cols_before), "G loading twice duplicates nothing")
	# old save: no band record -> full band
	var fa := FileAccess.open("user://quarry_save.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(fa.get_as_text())
	fa.close()
	data["deposits"].erase(BID)
	fa = FileAccess.open("user://quarry_save.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(data))
	fa.close()
	game._load()
	await process_frame
	var full := true
	for i in range(96):
		full = full and int(st.deposits[BID]["columns"][i]) == prog.column_max(BID, i)
	check(full, "G a save without the bench gets a full bench")
	# ---- F a miner works the bench
	prog.stage = prog.stage_index("large")
	st.money = 50000
	st.clock_minutes = 480.0
	game.business.payroll_minute = 480
	for id in ["stone_mountain", "hillside_face_01"]:
		for i in range(prog.column_count(id)):
			st.deposits[id]["columns"][i] = 0
		prog._sync_stock(st.deposits[id])
	game._sync_formations()
	for id in ["stone_mountain", "hillside_face_01"]:
		game.formation_nodes[id].refresh(true)
	game._rebake_nav()
	game.ui_hire("rosa")
	var miner: Dictionary = game.business.employees[0]
	game.business.set_shift(int(miner["id"]), 0, 1439)
	var w = game.worker_nodes[int(miner["id"])]
	var bad := {"unexposed": 0, "empty": 0, "last_empty": -1, "deps": {}, "cols": {}}
	var crew0: int = int(prog.stats["crew"])
	var d0: int = prog.units_left(BID)
	Engine.time_scale = 4.0
	await frames(16000, func():
		if w.anim == "work" and w.mine_col >= 0:
			bad["deps"][w.mine_dep] = true
			bad["cols"][w.mine_col] = true
			if prog.column_units(w.mine_dep, w.mine_col) <= 0:
				if bad["last_empty"] == w.mine_col:
					bad["empty"] += 1
				bad["last_empty"] = w.mine_col
			else:
				bad["last_empty"] = -1
				if not prog.column_exposed(w.mine_dep, w.mine_col):
					bad["unexposed"] += 1
		return int(game.state.storage["limestone"]) >= 5)
	Engine.time_scale = 1.0
	check(bad["deps"].has(BID) and int(prog.stats["crew"]) > crew0 and prog.units_left(BID) < d0, "F the miner walked through the gate to the bench and cut real stone (%d units, %s)" % [d0 - prog.units_left(BID), str(bad["deps"].keys())])
	check(int(game.state.storage["limestone"]) >= 5, "F the stone reached storage")
	check(bad["unexposed"] == 0 and bad["empty"] == 0, "F the miner only swings at exposed, standing rock")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
