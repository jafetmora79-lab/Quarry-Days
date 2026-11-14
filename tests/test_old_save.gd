extends SceneTree
## Connected quarry, Phase E: a save written by the build BEFORE the area contracts (Phase 10, mid-game: 6 of 18+8 debris items cleared,
## $480, 9 soil hauled) loads in the current game, keeps its progress, migrates into the Area 1 contract, and can be played on to completion
## with the contract paid exactly once.   godot --headless --fixed-fps 60 -s tests/test_old_save.gd
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
	var src := FileAccess.get_file_as_string("res://tests/fixtures/save_phase10_midgame.json")
	check(src.length() > 1000, "the old save fixture is there (%d bytes)" % src.length())
	var f := FileAccess.open("user://quarry_save.json", FileAccess.WRITE)
	f.store_string(src)
	f.close()
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	game.walter_dialog.skip() if game.walter_dialog else null
	game._load(true)
	await frames(20)
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	check(st.money == 480 and st.soil_dumped == 9, "the old save loads with its money and soil progress ($%d, %d hauled)" % [st.money, st.soil_dumped])
	check(prog.cleanup["cleared"].size() == 6 and not prog.cleanup["done"], "its cleanup progress is kept (%d cleared)" % prog.cleanup["cleared"].size())
	var a1 := prog.area_state("area_1")
	check(int(a1["soil_hauled"]) == 9 and not prog.area_complete("area_1"), "it enters the Area 1 contract with the work already done counted (hauled %d)" % int(a1["soil_hauled"]))
	check(game.hud_status_text().contains("AREA 1"), "and the HUD shows the contract")
	# ---- play on with the real actions
	var money0 := st.money
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	for id in prog.cleanup_ids():
		var node: Node3D = game.cleanup_nodes.get(id)
		if node != null:
			for k in range(30):
				if is_instance_valid(node):
					game.hit_debris(node, 50.0, node.global_position)
				st.inventory["limestone"] = 0
	await frames(20)
	check(prog.cleanup["done"], "the rest of the site can still be cleared")
	var ex = null
	for nd in game.vehicle_nodes.values():
		if nd.vtype == "starter_excavator":
			ex = nd
	check(ex != null, "Grandpa's excavator came through the load")
	if ex != null:
		var cell: int = game.soil.nearest_cell(Vector3(-10, 0, -20), 100.0)
		ex.global_position = game.soil.cell_center(cell) + Vector3(0, 0.1, 4.6)
		ex.rotation.y = 0.0
		await frames(3)
		var rec: Dictionary = game.fleet.vehicle(ex.vehicle_id)
		var last_removed := -1
		for round in range(120):
			var now_removed := int(prog.area_state("area_1")["soil_removed"])
			if now_removed == last_removed:         # this spot is dug out (or out of reach): move to another part of the soil field
				var probe := Vector3(-18.0 + float(round % 9) * 4.5, 0.0, -72.0 + float(round % 4) * 6.0)
				var pc: int = game.soil.nearest_cell(probe, 100.0)
				if pc >= 0:
					ex.global_position = game.soil.cell_center(pc) + Vector3(0, 0.1, 4.6)
			last_removed = now_removed
			for k in range(60):
				game._excavator_dig(ex, 1.0 / 30.0)
			if int(rec["cargo"].get("soil", 0)) > 0:
				game._dump_soil(rec)
			if int(prog.area_state("area_1")["soil_removed"]) >= 48 and int(prog.area_state("area_1")["soil_hauled"]) >= 24:
				break
			var nc: int = game.soil.nearest_cell(ex.work_point(), 4.0)
			if nc < 0:
				var nn: int = game.soil.nearest_cell(ex.global_position, 100.0)
				if nn < 0:
					break
				ex.global_position = game.soil.cell_center(nn) + Vector3(0, 0.1, 4.6)
	st.tool_tier = 1
	for round in range(400):
		var rock_id := "q_top" if game.blueprint else "hillside_face_01"
		var col := prog.nearest_column(rock_id, Vector3(-17, 0, -8), true, INF, "hand")
		if col < 0 or int(prog.area_state("area_1")["rock"]) >= 60:
			break
		game.player_mine(rock_id, col, 500.0)
		for ik in st.inventory.keys():
			st.inventory[ik] = 0
	check(prog.area_complete("area_1"), "the migrated save completes the Area 1 contract by playing on")
	var gained := st.money - money0
	check(gained >= 120 and gained <= 120 + 150 + 200, "the contract reward is paid once on top of the cleanup letter ($%d gained)" % gained)
	var m1 := st.money
	prog.area_check("area_1")
	check(st.money == m1, "and not again")
	DirAccess.remove_absolute("user://quarry_save.json")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
