extends SceneTree
## The Cash Hopper: model views and its animation states (windowed run):  godot --path . --resolution 1100x700 -s tools/shot_hopper.gd -- <dir>
func _initialize():
	call_deferred("run")
func shot(name: String, out: String, frames := 30) -> void:
	for i in frames:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func look(cam: Camera3D, from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to)
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
	game.hud.visible = false
	game.item_tips.enabled = false
	var h: int = game.business.cash_hopper_indices()[0]
	var node: Node3D = game.output_nodes[h]
	var cam := Camera3D.new()
	cam.name = "ShotCam"
	cam.fov = 55.0
	root.add_child(cam)
	cam.current = true
	game.player.global_position = node.global_position + Vector3(0, 0, 60)
	var c: Vector3 = node.global_position
	look(cam, c + Vector3(-2.6, 1.8, -3.4), c + Vector3(0, 1.0, 0))
	await shot("hopper_front_idle", out)
	look(cam, c + Vector3(3.2, 1.6, 2.8), c + Vector3(0, 1.0, 0))
	await shot("hopper_back_idle", out)
	game.business.outputs[h]["items"]["crushed_stone"] = 200
	game.business.outputs[h]["tier"] = 0
	look(cam, c + Vector3(-2.2, 1.5, -3.0), c + Vector3(0, 1.0, 0))
	for i in 20:
		await physics_frame
	for k in range(8):
		await shot("hopper_seq_%d" % k, out, 5)
	quit()
