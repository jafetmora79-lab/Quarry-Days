extends SceneTree
## First-person tool poses for comparing the hands with the reference mockup (windowed run):  godot --path . --resolution 1280x720 -s tools/shot_hands.gd -- <dir> [slot ...]
func _initialize():
	call_deferred("run")

func shot(name: String, out: String) -> void:
	for i in 40:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func run():
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
	for i in 10: await physics_frame
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	for i in 10: await physics_frame
	game.hud.close_card()
	game.item_tips.enabled = false
	game.hud.visible = false
	game.player.global_position = Vector3(8.0, 0.2, -12.0)
	game.player.rotation.y = PI
	var slots := ["shovel", "", "ramp_plan", "repaired_pickaxe", "sledgehammer"]
	for i in range(slots.size()):
		game.state.equipped = slots[i]
		game.player.tool_view.equip(game.prog.model_tier(), true)
		await shot("hand_slot%d" % (i + 1), out)
	quit()
