extends SceneTree
## The overburden wants the right tool: the shovel chews weeds and barely dents stone, the hammer breaks stone and only brushes weeds aside, so the shovel never out-cuts the hammer
## on rock. The quarry guide (scripts/coach.gd) follows what the player does. Run through tools/run_tests.sh.
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
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(20)
	var heap: Node3D = null
	var weed: Node3D = null
	for id in game.cleanup_nodes:
		if str(id).begins_with("w") and weed == null:
			weed = game.cleanup_nodes[id]
		elif not str(id).begins_with("w") and heap == null:
			heap = game.cleanup_nodes[id]
	check(heap != null and weed != null, "the site has both weeds and rubble heaps")
	var prog = game.prog
	var shovel_tier := -1
	var hammer_tier := -1
	for i in range(prog.tools().size()):
		if str(prog.tools()[i].get("id", "")) == "hand":
			hammer_tier = i
	prog.hotbar_select_for_test("shovel") if prog.has_method("hotbar_select_for_test") else null
	game.select_tool_slot(0)
	var tool_a: Dictionary = prog.tool()
	var shovel_stone: float = prog.tool_power() * game._debris_tool_factor(heap)
	var shovel_weed: float = prog.tool_power() * game._debris_tool_factor(weed)
	game.select_tool_slot(1)
	var tool_b: Dictionary = prog.tool()
	var hammer_stone: float = prog.tool_power() * game._debris_tool_factor(heap)
	var hammer_weed: float = prog.tool_power() * game._debris_tool_factor(weed)
	check(str(tool_a.get("class", "")) == "digging" and str(tool_b.get("class", "")) != "digging", "slot 1 is the shovel and slot 2 a rock tool")
	check(hammer_stone > shovel_stone * 3.0, "on stone the hammer (%.1f) does far more than the shovel (%.1f)" % [hammer_stone, shovel_stone])
	check(shovel_weed > hammer_weed * 2.0, "on weeds the shovel (%.1f) does far more than the hammer (%.1f)" % [shovel_weed, hammer_weed])
	# the guide: starts at step 1, moves on with what the player does, and marks itself done for good
	var c: QuarryCoach = game.coach
	check(c != null and not c.finished(), "the guide exists and has not finished")
	c.event("stone_hit")
	check(c._done("clear"), "the first hit on a stone heap completes step 1")
	game.hud.close_card()
	c.event("hopper_tipped")
	check(c.finished() and c._done("bucket"), "tipping a bucket into the hopper completes the guide")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
