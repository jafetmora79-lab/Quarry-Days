extends SceneTree
## The bucket floating over the Cash Hopper and pouring (windowed): godot --path . --resolution 1272x706 -s tools/shot_pour.gd -- <dir>
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
	var h: int = game.business.cash_hopper_indices()[0]
	var node: Node3D = game.output_nodes[h]
	game.player.global_position = node.global_position + Vector3(0.0, 0.3, -3.2)
	game.player.rotation.y = PI
	game.player.camera.rotation.x = -0.25
	game.state.hand_bucket = {"limestone": 14}
	for i in 20: await physics_frame
	game.deliver_hand_to_hopper(h)
	var t0 := Time.get_ticks_msec()
	for n in [0.5, 1.0, 1.6, 2.2, 2.8, 3.6]:
		while (Time.get_ticks_msec() - t0) / 1000.0 < n: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/pour_%d.png" % int(n * 10))
	quit()
