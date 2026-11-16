extends SceneTree
## The modular production line: two crushers feed two belts, which join at a MERGER (a 3-way junction), one belt carries the stream to a shared output
## bin. Material really moves machine to machine: nothing is created or lost at any moment (crusher output + on belts + in the bin is constant), both
## crushers are served fairly, a full bin blocks the line without losing a unit, and the layout (including the merger) survives a save and load.
##   godot --headless --fixed-fps 60 -s tests/test_merger_production.gd

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

func total_stone(biz, st) -> int:
	var n: int = biz.conveyor_total()
	for c in st.crushers:
		n += int(c["output"])
	for o in biz.outputs:
		n += int(o["items"].get("crushed_stone", 0))
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 6:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var st = game.state
	var biz = game.business
	# a clear patch of the yard: layout (flow is -Z for yaw 0)
	#   crusher C2 -> belt B ->  [ MERGER ] <- belt A <- crusher C1       (side inlets at x = -1 and +1)
	#                               |  belt O1
	#                            output bin
	var origin := Vector3(40.0, 0.0, 40.0)
	var c1 := origin + Vector3(4.2, 0, 0)
	var c2 := origin + Vector3(-4.2, 0, 0)
	st.new_crusher(c1, PI * 0.5, 1)
	game._create_crusher(st.crushers.size() - 1)
	st.new_crusher(c2, -PI * 0.5, 1)
	game._create_crusher(st.crushers.size() - 1)
	var out_i: int = biz.add_output(origin + Vector3(0, 0, -4.0), 0.0)
	game._create_output(out_i)
	var merger: int = biz.add_conveyor(origin, 0.0, "merger")
	game._create_conveyor(merger)
	var o1: int = biz.add_conveyor(origin + Vector3(0, 0, -2.0), 0.0)
	game._create_conveyor(o1)
	var a: int = biz.add_conveyor(origin + Vector3(2, 0, 0), PI * 0.5)
	game._create_conveyor(a)
	var b: int = biz.add_conveyor(origin + Vector3(-2, 0, 0), -PI * 0.5)
	game._create_conveyor(b)
	biz.compute_links()
	check(biz.conveyor_side_inputs(origin, 0.0, "merger").size() == 2 and biz.conveyor_side_inputs(origin, 0.0, "straight").is_empty(), "a merger has two side inlets, a straight belt none")
	check(str(biz.conveyors[merger]["kind"]) == "merger" and game.conveyor_nodes.size() == 4, "the merger and its belts exist as machines in the world")
	var la: Dictionary = biz.links[a]
	var lb: Dictionary = biz.links[b]
	check(str(la["dst"].get("type", "")) == "conveyor" and int(la["dst"]["index"]) == merger, "belt A (from the right) is connected to the merger")
	check(str(lb["dst"].get("type", "")) == "conveyor" and int(lb["dst"]["index"]) == merger, "belt B (from the left) is connected to the merger")
	check(str(biz.links[merger]["dst"].get("type", "")) == "conveyor" and int(biz.links[merger]["dst"]["index"]) == o1, "the merger leads into the output belt")
	check(str(biz.links[o1]["dst"].get("type", "")) == "output" and int(biz.links[o1]["dst"]["index"]) == out_i, "which ends in the shared output bin")
	check(str(la["src"].get("type", "")) == "crusher" and str(lb["src"].get("type", "")) == "crusher" and int(la["src"]["index"]) != int(lb["src"]["index"]), "each belt starts at its own crusher")
	check(str(la["resource"]) == "crushed_stone" and str(lb["resource"]) == "crushed_stone", "both lines carry crushed stone")
	# run the line: 12 finished stones on each crusher
	var ci1: int = int(la["src"]["index"])
	var ci2: int = int(lb["src"]["index"])
	st.crushers[ci1]["output"] = 12
	st.crushers[ci2]["output"] = 12
	var invariant_ok := true
	var half_diff := -1
	var t := 0.0
	while t < 400.0 and int(biz.outputs[out_i]["items"].get("crushed_stone", 0)) < 24:
		biz.tick_conveyors(0.1)
		t += 0.1
		if total_stone(biz, st) != 24:
			invariant_ok = false
		if half_diff < 0 and int(biz.outputs[out_i]["items"].get("crushed_stone", 0)) >= 12:
			half_diff = absi(int(st.crushers[ci1]["output"]) - int(st.crushers[ci2]["output"]))
	check(invariant_ok, "nothing was created or lost at any step (24 stones in the system throughout)")
	check(int(biz.outputs[out_i]["items"].get("crushed_stone", 0)) == 24 and biz.conveyor_total() == 0 and int(st.crushers[ci1]["output"]) == 0 and int(st.crushers[ci2]["output"]) == 0, "all 24 arrive in the bin: no duplicates, none stranded (%.0f s)" % t)
	check(half_diff >= 0 and half_diff <= 4, "both crushers were served fairly (their leftovers differed by %d when half had arrived)" % half_diff)
	# a full bin blocks the line without losing anything
	biz.outputs[out_i]["items"]["crushed_stone"] = biz.output_capacity() - 3
	st.crushers[ci1]["output"] = 10
	st.crushers[ci2]["output"] = 10
	var before := total_stone(biz, st)
	var blocked_seen := false
	for i in 1200:
		biz.tick_conveyors(0.1)
		for k in range(biz.conveyors.size()):
			if biz.belt_status(k) == "blocked":
				blocked_seen = true
	check(total_stone(biz, st) == before, "a full bin loses nothing (%d stones still in the system)" % before)
	check(int(biz.outputs[out_i]["items"]["crushed_stone"]) == biz.output_capacity(), "the bin filled to its capacity and no further")
	check(blocked_seen, "and the belts report 'blocked' while it is full")
	# save and load keep the merger and its connections
	var snap: Dictionary = JSON.parse_string(JSON.stringify(biz.snapshot()))
	var kinds_before := []
	for c in biz.conveyors:
		kinds_before.append(str(c["kind"]))
	biz.restore(snap)
	var kinds_after := []
	for c in biz.conveyors:
		kinds_after.append(str(c["kind"]))
	check(kinds_before == kinds_after and kinds_after.has("merger"), "the merger and its belts survive a save and load")
	check(int(biz.links[a]["dst"].get("index", -1)) == merger and int(biz.links[b]["dst"].get("index", -1)) == merger, "with their connections intact")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
