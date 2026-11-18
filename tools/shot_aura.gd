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
	game.player.global_position = b.global_position + Vector3(7.0, 0.3, 3.0)
	game.player.rotation.y = PI * 0.5 + 0.25
	game.player.camera.rotation.x = -0.12
	game.player.locked = true
	game.ui.visible = false
	for i in 20: await physics_frame
	for time in [1.0, 4.0, 5.5, 10.0, 17.0, 21.0]:
		b._pose(time)
		for i in 3: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/aura_%d.png" % int(time * 10))
	quit()
