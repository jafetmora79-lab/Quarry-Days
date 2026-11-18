extends SceneTree
## The hopper's screens and the interaction outline (windowed): godot --path . --resolution 1272x706 -s tools/shot_screens.gd -- <dir>
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
	var h: int = game.business.cash_hopper_indices()[0]
	var node: Node3D = game.output_nodes[h]
	game.business.outputs[h]["tier"] = 1
	var c: Vector3 = node.global_position
	game.player.global_position = c + Vector3(0.0, 0.3, -3.4)
	game.player.rotation.y = PI
	game.player.camera.rotation.x = -0.12
	for i in 30: await physics_frame
	for i in 20:
		game.last_target = node
		game._update_highlight()
		await physics_frame
	game.last_target = node
	game._update_highlight()
	print("DBGH node=", game.highlight_node, " shells=", game.highlight_meshes.size(), " menu=", game.menu, " driving=", game.driving, " card=", game.hud.card_open(), " conv=", game._conversation_active())
	game.set_process(false)
	game.set_physics_process(false)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/screens_outline.png")
	quit()
