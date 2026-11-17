extends SceneTree
## Looks at every kind of heap in the quarry (windowed): godot --path . --resolution 960x600 -s tools/shot_piles.gd -- <dir>
func _initialize():
	call_deferred("run")
func run():
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	Engine.set_meta("qd_skip_title", true)
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 10: await physics_frame
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	for i in 10: await physics_frame
	game.hud.close_card()
	game.hud.visible = false
	game.item_tips.enabled = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	game.add_child(cam)
	cam.current = true
	var spots := {}
	if game.spoil_node != null:
		game.state.soil_dumped = 300
		game._update_spoil()
		spots["spoil"] = game.spoil_node.global_position
	for id in game.pile_nodes:
		if game.pile_nodes[id].visible:
			spots["pile_" + str(id)] = game.pile_nodes[id].global_position
	if game.soil != null:
		spots["soil"] = Vector3(game.soil.origin.x + game.soil.cols * game.soil.cell * 0.5, 0, game.soil.origin.y + game.soil.rows * game.soil.cell * 0.5)
	if game.live_terrain != null and game.live_terrain.terrain != null:
		var t = game.live_terrain.terrain
		var found := []
		var x0: float = t.origin.x + 8.0
		while x0 < t.origin.x + float(t.cols) * 0.5 and found.size() < 1:
			var z0: float = t.origin.y + 8.0
			while z0 < t.origin.y + float(t.rows) * 0.5 and found.size() < 1:
				var ok := true
				for dx in [0.0, 3.0, 6.0, 9.0, 12.0]:
					for dz in [-3.0, 0.0, 3.0]:
						ok = ok and not t.is_locked_at(x0 + dx, z0 + dz)
				if ok:
					found.append(Vector3(x0, 0, z0))
				z0 += 3.0
			x0 += 3.0
		print("FREE ", found)
		if found.size() > 0:
			var c: Vector3 = found[0]
			t.add_pile(c.x, c.z, 2.6, 1.3, "topsoil", 0.0)
			t.add_pile(c.x + 6, c.z, 2.6, 1.8, "limestone", 0.0)
			t.add_pile(c.x + 12, c.z, 2.6, 1.8, "iron_ore", 0.0)
			var g: Vector2i = t.vertex_at(Vector3(c.x + 6, 0, c.z))
			for d in range(4):
				var kk: int = t.idx(g.x + d, g.y)
				print("VIS ", d, " loose ", t.lsum[kk], " top ", t.top_material(kk), " h ", t.vheight(kk), " vis ", t.vheight_vis(g.x + d, g.y))
			spots["terrain_dirt_rock"] = c + Vector3(6, 0, 0)
			spots["terrain_close"] = c + Vector3(6, 0, 0)
	print("SPOTS ", spots)
	var n := 0
	for k in spots:
		var p: Vector3 = spots[k]
		var far := 7.0 if not k.ends_with("close") else 3.0
		cam.global_position = p + Vector3(far, 4.5 if far > 5 else 2.2, far + 1.0)
		cam.look_at(p + Vector3(0, 0.6, 0))
		for i in 60: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/pile_%d_%s.png" % [out, n, k])
		n += 1
	quit()
