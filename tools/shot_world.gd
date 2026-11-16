extends SceneTree
## Saves four views of the landscape (windowed run):  godot --path . --resolution 800x500 -s tools/shot_world.gd -- <dir> [hour]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var out := "."
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 10:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	for n in game.find_children("*", "", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).contains("title_menu"):
			n.visible = false
	game.hud.visible = false
	if args.size() > 1:
		game.state.clock_minutes = float(args[1]) * 60.0
	game._update_light()
	var wl = game.wildlife
	wl.enabled = false
	var d = wl.animals[0]
	d.root.visible = true
	d.root.global_position = d.anchor
	d.root.rotation.y = 2.2
	d.state = "graze"
	d.timer = 100.0
	var rb = wl.animals[2]
	rb.root.visible = true
	rb.root.global_position = rb.anchor + Vector3(1.5, 0, 1.0)
	rb.state = "idle"
	rb.timer = 100.0
	print("DEER AT ", d.anchor, " RABBIT ", rb.anchor)
	for i in 40:
		wl.step(0.05)
	var views := [["portal", Vector3(-9.0, 2.2, 25.4), Vector3(-30.0, 3.0, 25.4)], ["inside", Vector3(-32.0, 1.9, 25.4), Vector3(-110.0, 2.2, 25.4)],
		["exit", Vector3(-126.0, 2.2, 25.4), Vector3(-114.0, 3.0, 25.4)], ["mountain", Vector3(-8.0, 6.0, 40.0), Vector3(-60.0, 12.0, 25.4)]]
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	root.add_child(cam)
	cam.current = true
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		for i in 30:
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
	quit()
