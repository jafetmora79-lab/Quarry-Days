extends SceneTree
## The deeper layers with their ore (windowed run):  godot --path . --resolution 1280x720 -s tools/shot_ore.gd -- <dir>
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
	# open a shaft: topsoil and the first benches over x -24..24, z -92..-44
	for fid in ["q_top", "q_a2_gravel", "q_a2_rock"]:
		for i in range(game.prog.column_count(fid)):
			var cp: Vector3 = game.prog.column_pos(fid, i)
			if cp.x > -24.0 and cp.x < 24.0 and cp.z > -92.0 and cp.z < -44.0:
				game.prog.extract(fid, i, 99999.0, 99999, "excavator")
		(game.formation_nodes[fid]).refresh(true)
	var views := [["ore_a", Vector3(0, 9, -36), Vector3(0, -6, -66)], ["ore_b", Vector3(-6, 3.5, -50), Vector3(0, -7, -68)], ["ore_c", Vector3(6, -5, -52), Vector3(0, -9, -66)]]
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await shot(v[0], out)
	quit()
