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
	var views := [["north", Vector3(0, 3.0, 8.0), Vector3(0, 14.0, -160.0)], ["portal", Vector3(-9.0, 2.2, 25.4), Vector3(-30.0, 2.5, 25.4)],
		["east", Vector3(120.0, 5.0, 10.0), Vector3(190.0, 10.0, -30.0)], ["west", Vector3(-124.0, 5.0, 10.0), Vector3(-190.0, 8.0, -40.0)]]
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
