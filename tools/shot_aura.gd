extends SceneTree
## The aura battle up close (windowed): godot --path . --resolution 1272x706 -s tools/shot_aura.gd -- <dir>
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
	var b = game.wildlife.aura_battle
	b.set_process(false)
	game.player.global_position = Vector3(-120.0, 0.3, -58.0)
	for i in 20: await physics_frame
	b.elapsed = 0.0
	b._cine_start()
	for time in [1.0, 4.5, 7.0, 10.0, 13.5, 17.0, 21.5]:
		b.elapsed = time
		b._pose(time)
		b._cine_update(time)
		for i in 3: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/aura_%d.png" % int(time * 10))
	quit()
