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
	for lp in game.pit_zone.level_pits:
		print("LEVEL ", lp["n"], " y_top ", lp["y_top"], " y_bot ", lp["y_bot"], " rect ", lp["rect"], " cols ", lp["cols"])
	print("PZ origin ", game.pit_zone.global_position, " rot ", game.pit_zone.global_rotation)
	for id in game.prog.formation_ids():
		var f: Dictionary = game.prog.fdef(id)
		if str(f.get("world", "")) == "filled":
			print("F ", id, " level ", f.get("quarry_level"), " y ", game.prog.column_pos(id, 0).y, " tiers max ", f["tiers"][0][0])
	quit()
