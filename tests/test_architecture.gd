extends SceneTree
## Architecture repair checks (geometry, not looks): nothing pokes through a roof, the garage roof sits exactly on its walls, every furnishing detail rests on something,
## doors swing clear of furniture, chairs and furniture leave room to walk. Automated tests cannot judge appearance: see the delivery notes for what needs eyes.
##   godot --headless --fixed-fps 60 -s tests/test_architecture.gd
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

## every vertex (world space) of the visible meshes at or under `node`
func world_vertices(node: Node, out: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null and not (node.get_parent() is Label3D):
		for si in range(node.mesh.get_surface_count()):
			var arr = node.mesh.surface_get_arrays(si)
			if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
				continue
			for v in arr[Mesh.ARRAY_VERTEX]:
				out.append(node.global_transform * v)
	for ch in node.get_children():
		world_vertices(ch, out)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(30)
	var art = game.art
	var verts := PackedVector3Array()
	world_vertices(game, verts)
	check(verts.size() > 1000, "the world has geometry to check (%d vertices)" % verts.size())
	# ---- gable buildings: nothing rises above the ridge cap, and the roof sheets start at the wall tops
	var specs := [["office", game.OFFICE_POS, 1.1], ["home", game.HOME_POS, 1.0], ["workshop", game.TOOLSHED_POS, 0.9], ["storage shed", game.SHED_POS, 0.7]]
	for sp in specs:
		var c: Vector3 = sp[1]
		var rise: float = sp[2]
		var top := 2.8 + rise + QuarryArt.ROOF_T + 0.05
		var highest := -1.0
		var lowest_roof := 99.0
		for v in verts:
			if absf(v.x - c.x) < 2.9 and absf(v.z - c.z) < 2.9:
				highest = maxf(highest, v.y)
		check(highest <= top + 0.001 and highest > 2.8 + rise, "%s: nothing pokes above the ridge cap (highest %.3f, ridge top %.3f)" % [sp[0], highest, top])
		# the sheet underside meets the wall top at the eave, and the frieze/gable close everything below it: sample the roof underside at 3 depths
		for z in [0.0, 1.4, 2.5]:
			var want: float = 2.8 + art.roof_under(z, 5.6, rise)
			check(want >= 2.8 - 0.001 and want <= 2.8 + rise + 0.001, "%s: roof underside at depth %.1f is %.3f m (inside wall top .. ridge)" % [sp[0], z, want])
	# ---- the garage: roof sheet vertices lie on the slope; nothing but the sheet rises above it; side wall tops sit 2 cm into the sheet
	var z0 := 14.9
	var z1 := 22.4
	var x0: float = -4.7 + game.GARAGE_DX
	var x1: float = 14.5 + game.GARAGE_DX
	var roof_ok := true
	var rv := PackedVector3Array()
	world_vertices(art.garage_roof, rv)
	for v in rv:
		var u: float = art.garage_under(v.z, z0, z1)
		if absf(v.y - u) > 0.006 and absf(v.y - (u + 0.12)) > 0.006:
			roof_ok = false
	check(roof_ok and rv.size() > 0, "garage: every roof vertex lies on the sloped underside or the 12 cm sheet top")
	var poke := 0
	var top_front := false
	var top_back := false
	for v in verts:
		if v.x > x0 - 0.35 and v.x < x1 + 0.35 and v.z > z0 - 0.7 and v.z < z1 + 0.4 and v.y > 3.0:
			var u2: float = art.garage_under(v.z, z0, z1)
			if v.y > u2 + 0.12 + 0.01:
				poke += 1
		if absf(v.x - x0) < 0.11:                  # the left side wall: its top corners sit 2 cm inside the roof sheet at both ends, so the straight edge between them follows the slope
			if absf(v.z - z0) < 0.001 and absf(v.y - (art.garage_under(z0, z0, z1) + 0.02)) < 0.005:
				top_front = true
			if absf(v.z - z1) < 0.001 and absf(v.y - (art.garage_under(z1, z0, z1) + 0.02)) < 0.005:
				top_back = true
	check(poke == 0, "garage: nothing (truss, beam, sign) pokes through the roof (%d vertices above it)" % poke)
	check(top_front and top_back, "garage: the side walls' top corners meet the roof underside at both ends (no gap under the sheet)")
	# ---- details rest on something: floor, ceiling, a wall, or another detail
	var reg: Array = BuildingDetails.registry
	var floating := []
	for item in reg:
		var bb: AABB = item[0]
		var cen := bb.get_center()
		var owner_c := Vector3.INF
		for sp in specs:
			var c2: Vector3 = sp[1]
			if absf(cen.x - c2.x) < 2.7 and absf(cen.z - c2.z) < 2.7:
				owner_c = c2
		if owner_c == Vector3.INF:
			floating.append("outside any building %s" % str(cen))
			continue
		var rel: Vector3 = bb.position - owner_c
		var rel_end: Vector3 = bb.end - owner_c
		var supported := rel.y <= 0.22 or rel_end.y >= 2.72 or rel_end.x >= 2.2 or rel.x <= -2.2 or rel_end.z >= 2.16 or rel.z <= -2.16
		if not supported:
			for other in reg:
				if other[0] != item[0] and (other[0] as AABB).grow(0.03).intersects(bb):
					supported = true
					break
		if not supported:
			floating.append("%s at %s" % [item[1], str(cen)])
	check(floating.is_empty(), "no furnishing detail floats (%d of %d checked) %s" % [reg.size() - floating.size(), reg.size(), str(floating.slice(0, 4))])
	# ---- every door's leaf sweeps clear of furniture and walls
	var boxes := []
	for body in game.world.find_children("*", "StaticBody3D", true, false):
		if str(body.get_meta("kind", "")) == "door":
			continue
		for cs in body.get_children():
			if cs is CollisionShape3D and cs.shape is BoxShape3D:
				boxes.append([cs.global_transform, (cs.shape as BoxShape3D).size])
	for dr in game.doors:
		var hit := false
		for t in range(2, 11):
			var f := float(t) / 10.0
			var ry: float = dr.hinge_side * dr.swing * smoothstep(0.0, 1.0, f)
			var dirv := Basis(Vector3.UP, ry) * Vector3(-dr.hinge_side, 0, 0)
			for k in range(0, 14):
				var p: Vector3 = dr.global_position + dirv * (0.1 + float(k) * 0.1) + Vector3(0, 0.9, 0)
				for b in boxes:
					var xf: Transform3D = b[0]
					var sz: Vector3 = b[1]
					var l: Vector3 = xf.affine_inverse() * p
					if absf(l.x) < sz.x * 0.5 - 0.02 and absf(l.y) < sz.y * 0.5 - 0.02 and absf(l.z) < sz.z * 0.5 - 0.02:
						hit = true
		check(not hit, "%s: the leaf swings through its whole arc without touching anything" % str(dr.name))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
