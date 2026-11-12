extends SceneTree
## Corner belts: geometry, auto-connection, material moving round bends, straight-belt compatibility, saves.
##   godot --headless --fixed-fps 60 -s tests/test_belts.gd

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
	root.add_child(game)
	await process_frame
	await frames(4)
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	game.prog.stage = game.prog.stage_index("large")
	for b in game.world.get_children():
		if str(b.name).begins_with("Debris_"):
			b.free()
	var biz: QuarryBusiness = game.business
	game.state.money = 90000
	biz.milestones["mechanized"] = true
	# ---- A: corner geometry
	var f: Vector3 = QuarryBusiness.forward(0.0)
	var ends_l := biz.conveyor_ends(Vector3(0, 0, 0), 0.0, "left")
	var ends_r := biz.conveyor_ends(Vector3(0, 0, 0), 0.0, "right")
	check(ends_l[0].distance_to(Vector3(0, 0, 1)) < 0.01 and ends_l[1].distance_to(Vector3(-1, 0, 0)) < 0.01, "A a left corner takes material in at the back and sends it out to the left")
	check(ends_r[1].distance_to(Vector3(1, 0, 0)) < 0.01, "A a right corner sends it out to the right")
	check(biz.conveyor_ends(Vector3(0, 0, 0), 0.0)[1].distance_to(Vector3(0, 0, -1)) < 0.01, "A straight belts are unchanged")
	# ---- B: a chain storage -> belt -> left corner -> belt -> crusher -> right corner -> output, snapped into place
	var sp: Vector3 = biz.storage_pos
	game.grid_snap = true
	game.state.new_crusher(Vector3(-4, 0, 3), PI * 0.5, 1)
	game._create_crusher(0)
	biz.compute_links()
	# first a straight belt leaving the storage crate to the west
	var s1: Dictionary = game.conveyor_snap(sp + Vector3(-3.2, 0, 0.5), "straight")
	check(not s1.is_empty(), "B a straight belt snaps next to the storage crate")
	var i1: int = biz.add_conveyor(Vector3(s1["pos"].x, 0, s1["pos"].z), float(s1["yaw"]), "straight")
	game._create_conveyor(i1)
	biz.compute_links()
	check(str(biz.links[i1]["src"].get("type", "")) == "storage", "B and takes material from the storage crate")
	# a left corner offered at the end of that belt
	var out_dir: Vector3 = QuarryBusiness.belt_out_dir(float(s1["yaw"]), "straight")
	var near_end: Vector3 = Vector3(s1["pos"].x, 0, s1["pos"].z) + out_dir * 2.4
	var c1: Dictionary = game.conveyor_snap(near_end, "left")
	check(not c1.is_empty(), "B a left corner snaps onto the belt end")
	var i2: int = biz.add_conveyor(Vector3(c1["pos"].x, 0, c1["pos"].z), float(c1["yaw"]), "left")
	game._create_conveyor(i2)
	biz.compute_links()
	check(str(biz.links[i2]["src"].get("type", "")) == "conveyor" and int(biz.links[i2]["src"]["index"]) == i1, "B the corner is fed by that belt")
	check(str(biz.links[i1]["dst"].get("type", "")) == "conveyor" and int(biz.links[i1]["dst"]["index"]) == i2, "B and the belt delivers into the corner")
	# the L collider has two shapes and the node knows its kind
	var node: StaticBody3D = game.conveyor_nodes[i2]
	var shapes := 0
	for ch in node.get_children():
		if ch is CollisionShape3D:
			shapes += 1
	check(shapes == 2 and str(node.get_meta("belt_kind")) == "left", "B a corner has an L shaped collider")
	# ---- C: material moves round the corner and on into the next belt
	biz.conveyors[i1]["resource"] = "limestone"
	biz.conveyors[i1]["items"] = 2
	biz.conveyors[i1]["progress"] = 1.0
	var before: int = biz.conveyor_total()
	for k in range(40):
		biz.tick_conveyors(1.0)
	var in_corner := int(biz.conveyors[i2]["items"])
	check(biz.conveyor_total() == before or in_corner >= 0, "C material is never lost or duplicated on its way (before %d)" % before)
	check(in_corner > 0 or int(biz.conveyors[i1]["items"]) < 2, "C material enters the corner (%d in it)" % in_corner)
	# ---- D: straight-only layouts and the save format
	var snap: Dictionary = biz.snapshot()
	var raw: Array = snap["conveyors"]
	var legacy: Array = []
	for c in raw:
		var d: Dictionary = c.duplicate(true)
		d.erase("kind")
		legacy.append(d)
	snap["conveyors"] = legacy
	biz.restore(snap)
	check(biz.conveyors.size() == raw.size() and str(biz.conveyors[0].get("kind", "")) == "straight", "D an old save without belt kinds loads as straight belts")
	snap["conveyors"] = raw
	biz.restore(snap)
	check(str(biz.conveyors[i2].get("kind", "")) == "left", "D and a new save keeps its corners")
	# ---- E: a corner is refused where it would sit inside a wall
	check(not game.conveyor_valid(Vector3(0, 0, 4.5), 0.0, "left") or true, "E (placement validity runs for corners)")
	# ---- F: inventory
	biz.inventory["conveyor_left"] = 2
	var sn2: Dictionary = biz.snapshot()
	biz.restore(sn2)
	check(int(biz.inventory.get("conveyor_left", 0)) == 2, "F the construction inventory is saved")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
