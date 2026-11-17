extends SceneTree
## The seated driver in each drivable machine (windowed): godot --path . --resolution 960x600 -s tools/shot_driver.gd -- <dir>
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
	game.hud.visible = false
	game.item_tips.enabled = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	game.add_child(cam)
	cam.current = true
	var seen := {}
	var list := [game._starter_vehicle()]
	for id in game.vehicle_nodes:
		var v = game.vehicle_nodes[id]
		if not seen.has(v.vtype):
			seen[v.vtype] = true
			list.append(v)
	var n := 0
	for v in list:
		if v == null or not QuarryBoarding.has_cab(v):
			print("NOCAB ", v.vtype if v else "null")
			continue
		var d := SeatedDriver.attach_to(v)
		d.first_person = false
		d.show_driver(true)
		for i in 6: await physics_frame
		var c := QuarryBoarding.cab(v)
		var eye: Vector3 = (c["ref"] as Node3D).to_global(c["eye"])
		var side: float = c["side"]
		var ref: Node3D = c["ref"]
		var out_dir: Vector3 = ref.global_basis * Vector3(side, 0.0, 0.0)
		cam.global_position = eye + out_dir * 2.2 + Vector3(0, 0.3, 0.6)
		cam.look_at(eye - Vector3(0, 0.5, 0))
		for i in 4: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/drv_%d_%s.png" % [out, n, v.vtype])
		print("shot ", v.vtype)
		d.show_driver(false)
		n += 1
	quit()
