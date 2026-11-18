extends SceneTree
## The hotbar (windowed): godot --path . --resolution 1100x700 -s tools/shot_hotbar.gd -- <dir>
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
	game.item_tips.enabled = false
	if game.walter_dialog:
		game.walter_dialog.skip()
	game._cine_tween().kill()
	game._remove_walter()
	game.hud.refresh_panels()
	for i in 90: await physics_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out + "/hotbar_full.png")
	print('DBGH vis=', game.hud.hotbar_view.visible, ' rect=', game.hud.hotbar_view.get_global_rect(), ' kids=', game.hud.hotbar_view.get_child_count())
	var r: Rect2 = game.hud.hotbar_view.get_global_rect()
	img.get_region(Rect2i(Vector2i(r.position) - Vector2i(10, 10), Vector2i(r.size) + Vector2i(20, 20))).save_png(out + "/hotbar.png")
	quit()
