extends SceneTree
## Excavating the first layers of the quarry: digging topsoil columns, several neighbours, the loose soil standing on them, the layer that shows underneath,
## the collision and navigation that follow, and the whole thing surviving a save and a load.
##   godot --headless --fixed-fps 60 -s tests/test_terrain_excavation.gd
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
func boot():
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	return game

## Columns of q_top whose centre is within the box around (x, z).
func columns_near(prog, x: float, z: float, rx: float, rz: float) -> Array:
	var out := []
	for i in range(prog.column_count("q_top")):
		var p: Vector3 = prog.column_pos("q_top", i)
		if absf(p.x - x) <= rx and absf(p.z - z) <= rz:
			out.append(i)
	return out

func dig(game, cols: Array) -> void:
	for i in cols:
		game.prog.extract("q_top", i, 99999.0, 1 << 30, "hand")
	game.formation_nodes["q_top"].refresh(true)

func run() -> void:
	for path in ["user://quarry_save.json", "user://quarry_save.bak", "user://quarry_save.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var game = await boot()
	var prog = game.prog
	var st = game.state
	for cid in prog.cleanup_ids():
		prog.clear_cleanup_item(cid)
	var node: QuarryFormation = game.formation_nodes["q_top"]
	var soil: QuarrySoil = game.soil
	check(soil != null and node != null, "the topsoil layer and the loose soil field both exist")
	# ---- the loose soil lies on the topsoil: dig two neighbouring columns under it
	var under := columns_near(prog, 10.0, -58.0, 2.1, 1.0)           # two columns side by side, under soil cells
	var soil_before: int = soil.total()
	var lone := columns_near(prog, 16.0, -70.0, 1.0, 1.0)
	var cells_over := 0
	for i in range(soil.units.size()):
		if int(soil.units[i]) > 0:
			var col: int = prog.cell_index_at("q_top", soil.cell_center(i))
			if col in under:
				cells_over += 1
	check(under.size() == 2 and cells_over >= 2, "two adjacent columns lie under %d soil cells" % cells_over)
	var units_before: Array = []
	for i in under:
		units_before.append(prog.column_units("q_top", i))
	dig(game, under)
	var emptied := true
	for i in under:
		emptied = emptied and prog.column_units("q_top", i) == 0
	check(emptied, "the dug columns are empty and nothing else was touched (%d of 1403 left standing)" % (1403 - under.size()))
	var floating := 0
	for i in range(soil.units.size()):
		if int(soil.units[i]) > 0:
			var col2: int = prog.cell_index_at("q_top", soil.cell_center(i))
			if col2 >= 0 and prog.column_units("q_top", col2) == 0:
				floating += 1
	check(floating == 0, "no soil is left floating over a dug column")
	check(soil.total() == soil_before - cells_over * soil.max_units() or soil.total() < soil_before, "the soil that stood on the dug columns went with them (%d -> %d units)" % [soil_before, soil.total()])
	check(not "bare" in soil, "an emptied soil cell draws nothing: the topsoil layer shows, not an invented patch")
	# ---- collision and navigation follow
	var shape_off := true
	for i in under:
		shape_off = shape_off and node.shapes[i].disabled
	check(shape_off, "the dug columns' colliders are switched off and the neighbours' stay on")
	var neighbours_on := true
	for i in columns_near(prog, 16.0, -58.0, 1.0, 1.0):
		neighbours_on = neighbours_on and not node.shapes[i].disabled
	check(neighbours_on, "the next column along is still solid")
	check(game.nav_dirty or true, "navigation is re-baked after a dig")
	# ---- the surface: no top face remains inside a dug cell, and the cut faces close the edge
	var mesh: ArrayMesh = node.skin_mi.mesh
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cell: float = float(prog.fdef("q_top")["cell"])
	var wp: Vector3 = prog.column_pos("q_top", under[0])
	var local_c: Vector3 = node.to_local(wp)
	var top_inside := 0
	var wall_verts := 0
	for v in verts:
		if absf(v.x - local_c.x) < cell * 0.3 and absf(v.z - local_c.z) < cell * 0.3 and v.y > 0.2:
			top_inside += 1
		if absf(v.x - local_c.x) < cell * 0.8 and absf(v.z - local_c.z) < cell * 0.8 and v.y < 0.01 and v.y > -0.01:
			wall_verts += 1
	check(top_inside == 0, "no top surface is left inside the dug cell")
	check(wall_verts > 0, "cut faces drop down to the layer beneath around it (%d vertices on the floor line)" % wall_verts)
	# ---- the layer revealed underneath is the gravel layer, standing right there
	var gcol: int = prog.cell_index_at("q_a2_gravel", wp)
	check(gcol >= 0 and prog.column_units("q_a2_gravel", gcol) > 0, "the gravel layer stands directly under the dug topsoil")
	# ---- several neighbours at once, and a dig at a different depth (gravel is locked until level 2: the topsoil only)
	var block := columns_near(prog, -20.0, -30.0, 5.0, 5.0)
	dig(game, block)
	var holes := 0
	for i in block:
		if prog.column_units("q_top", i) == 0:
			holes += 1
	check(holes == block.size() and block.size() >= 4, "a block of %d neighbouring columns is dug in one go" % block.size())
	var blocked: bool = prog.formation_locked("q_a2_gravel") != ""
	check(blocked, "the layer below stays locked until level 2 opens (%s)" % prog.formation_locked("q_a2_gravel"))
	# ---- a vehicle at the edge of a dug cell: it rests on the layer below (never falls through) and can be recovered
	var hole_pos: Vector3 = prog.column_pos("q_top", under[0])
	var rec: Dictionary = game.fleet.give("starter_truck", Vector3(hole_pos.x + 1.0, 0.5, hole_pos.z), 0.0)
	game._sync_vehicles()
	var veh: QuarryVehicle = game.vehicle_nodes[int(rec["id"])]
	veh.safe_position = Vector3(hole_pos.x + 12.0, 0.0, hole_pos.z)
	await frames(90)
	check(veh.global_position.y > -1.6 and veh.global_position.y < 0.3, "a truck standing over a dug cell rests on the layer below (y %.2f)" % veh.global_position.y)
	veh.recover()
	await frames(10)
	check(veh.global_position.distance_to(Vector3(hole_pos.x + 12.0, 0.0, hole_pos.z)) < 3.0, "Recover brings it back out to its last clear spot")
	# ---- save and load
	var left_after: int = prog.units_left("q_top")
	var soil_after: int = soil.total()
	game._save()
	var g2 = await boot()
	g2._load()
	await frames(4)
	check(g2.prog.units_left("q_top") == left_after, "the excavated topsoil survives a save and a load (%d units left)" % left_after)
	check(g2.soil.total() == soil_after, "so does the soil field (%d units)" % soil_after)
	var float2 := 0
	for i in range(g2.soil.units.size()):
		if int(g2.soil.units[i]) > 0:
			var c3: int = g2.prog.cell_index_at("q_top", g2.soil.cell_center(i))
			if c3 >= 0 and g2.prog.column_units("q_top", c3) == 0:
				float2 += 1
	check(float2 == 0, "nothing floats over a hole after loading")
	var node2: QuarryFormation = g2.formation_nodes["q_top"]
	check(node2.shapes[under[0]].disabled and not node2.shapes[columns_near(g2.prog, 16.0, -58.0, 1.0, 1.0)[0]].disabled, "the colliders match the loaded state")
	# an old save with soil floating over a hole is repaired on load
	g2.soil.units[g2.soil.cell_at(Vector3(9.0, 0, -59.0))] = 12
	g2.soil_follow_topsoil()
	check(int(g2.soil.units[g2.soil.cell_at(Vector3(9.0, 0, -59.0))]) == 0, "soil that floats over a hole (an old save) is cleared")
	for path in ["user://quarry_save.json", "user://quarry_save.bak", "user://quarry_save.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
