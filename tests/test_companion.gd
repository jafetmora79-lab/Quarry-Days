extends SceneTree
## Phase 7.7: the dinosaur companion: egg, hatching, naming, growth, following, resting, tail smash (hardness rule), saves.
##   godot --headless --fixed-fps 60 -s tests/test_companion.gd

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

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	await frames(2)
	var prog: QuarryProgression = game.prog
	game.sleeping = false
	game.state.clock_minutes = 10.0 * 60.0
	# ---- only the scientist route brings the egg
	check(prog.companion_stage(0) == "" and game.companion_node == null, "1 no companion at the start")
	prog.story["fossil"] = "found"
	prog.fossil_choose("collector")
	await frames(40)
	check(prog.companion().get("state", "none") == "none" and game.egg_node == null, "2 the collector route brings no egg")
	prog.story["fossil"] = "found"
	prog.story["companion"] = {"state": "none"}
	var day0: int = game._sim_day()
	prog.current_day = day0
	prog.fossil_choose("scientist")
	check(prog.companion().get("state") == "pending" and not prog.companion_egg_waiting(day0), "3 the scientist route promises an egg for tomorrow, not today")
	game.hud.close_card()
	game.player.locked = false
	await frames(40)
	check(game.egg_node == null, "4 the egg is not there on the same day")
	game.state.clock_minutes += 1440.0
	await frames(70)
	check(game.egg_node != null and prog.companion_egg_waiting(prog.current_day), "5 the next day the egg waits by the yard")
	# ---- take the egg
	game._take_egg()
	check(prog.companion().get("state") == "egg" and "companion_egg" in prog.story["journal"], "6 taking the egg starts incubation and is journaled")
	game.hud.close_card()
	check(prog.companion_stage(prog.current_day) == "egg", "7 it is an egg at first")
	# ---- hatching after a couple of days
	game.state.clock_minutes += 1440.0 * float(prog.companion_cfg()["egg_days"])
	await frames(70)
	check(prog.companion().get("state") == "alive" and game.companion_node != null and game.egg_node == null, "8 the egg hatches into a living companion")
	check(game.hud.card_open() and game.hud.card_title.text == "IT HATCHED", "9 the hatching card shows")
	game.hud.close_card()
	await process_frame
	check(game.name_dialog != null, "10 then it asks for a name")
	var le: LineEdit = game.name_dialog.find_child("NameEdit", true, false)
	le.text = "Bruno"
	game._finish_naming(le.text)
	check(prog.companion()["name"] == "Bruno" and game.name_dialog == null and not game.player.locked, "11 the player names it")
	check(prog.companion_stage(prog.current_day) == "hatchling" and game.companion_node.stage == "hatchling" and game.companion_node.scale.x < 0.5, "12 it starts as a small hatchling")
	# ---- following
	game.player.global_position = Vector3(0, 0.2, 8)
	game.companion_node.global_position = Vector3(10, 0, 8)
	await frames(240)
	var d: float = Vector2(game.companion_node.global_position.x - game.player.global_position.x, game.companion_node.global_position.z - game.player.global_position.z).length()
	check(d < 4.0, "13 it follows the player (%.1f m away)" % d)
	game.player.global_position = Vector3(0, 0.2, 8) + Vector3(100, 0, 0)
	await frames(10)
	check(game.companion_node.global_position.distance_to(game.player.global_position) < 8.0, "14 it catches up when left far behind")
	game.player.global_position = Vector3(0, 0.2, 8)
	await frames(480)
	check(game.companion_node.resting, "15 it rests when the player stands still")
	# ---- hatchlings cannot smash
	var kind := "hillside_face_01"
	prog.cleanup["done"] = true
	prog.init_formation(kind)
	var col := prog.nearest_column(kind, prog.formation_origin_world(kind), true, 100.0)
	check(col >= 0, "16 there is exposed rock to try on")
	check(game.companion_node.command_smash(kind, col) != "", "17 a hatchling is too small to smash rock")
	# ---- growth
	game.state.clock_minutes += 1440.0 * float(prog.companion_cfg()["hatchling_days"])
	await frames(70)
	check(prog.companion_stage(prog.current_day) == "juvenile" and game.companion_node.stage == "juvenile", "18 it grows into a juvenile")
	check(prog.companion_can_break("limestone", prog.current_day) and not prog.companion_can_break("copper_ore", prog.current_day) and not prog.companion_can_break("gold_ore", prog.current_day), "19 a juvenile breaks limestone but not copper or gold")
	game.state.clock_minutes += 1440.0 * float(prog.companion_cfg()["juvenile_days"])
	await frames(70)
	check(prog.companion_stage(prog.current_day) == "adult" and game.companion_node.scale.x > 1.0, "20 and then into an adult")
	check(prog.companion_can_break("copper_ore", prog.current_day) and not prog.companion_can_break("gold_ore", prog.current_day), "21 an adult breaks copper (hardness 3) but never gold (hardness 4)")
	check("companion_adult" in prog.story["journal"], "22 growing up is journaled")
	# ---- tail smash follows the mining rules
	var u0: int = prog.column_units(kind, col)
	var msg: String = game.companion_node.command_smash(kind, col)
	check(msg == "" and game.companion_node.busy(), "23 an adult accepts the smash command")
	game.companion_node.global_position = game.formation_nodes[kind].column_top(col) + Vector3(2.0, 0, 0)
	await frames(240)
	check(prog.column_units(kind, col) < u0 and int(prog.stats.get("companion", 0)) > 0, "24 the tail smashes the rock down (%d -> %d units)" % [u0, prog.column_units(kind, col)])
	check(not game.companion_node.busy() or game.companion_node.smash_left < int(prog.companion_cfg()["smash_hits"]), "25 the command is spent hit by hit")
	game.companion_node.cancel_smash()
	# covered or locked rock cannot be smashed
	var covered := ""
	for id in prog.cfg["formations"]:
		if prog.formation_locked(id) != "":
			covered = id
			break
	var u1 := 0
	if covered != "":
		u1 = prog.units_left(covered)
		game.companion_strike(covered, 0, 500.0, game.companion_node)
	check(covered == "" or prog.units_left(covered) == u1, "26 locked rock is untouched by the companion")
	var gold := "bench_l4_gold"
	prog.init_formation(gold)
	var g0: int = prog.units_left(gold)
	game.companion_strike(gold, 0, 5000.0, game.companion_node)
	check(prog.units_left(gold) == g0, "27 even the adult cannot break gold-bearing rock")
	# ---- Walter
	check(prog.visit_condition_met(prog.visit_def("companion_adult")) and prog.visit_condition_met(prog.visit_def("companion_born")), "28 Walter has things to say about the dinosaur")
	# ---- saves
	var snap := prog.snapshot()
	prog.story["companion"] = {"state": "none"}
	prog.restore(snap, [])
	check(prog.companion().get("state") == "alive" and prog.companion()["name"] == "Bruno" and prog.companion_stage(prog.current_day) == "adult", "29 name, age and growth survive save and load")
	var old := snap.duplicate(true)
	old["story"].erase("companion")
	prog.restore(old, [])
	check(prog.companion().get("state") == "none", "30 older saves simply have no companion")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
