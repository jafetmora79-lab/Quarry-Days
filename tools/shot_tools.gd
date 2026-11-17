extends SceneTree
## First-person tool poses for review (windowed): godot --path . --resolution 960x600 -s tools/shot_tools.gd -- <dir> <key> [key ...]   keys: ladder_0..4 or a tool id; "all" = every tool
## writes <dir>/tool_<key>_<state>.png for idle, wind (early swing), mid, recovery; the shovel also: insert, lift, carry, dump
func _initialize():
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
func run():
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "."
	var keys: Array = []
	for i in range(1, args.size()):
		keys.append(args[i])
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
	game.item_tips.enabled = false
	game.hud.visible = false
	game.player.global_position = Vector3(8.0, 0.2, -12.0)
	game.player.rotation.y = PI
	var prog = game.prog
	for id in prog.gear_ids():
		if not (id in game.state.gear):
			game.state.gear.append(id)
	if keys.is_empty() or keys[0] == "all":
		keys = ["ladder_0", "ladder_1", "ladder_2", "ladder_3", "ladder_4"]
		for id in prog.gear_ids():
			if str(prog.cfg["gear"][id].get("kind", "tool")) == "tool":
				keys.append(id)
	var pitch: float = float(OS.get_environment("QD_PITCH")) if OS.has_environment("QD_PITCH") else -0.25
	for k in keys:
		var tier := 0
		var eq := ""
		if str(k).begins_with("ladder_"):
			tier = int(str(k).substr(7))
		else:
			eq = str(k)
		game.state.tool_tier = tier
		game.state.equipped = eq
		await frames(50)
		var tv = game.player.tool_view
		tv.equip(prog.model_tier(), true)
		game.player.camera.rotation.x = pitch
		await frames(25)
		print("DBG ", k, " pivot_rot ", tv.pivot.rotation, " pos ", tv.position, " model_y_in_cam ", game.player.camera.global_basis.inverse() * tv.model.global_basis.y, " tier ", tv.tier, " scale ", tv.model.scale, " rot ", tv.model.rotation)
		await snap("%s/tool_%s_idle.png" % [out, k])
		var swinging: bool = str(prog.tool().get("class", "")) not in ["survey", "carry"]
		var is_shovel: bool = eq == "shovel"
		if swinging and not bool(tv._def(tv.tier).get("power", false)):
			var impact := func():
				if is_shovel:
					tv.set_payload("topsoil")
			tv.swing(prog.tool_interval(), impact)
			var marks: Array = [["wind", 0.12], ["mid", 0.36], ["lift", 0.58], ["carry", 0.72], ["dump", 0.84], ["recover", 0.95]] if is_shovel else [["wind", 0.3], ["mid", 0.58], ["recover", 0.85]]
			tv.duration = 100000.0                         # hold each phase still for the picture
			tv.impact_done = true
			for m in marks:
				tv.phase = float(m[1])
				if is_shovel and float(m[1]) >= 0.34 and not tv.has_payload():
					tv.set_payload("topsoil")                # (the strike that collected it)
				await frames(10)
				await snap("%s/tool_%s_%s.png" % [out, k, m[0]])
			tv.phase = 1.0
			tv._dump_payload(false)
			while tv.phase >= 0.0:
				await physics_frame
		elif bool(tv._def(tv.tier).get("power", false)):
			tv.operating = true
			await frames(25)
			await snap("%s/tool_%s_mid.png" % [out, k])
			tv.operating = false
			await frames(25)
			await snap("%s/tool_%s_recover.png" % [out, k])
		print("done ", k)
	quit()
