extends SceneTree
## Saves frames of the opening cinematic (windowed run, real time, about 2 minutes):  godot --path . --resolution 1280x720 -s tools/shot_opening.gd -- <dir>
func _initialize() -> void:
	call_deferred("run")

func shot(name: String, out: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)

func run() -> void:
	var out := "."
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Engine.set_meta("qd_skip_title", true)
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = true
	root.add_child(game)
	await process_frame
	for i in 10:
		await physics_frame
	var sc = game.opening_scene
	var marks := [["a_road_cab", 7.0], ["b_road_turn", 12.0], ["c_mouth", 17.5], ["d_tunnel", 26.0], ["e_tunnel_late", 33.0], ["f_yard", 42.0]]
	var mi := 0
	while sc.phase == "drive" or sc.phase == "exit":
		await physics_frame
		if sc.clock >= 9.0 and not FileAccess.file_exists(out + "/a2_walt_wheel.png"):
			sc.look_yaw = 0.8
			sc.look_pitch = -0.1
			for i in 20:
				await physics_frame
			await shot("a2_walt_wheel", out)
			sc.look_yaw = 0.0
			sc.look_pitch = 0.0
		if mi < marks.size() and sc.clock >= float(marks[mi][1]):
			await shot(marks[mi][0], out)
			mi += 1
	while sc.phase != "yard":
		await physics_frame
	for i in 150:
		await physics_frame
	await shot("g_outside_walt", out)
	while not sc.deed_given and sc.active:
		await physics_frame
		if sc.deed != null and sc.deed.get_parent() == game.world and not FileAccess.file_exists(out + "/h_deed_offered.png"):
			for i in 40:
				await physics_frame
			await shot("h_deed_offered", out)
	for i in 30:
		await physics_frame
	await shot("i_deed_hands", out)
	for i in 160:
		await physics_frame
	await shot("j_deed_read", out)
	while sc.phase != "post":
		await physics_frame
	for i in 60:
		await physics_frame
	await shot("k_post", out)
	quit(0)
