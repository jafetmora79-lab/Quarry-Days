extends SceneTree
## Stones thrown from the bag into a bucket (windowed): godot --path . --resolution 960x600 -s tools/shot_throw.gd -- <dir>
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
	game.player.global_position = Vector3(8.0, 0.2, -12.0)
	game.player.rotation.y = PI
	for i in 30: await physics_frame
	var pb = game._buckets()
	var p: Vector3 = game.player.global_position + game.player.global_transform.basis * Vector3(0.5, 0, -1.6)
	p.y = game._ground_y_at(p)
	var b: Dictionary = pb.place(p, {}, 0.0)
	game.state.inventory["limestone"] = 14
	game.state.equipped = "shovel"
	for i in 30: await physics_frame
	game.throw_bag_into_bucket(b["body"])
	var n := 0
	for i in 60:
		await physics_frame
		if i % 7 == 3 and n < 6:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/throw_%d.png" % [out, n])
			n += 1
	quit()
