extends SceneTree
## The excavator's repair kit in the real game (windowed run):  godot --path . --resolution 1100x700 -s tools/shot_repair.gd -- <dir> [mode]
## mode "kit" (default) shows the kit's three states from the vantage points; mode "seq:<fuel|hose|battery>" plays that repair and saves a frame every few frames.
func _initialize():
	call_deferred("run")
func shot(name: String, out: String, frames := 8) -> void:
	for i in frames:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func look(cam: Camera3D, from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to)
func run():
	var out := "."
	var mode := "kit"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		mode = args[1]
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
	var v = game._starter_vehicle()
	print("STARTER ", v, " kit ", v.repair_kit if v else null)
	var cam := Camera3D.new()
	cam.name = "ShotCam"
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	game.player.global_position = v.global_position + Vector3(0, 0, 60)
	var kit = v.repair_kit
	if mode == "kit":
		for st in [[false, false, false, "broken"], [true, true, true, "fixed"]]:
			kit.apply_state(st[0], st[1], st[2])
			await physics_frame
			var t: Transform3D = kit.turret_part.global_transform
			var views := {"fuel": [kit.m("FuelFiller").global_position + t.basis * Vector3(0.9, 0.6, 0.9), kit.m("FuelFiller").global_position],
				"battery": [kit.m("BatteryTray").global_position + t.basis * Vector3(-0.2, 0.9, 0.95), kit.m("BatteryTray").global_position + Vector3(0, 0.1, 0)],
				"hose": [kit.m("HoseStart").global_position + t.basis * Vector3(1.9, 0.5, 0.2), (kit.m("HoseStart").global_position + kit.m("HoseEnd").global_position) * 0.5]}
			for k in views:
				look(cam, views[k][0], views[k][1])
				await shot("%s_%s" % [k, st[3]], out)
	elif mode.begins_with("seq:"):
		var which := mode.substr(4)
		game.safety.enabled = false
		kit.apply_state(which != "battery" and false, false, false)
		game.prog.excavator_state()["battery"] = false
		game.prog.pick_up_part(which)
		print("CARRIED ", game.prog.carried_part())
		# stand the player where a person would, a few metres from the machine
		game.player.global_position = v.global_position + Vector3(4.5, 0.2, 3.0)
		game.player.camera.current = true
		game._install_part(v)
		var frame := 0
		var t_end := Time.get_ticks_msec() + 16000
		var last_seq = game.repair_seq
		var gcam: Camera3D = game.player.camera
		while game.repair_seq != null and Time.get_ticks_msec() < t_end:
			await process_frame
			frame += 1
			if frame % 40 == 1:
				print("DBG frame ", frame, " cam ", gcam.global_position, " tool vis ", game.player.tool_view.visible, " in tree ", game.player.tool_view.is_visible_in_tree(), " turret ", v.turret.global_position, " current ", gcam.current)
			if frame % 3 == 0:
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png("%s/seq_%s_%03d.png" % [out, which, frame / 3])
		print("SEQ done frames ", frame, " repaired ", game.prog.repair_done(which))
	quit()
