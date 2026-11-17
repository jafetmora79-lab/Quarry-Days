extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	Engine.set_meta("qd_skip_title", true)
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	root.add_child(game)
	await process_frame
	for i in 5: await physics_frame
	for fid in game.prog.formation_ids():
		if str(game.prog.fdef(fid).get("world", "")) != "filled":
			continue
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for i in range(game.prog.column_count(fid)):
			if game.prog.column_tiers(fid, i) <= 0:
				continue
			var p: Vector3 = game.prog.column_pos(fid, i)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		print("BOUNDS ", fid, " x ", lo.x, "..", hi.x, " z ", lo.y, "..", hi.y, " dims ", game.prog.dims(fid), " cols ", game.prog.column_count(fid))
	print("PIT ", game.pit_zone.basin_zn() if game.pit_zone else "-")
	quit()
