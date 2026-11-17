extends SceneTree
## Writes a save with the site's weeds and rubble already cleared (a fresh game past the intro): godot --headless -s tools/make_cleaned_save.gd  (APPDATA decides where user:// is)
func _initialize():
	call_deferred("run")
func run():
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 10: await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	for i in 20: await physics_frame
	var n := 0
	for id in game.prog.cleanup_ids():
		game.prog.cleanup["units"][str(id)] = 0
		game.prog.clear_cleanup_item(str(id))
		n += 1
	print("cleared ", n, " done=", game.prog.cleanup["done"], " left=", game.prog.cleanup_left())
	game._save(true)
	print("saved to ", ProjectSettings.globalize_path("user://quarry_save.json"))
	quit()
