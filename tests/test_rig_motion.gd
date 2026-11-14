extends SceneTree
## Drilling rigs: stabilisers deploy while working and fold when idle, the machine hums on its jacks only while extracting, stronger machines are visibly
## stronger. Extraction itself is untouched (tick_rigs).   godot --headless --fixed-fps 60 -s tests/test_rig_motion.gd
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
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false
	game.autosave_enabled = false
	root.add_child(game)
	await process_frame
	await frames(3)
	game.hud.close_card()
	game.tutorial_visible = false
	var prog: QuarryProgression = game.prog
	game.state.money = 100000
	prog.stage = prog.stage_index("large")
	check(game.install_rig("drill_rig", "stone_mountain") and game.rig_nodes.size() == 1, "a drilling rig is installed")
	var rig = game.rig_nodes[0]
	var r: Dictionary = prog.rigs[0]
	check(rig.outriggers.size() == 4, "it has four stabiliser legs")
	game.state.money = 5000
	var folded_y: float = rig.outriggers[0]["foot"].position.y
	var folded_x: float = absf(rig.outriggers[0]["pivot"].position.x)
	await frames(600, func(): return rig.work > 0.95)
	check(bool(r["working"]) and rig.work > 0.9, "the rig is working")
	var deployed_y: float = rig.outriggers[0]["foot"].position.y
	var deployed_x: float = absf(rig.outriggers[0]["pivot"].position.x)
	check(deployed_y < 0.02, "the jack pads are planted on the ground while working (%.2f)" % deployed_y)
	check(deployed_x > folded_x + 0.15, "the beams slide out to the sides (%.2f -> %.2f)" % [folded_x, deployed_x])
	var base_y: float = rig.pad_pos.y
	var wobble := 0.0
	for i in range(120):
		await physics_frame
		wobble = maxf(wobble, absf(rig.position.y - base_y))
	check(wobble > 0.0005 and wobble < 0.02, "the machine hums on its jacks while drilling (%.4f m)" % wobble)
	var units_before: int = prog.units_left("stone_mountain")
	r["on"] = false
	await frames(400)
	check(rig.work < 0.05 and rig.outriggers[0]["foot"].position.y > deployed_y + 0.15, "switched off: the jacks fold up")
	var still := 0.0
	for i in range(60):
		await physics_frame
		still = maxf(still, absf(rig.position.y - base_y))
	check(still < 0.0002, "and it is perfectly still")
	check(prog.units_left("stone_mountain") == units_before, "nothing was mined while it was switched off")
	check(float(prog.machine("improved_rig")["dps"]) > float(prog.machine("drill_rig")["dps"]), "the improved rig is the stronger machine")
	var br = load("res://scripts/rig.gd").new()
	br.rtype = "heavy_breaker"
	check(br.power == 1.0 and not br.heavy, "(a rig that is not set up yet has neutral power)")
	br.free()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
