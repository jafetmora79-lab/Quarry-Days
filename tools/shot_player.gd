extends SceneTree
## The protagonist in the game (windowed): godot --path . --resolution 960x600 -s tools/shot_player.gd -- <dir>
## on foot (idle, walk, mining swing, carrying a bucket) with the satchel in its four states, and seated in the excavator and the truck.
func _initialize():
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
func run():
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	Engine.set_meta("qd_skip_title", true)
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	await frames(10)
	game.hud.close_card()
	game.hud.visible = false
	game.item_tips.enabled = false
	game.player.global_position = Vector3(8.0, 0.2, -12.0)
	game.player.rotation.y = PI
	await frames(30)
	var pb: PlayerBody = game.player_body
	game.player_body = null                         # the game stops driving the body: the poses below are the ones set here
	pb.set_shadow_only(false)
	pb.first_person = false
	var cam := Camera3D.new()
	cam.fov = 45
	game.add_child(cam)
	cam.current = true
	var base: Vector3 = game.player.global_position
	var fwd: Vector3 = -game.player.global_transform.basis.z
	var right: Vector3 = game.player.global_transform.basis.x
	# the four satchel states, seen from behind and the side
	var states := [0, 5, 14, 18]          # of a bag that holds 18
	for i in states.size():
		game.state.inventory["limestone"] = states[i]
		await frames(4)
		cam.global_position = base - fwd * 3.0 + right * 1.9 + Vector3(0, 1.4, 0)
		cam.look_at(base + Vector3(0, 0.95, 0))
		await frames(2)
		await snap("%s/pl_bag_%d.png" % [out, i])
	game.state.inventory["limestone"] = 0
	# front, side, 3/4 idle
	for k in [["front", fwd * 3.2 + Vector3(0, 1.1, 0)], ["side", right * 3.2 + Vector3(0, 1.1, 0)], ["back", -fwd * 3.2 + Vector3(0, 1.1, 0)]]:
		cam.global_position = base + k[1]
		cam.look_at(base + Vector3(0, 0.95, 0))
		await frames(3)
		await snap("%s/pl_%s.png" % [out, k[0]])
	# walking: freeze a few phases of the walk cycle
	cam.global_position = base + right * 3.2 + Vector3(0, 1.1, 0)
	cam.look_at(base + Vector3(0, 0.95, 0))
	for i in 4:
		for j in 6:
			pb.animate(0.05, "walk", 2.2, "miner", false, -1.0, 0.0)
		await frames(2)
		await snap("%s/pl_walk_%d.png" % [out, i])
	# mining swing (generic reach) and carrying a bucket
	pb.animate(0.1, "work", 0.0, "miner", false, 0.5, 0.0)
	await frames(2)
	await snap("%s/pl_work.png" % out)
	for j in 20:
		pb.animate(0.05, "idle", 0.0, "miner", true, -1.0, 0.0)
	await frames(2)
	await snap("%s/pl_carry.png" % out)
	# seated in the excavator and the truck
	var vs := [game._starter_vehicle()]
	for id in game.vehicle_nodes:
		var v = game.vehicle_nodes[id]
		if v.vtype != "starter_excavator":
			vs.append(v)
			break
	var n := 0
	for v in vs:
		if v == null or not QuarryBoarding.has_cab(v):
			continue
		var d := SeatedDriver.attach_to(v)
		d.first_person = false
		d.show_driver(true)
		await frames(8)
		var c := QuarryBoarding.cab(v)
		var eye: Vector3 = (c["ref"] as Node3D).to_global(c["eye"])
		var side: float = c["side"]
		var outd: Vector3 = (c["ref"] as Node3D).global_basis * Vector3(side, 0, 0)
		cam.global_position = eye + outd * 2.0 + Vector3(0, 0.2, 0.7)
		cam.look_at(eye - Vector3(0, 0.45, 0))
		await frames(3)
		await snap("%s/pl_seat_%d_%s.png" % [out, n, v.vtype])
		d.show_driver(false)
		n += 1
	quit()
