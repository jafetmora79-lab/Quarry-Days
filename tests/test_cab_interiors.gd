extends SceneTree
## Real cabs: every driveable machine has a seat, controls, a door that opens, steps and an ignition; the boarding keyframes lead from the ground
## through the door to the seat; the cab view sits the camera in the seat; the hose repair attaches to the boom instead of floating.
##   godot --headless --fixed-fps 60 -s tests/test_cab_interiors.gd
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
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 10: await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.safety.enabled = false
	for t in ["loader", "truck", "excavator"]:
		var types := []
		for ty in game.fleet.types():
			if game.fleet.kind(ty) == t:
				types.append(ty)
		var rec: Dictionary = game.fleet.give(str(types[0]), Vector3(0, 0, 40), 0.0)
		game._sync_vehicles()
		var v: QuarryVehicle = game.vehicle_nodes[int(rec["id"])]
		var c: Dictionary = QuarryBoarding.cab(v)
		check(not c.is_empty() and c["door"] is Node3D and c["key"] is Node3D and c["lamps"].size() >= 3, "%s: has a cab with a door, an ignition key and dashboard lamps" % types[0])
		var inter: Node = (c["ref"] as Node3D).get_node_or_null("Interior")
		check(inter != null and inter.get_child_count() >= 4, "%s: seat, controls, dash and floor mat are modelled (%d parts)" % [types[0], inter.get_child_count() if inter else 0])
		# the door really swings out of the way
		(c["door"] as Node3D).rotation.y = float(c["open"])
		check(absf((c["door"] as Node3D).rotation.y) > 1.2, "%s: the door opens about 80 degrees" % types[0])
		(c["door"] as Node3D).rotation.y = 0.0
		# climbing in: from the ground by the door to the seat
		var ground := Transform3D(Basis(), v.global_position + v.global_transform.basis * Vector3(-3.0, QuarryBoarding.EYE, 0.0))
		var frames := QuarryBoarding.poses_in(v, ground)
		var seat_world: Vector3 = (c["ref"] as Node3D).to_global(c["eye"])
		var last: Transform3D = frames[frames.size() - 1][0]
		check(frames.size() >= 5 and last.origin.distance_to(seat_world) < 0.01, "%s: the climb ends in the seat (%d keyframes)" % [types[0], frames.size()])
		var finite := true
		var total := 0.0
		for fr in frames:
			finite = finite and fr[0].origin.is_finite() and fr[0].basis.determinant() > 0.5
			total += float(fr[1])
		check(finite and total > 2.0 and total < 5.0, "%s: every keyframe is a valid pose and the climb takes %.1f s" % [types[0], total])
		var out := QuarryBoarding.poses_out(v, ground)
		check(out[out.size() - 1][0].origin.distance_to(ground.origin) < 0.01 and out[0][0].origin.distance_to(seat_world) < 0.01, "%s: climbing out is the reverse, ending on the ground" % types[0])
		# the cab view
		v.cab_view = true
		v.driven = true
		v._animate(1.0 / 60.0)
		check(v.camera.global_position.distance_to(seat_world) < 0.05, "%s: the cab view puts the camera in the driver's seat" % types[0])
		v.driven = false
		v.cab_view = false
	# the lamps and key
	var sv: QuarryVehicle = game._starter_vehicle()
	QuarryBoarding.lamps(sv, true)
	var lit: StandardMaterial3D = QuarryBoarding.cab(sv)["lamps"][0]["mat"]
	check(lit.emission_enabled, "the dashboard lamps light when the key is turned")
	QuarryBoarding.lamps(sv, false)
	check(not lit.emission_enabled, "and go dark again")
	# the hose runs along the boom, in the boom's own frame, so it follows it
	game.prog.story["excavator"]["hose"] = true
	game._decorate_starter()
	var hose: Node = sv.arm.get_node_or_null("BoomHose")
	check(hose != null and hose.get_child_count() >= 2, "a fitted hose is attached to the boom")
	check(absf(RepairSequence.HOSE_B.x - 0.72) < 0.01 and RepairSequence.HOSE_A.z > RepairSequence.HOSE_B.z, "the repair lays it from the pump port on the pedestal out along the boom's side")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
