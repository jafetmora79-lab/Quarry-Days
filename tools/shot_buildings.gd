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
		["garage_out", Vector3(cx, 3.0, 5.0), Vector3(cx, 1.8, 18.0), false],
		["garage_in", Vector3(cx - 7.5, 3.6, 15.4), Vector3(cx + 1.0, 0.8, 21.5), true],
		["home_wing", h + Vector3(-2.6, 1.6, -1.7), h + Vector3(-4.4, 0.9, 1.8), false],
		["home_cabin", h + Vector3(1.2, 1.6, -1.9), h + Vector3(-0.4, 0.9, 1.9), false],
		["workshop", t + Vector3(0, 1.7, -1.7), t + Vector3(0, 0.9, 2.0), false],
		["shed", sh + Vector3(0, 1.7, -1.7), sh + Vector3(0, 0.9, 2.0), false],
		["office", of + Vector3(0, 1.7, -1.7), of + Vector3(0, 0.9, 2.0), false],
		["home_out", h + Vector3(-9, 3.0, -9), h + Vector3(-1.5, 1.3, 0), false]]
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
