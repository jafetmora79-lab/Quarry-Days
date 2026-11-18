extends SceneTree
## The old square soil field is real ground now: loose topsoil lying on the terrain. Nothing is a box or a patch any more; the cell bookkeeping that contracts, machines, the crew and saves use
## is READ from the ground, and every way of digging it (spade, bucket, blade, loader) changes the same ground.   godot --headless --fixed-fps 60 -s tests/test_soil_terrain.gd

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
	game.title_enabled = false
	root.add_child(game)
	await process_frame
	await frames(12)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var soil: QuarrySoil = game.soil
	var lt: LiveTerrain = game.live_terrain
	var t: QuarryTerrain = lt.terrain
	check(soil != null and soil.terrain == t, "the soil field is backed by the live terrain")
	check(soil.get_child_count() == 0 and soil.get("body") == null and soil.get("surface") == null, "there are no collision boxes or separate surface mesh: nothing is drawn or collided but the terrain")
	var cells := 0
	for i in range(soil.units.size()):
		cells += int(soil.active[i])
	var vol := 0.0
	for i in range(soil.units.size()):
		if int(soil.active[i]) == 1:
			vol += t.loose_rect_volume(Rect2(soil.origin.x + float(i % soil.cols) * soil.cell, soil.origin.y + float(i / soil.cols) * soil.cell, soil.cell, soil.cell), "topsoil")
	check(absf(vol / soil.unit_volume() - float(soil.total())) < 0.5 * float(cells), "the cells' units are the ground's loose topsoil / 0.3 m3 (%d units, %.0f m3)" % [soil.total(), vol])
	var all_loose := t.loose_volume("topsoil")
	check(all_loose >= vol - 0.001 and all_loose <= float(cells * soil.max_units()) * soil.unit_volume() * 1.08, "the topsoil on the ground is what the field held, conserved (%.0f of %.0f m3, plus the odd heap elsewhere)" % [all_loose, float(cells * soil.max_units()) * soil.unit_volume()])
	# no square steps: every neighbouring pair of vertices across the field is within the repose slope
	var worst := 0.0
	for j in range(2, t.VR - 2):
		var z := t.origin.y + float(j) * QuarryTerrain.CELL
		if z < soil.origin.y - 3.0 or z > soil.origin.y + float(soil.rows) * soil.cell + 3.0:
			continue
		for i in range(2, t.V - 2):
			var x := t.origin.x + float(i) * QuarryTerrain.CELL
			if x < soil.origin.x - 3.0 or x > soil.origin.x + float(soil.cols) * soil.cell + 3.0:
				continue
			worst = maxf(worst, absf(t.vheight(t.idx(i, j)) - t.vheight(t.idx(i + 1, j))))
	check(worst <= 0.55, "the edge of the field slumps into a real slope, not a stack of square steps (steepest %.2f m per 0.5 m)" % worst)
	# ---- the spade
	game.prog.cleanup["done"] = true
	if not game.state.gear.has("shovel"):
		game.state.gear.append("shovel")
	game.state.equipped = "shovel"
	var ci := -1
	for i in range(soil.units.size()):
		var c := soil.cell_center(i)
		if int(soil.active[i]) == 1 and absf(c.x) > 7.0 and absf(c.x) < 14.0 and int(soil.units[i]) >= 12:
			ci = i
			break
	check(ci >= 0, "an interior soil cell was found")
	var cc := soil.cell_center(ci)
	var p := Vector3(cc.x, t.height_at(cc.x, cc.z), cc.z)
	var units0 := soil.total()
	var h0 := t.height_at(cc.x, cc.z)
	var bag0: int = game.state.inventory_total() if game.state.has_method("inventory_total") else 0
	var removed0 := int(game.prog.story["areas"]["area_1"]["soil_removed"])
	for i in range(14):
		game._terrain_strike(p)
		p.y = t.height_at(cc.x, cc.z)
	soil.sync()
	check(t.height_at(cc.x, cc.z) < h0 - 0.1, "a spade strikes the soil and the ground really goes down (%.2f to %.2f m)" % [h0, t.height_at(cc.x, cc.z)])
	check(soil.total() < units0, "the cells lost units (%d to %d)" % [units0, soil.total()])
	var removed1 := int(game.prog.story["areas"]["area_1"]["soil_removed"])
	check(removed1 > removed0, "the Area 1 contract counts the soil dug by hand (%d to %d)" % [removed0, removed1])
	check(absi((units0 - soil.total()) - (removed1 - removed0)) <= 2, "and counts exactly what the ground lost (%d vs %d)" % [units0 - soil.total(), removed1 - removed0])
	var bag: int = 0
	for k in game.state.inventory:
		bag += int(game.state.inventory[k])
	check(bag > 0, "the dug soil went into the bag (%d)" % bag)
	# ---- the cells' own API: take and put, conserving
	var a := soil.total()
	var took := soil.remove(ci, 3)
	var put := soil.add(ci, took)
	check(took <= 3 and put == took and soil.total() == a, "taking units out of a cell and putting them back conserves the field (%d)" % took)
	# ---- saving: the terrain holds it; an older save (cells only) is laid onto the ground
	game.soil_sync_state()
	var before := soil.total()
	game._save(true)
	for r in range(2):
		game._load(true)
		await frames(3)
	check(absi(game.soil.total() - before) <= 3 and int(game.prog.story["areas"]["area_1"]["soil_removed"]) == removed1, "the dug ground and the contract count survive save/load (%d vs %d)" % [game.soil.total(), before])
	var old := []
	for i in range(game.soil.units.size()):
		old.append(0 if int(game.soil.active[i]) == 0 else (4 if (i % game.soil.cols) < game.soil.cols / 2 else game.soil.max_units()))
	game.soil.apply(old)
	var want := 0
	for v in old:
		want += int(v)
	check(absi(game.soil.total() - want) <= int(0.08 * float(want)), "an older save (cells only) is laid onto the ground with the same quantity (%d vs %d)" % [game.soil.total(), want])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
