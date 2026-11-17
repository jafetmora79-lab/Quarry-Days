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
	var g := QuarryGeology.new(game.prog)
	for p in [Vector2(0, -50), Vector2(4, -60), Vector2(-40, -60), Vector2(30, -60), Vector2(10, -20)]:
		print("LAYERS ", p, " ", g.layers_at(p.x, p.y))
	print("FORM ", g._formations)
	for id in g._formations:
		print("COL ", id, " ", game.prog.cell_index_at(id, Vector3(4, 0, -60)), " tiers ", game.prog.column_max(id, max(0, game.prog.cell_index_at(id, Vector3(4, 0, -60)))), " y ", game.prog.column_pos(id, max(0, game.prog.cell_index_at(id, Vector3(4, 0, -60)))).y)
	quit()
