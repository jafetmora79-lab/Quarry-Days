extends SceneTree
## Placed buckets in the world (windowed): godot --path . --resolution 960x600 -s tools/shot_buckets.gd -- <dir>
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
	for i in 20: await physics_frame
	var pb: PlacedBuckets = game._buckets()
	var base: Vector3 = game.player.global_position
	var loads := [{}, {"topsoil": 18}, {"topsoil": 9}, {"gravel": 18}, {"limestone": 18}, {"coal": 12}, {"iron_ore": 18}, {"gold_ore": 18}, {"topsoil": 9, "limestone": 9}, {"copper_ore": 6}]
	for k in range(loads.size()):
		var p := base + Vector3(-2.0 + float(k % 5) * 1.0, 0.0, 1.6 + float(k / 5) * 1.0)
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 5, 0), p - Vector3(0, 5, 0), 1)
		var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
		if h.is_empty(): continue
		pb.place(h["position"], loads[k], float(k))
	game.player.rotation.y = 0.0     # face -Z: buckets are at +Z of base; turn round
	game.player.rotation.y = PI
	game.state.equipped = "bucket"
	game.prog.select_slot(game.prog.hotbar().find("bucket"))
	for i in 60: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/bucket_world.png")
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.current = true
	cam.global_position = base + Vector3(0.0, 2.6, 0.2)
	cam.look_at(base + Vector3(0.0, 0.1, 2.1))
	cam.fov = 50.0
	game.hud.visible = false
	for i in 10: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/bucket_top.png")
	cam.queue_free()
	game.player.camera.current = true
	game.hud.visible = true
	game.state.hand_bucket = {"topsoil": 14}
	for i in 40: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/bucket_carry.png")
	quit()
