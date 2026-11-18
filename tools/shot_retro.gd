extends SceneTree
## The retro-colour levels side by side (windowed): godot --path . --resolution 1272x706 -s tools/shot_retro.gd -- <dir>
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
	for lv in range(3):
		GameSettings.set_retro(lv)
		for i in 6: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/retro_%d.png" % [out, lv])
	GameSettings.set_retro(0)
	quit()
