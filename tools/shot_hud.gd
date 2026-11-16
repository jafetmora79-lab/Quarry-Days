extends SceneTree
## Saves the in-game HUD and a notification (windowed run):  godot --path . --resolution 1280x720 -s tools/shot_hud.gd -- <dir>
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
	for i in 30:
		await physics_frame
	game.hud.toast("Sold stone", "+$120", "sale")
	await shot("hud_play", out)
	game.item_tips.offer("gear:ramp_plan")
	for i in 80:
		await physics_frame
	await shot("tip_ramp", out)
	game.item_tips._close()
	game.item_tips.offer("vehicle:compact_excavator")
	for i in 80:
		await physics_frame
	await shot("tip_excavator", out)
	quit()
