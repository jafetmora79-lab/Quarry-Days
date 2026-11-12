extends SceneTree
## Phase 7.6: the fossil in the lowest level: real excavation reveals it, the choice is final, persisted.
##   godot --headless --fixed-fps 60 -s tests/test_fossil.gd

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
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await frames(4)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	await frames(2)
	var prog: QuarryProgression = game.prog
	var f: Dictionary = prog.fossil_cfg()
	var fid: String = f["formation"]
	check(prog.fossil_state() == "" and game.fossil_node == null, "1 the fossil starts buried")
	check(f["buyers"]["collector"]["price"] == 75000 and f["buyers"]["scientist"]["price"] == 2000, "2 the offers are $75,000 and $2,000")
	check(str(f["buyers"]["scientist"]["who"]) == "Dr. Evelyn Marsh", "3 the scientist is Dr. Evelyn Marsh")
	check(prog.level_def(4).get("formations", []).has(fid), "4 it lies in a level 4 formation")
	# not exposed while the rock is there, even deep in the quarry
	prog.quarry_level = 4
	prog.init_formation(fid)
	game.state.clock_minutes = 600.0
	game.sleeping = false
	await frames(70)
	check(prog.fossil_state() == "" and game.fossil_node == null, "5 untouched rock hides it")
	# mining only one of the two columns is not enough
	var cols: Array = f["columns"]
	prog.state.deposits[fid]["columns"][int(cols[0])] = 0
	await frames(70)
	check(prog.fossil_state() == "", "6 one column is not enough")
	# real excavation of the listed columns exposes it
	prog.state.deposits[fid]["columns"][int(cols[1])] = 0
	prog._sync_stock(prog.state.deposits[fid])
	await frames(70)
	check(prog.fossil_state() == "found" and game.fossil_node != null, "7 mining out its columns reveals the fossil")
	check("fossil_found" in prog.story["journal"], "8 the discovery is journaled")
	check(game.fossil_node.global_position.distance_to(prog.fossil_pos()) < 0.2 and prog.fossil_pos().y < -10.0, "9 it lies on the lowest floor")
	# ---- Walter reacts
	check(prog.visit_condition_met(prog.visit_def("fossil_found")), "10 Walter has a reaction to the find")
	# ---- examine it
	var m0: int = game.state.money
	game._talk_to_fossil()
	check(game.hud.card_open() and game.hud.card_title.text == f["found_title"], "11 examining it shows the discovery")
	game.hud.close_card()
	await process_frame
	check(game.fossil_dialog != null, "12 then offers the choice")
	game.fossil_dialog.cancelled.emit()
	await process_frame
	check(game.fossil_dialog == null and prog.fossil_state() == "found" and game.state.money == m0, "13 'Not yet' leaves the choice open and charges nothing")
	game._talk_to_fossil()
	game.hud.close_card()
	await process_frame
	# picking an option asks for confirmation first
	game.fossil_dialog._ask("collector")
	check(game.fossil_dialog.pending == "collector" and prog.fossil_state() == "found", "14 choosing asks for confirmation before anything happens")
	game.fossil_dialog._show_options()
	check(game.fossil_dialog.pending == "" and prog.fossil_state() == "found", "15 going back cancels")
	# ---- choose the scientist
	game.fossil_dialog._ask("scientist")
	game.fossil_dialog.chosen.emit("scientist")
	await process_frame
	check(prog.fossil_state() == "scientist" and game.state.money == m0 + 2000, "16 the scientist route pays $2,000")
	check(game.fossil_node == null and game.fossil_dialog == null, "17 the bones are taken away")
	check(prog.story.get("fossil_egg", false) and "fossil_scientist" in prog.story["journal"], "18 the scientist route is journaled and keeps the egg for later")
	game.hud.close_card()
	await process_frame
	check(not game.player.locked, "19 the player is free afterwards")
	# ---- final
	check(prog.fossil_choose("collector") == 0 and prog.fossil_state() == "scientist" and game.state.money == m0 + 2000, "20 the choice cannot be changed")
	game._talk_to_fossil()
	check(game.fossil_dialog == null, "21 there is nothing left to examine")
	# ---- persistence
	var snap := prog.snapshot()
	prog.story["fossil"] = ""
	prog.restore(snap, [])
	check(prog.fossil_state() == "scientist" and prog.story.get("fossil_egg", false), "22 the decision survives save and load")
	prog.story["fossil"] = "found"
	var snap2 := prog.snapshot()
	prog.restore(snap2, [])
	check(prog.fossil_state() == "found", "23 an undecided fossil survives too")
	# ---- Walter's reaction to the choice
	prog.story["fossil"] = "collector"
	check(prog.due_visit() != "", "24 Walter has something to say afterwards")
	# ---- collector pays $75,000
	prog.story["fossil"] = "found"
	var m1: int = game.state.money
	check(prog.fossil_choose("collector") == 75000 and game.state.money == m1 + 75000 and not prog.story.get("fossil_egg_collector", false), "25 the collector route pays $75,000")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
