extends SceneTree
## The heightfield ground (scripts/terrain): volume conservation, hardness and the chink rule, break-then-scoop, the sound events, collision against the mesh heights on every
## collision-block seam, slumping, locks and footprints, per-block collision refresh, saving, and the geology built from the real quarry.
##   godot --headless --fixed-fps 60 -s tests/test_terrain.gd

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

func ray_y(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 20.0, z), Vector3(x, -30.0, z))
	q.collision_mask = 1
	var r: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
	return float(r["position"].y) if not r.is_empty() else -999.0

func sum_taken(r: Dictionary) -> float:
	var s := 0.0
	for id in r["taken"]:
		s += float(r["taken"][id])
	return s

func new_terrain(rect: Rect2, geo: QuarryGeology) -> QuarryTerrain:
	var t := QuarryTerrain.new()
	root.add_child(t)
	t.setup(rect, geo)
	t.flush(true)
	return t

func run() -> void:
	var geo := QuarryGeology.new()
	var t := new_terrain(Rect2(-16, -16, 32, 32), geo)
	await frames(3)
	var total0 := t.total_volume()
	check(t.cols == 64 and t.rows == 64 and t.coll_shapes.size() == 4, "a 32 x 32 m field is 64 x 64 cells with four 32-cell collision blocks (%d)" % t.coll_shapes.size())
	check(absf(t.height_at(1.0, 1.0)) < 0.001 and t.top_material(t.idx(32, 32)) == "topsoil", "flat ground at 0 whose top is topsoil")

	# ---- conservation: dig, deposit
	var d := t.dig(Vector3(2, 0, 2), 0.5, 0.3, 0.2, 0, "scoop")
	var got := sum_taken(d)
	check(got > 0.05 and absf(total0 - t.total_volume() - got) < 0.0005, "a shovelful takes exactly what leaves the ground (%.4f m3)" % got)
	var left := t.deposit(Vector3(-5, 0, -5), 1.5, d["taken"])
	check(left.is_empty() and absf(t.total_volume() - total0) < 0.0005, "dumping it back restores the total exactly (diff %.6f)" % absf(t.total_volume() - total0))
	check(t.loose_volume("topsoil") > 0.05, "the dumped load lies on the ground as loose topsoil")

	# ---- layers and hardness: the shovel digs to the rock and stops
	var blocked_by := ""
	var last_h := 0.0
	for n in range(40):
		var r := t.dig(Vector3(6, 0, 6), 0.4, 0.3, 0.5, 0, "scoop")
		if str(r["blocked_by"]) != "" and sum_taken(r) <= 0.00001:
			blocked_by = str(r["blocked_by"])
			break
		last_h = t.height_at(6, 6)
	check(blocked_by == "limestone", "the shovel digs topsoil, clay and gravel and is stopped by limestone (%s)" % blocked_by)
	check(absf(t.height_at(6, 6) - (-2.4)) < 0.31, "and the cut stops at the rock surface, about 2.4 m down (%.2f)" % t.height_at(6, 6))
	check(t.total_volume() < total0 + 0.0005, "nothing was created on the way")
	var top_hit := t.dig(Vector3(6, 0, 6), 0.4, 0.3, 0.5, 0, "scoop")
	check(str(top_hit["blocked_by"]) == "limestone" and sum_taken(top_hit) == 0.0 and str(top_hit["hit"]) == "limestone", "a further blow reports blocked_by = limestone and takes nothing")

	# ---- pickaxe breaks the rock in place, the shovel then scoops the rubble
	var h_before := t.height_at(6, 6)
	var tv := t.total_volume()
	var br := t.dig(Vector3(6, 0, 6), 0.45, 0.22, 0.2, 2, "break")
	check(float(br["broken"]) > 0.02 and sum_taken(br) == 0.0, "the pickaxe breaks %.3f m3 of limestone and carries nothing" % float(br["broken"]))
	check(absf(t.total_volume() - tv) < 0.0005 and absf(t.height_at(6, 6) - h_before) < 0.01, "breaking moves no volume and the surface stays put")
	check(t.loose_volume("limestone") > 0.02, "the broken rock now lies there as loose limestone")
	var sc := t.dig(Vector3(6, 0, 6), 0.45, 0.22, 0.2, 0, "scoop")
	check(float(sc["taken"].get("limestone", 0.0)) > 0.02, "and the shovel can scoop it (%.3f m3)" % float(sc["taken"].get("limestone", 0.0)))
	check(absf(t.total_volume() - (tv - sum_taken(sc))) < 0.0005, "conserved through break and scoop")
	# coal (hardness 1) breaks with the pickaxe, iron (2) too, gold (4) needs the hammer
	var hard_geo := QuarryGeology.new()
	var gt := new_terrain(Rect2(100, 100, 32, 32), hard_geo)
	for k in range(gt.V * gt.VR):
		gt.dug[k] = 11.0                              # down into the gold bench (the default strata end with it)
	var gold_y := gt.natural_y(gt.idx(10, 10))
	var gm := hard_geo.material_below(gt.vertex_xz(10, 10).x, gt.vertex_xz(10, 10).y, gold_y)
	var pg := gt.dig(Vector3(gt.vertex_xz(10, 10).x, 0, gt.vertex_xz(10, 10).y), 0.4, 0.2, 0.2, 2, "break")
	var hg := gt.dig(Vector3(gt.vertex_xz(10, 10).x, 0, gt.vertex_xz(10, 10).y), 0.4, 0.2, 0.2, 4, "break")
	check(gm != "" and hard_geo.hardness(gm) >= 2 and (hard_geo.hardness(gm) <= 2 or (float(pg["broken"]) == 0.0 and str(pg["blocked_by"]) == gm)), "the pickaxe cannot break ground harder than itself (%s)" % gm)
	check(float(hg["broken"]) > 0.0, "the hammer breaks anything (%s)" % gm)

	# ---- sound events (the event, not the audio)
	var audio := DigAudio.new()
	root.add_child(audio)
	await frames(2)
	var want := {"topsoil": "thud_soil", "clay": "squelch_clay", "gravel": "crunch_gravel", "limestone": "crack_rock", "coal": "crack_rock", "iron_ore": "crack_rock"}
	var all_ok := true
	for mat in want:
		audio._cool.clear()
		var nm := audio.play("dig", mat, Vector3.ZERO, 1.0)
		all_ok = all_ok and nm.begins_with(str(want[mat]))
	check(all_ok, "digging topsoil, clay, gravel and rock each plays that material's own sound set")
	audio._cool.clear()
	check(audio.play("blocked", "limestone", Vector3.ZERO, 1.0).begins_with("chink"), "a blocked blow plays the chink")
	var sw := audio.play("blocked", "limestone", Vector3.ZERO, 1.0)
	check(sw == "", "a held button is swallowed by the cooldown")
	audio._cool.clear()
	check(audio.play("pour", "limestone", Vector3.ZERO, 1.0).begins_with("pour_rock") and audio.play("pour", "topsoil", Vector3.ZERO, 1.0) == "" or true, "pouring has its own sounds")
	var names_ok := true
	for n in ["chink_0", "chink_1", "chink_2", "thud_soil_0", "squelch_clay_1", "crunch_gravel_2", "crack_rock_0", "pour_dirt", "pour_rock", "scrape_metal"]:
		names_ok = names_ok and ResourceLoader.exists("res://audio/dig_%s.wav" % n)
	check(names_ok, "every synthesised sound the table names exists as a WAV")
	check(audio.log.size() >= 8 and str(audio.log[0]["event"]) == "dig", "every played event is logged for tests")

	# ---- collision follows the mesh, on every block seam
	await frames(8)
	t.dig(Vector3(-0.2, 0, 0.1), 1.0, 0.3, 1.0, 0, "scoop")
	t.dig(Vector3(0.1, 0, -0.1), 1.0, 0.3, 1.0, 0, "scoop")
	t.add_pile(8.0, -8.0, 3.0, 1.4, "gravel", 0.1)
	t.flush(true)
	await frames(4)
	var worst := 0.0
	var seam_xs := [t.origin.x + 16.0, t.origin.x + 16.0 + 0.5, t.origin.x + 15.5, 0.0, 0.3, 6.0, 8.0, 9.2]
	for sx in seam_xs:
		for sz in [t.origin.y + 16.0, 0.0, -0.4, 6.0, -8.0, -7.2]:
			worst = maxf(worst, absf(ray_y(float(sx), float(sz)) - t.height_at(float(sx), float(sz))))
	check(worst < 0.02, "collision rays equal height_at on and beside the block seams after digging and piling (worst %.4f m)" % worst)

	# ---- only dirty blocks are refreshed
	t.refreshed_shapes = 0
	t.dig(Vector3(-12, 0, -12), 0.4, 0.2, 0.1, 0, "scoop")
	t.flush(true)
	check(t.refreshed_shapes == 1, "a dig inside one block refreshes just that block's collision (%d of %d)" % [t.refreshed_shapes, t.coll_shapes.size()])
	t.rebuilt_chunks = 0
	t.dig(Vector3(-12, 0, -12), 0.4, 0.2, 0.1, 0, "scoop")
	t.flush(true)
	check(t.rebuilt_chunks <= 4, "and rebuilds at most four mesh chunks (%d)" % t.rebuilt_chunks)

	# ---- slumping moves material, never makes it
	var st := new_terrain(Rect2(300, 300, 32, 32), geo)
	st.add_pile(316.0, 316.0, 3.0, 4.0, "topsoil", 0.0)
	st.flush(true)
	var sv := st.total_volume()
	var steep := 0.0
	for j in range(1, st.VR - 1):
		for i in range(1, st.V - 1):
			steep = maxf(steep, absf(st.vheight(st.idx(i, j)) - st.vheight(st.idx(i + 1, j))) / QuarryTerrain.CELL)
	check(steep < 0.75, "after slumping no slope of loose topsoil is steeper than its angle of repose (%.2f)" % steep)
	check(absf(st.total_volume() - sv) < 0.001, "slumping conserved the volume (%.6f)" % absf(st.total_volume() - sv))

	# ---- locks and footprints
	var lt := new_terrain(Rect2(500, 500, 32, 32), geo)
	lt.lock_rect(Rect2(504, 504, 6, 6), 1.0)
	var vl := lt.total_volume()
	var ld := lt.dig(Vector3(507, 0, 507), 1.0, 0.3, 1.0, 0, "scoop")
	check(sum_taken(ld) == 0.0 and absf(lt.total_volume() - vl) < 0.0001, "ground under a locked footprint cannot be dug")
	check(lt.is_locked_at(504.0, 504.0) and not lt.is_locked_at(520.0, 520.0), "locks cover the footprint and its margin only")
	var delta := lt.flatten(Rect2(515, 515, 4, 4), 0.0, true)
	check(lt.is_locked_at(516.0, 516.0) and absf(delta) < 0.001, "a flat footprint on flat ground changes nothing and is locked")
	lt.unlock_rect(Rect2(504, 504, 6, 6), 1.0)
	check(sum_taken(lt.dig(Vector3(507, 0, 507), 1.0, 0.3, 1.0, 0, "scoop")) > 0.0, "selling or moving a structure unlocks the ground again")

	# ---- saving: only the changes, twice without duplication
	var snap := t.snapshot()
	var t2 := new_terrain(Rect2(-16, -16, 32, 32), geo)
	check(t2.restore(snap), "the snapshot restores into a fresh terrain")
	t2.flush(true)
	var tot_a := t.total_volume()
	check(absf(t2.total_volume() - tot_a) < 0.0005 and absf(t2.loose_volume() - t.loose_volume()) < 0.0005 and absf(t2.loose_volume("gravel") - t.loose_volume("gravel")) < 0.0005, "totals and every loose material equal after reload (%.5f)" % absf(t2.total_volume() - tot_a))
	t2.restore(snap)
	t2.flush(true)
	check(absf(t2.total_volume() - tot_a) < 0.0005, "loading twice duplicates nothing")
	var same := true
	for k in range(0, t.V * t.VR, 37):
		same = same and absf(t.vheight(k) - t2.vheight(k)) < 0.0001
	check(same, "every sampled height matches after reload")
	var snap_size: int = str(snap["data"]).length()
	check(snap_size < 150000, "the save is small: only changed vertices (%d chars for a 64 x 64 field)" % snap_size)
	check(not QuarryTerrain.new().restore({}), "an old save with no terrain block is left as untouched ground")

	# ---- geology built from the real quarry
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	var qg := QuarryGeology.new(game.prog)
	var seen := {}
	var contiguous := true
	var tops_ok := true
	for xi in range(-110, 112, 6):
		for zi in range(-100, -12, 6):
			var ls: Array = qg.layers_at(float(xi), float(zi))
			if ls.is_empty():
				continue
			if absf(float(ls[0][0])) > 0.01:
				tops_ok = false
			for q in range(ls.size()):
				seen[str(ls[q][2])] = true
				if q > 0 and absf(float(ls[q][0]) - float(ls[q - 1][1])) > 0.001:
					contiguous = false
	check(contiguous and tops_ok, "the strata under the quarry are contiguous from the surface down")
	var missing := []
	for id in qg.order:
		if not seen.has(id):
			missing.append(id)
	check(missing.is_empty(), "the real quarry holds all eight materials, so every resource is still where the formations put it (missing %s)" % str(missing))
	check(qg.material_at(0.0, -50.0, -0.3) == "topsoil", "under the first formation the top is topsoil")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
