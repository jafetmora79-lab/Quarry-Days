extends SceneTree
## The shovel digging, carrying and dumping in the real game (windowed): godot --path . --resolution 960x600 -s tools/shot_shovel_gif.gd -- <dir>
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
	game.hud.visible = false
	game.player.global_position = Vector3(8.0, 0.2, -12.0)
	game.player.rotation.y = PI
	game.state.equipped = "shovel"
	for i in 50: await physics_frame
	var tv = game.player.tool_view
	tv.equip(game.prog.model_tier(), true)
	game.player.camera.rotation.x = -0.3
	for i in 20: await physics_frame
	var n := 0
	var frame := 0
	for swing in range(2):
		tv.swing(game.prog.tool_interval(), func(): game._terrain_yield({"topsoil": 0.5}, []))
		while tv.phase >= 0.0 or frame % 3 != 0:
			await physics_frame
			frame += 1
			if frame % 3 == 0:
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png("%s/gif_%03d.png" % [out, n])
				n += 1
			if frame > 600: break
	print("frames ", n)
	quit()
