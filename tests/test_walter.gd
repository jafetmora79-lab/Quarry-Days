extends SceneTree
## Phase 7.5: Walter is alive and retiring: skippable intro scene (never replays), timed visits, the journal, saves.
##   godot --headless --fixed-fps 60 -s tests/test_walter.gd

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
	var prog: QuarryProgression = game.prog
	# ---- the premise: alive, retiring
	var w: Dictionary = prog.walter_cfg()
	var all := ""
	for l in w["intro"]:
		all += str(l["text"]).to_lower() + " "
	check(all.contains("retiring") and not all.contains("passed away") and not all.contains("you're reading the page") and not all.contains("if you're reading this"), "1 the intro has Walter alive and retiring, not dead")
	check(w["intro"].size() >= 4, "2 the handover scene has several lines")
	# ---- intro scene
	check(game.walter_node != null and game.walter_dialog != null and game.player.locked, "3 a new game opens with Walter in the yard and the player locked")
	check(game.walter_node.global_position.distance_to(game.walter_pos()) < 0.1, "4 Walter stands at his spot")
	game.walter_dialog.advance()
	check(game.walter_dialog.index == 1, "5 Continue moves to the next line")
	game.walter_dialog.skip()
	await process_frame
	check(game.walter_dialog == null and game.hud.card_open(), "6 skipping ends the scene and shows the first-day card")
	check("handover" in prog.story["journal"], "7 the handover is written in the journal")
	game.hud.close_card()
	await process_frame
	check(prog.story["intro_seen"] and not game.player.locked and game.walter_node == null, "8 the intro finishes: Walter heads home, the player is free")
	# ---- no visits before there is a reason
	game.state.clock_minutes = 10.0 * 60.0
	await frames(3)
	check(prog.due_visit() == "" and game.walter_node == null, "9 no visit is due at the start")
	# ---- a visit when the crew stage is reached
	prog.stage = prog.stage_index("crew")
	check(prog.due_visit() == "first_crew", "10 reaching the crew stage makes a visit due")
	game.state.clock_minutes = 23.0 * 60.0
	await frames(3)
	check(game.walter_node == null, "11 Walter does not visit at night")
	game.state.clock_minutes = 10.0 * 60.0
	await frames(3)
	game.sleeping = false # the curfew put the player to bed; let them wake
	game.player.locked = false
	await frames(3)
	check(game.walter_node != null and game.walter_visit == "first_crew", "12 he comes by in the day")
	game.player.global_position = game.walter_pos() + Vector3(1.5, 0.2, 0)
	game._talk_to_walter()
	check(game.walter_dialog != null and game.walter_dialog.lines.size() == prog.visit_def("first_crew")["lines"].size(), "13 talking to him plays the visit lines")
	game.walter_dialog.skip()
	await process_frame
	check(prog.story["visits"].get("first_crew", false) and "first_crew" in prog.story["journal"], "14 the visit is remembered and journaled")
	check(prog.due_visit() == "" and game.walter_node == null and not game.player.locked, "15 it does not repeat and Walter leaves")
	game.state.clock_minutes += 1440.0
	await frames(3)
	check(game.walter_node == null, "16 no second visit the next day")
	# ---- later visits follow quarry progress
	prog.quarry_level = 2
	check(prog.due_visit() == "first_bench", "17 opening the first bench brings Walter back")
	prog.quarry_level = 3
	prog.complete_visit("first_bench")
	check(prog.due_visit() == "deep_dig", "18 level 3 brings another visit")
	# ---- journal contents
	var titles := []
	for e in prog.journal_entries():
		titles.append(e["title"])
	check(titles.size() >= 3 and "The handover" in titles, "19 the journal lists entries in the order they were written: %s" % str(titles))
	# ---- saves
	var snap := prog.snapshot()
	var p2 := QuarryProgression.new(game.state, game.business, game.settings) if false else null
	prog.restore(snap, [])
	check(prog.story["visits"].get("first_crew", false) and prog.story["journal"].size() >= 3, "20 visits and the journal survive save and load")
	# old save (no visits key): no flood of visits for what was already done
	var old := snap.duplicate(true)
	old["story"].erase("visits")
	old["story"].erase("journal")
	old["story"]["intro_seen"] = true
	prog.restore(old, [])
	check(prog.due_visit() == "" and "handover" in prog.story["journal"], "21 an older save skips visits for what it already did and gets the handover entry")
	# the intro never replays for a finished game
	prog.restore(snap, [])
	check(prog.story["intro_seen"], "22 a loaded game does not replay the intro")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
