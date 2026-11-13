extends SceneTree
## Phase 10.3: benches, buried mineral pockets, survey mode and the manual excavator joints.
##   godot --headless --fixed-fps 60 -s tests/test_phase10_geology.gd

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
	game.natural_start_enabled = false      # the bench mechanic belongs to the legacy hillside, which the blueprint world no longer has
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var prog: QuarryProgression = game.prog
	var id: String = "hillside_face_01"
	prog.cleanup["done"] = true
	# ---- benches
	check(prog.benched(id) and prog.bench_levels(id) == 4, "the hillside face is a four-bench formation")
	check(prog.bench_number(id) == 1 and prog.bench_level(id) == 4, "work starts on the top bench")
	var low := -1
	var wl := prog.working_level(id)
	for i in range(prog.column_count(id)):
		if low < 0 and prog.column_minable(id, i) and prog.chunks_left(id, i) > 0 and prog.chunks_left(id, i) < wl:
			low = i
	check(wl > 0 and wl <= 4, "the working bench is the tallest EXPOSED column (%d chunks), so a buried tall interior never locks machines out" % wl)
	check(low >= 0 and not prog.column_in_bench(id, low), "a lower exposed column waits until its bench opens")
	# cut every top-bench column down one chunk: the bench is finished and the next one opens
	var n := prog.column_count(id)
	var one: float = float(prog.material("limestone")["hp"]) * float(prog.fdef(id)["chunk_units"])
	for i in range(n):
		if prog.chunks_left(id, i) >= 4:
			prog.extract(id, i, one, 1 << 30, "hand")
	check(prog.bench_level(id) == 3 and prog.bench_number(id) == 2, "after the top bench is cut, bench 2 opens")
	check(prog.bench_progress(id) < 0.05, "and the new bench starts at 0% cut")
	# ---- veins
	var vs := prog.veins(id)
	check(vs.size() >= 6, "the face holds buried mineral pockets (%d)" % vs.size())
	check(vs == prog.veins(id), "the pockets are laid out from a fixed seed")
	var found := 0
	for i in range(prog.column_count(id)):
		var ex := prog.extract(id, i, 1.0e6, 1 << 30, "hand")
		found += (ex.get("veins", []) as Array).size()
	check(found > 0, "cutting the rock out drops the pockets (%d found)" % found)
	var again := 0
	for i in range(prog.column_count(id)):
		again += prog.collect_veins(id, i).size()
	check(again == 0, "a pocket is only ever found once")
	# saved pockets survive a save and load
	var taken := (prog.story.get("veins", {}).get(id, []) as Array).size()
	var snap := prog.snapshot()
	prog.story["veins"] = {}
	prog.restore(snap, [])
	check((prog.story.get("veins", {}).get(id, []) as Array).size() == taken and taken > 0, "found pockets are saved")
	# ---- survey
	game.set_survey(true)
	check(game.survey_root != null, "survey mode draws the pockets")
	game.set_survey(false)
	check(game.survey_root == null, "and switches off again")
	# ---- manual excavator joints
	var rec = game.fleet.give("starter_excavator", Vector3(-12, 0, 6.6), 0.0)
	game._sync_vehicles()
	await frames(10)
	var v = null
	for nd in game.vehicle_nodes.values():
		if nd.vkind == "excavator" or ("turret" in nd and nd.turret != null):
			v = nd
	check(v != null and v.turret != null and v.stick != null, "the excavator has a turret, boom, stick and bucket")
	if v != null:
		var w0: Vector3 = v.work_point()
		v.joint_in["swing"] = 1.0
		await frames(60)
		v.joint_in["swing"] = 0.0
		await frames(30)          # the cab eases to a stop
		check(v.swing > 0.8 and absf(v.turret.rotation.y - v.swing) < 0.01, "the upper body swings")
		check(v.work_point().distance_to(w0) > 1.0, "the bucket's reach follows the swing")
		var sw0: float = v.swing
		v.rotate_camera(Vector2(-200.0, 0.0))
		check(absf(angle_difference(v.swing, sw0)) > 0.4, "the mouse spins the cab")
		var w1: Vector3 = v.work_point()
		v.joint_in["stick"] = 1.0
		await frames(60)
		v.joint_in["stick"] = 0.0
		check(v.stick.rotation.x > 0.4, "the stick works on its own joint")
		check(v.work_point().distance_to(w1) > 0.3, "and moves the digging point")
	if v != null:
		v.joint_in["boom"] = -1.0
		v.joint_in["stick"] = -1.0
		await frames(150)
		v.joint_in["boom"] = 0.0
		v.joint_in["stick"] = 0.0
		check(v._tip_y(v.arm.rotation.x, v.stick.rotation.x) >= -0.31, "the bucket cannot be pushed through the ground")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
