extends SceneTree
## Saves the Quarry OS desktop and a few windows (windowed run):  godot --path . --resolution 1280x720 -s tools/shot_os.gd -- <dir>
func _initialize() -> void:
	call_deferred("run")

func shot(name: String, out: String) -> void:
	for i in 12:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

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
	root.add_child(game)
	await process_frame
	for i in 10:
		await physics_frame
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	for i in 10:
		await physics_frame
	game.hud.close_card()
	game.item_tips.enabled = false
	game.item_tips.queue.clear()
	if game.item_tips.panel != null:
		game.item_tips._close()
	for i in 20:
		await physics_frame
	game._open_menu("manage")
	await shot("os_desktop", out)
	var os: QuarryOS = game.management.os
	os.open_app("catalog")
	await shot("os_catalog", out)
	os.open_app("sales")
	await shot("os_two_windows", out)
	quit()
