extends SceneTree
## godot --path . --resolution 960x600 -s tools/shot_storage.gd -- <dir>
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
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.current = true
	cam.fov = 60.0
	var views := {"a": [Vector3(4, 1.7, -6), Vector3(9, 0.8, -13.5)], "b": [Vector3(14, 3.0, -5), Vector3(9, 0.8, -13.5)], "c": [Vector3(9, 1.6, -9.5), Vector3(9, 1.0, -14)]}
	for k in views:
		cam.global_position = views[k][0]
		cam.look_at(views[k][1])
		for i in 8: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/storage_%s.png" % k)
	quit()
