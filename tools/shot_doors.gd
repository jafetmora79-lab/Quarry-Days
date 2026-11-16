extends SceneTree
## Saves what the player would see inside and outside the yard buildings (windowed run):  godot --path . --resolution 800x500 -s tools/shot_buildings.gd -- <dir>

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
	var ox: float = game.GARAGE_DX
	var cx := 4.9 + ox
	var h: Vector3 = game.HOME_POS
	var t: Vector3 = game.TOOLSHED_POS
	var sh: Vector3 = game.SHED_POS
	var of: Vector3 = game.OFFICE_POS
	var views := [
		["home_front", h + Vector3(0.0, 1.6, -5.0), h + Vector3(0.0, 1.2, -2.35), false],
		["home_front_l", h + Vector3(-3.5, 1.6, -4.5), h + Vector3(-1.5, 1.2, -2.35), false],
		["home_wing_door", h + Vector3(-6.5, 1.6, -4.0), h + Vector3(-4.1, 1.2, -2.35), false],
		["workshop_front", t + Vector3(0, 1.6, -5.0), t + Vector3(0, 1.2, -2.35), false],
		["shed_front", sh + Vector3(0, 1.6, -5.0), sh + Vector3(0, 1.2, -2.35), false],
		["office_front", of + Vector3(0, 1.6, -5.0), of + Vector3(0, 1.2, -2.35), false],
		["garage_front", Vector3(cx, 2.2, 3.0), Vector3(cx, 1.8, 14.0), false],
		["home_door_close", h + Vector3(0.0, 1.5, -3.6), h + Vector3(0.0, 1.2, -2.35), false]]
	var cam := Camera3D.new()
	cam.fov = 70.0
	root.add_child(cam)
	cam.current = true
	for v in views:
		if game.art.garage_roof != null:
			game.art.garage_roof.visible = not v[3]
		cam.global_position = v[1]
		cam.look_at(v[2])
		for i in 25:
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
	quit()
