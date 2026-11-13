extends SceneTree
## Phase 10.1: the natural starting ground and Grandpa's excavator restoration.   godot --headless --fixed-fps 60 -s tests/test_phase10_opening.gd

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

func skip_dialogs(game, rounds := 6) -> void:
	for i in range(rounds):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)

func boot() -> Node:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	return game

func run() -> void:
	var game = await boot()
	await skip_dialogs(game)                      # the opening letter and Grandpa's handover, skipped
	game.hud.close_card()
	await frames(3)
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	game.safety.enabled = false
	# ---- A: the starting ground
	var piles := ["stone_mountain", "coal_mountain", "iron_mountain"]
	var no_piles := true
	for id in piles:
		no_piles = no_piles and not game.formation_nodes.has(id)
	check(no_piles and (game.formation_nodes.has("q_top") and game.formation_nodes.has("q_a2_gravel") if game.prog.filled_world() else (game.formation_nodes.has("hillside_face_01") and game.formation_nodes.has("q_l1_top") and game.formation_nodes.has("q_l2_coal"))), "A the three artificial starting piles are gone; the hillside and the quarry's layered formations remain")
	check(game.deposit_nodes.has("coal_outcrop") and game.deposit_nodes.has("iron_boulder"), "A coal and iron appear as small natural outcrops")
	var counts: Dictionary = game.natural_root.get_meta("counts") if game.natural_root else {}
	check(not counts.is_empty() and counts["boulders"] >= 5 and counts["outcrops"] >= 3 and counts["patches"] >= 6 and counts["scrub"] == 0 and counts["pebbles"] >= 40, "A the site is dirt patches, scattered rocks, boulders and buried outcrops - no scrub %s" % str(counts))
	var hub: Rect2 = game.hub_rect()
	var inside_hub := false
	for c in game.natural_root.get_children():
		if c is StaticBody3D and hub.has_point(Vector2(c.global_position.x, c.global_position.z)):
			inside_hub = true
	check(not inside_hub, "A no boulder stands in the service area")
	var solids := 0
	for c in game.natural_root.get_children():
		if c is StaticBody3D:
			solids += 1
	check(solids == counts["boulders"] + counts["outcrops"], "A boulders and outcrops are solid (%d) while pebbles and scrub are merged meshes (%d draw nodes)" % [solids, game.natural_root.get_child_count() - solids])
	# ---- B: the broken excavator
	var ex: QuarryVehicle = game._starter_vehicle()
	check(ex != null and ex.vtype == "starter_excavator" and game.fleet.vehicles.size() == 2, "B the new game owns Grandpa's mini excavator and utility truck")
	check(not game.fleet.types().has("starter_excavator") and game.fleet.buy_block_reason("starter_excavator") == "Not for sale", "B it is not in the shop")
	check(not prog.excavator_ready() and game.opening_parts.size() == 3, "B it is broken and the three parts lie near the workshop")
	game.enter_vehicle(ex)
	check(game.driving == null, "B it cannot be driven before the repairs")
	var spec: Dictionary = game.fleet.spec("starter_excavator")
	check(int(spec["dig_hardness"]) == 0 and float(spec["capacity"]) <= 3 and float(spec["max_speed"]) < 2.0, "B it digs nothing harder than soil (hardness 0), carries 3 and creeps along")
	var walter_ok: bool = game.walter_node != null and is_instance_valid(game.walter_node) and game.walter_node.global_position.distance_to(Vector3(-14.9, 0, 5.6)) < 1.5
	check(walter_ok, "B Grandpa stands by the workshop")
	# parts
	var near_ok := true
	for id in game.opening_parts:
		near_ok = near_ok and game.opening_parts[id].global_position.distance_to(ex.global_position) < 7.5
	check(near_ok, "B every part lies within a few steps of the machine")
	var deco0: int = ex.model_root.get_node("OpeningParts").find_children("*", "MeshInstance3D", true, false).size()
	game._pick_up_part("battery")
	check(prog.carried_part() == "battery" and not game.opening_parts.has("battery"), "B the battery is picked up and leaves the ground")
	game._pick_up_part("hose")
	check(prog.carried_part() == "battery" and game.opening_parts.has("hose"), "B only one part can be carried")
	game._use_starter(ex)
	await frames(120)
	check(prog.repair_done("battery") and prog.carried_part() == "" and not game.repair_busy and not game.player.locked, "B the battery is fitted after the short repair, and play resumes")
	var deco1: Node = ex.model_root.get_node("OpeningParts")
	check(deco1 != null and deco1.find_children("*", "MeshInstance3D", true, false).size() >= 1, "B the machine shows the fitted battery")
	game._use_starter(ex)
	check(prog.repairs_done() == 1, "B pressing E with nothing in hand only reports what is missing")
	# ---- C: saves in the middle of the repairs
	game._save(true)
	for r in range(2):
		game._load(true)
		await frames(3)
	check(prog.repair_done("battery") and not prog.repair_done("hose") and game.fleet.vehicles.size() == 2 and game.opening_parts.size() == 2 and not game.opening_parts.has("battery"), "C the repair record survives saving: battery done, two parts still lie there, one excavator")
	ex = game._starter_vehicle()
	# ---- D: finish the repairs and the start
	game._pick_up_part("hose")
	game._use_starter(ex)
	await frames(120)
	game._pick_up_part("fuel")
	game._use_starter(ex)
	await frames(120)
	check(prog.repairs_complete() and game.walter_dialog != null and not prog.excavator_ready(), "D with the last repair Grandpa speaks, and the machine is not yet running")
	game.enter_vehicle(ex)
	check(game.driving == null, "D it still cannot be driven while it has not started")
	await skip_dialogs(game, 1)
	await frames(100)
	var said_it := game.walter_dialog != null
	await skip_dialogs(game, 3)
	await frames(30)
	check(said_it and prog.excavator_ready() and not game.player.locked, "D the engine struggles, catches, Grandpa has his line, and play resumes at once")
	game.enter_vehicle(ex)
	check(game.driving == ex, "D the repaired excavator can be driven")
	game._reset_driving()
	game.player.locked = false
	# ---- E: persistence of the finished repair
	game._save(true)
	game._load(true)
	await frames(3)
	check(prog.excavator_ready() and game.opening_parts.is_empty() and game.fleet.vehicles.size() == 2 and game.walter_mode != "waiting", "E a finished repair stays finished after loading (no parts, one machine, Grandpa has left his post)")
	# ---- F: a save from before Phase 10 skips the opening
	var legacy := {"schema": 3, "stage": 3, "quarry_level": 1, "story": {"intro_seen": true}, "rigs": []}
	prog.restore(legacy, [])
	game.fleet.vehicles.clear()
	game._sync_vehicles(true)
	game._ensure_opening()
	game._sync_formations()
	await frames(4)
	check(prog.excavator_ready() and bool(prog.excavator_state()["legacy"]) and game.opening_parts.is_empty() and game.natural_root == null and game.fleet.vehicles.is_empty(), "F an old save counts every repair as done, repeats nothing and is given no machine")
	check(game.formation_nodes.has("stone_mountain") and game.formation_nodes.has("coal_mountain"), "F and its old starting piles are still there")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
