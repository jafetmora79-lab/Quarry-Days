extends SceneTree
## Magnetic machine placement: crushers and outputs snap to belt ends and chutes so they connect when placed.
##   godot --headless --fixed-fps 60 -s tests/test_connect.gd

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
			b.free()   # tutorial weeds would block the build spots
	game.state.money = 90000
	game.business.milestones["mechanized"] = true
	# a crusher, with a loose output spot near its chute
	game.state.new_crusher(Vector3(-8, 0, 3), 0.0, 1)
	game._create_crusher(0)
	game.business.compute_links()
	game.grid_snap = true
	var sn: Dictionary = game.machine_snap("output", Vector3(-8.3, 0, 0.5))
	check(not sn.is_empty(), "A an output placed near a crusher's chute snaps to it")
	var o: int = game.business.add_output(Vector3(sn["pos"].x, 0, sn["pos"].z), float(sn["yaw"]))
	game._create_output(o)
	game.business.compute_links()
	check(game.business.crusher_outputs[0] == o, "A and the crusher's chute drops straight into it (output #%d)" % (o + 1))
	# a belt from a spot clear of both, then a second crusher snapped onto its end
	var cs: Dictionary = game.conveyor_snap(Vector3(6.0, 0, 7.0))
	var bi: int = game.business.add_conveyor(Vector3(6, 0, 7), 0.0)
	game._create_conveyor(bi)
	game.business.compute_links()
	var link: Dictionary = game.business.links[bi]
	check(link["src"].is_empty() and link["dst"].is_empty(), "B a lone belt starts unconnected")
	var s2: Dictionary = game.machine_snap("crusher", Vector3(6.2, 0, 4.2))
	check(not s2.is_empty(), "B a crusher placed near the belt end snaps to it (%s)" % str(s2.get("note", "")))
	game.state.new_crusher(Vector3(s2["pos"].x, 0, s2["pos"].z), float(s2["yaw"]), 1)
	game._create_crusher(1)
	game.business.compute_links()
	link = game.business.links[bi]
	check(not link["dst"].is_empty() and str(link["dst"]["type"]) == "crusher", "B and the belt now feeds that crusher without any fiddling")
	var s3: Dictionary = game.machine_snap("output", Vector3(14.0, 0, 8.0))
	check(s3.is_empty() or not (str(s3.get("note", "")).begins_with("end of conveyor")), "C a belt that already ends in a machine offers no second end spot")
	# belts snap to the storage crate
	var cb: Dictionary = game.conveyor_snap(game.business.storage_pos + Vector3(0, 0, 3.4))
	check(not cb.is_empty(), "D a belt placed near the storage crate snaps to it")
	var far: Dictionary = game.machine_snap("crusher", Vector3(-18, 0, 9))
	check(far.is_empty(), "E far from everything nothing snaps (free placement still works)")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
