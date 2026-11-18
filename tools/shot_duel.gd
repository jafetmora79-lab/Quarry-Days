extends SceneTree
## The deer / rabbit showdown (windowed): godot --path . --resolution 1272x706 -s tools/shot_duel.gd -- <dir>
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
	if game.walter_dialog:
		game.walter_dialog.skip()
	game._cine_tween().kill()
	game._remove_walter()
	game.wildlife.duel_enabled = false
	var d := QuarryDuel.new()
	var at := Vector3(10.0, 0.0, 44.0)
	d.setup(game, at, 0.0)
	game.wildlife.add_child(d)
	game.player.global_position = at + Vector3(3.0, 0.3, 9.0)
	game.player.rotation.y = 0.0
	game.player.camera.rotation.x = -0.05
	game.player.locked = true
	game.ui.visible = false
	for time in [3.0, 8.0, 10.5, 25.5, 30.0]:
		while d.t < time:
			d.step(1.0 / 60.0)
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/duel_%d.png" % int(time * 10))
	quit()
