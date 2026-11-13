extends SceneTree
## Connected quarry, Phase B checkpoint: Area 1 played end to end with the REAL game actions (hand tools on debris, the excavator on the
## soil field, a truck-less haul to the spoil heap, the pickaxe on the hillside rock): the terrain really changes, the percentages come
## from that work, the contract completes once and the remaining rock stays.   godot --headless --fixed-fps 60 -s tests/test_area1_playthrough.gd
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
	var st: QuarryState = game.state
	game.safety.enabled = false
	check(game.soil != null and game.soil.total() > 100, "Area 1 holds a soil field to dig (%d units)" % (game.soil.total() if game.soil else 0))
	check(game.hud_status_text().contains("AREA 1 - STARTER CUT"), "the HUD shows the contract")
	# ---- 1: the debris, with the hand tool, in the area (not the yard)
	var soil0: int = game.soil.total()
	var cleared := 0
	for id in prog.cleanup_ids():
		var node: Node3D = game.cleanup_nodes.get(id)
		if node != null:
			for k in range(30):
				if is_instance_valid(node):
					game.hit_debris(node, 50.0, node.global_position)
				st.inventory["limestone"] = 0
			cleared += 1
	await frames(20)
	check(cleared == prog.cleanup_total() and prog.cleanup["done"], "all %d weeds and heaps were cleared by hitting them (the site is clean)" % cleared)
	var after_debris := int(prog.area_progress("area_1")["pct"])
	check(after_debris >= 20 and not prog.area_complete("area_1"), "that is part of the contract, not all of it (%d%%)" % after_debris)
	# ---- 2: dig the soil with Grandpa's excavator (starter machine), and carry it to the spoil heap
	var ex = null
	for nd in game.vehicle_nodes.values():
		if nd.vtype == "starter_excavator":
			ex = nd
	check(ex != null, "Grandpa's excavator exists")
	var cell: int = game.soil.nearest_cell(Vector3(-10, 0, -20), 100.0)
	var cell_pos: Vector3 = game.soil.cell_center(cell)
	ex.global_position = cell_pos + Vector3(0, 0.1, 4.6)
	ex.rotation.y = 0.0
	await frames(3)
	var rec: Dictionary = game.fleet.vehicle(ex.vehicle_id)
	var hauled := 0
	for round in range(40):
		for k in range(60):
			game._excavator_dig(ex, 1.0 / 30.0)
		var carried := int(rec["cargo"].get("soil", 0))
		if carried > 0:
			hauled += game._dump_soil(rec)
		if int(prog.area_state("area_1")["soil_removed"]) >= 48 and hauled >= 24:
			break
		# move on to the next soil cell once this one is empty
		var nc: int = game.soil.nearest_cell(ex.work_point(), 4.0)
		if nc < 0:
			var nn: int = game.soil.nearest_cell(ex.global_position, 100.0)
			if nn < 0:
				break
			ex.global_position = game.soil.cell_center(nn) + Vector3(0, 0.1, 4.6)
	check(game.soil.total() < soil0 and int(prog.area_state("area_1")["soil_removed"]) >= 48, "digging removed real soil from the ground (%d units gone)" % (soil0 - game.soil.total()))
	check(int(prog.area_state("area_1")["soil_hauled"]) >= 24 and st.soil_dumped >= 24, "and hauling it to the spoil heap is counted (%d)" % st.soil_dumped)
	check(not prog.area_complete("area_1"), "still not complete: the rock has not been recovered")
	# ---- 3: the rock, with a pickaxe, from the hillside face (it opened when the site was cleaned)
	st.tool_tier = 1
	var node: QuarryFormation = game.formation_nodes["hillside_face_01"]
	var units0 := prog.units_left("hillside_face_01")
	var mined := 0
	for round in range(400):
		var col := prog.nearest_column("hillside_face_01", Vector3(-17, 0, -8), true, INF, "hand")
		if col < 0 or int(prog.area_state("area_1")["rock"]) >= 60:
			break
		mined += game.player_mine("hillside_face_01", col, 500.0)
		st.inventory["limestone"] = 0              # empty the bag so the pickaxe keeps working
	check(prog.units_left("hillside_face_01") < units0 and int(prog.area_state("area_1")["rock"]) >= 60, "cutting the face removed real rock (%d units) and counted for the contract" % (units0 - prog.units_left("hillside_face_01")))
	check(prog.area_complete("area_1"), "with every part done the contract is complete")
	check(prog.units_left("hillside_face_01") > 0, "the rock that was not needed is still there to cut")
	# ---- 4: the terrain shows it, and what was removed stays removed
	var shown_ok := true
	for i in range(prog.column_count("hillside_face_01")):
		var shape := node.shapes[i] as CollisionShape3D
		shown_ok = shown_ok and shape.disabled == (prog.chunks_left("hillside_face_01", i) <= 0)
	check(shown_ok, "visuals and colliders agree for every column of the cut")
	game._save(true)
	var soil_after: int = game.soil.total()
	var rock_after := prog.units_left("hillside_face_01")
	game._load(true)
	await frames(10)
	check(game.soil.total() == soil_after and prog.units_left("hillside_face_01") == rock_after and prog.area_complete("area_1"), "after a save and load the excavation is permanent and the contract stays complete")
	for path in [game.SAVE_PATH, game.SAVE_BACKUP]:
		DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
