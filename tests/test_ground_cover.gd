extends SceneTree
## No bare strips: every point of the ground around and inside the blueprint quarry (the soil field's outer edge, the fence strip, the south side)
## is covered by a visible, upward-facing ground surface - the grass sheet or the topsoil skin - so the background never shows through.
##   godot --headless --fixed-fps 60 -s tests/test_ground_cover.gd
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
## Upward-facing triangles of a mesh instance in world xz: [[Vector2 x3], ...]
func up_tris(m: MeshInstance3D) -> Array:
	var out := []
	var mesh: Mesh = m.mesh
	for sidx in range(mesh.get_surface_count()):
		var arr = mesh.surface_get_arrays(sidx)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var tri_idx := []
		if idx != null and idx.size() > 0:
			for i in range(0, idx.size(), 3):
				tri_idx.append([idx[i], idx[i + 1], idx[i + 2]])
		else:
			for i in range(0, v.size(), 3):
				tri_idx.append([i, i + 1, i + 2])
		for t in tri_idx:
			var ny := 0.0
			if nrm != null and nrm.size() > 0:
				ny = (nrm[t[0]].y + nrm[t[1]].y + nrm[t[2]].y) / 3.0
			if ny < 0.5:
				continue
			var a: Vector3 = m.global_transform * v[t[0]]
			var b: Vector3 = m.global_transform * v[t[1]]
			var c: Vector3 = m.global_transform * v[t[2]]
			out.append([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
	return out
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	var tris := []
	var grass_ok := 0
	for mi in game.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var bb: AABB = m.global_transform * m.mesh.get_aabb()
		var is_sheet: bool = bb.size.x > 300.0 and bb.size.y < 0.2 and absf(bb.position.y) < 0.2
		var is_skin: bool = m.name == "RockSkin" and m.get_parent().name == "q_top"
		if is_sheet or is_skin:
			var tt: Array = up_tris(m)
			print("DBG ", m.get_parent().name, "/", m.name, " tris=", tt.size(), " z=[%.1f,%.1f]" % [bb.position.z, bb.end.z])
			tris.append_array(tt)
			grass_ok += 1
	check(grass_ok >= 2, "the ground sheets and the topsoil skin are all present (%d)" % grass_ok)
	var foot: Rect2 = game.pit_zone._soil_footprint()
	for probe in [Vector2(0.01, -106.0), Vector2(-121.987, -107.983), Vector2(-100.5, -105.5), Vector2(0.01, -110.2), Vector2(0.01, -103.0)]:
		var hits := 0
		var near := 1e9
		for t in tris:
			if Geometry2D.is_point_in_polygon(probe, PackedVector2Array([t[0], t[1], t[2]])):
				hits += 1
		print("PROBE ", probe, " covered by ", hits, " tris")
	check(foot.size.x > 200.0 and foot.size.y > 80.0, "the soil footprint is known (%s)" % str(foot))
	var missing := []
	var checked := 0
	# a ring of samples across the soil edge on all four sides (from 4 m outside to 4 m inside), plus the strip between the fence and the soil
	var xs := []
	var zs := []
	var x := foot.position.x - 4.0
	while x <= foot.end.x + 4.0:
		xs.append(x)
		x += 1.0
	var z := foot.position.y - 4.0
	while z <= foot.end.y + 6.0:
		zs.append(z)
		z += 1.0
	for xx in xs:
		for zz in zs:
			var near_edge: bool = absf(xx - foot.position.x) < 4.0 or absf(xx - foot.end.x) < 4.0 or absf(zz - foot.position.y) < 4.0 or absf(zz - foot.end.y) < 4.0
			if not near_edge:
				continue
			checked += 1
			var covered := false
			var pt := Vector2(xx + 0.013, zz + 0.017)       # off the exact cell edges
			for t in tris:
				if Geometry2D.is_point_in_polygon(pt, PackedVector2Array([t[0], t[1], t[2]])):
					covered = true
					break
			if not covered:
				missing.append(pt)
	print("checked %d points, %d bare" % [checked, missing.size()])
	var by := {"north(z<foot)": 0, "south(z>foot)": 0, "west(x<foot)": 0, "east(x>foot)": 0, "inside": 0}
	for pt in missing:
		if pt.y < foot.position.y:
			by["north(z<foot)"] += 1
		elif pt.y > foot.end.y:
			by["south(z>foot)"] += 1
		elif pt.x < foot.position.x:
			by["west(x<foot)"] += 1
		elif pt.x > foot.end.x:
			by["east(x>foot)"] += 1
		else:
			by["inside"] += 1
	print("bare by side: ", by)
	check(missing.size() == 0, "no bare ground round the topsoil field (%d of %d samples uncovered, e.g. %s)" % [missing.size(), checked, str(missing.slice(0, 4))])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
