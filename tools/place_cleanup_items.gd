extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in range(10):
		await physics_frame
	var solids := []
	for c in game.natural_root.get_children():
		if c is StaticBody3D:
			solids.append(Vector2(c.global_position.x, c.global_position.z))
	var soil_pts := []
	for i in range(game.soil.units.size()):
		if game.soil.active[i] == 1:
			soil_pts.append(game.soil.cell_center(i))
	print("SOILCELLS ", soil_pts.size(), " solids ", solids.size())
	var cands := []
	var x := -21.5
	while x <= 21.5:
		var z := -26.0
		while z <= -8.5:
			var p := Vector2(x, z)
			var v := Vector3(x, 0, z)
			var ok: bool = absf(x) > 4.6 and not game.in_pit_corridor(v, 4.0) and not game.in_hillside_zone(v, 2.5) and not game.hub_rect().grow(2.0).has_point(p)
			for q in solids:
				if q.distance_to(p) < 2.0:
					ok = false
			for q in [Vector2(2, -14), Vector2(11.5, -11), Vector2(-19, -5)]:
				if q.distance_to(p) < 3.0:
					ok = false
			for sp in soil_pts:
				if Vector2(sp.x, sp.z).distance_to(p) < 1.9:
					ok = false
			if ok:
				var q := PhysicsPointQueryParameters3D.new()
				q.position = Vector3(x, 0.6, z)
				q.collision_mask = 1 | 8
				if not game.get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
					ok = false
			if ok:
				cands.append(p)
			z += 0.5
		x += 0.5
	print("CANDS ", cands.size())
	# farthest point sampling, deterministic
	var chosen := [cands[0]] if cands.size() > 0 else []
	while chosen.size() < 26:
		var best := -1.0
		var bp: Vector2 = cands[0]
		for c in cands:
			var d := 1e9
			for q in chosen:
				d = minf(d, (c as Vector2).distance_to(q))
			if d > best:
				best = d
				bp = c
		if best < 2.1:
			break                       # no spot left that is at least 2.6 m from every item already placed
		chosen.append(bp)
	var out := []
	for c in chosen:
		out.append([snappedf(c.x, 0.5), snappedf(c.y, 0.5)])
	print("CHOSEN ", JSON.stringify(out))
	quit()
