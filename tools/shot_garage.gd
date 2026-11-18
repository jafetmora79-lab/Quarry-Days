extends SceneTree
## The garage and its floor, then the whole yard (windowed): godot --path . --resolution 1272x706 -s tools/shot_screens.gd -- <dir>
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
	game.player.global_position = Vector3(-2.0, 0.3, 9.5)
	game.player.rotation.y = PI
	game.player.camera.rotation.x = -0.16
	for i in 40: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/garage_front.png")
	game.player.global_position = Vector3(-2.0, 0.3, 14.6)
	game.player.camera.rotation.x = -0.35
	for i in 20: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/garage_floor.png")
	quit()
