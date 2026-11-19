extends SceneTree
## Every held item in first person (idle + mid-swing) and its hotbar picture, for the collage:  godot --path . --resolution 960x600 -s tools/shot_held_all.gd -- <dir>
func _initialize():
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
func run():
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	Engine.set_meta("qd_skip_title", true)
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	await frames(10)
	game.hud.close_card()
	if game.coach != null:
		game.coach._mark_all()
		if game.coach.flying():
			game.coach._end_fly()
	game.item_tips.enabled = false
	game.hud.visible = false
	game.player.global_position = Vector3(8.0, 0.2, -12.0)
	game.player.rotation.y = PI
	var prog = game.prog
	for id in prog.gear_ids():
		if not (id in game.state.gear):
			game.state.gear.append(id)
	var entries := []
	for t in range(5):
		entries.append(["ladder_%d" % t, "", t])
	for id in prog.gear_ids():
		var kind := str(prog.cfg["gear"][id].get("kind", "tool"))
		if kind == "tool":
			entries.append([id, id, game.state.tool_tier])
	var n := 0
	for e in entries:
		game.state.tool_tier = int(e[2])
		game.state.equipped = str(e[1])
		await frames(50)
		game.player.tool_view.equip(prog.model_tier(), true)
		await frames(20)
		await snap("%s/held_%02d_%s_idle.png" % [out, n, e[0]])
		game.player.tool_view.swing(0.5, func(): pass)
		await frames(9)
		await snap("%s/held_%02d_%s_swing.png" % [out, n, e[0]])
		await frames(40)
		# the hotbar picture
		var mk: String = str(e[1]) if str(e[1]) in GearModels.IDS else ToolModels.key_of(int(e[2]))
		var th = game.hud.thumbs
		var tex = null
		for k in 200:
			if str(e[1]) == "ramp_plan":
				tex = th.get_thumb("tool:ramp_miniature", Callable(QuarryHotbar, "ramp_miniature"), "tool", 160)
			elif str(e[1]) == "bucket":
				tex = th.get_thumb("tool:bucket_big", func(): return GearModels.bucket_tool(), "tool", 160)
			else:
				tex = th.get_thumb("tool:" + mk + "_big", func(): return ToolModels.load_tool(mk), "tool", 160)
			if tex != null:
				break
			await physics_frame
		if tex != null:
			tex.get_image().save_png("%s/held_%02d_%s_icon.png" % [out, n, e[0]])
		else:
			print("NO ICON ", e[0])
		print("done ", e[0])
		n += 1
	quit()
