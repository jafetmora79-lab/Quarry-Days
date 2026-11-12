extends SceneTree
## Natural environment checks: sky, clouds, distant mountains and forest are lightweight, collision-free and
## outside the playable area; the rock materials map in world space; no resources are missing.
##   godot --headless --fixed-fps 60 -s tests/test_natural_env.gd

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

func count_type(node: Node, cls: String) -> int:
	var n := 0
	for c in node.find_children("*", cls, true, false):
		n += 1
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await process_frame
	for i in range(4):
		await physics_frame
	game.hud.close_card()
	var ls: QuarryLandscape = game.landscape
	check(ls != null and ls.is_inside_tree(), "A the landscape is built")
	var env: Environment = game.sky_light.environment
	check(env.background_mode == Environment.BG_SKY and env.sky != null and env.sky.sky_material is ProceduralSkyMaterial, "A the flat colour background is replaced by a sky gradient")
	# no gameplay objects at all in the landscape
	check(count_type(ls, "CollisionObject3D") == 0 and count_type(ls, "CollisionShape3D") == 0 and count_type(ls, "NavigationRegion3D") == 0, "B the landscape has no collision, no navigation")
	check(count_type(ls, "MeshInstance3D") + count_type(ls, "MultiMeshInstance3D") <= 22, "B it costs at most a couple of dozen draw calls (%d)" % (count_type(ls, "MeshInstance3D") + count_type(ls, "MultiMeshInstance3D")))
	# mountains are far outside the playable area and the pit zone
	var near := 1e9
	for m in ls.mountain_nodes:
		var aabb: AABB = (m as MeshInstance3D).mesh.get_aabb()
		near = minf(near, minf(minf(absf(aabb.position.x), absf(aabb.end.x)), 1e9))
	check(ls.mountain_nodes.size() == 3, "C three layers of mountains")
	var min_r := 1e9
	for m in ls.mountain_nodes:
		var arr: Array = (m as MeshInstance3D).mesh.surface_get_arrays(0)
		for v in arr[Mesh.ARRAY_VERTEX]:
			if v.y > 0.0:
				min_r = minf(min_r, Vector2(v.x, v.z).length())
	check(min_r > 290.0, "C every mountain crest is beyond 290 m from the quarry centre (%.0f)" % min_r)
	# the forest stays on the embankment, away from the corridor and the east expansion
	var mm: MultiMesh = ls.forest.multimesh
	var ok := mm.instance_count > 200
	var clear := true
	for p in ls.tree_positions:
		var r := Vector2(p.x, p.z).length()
		ok = ok and r >= 33.5 and r <= 49.5
		clear = clear and not game.in_pit_corridor(p, 7.9) and not (p.x > 24.0 and absf(p.z) < 18.0)
	check(ok and ls.tree_count == mm.instance_count, "D %d trees grow on the embankment ring" % ls.tree_count)
	check(clear, "D no tree stands in the access corridor or the east expansion")
	# time of day recolours the sky
	ls.set_day(1.0)
	var day_top: Color = ls.sky_mat.sky_top_color
	ls.set_day(0.0)
	var night_top: Color = ls.sky_mat.sky_top_color
	ls.set_day(1.0)
	check(day_top.v > night_top.v + 0.3, "E the sky is darker at night and light by day")
	# rock materials map in world space (continuous across blocks)
	var hill = game.formation_nodes["hillside_face_01"]
	var m0: StandardMaterial3D = hill.mat_old
	check(m0.uv1_triplanar and m0.uv1_world_triplanar, "F hillside rock is mapped in world space")
	var arc = game.formation_nodes["pit_band_01"]
	var mmi: MultiMeshInstance3D = arc.find_children("Chunks0", "MultiMeshInstance3D", false, false)[0]
	check((mmi.material_override as StandardMaterial3D).uv1_world_triplanar, "F the curved bench rock is mapped in world space")
	check(hill.mat_old == hill.mat_old2 and arc.TONE_OLD[0] == arc.TONE_OLD[1], "F courses share one tone (no stripes between blocks)")
	# every texture and material the world uses loads
	var missing := []
	for path in ["T_QD_CutLimestone", "T_QD_CliffStrata", "T_QD_RockLimestone", "T_QD_RockCoal", "T_QD_RockIron", "T_QD_RockDeep", "T_QD_QuarryFloor", "T_QD_ExcavatedDirt"]:
		if load("res://assets/textures/%s.png" % path) == null:
			missing.append(path)
	for mname in ["CutLimestone", "CliffStrata", "RockLimestone", "QuarryFloor", "ExcavatedDirt"]:
		if MeshKit.mat(mname) == null:
			missing.append(mname)
	check(missing.is_empty(), "G no missing textures or materials %s" % str(missing))
	# stone formations keep their colliders and the ring is still closed
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var gaps := 0
	for deg in range(0, 360, 4):
		if deg > 296 and deg < 316:
			continue # the closed gate barrier region is covered by its own test
		var a := deg_to_rad(float(deg))
		var hit := false
		for y in [0.5, 2.0, 4.0]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(cos(a) * 22.0, y, sin(a) * 22.0), Vector3(cos(a) * 33.0, y, sin(a) * 33.0))
			q.collision_mask = 1
			if not space.intersect_ray(q).is_empty():
				hit = true
		if not hit:
			gaps += 1
	check(gaps == 0, "H the yard's cliff ring still blocks every direction (%d gaps)" % gaps)
	# new cliff meshes are still closed solids
	var s := MeshKit.Soup.new()
	MeshKit.cliff_into(s, 30.0, 8.0, 3.0, 811, 4, Transform3D.IDENTITY)
	var edges := {}
	for i in range(0, s.verts.size(), 3):
		var tri := [s.verts[i], s.verts[i + 1], s.verts[i + 2]]
		for k in range(3):
			var a2: Vector3 = tri[k]
			var b2: Vector3 = tri[(k + 1) % 3]
			var ka := "%d,%d,%d" % [roundi(a2.x * 1000.0), roundi(a2.y * 1000.0), roundi(a2.z * 1000.0)]
			var kb := "%d,%d,%d" % [roundi(b2.x * 1000.0), roundi(b2.y * 1000.0), roundi(b2.z * 1000.0)]
			var key := (ka + "|" + kb) if ka < kb else (kb + "|" + ka)
			edges[key] = int(edges.get(key, 0)) + 1
	var open_edges := 0
	for k in edges:
		if edges[k] != 2:
			# unpaired edges are only T-junctions on the hidden back plane (z = +1.5) and the open underside, which sits on the ground
			var parts: PackedStringArray = k.split("|")
			var on_back := false
			for pt in parts:
				on_back = on_back or int(pt.split(",")[2]) == 1500
			var on_ground: bool = int(parts[0].split(",")[1]) == 0 and int(parts[1].split(",")[1]) == 0
			if not on_back and not on_ground:
				open_edges += 1
	check(open_edges == 0, "H the rough cliff mesh has no holes (%d open edges outside the back plane and the ground line)" % open_edges)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
