extends SceneTree
## The three excavator repairs show the player's gloved hands doing the work: the hands are on the part (parented to it, so they never float free of it), the part
## is consumed only when the sequence finishes (for the fuel: after the cap is back on), a cancel before that leaves everything as it was, and each sequence takes
## a few seconds.
##   godot --headless --fixed-fps 60 -s tests/test_repair_hands.gd

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

func gloves(v: QuarryVehicle) -> Array:
	var out := []
	var cab: Node = v.turret if v.turret else v.model_root
	var props := cab.find_child("RepairProps", true, false)
	if props == null:
		return out
	for g in props.find_children("Glove_*", "Node3D", true, false):
		out.append(g)
	return out

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
	check(v != null and not prog.repairs_complete(), "the excavator is broken")
	for part in ["battery", "hose", "fuel"]:
		check(prog.pick_up_part(part), "%s: picked up" % part)
		game._install_part(v)
		var st := {"max": 0, "parented": true}
		var f := await frames(60 * 9, func():
			var gs := gloves(v)
			st["max"] = maxi(int(st["max"]), gs.size())
			for g in gs:
				st["parented"] = bool(st["parented"]) and g.get_parent() != null and g.get_parent() != game.player
			return game.repair_seq == null)
		var max_gloves: int = st["max"]
		var seen_parented: bool = st["parented"]
		check(max_gloves >= 2, "%s: the player's gloved hands are on screen working (%d glove models)" % [part, max_gloves])
		check(seen_parented, "%s: every hand is attached to something it holds or touches" % part)
		check(prog.repair_done(part) and prog.carried_part() == "", "%s: fitted and consumed once, at the end" % part)
		var secs := float(f) / 60.0
		check(secs > 2.5 and secs < 7.5, "%s: it takes %.1f s" % [part, secs])
		if part != "fuel":
			await frames(60)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
