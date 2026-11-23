extends SceneTree
## Aiming at a rubble heap: the pulsing red outline, and the minimap with its red markers (windowed):  godot --path . --resolution 1280x720 -s tools/shot_debris.gd -- <dir>
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
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
	game.prog.story["intro_seen"] = true
	if game.coach != null:
		game.coach._mark_all()
		if game.coach.flying():
			game.coach._end_fly()
	game.item_tips.enabled = false
	game.hud.close_card()
	var target: Node3D = null
	for id in game.cleanup_nodes:
		var n: Node3D = game.cleanup_nodes[id]
		if is_instance_valid(n) and not str(id).begins_with("w"):
			target = n
			break
	game.player.global_position = target.global_position + Vector3(0.0, 0.3, 2.4)
	game.player.rotation.y = 0.0
	game.player.pitch = -0.4
	for i in 40: await physics_frame
	for k in [0, 1]:
		for i in (18 if k == 0 else 25): await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/debris_%d.png" % [out, k])
	print("DBG target=", game.last_target, " outline=", game._debris_outline.active() if game._debris_outline else null)
	quit()
