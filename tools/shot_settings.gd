extends SceneTree
## The Settings > Display tab and the hopper's top screen (windowed): godot --path . --resolution 1272x706 -s tools/shot_settings.gd -- <dir>
func _initialize():
	call_deferred("run")
func run():
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	for i in 40: await physics_frame
	var sv := game.title.get("col") as Node
	for b in game.title.find_children("*", "Button", true, false):
		if str((b as Button).text) == "SETTINGS":
			(b as Button).pressed.emit()
	for i in 6: await physics_frame
	for b in game.title.find_children("Tab_Display", "Button", true, false):
		(b as Button).pressed.emit()
	for i in 6: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/settings_display.png")
	quit()
