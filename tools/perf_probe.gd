extends SceneTree
## Frame-time probe on real hardware (windowed run, no screenshots):  godot --path . --resolution 1280x720 -s tools/perf_probe.gd -- <terrain 1|0> [seconds]
## Prints the mean / 95th percentile / worst frame time (ms) and the process time split, standing at the quarry edge looking over the dug ground, then while digging.
func _initialize():
	call_deferred("run")
func run():
	var args := OS.get_cmdline_user_args()
	var with_terrain := args.size() < 1 or args[0] != "0"
	var secs := float(args[1]) if args.size() > 1 else 8.0
	var digging := args.size() < 3 or args[2] != "0"
	Engine.set_meta("qd_skip_title", true)
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.live_terrain_enabled = with_terrain
	root.add_child(game)
	await process_frame
	for i in 20: await physics_frame
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	for i in 10: await physics_frame
	game.hud.close_card()
	game.prog.cleanup["done"] = true
	game.player.global_position = Vector3(0.0, 0.3, -20.0)
	game.player.rotation.y = 0.0
	game.player.pitch = -0.25
	# dig a trench so the terrain has real work to do
	if with_terrain:
		for z in range(0, 40):
			game.state.equipped = "shovel"
			game._terrain_strike(Vector3(-6.0 + 0.5 * float(z % 24), 0.0, -30.0 - 0.5 * float(z / 24)))
	var ft := []
	var t_end := Time.get_ticks_msec() + int(secs * 1000.0)
	var last := Time.get_ticks_usec()
	var n := 0
	var phys_sum := 0.0
	var proc_sum := 0.0
	while Time.get_ticks_msec() < t_end:
		await process_frame
		var now := Time.get_ticks_usec()
		ft.append(float(now - last) / 1000.0)
		last = now
		n += 1
		phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
		if with_terrain and digging and n % 20 == 0:
			game.dig_audio._cool.clear()
			game._terrain_strike(Vector3(-4.0 + 0.4 * float(n % 30), 0.0, -32.0))         # keep digging while measuring
	ft.sort()
	var mean := 0.0
	for v in ft:
		mean += v
	mean /= float(ft.size())
	var draw := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("PERF digging=%s terrain=%s frames=%d mean=%.2f ms (%.0f fps) p95=%.2f worst=%.2f draws=%d prims=%d proc=%.2f phys=%.2f" % [str(digging), str(with_terrain), ft.size(), mean, 1000.0 / mean, ft[int(ft.size() * 0.95)], ft[ft.size() - 1], draw, prims, proc_sum / float(n) * 1000.0, phys_sum / float(n) * 1000.0])
	quit()
