extends SceneTree
## The ways of putting material into the Cash Hopper (windowed): godot --path . --resolution 1100x700 -s tools/shot_intake.gd -- <dir>
func _initialize():
	call_deferred("run")
func shot(name: String, out: String, frames := 10) -> void:
	for i in frames:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func run():
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
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
	game.hud.visible = false
	game.item_tips.enabled = false
	var h: int = game.business.cash_hopper_indices()[0]
	var node: Node3D = game.output_nodes[h]
	var v = node.get_node("CashHopperView")
	var c: Vector3 = node.global_position
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	game.player.global_position = c + Vector3(0, 0, 60)
	game.business.outputs[h]["tier"] = 0
	var cases := [["hand", "limestone", 16, Vector3(-1.1, 1.3, -1.5)], ["shovel", "gold_ore", 14, Vector3(-1.2, 1.4, -1.3)], ["bucket", "coal", 18, Vector3(-0.8, 1.7, -0.9)],
		["machine", "iron_ore", 20, Vector3(-2.4, 2.6, -1.4)], ["truck", "crushed_stone", 30, Vector3(2.6, 2.3, -0.4)]]
	for cs in cases:
		cam.global_position = c + Vector3(-2.6, 2.6, -4.2)
		cam.look_at(c + Vector3(0, 1.5, 0))
		v.intake(cs[0], cs[1], cs[2], c + cs[3])
		for k in range(3):
			await shot("intake_%s_%d" % [cs[0], k], out, 9 if cs[0] != "truck" else 14)
		for i in 150: await physics_frame
	quit()
