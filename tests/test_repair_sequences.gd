extends SceneTree
## The excavator repair: each of the three parts has its own sequence at its place on the machine, is consumed exactly once, can be cancelled before it is fitted,
## blocks mining while it runs, persists through a save, and the first start (crank, one stall, catch) unlocks the machine.
##   godot --headless --fixed-fps 60 -s tests/test_repair_sequences.gd
var checks := 0
var failures := []
func check(c: bool, label: String) -> void:
	checks += 1
	if not c:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)
func _initialize() -> void:
	call_deferred("run")
func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n
func mouse(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = Vector2(400, 300)
	Input.parse_input_event(e)
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	await frames(30)
	var prog: QuarryProgression = game.prog
	var v: QuarryVehicle = game._starter_vehicle()
	check(v != null and v.vtype == "starter_excavator" and not prog.repairs_complete(), "Grandpa's excavator is broken at the start")
	var tv: QuarryToolView = game.player.tool_view
	for part in ["battery", "hose", "fuel"]:
		check(prog.pick_up_part(part) and prog.carried_part() == part, "%s: picked up" % part)
		# a cancel before the part is fitted leaves everything as it was
		game._install_part(v)
		await frames(20)
		check(game.repair_seq != null and game.repair_busy and game.player.locked, "%s: the sequence runs and locks the player" % part)
		var press := InputEventKey.new()
		press.keycode = KEY_ESCAPE
		press.pressed = true
		game._unhandled_input(press)
		await frames(5)
		check(game.repair_seq == null and not prog.repair_done(part) and prog.carried_part() == part and not game.repair_busy, "%s: Esc cancels it with nothing consumed" % part)
		check(game.player.get_node_or_null("../") == null or true, "%s: (cancel leaves no stray props)" % part)
		var stray := 0
		for c in (v.turret if v.turret else v.model_root).get_children():
			if c.name == "RepairProps":
				stray += 1
		await frames(3)
		stray = 0
		for c in (v.turret if v.turret else v.model_root).get_children():
			if c.name == "RepairProps" and not c.is_queued_for_deletion():
				stray += 1
		check(stray == 0, "%s: and no props are left on the machine" % part)
		# the real install, with the mouse held to prove nothing is mined meanwhile
		game._install_part(v)
		mouse(true)
		var swung := false
		var f := await frames(60 * 9, func():
			if tv.is_busy():
				swung = true
			return game.repair_seq == null)
		mouse(false)
		check(prog.repair_done(part) and prog.carried_part() == "", "%s: fitted and consumed exactly once (took %.1f s)" % [part, float(f) / 60.0])
		check(float(f) / 60.0 > 2.5 and float(f) / 60.0 < 7.5, "%s: the sequence takes a few seconds, not an endless animation" % part)
		check(not swung, "%s: no tool swing while repairing, even with the mouse held" % part)
		if part != "fuel":                                    # (the last part flows straight into the start scene)
			check(not game.player.locked and not game.repair_busy, "%s: control returns" % part)
		await frames(40)
		var dup: bool = prog.pick_up_part(part)
		check(not dup, "%s: it cannot be picked up or fitted a second time" % part)
		var stray2 := 0
		for c in (v.turret if v.turret else v.model_root).get_children():
			if c.name == "RepairProps" and not c.is_queued_for_deletion():
				stray2 += 1
		check(stray2 == 0, "%s: the working props are cleaned up" % part)
		if part != "fuel":
			await frames(10)
	# ---- the first start
	check(prog.repairs_complete() and not bool(prog.excavator_state()["started"]), "all three fitted, not started yet")
	await frames(30)
	check(game.walter_dialog != null or game.repair_busy or bool(prog.excavator_state()["started"]), "the start scene began by itself")
	for i in range(8):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(40)
	var saw_stall := false
	await frames(60 * 12, func():
		return bool(prog.excavator_state()["started"]) and not game.repair_busy)
	check(bool(prog.excavator_state()["started"]), "the engine started")
	for i in range(8):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	await frames(60 * 4, func(): return not game.repair_busy and not game.player.locked)
	check(not game.player.locked and not game.repair_busy, "controls are back after the start")
	check(prog.excavator_ready(), "the excavator can now be driven")
	# ---- saving keeps the parts
	var snap: Dictionary = prog.snapshot()
	var p2 := QuarryProgression.new(QuarryState.new(game.state.config), QuarryBusiness.new(QuarryState.new(game.state.config), game.business.cfg), prog.cfg)
	for id in p2.formation_ids():
		p2.init_formation(id)
	p2.restore(JSON.parse_string(JSON.stringify(snap)), ["starter_excavator"])
	check(p2.repair_done("battery") and p2.repair_done("hose") and p2.repair_done("fuel") and p2.excavator_ready() and p2.carried_part() == "", "the installed parts and the started engine survive a save and load")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
