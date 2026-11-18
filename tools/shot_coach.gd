extends SceneTree
## The quarry fly-over and the guide panel (windowed): godot --path . --resolution 1272x706 -s tools/shot_screens.gd -- <dir>
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
	game.item_tips.enabled = false
	game.hud.close_card()
	if game.walter_dialog:
		game.walter_dialog.skip()
	game._cine_tween().kill()
	game._remove_walter()
	for i in 5: await physics_frame
	game.hud.close_card()
	game.player.global_position = Vector3(0.0, 0.3, -12.5)
	game.player.rotation.y = 0.0
	for i in 30: await physics_frame
	print("DBG flying=", game.coach.flying(), " intro=", game.prog.story.get("intro_seen"), " cleanup=", game.prog.cleanup_active())
	var t0 := Time.get_ticks_msec()
	for n in [1.5, 5.5, 10.0]:
		while (Time.get_ticks_msec() - t0) / 1000.0 < n: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/fly_%d.png" % int(n))
	while game.coach.flying(): await physics_frame
	for i in 20: await physics_frame
	game.player.global_position = Vector3(0.0, 0.3, -12.0)
	game.player.rotation.y = 0.0
	game.player.camera.rotation.x = -0.35
	for i in 60: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/coach_panel.png")
	quit()
