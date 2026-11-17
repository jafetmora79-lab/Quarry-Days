extends SceneTree
## The quarry ground from several views (windowed run):  godot --path . --resolution 1280x720 -s tools/shot_quarry.gd -- <dir>
func _initialize():
	call_deferred("run")
func shot(name: String, out: String, frames := 20) -> void:
	for i in frames:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func run():
	var out := "."
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
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
	cam.name = "ShotCam"
	cam.fov = 70.0
	cam.far = 600.0
	root.add_child(cam)
	cam.current = true
	game.player.global_position = Vector3(0, 0, 80)
	# dig a trench and a bay in the topsoil (as a player would), then look at what it reveals
	var node = game.formation_nodes["q_top"]
	var dug := 0
	for i in range(game.prog.column_count("q_top")):
		var cp: Vector3 = game.prog.column_pos("q_top", i)
		if (cp.x > -14.0 and cp.x < 6.0 and cp.z > -60.0 and cp.z < -44.0) or (absf(cp.z + 40.0) < 2.0 and cp.x > -30.0 and cp.x < 30.0):
			var ex: Dictionary = game.prog.extract("q_top", i, 9999.0, 9999, "excavator")
			dug += int(ex["units"])
	node.refresh(true)
	print("DUG ", dug)
	var views := [["q_over", Vector3(0, 30, -20), Vector3(-4, 0, -50)], ["q_side", Vector3(-30, 6, -30), Vector3(0, 0, -50)], ["q_close", Vector3(8, 2.2, -34), Vector3(-4, -0.5, -50)], ["q_rim", Vector3(-2, 1.8, -36), Vector3(-6, -0.5, -52)],
		["q_stake", Vector3(-3, 1.4, -36), Vector3(-1, 0.6, -39)], ["q_far", Vector3(0, 60, 10), Vector3(0, 0, -60)]]
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await shot(v[0], out)
	quit()
