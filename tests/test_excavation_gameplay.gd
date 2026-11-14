extends SceneTree
## The excavation loop: material-specific tools and the hotbar, digging under your own feet, the quarry plan (Q) and its rings, ring completion, digging outside the active
## ring, and saving everything. Headless runs cannot judge feel: see the delivery notes.   godot --headless --fixed-fps 60 -s tests/test_excavation_gameplay.gd
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
func key(game, code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	game._unhandled_input(e)
func boot(natural := true):
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	game.natural_start_enabled = natural
	root.add_child(game)
	await process_frame
	game.hud.close_card()
	await frames(260)
	for k in range(6):
		if game.walter_dialog != null:
			game.walter_dialog.skip()
		if game.dialog != null:
			game.dialog.skip_btn.pressed.emit()
		if game.est_running:
			game._est_finish()
		await frames(30)
		game.hud.close_card()
	return game

func clean_saves() -> void:
	for path in ["user://quarry_save.json", "user://quarry_save.bak", "user://quarry_save.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func run() -> void:
	clean_saves()
	var game = await boot(true)
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	prog.cleanup["done"] = true                       # (the opening clean-up is not what is under test here)
	# ---- starting equipment and the hotbar
	check("shovel" in st.gear and "ramp_plan" in st.gear, "every game owns the shovel and the ramp plan")
	var bar: Array = prog.hotbar()
	check(bar[0] == "shovel" and bar[1] == "" and bar[2] == "ramp_plan", "the hotbar order is shovel, hammer (the ladder tool), ramp plan (%s)" % str(bar))
	key(game, KEY_1)
	check(st.equipped == "shovel" and str(prog.tool()["title"]) == "Shovel", "key 1 takes the shovel")
	key(game, KEY_2)
	check(st.equipped == "" and str(prog.tool().get("class", "")) != "digging", "key 2 takes the ladder tool")
	key(game, KEY_3)
	check(st.equipped == "ramp_plan", "key 3 takes the ramp plan")
	key(game, KEY_9)
	check(st.equipped == "ramp_plan", "an empty slot changes nothing")
	key(game, KEY_1)
	# ---- tool and material compatibility
	check(prog.tool_suits("topsoil") == "" and prog.tool_suits("gravel") == "", "the shovel suits topsoil and gravel")
	check(prog.tool_suits("limestone").begins_with("Requires a pickaxe"), "the shovel on stone: %s" % prog.tool_suits("limestone"))
	st.equipped = ""
	check(prog.tool_suits("topsoil").begins_with("Requires a shovel") and prog.tool_suits("limestone") == "", "the hammer is refused on topsoil and fine on stone: %s" % prog.tool_suits("topsoil"))
	st.equipped = "shovel"
	# ---- mining topsoil with the shovel, refused with the hammer
	var kind := "q_top"
	var col := prog.nearest_column(kind, Vector3(0, 0, -20), false)
	check(col >= 0, "there is topsoil to dig")
	var bag0: int = st.total(st.inventory)
	game.player.global_position = prog.column_pos(kind, col) + Vector3(5.5, 2.0, 0)
	game.player.velocity = Vector3.ZERO
	await frames(20)
	st.equipped = ""
	var got: int = game.player_mine(kind, col, 999.0, prog.column_pos(kind, col))
	check(got == 0 and game.message.begins_with("Requires a shovel"), "the hammer on topsoil is refused with a reason: '%s'" % game.message)
	st.equipped = "shovel"
	game._mismatch_t = 0.0
	got = game.player_mine(kind, col, 999.0, prog.column_pos(kind, col))
	check(got > 0 and st.total(st.inventory) > bag0, "the shovel digs topsoil into the bag (%d units)" % got)
	# ---- digging directly under the player's feet
	var col2 := prog.nearest_column(kind, Vector3(0, 0, -20), false)
	var pos2: Vector3 = prog.column_pos(kind, col2)
	var node: QuarryFormation = game.formation_nodes[kind]
	game.player.global_position = Vector3(pos2.x, pos2.y + float(prog.chunks_left(kind, col2)) * float(prog.fdef(kind).get("tier_h", 1.2)) + 0.15, pos2.z)
	game.player.velocity = Vector3.ZERO
	await frames(30)
	var y_stand: float = game.player.global_position.y
	check(game.player.is_on_floor() and game._column_has_player(kind, col2), "the player stands on a column of topsoil (y %.2f)" % y_stand)
	var cam_y0: float = game.player.camera.position.y
	var ys := []
	var dug := 0
	for i in range(6):
		game._mismatch_t = 0.0
		dug += game.player_mine(kind, col2, 999.0, pos2)
	for i in range(90):
		await physics_frame
		ys.append(game.player.global_position.y)
	var jump := 0.0
	for i in range(1, ys.size()):
		jump = maxf(jump, absf(ys[i] - ys[i - 1]))
	check(dug > 0 and game.player.global_position.y < y_stand - 0.5, "the column under the player was dug away and the player dropped %.2f m" % (y_stand - game.player.global_position.y))
	check(game.player.is_on_floor() and jump < 0.8, "the player landed on the new surface without a teleport (largest step %.2f m)" % jump)
	check(absf(game.player.camera.position.y - cam_y0) < 0.001, "the camera did not snap")
	check(game.player.global_position.y > y_stand - 4.0, "and did not fall through the ground")
	# ---- the quarry plan (Q)
	game.player.global_position = Vector3(0.0, 0.2, 8.0)
	game.player.velocity = Vector3.ZERO
	await frames(20)
	key(game, KEY_Q)
	await frames(3)
	check(game.menu == "plan" and game.plan_view.visible and game.player.locked, "Q opens the quarry plan and suspends play")
	var texts := []
	for l in game.plan_view.find_children("*", "Label", true, false):
		texts.append(str(l.text))
	var joined := " ".join(texts)
	check(joined.contains("RING 1") and joined.contains("ACTIVE") and joined.contains("Only work inside this ring counts"), "the plan lists the rings, marks the active one and explains the contract rule")
	check(joined.contains("Overall excavation"), "contract progress and overall excavation are shown apart")
	var outlines_before: int = game.survey.rects.size()
	check(outlines_before >= 1 and game.state.plan_outlines, "the active ring is outlined in the world (%d outlines)" % outlines_before)
	game.plan_view.outline_btn.pressed.emit()
	await frames(2)
	check(not game.state.plan_outlines and game.survey.rects.is_empty() and game.menu == "plan", "the outlines switch off without closing the plan")
	game.plan_view.outline_btn.pressed.emit()
	await frames(2)
	check(game.state.plan_outlines and game.survey.rects.size() >= 1, "and back on")
	key(game, KEY_Q)
	await frames(2)
	check(game.menu == "" and not game.plan_view.visible and not game.player.locked, "Q closes it again")
	# ---- the markers stand on real ground (no floating stakes) and finished levels lose theirs
	prog.quarry_level = 3
	game.survey.refresh(true)
	await frames(2)
	var floating := 0
	var stakes_n := 0
	for rid in game.survey.rects:
		var sm: MeshInstance3D = game.survey.rects[rid].get_child(0)
		var verts: PackedVector3Array = sm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if sm.mesh != null and sm.mesh.get_surface_count() > 0 else PackedVector3Array()
		var low := {}                                  # per metre cell: the lowest vertex (the foot of the post; its flag hangs higher up beside it)
		for v in verts:
			var g: Vector3 = sm.global_transform * v
			var k := Vector2i(floori(g.x), floori(g.z))
			if not low.has(k) or g.y < (low[k] as Vector3).y:
				low[k] = g
		for k in low:
			var foot: Vector3 = low[k]
			var gy: float = game.ramps.ground_at(foot.x, foot.z, foot.y + 12.0)
			stakes_n += 1
			if is_nan(gy) or absf(gy - foot.y) > 0.2:
				floating += 1
	check(stakes_n > 10 and floating == 0, "every survey stake stands on the ground (%d stakes, %d floating)" % [stakes_n, floating])
	prog.quarry_level = 1
	game.survey.refresh(true)
	# ---- digging outside the active ring does not advance its contract
	var a1_before: Dictionary = prog.area_state("area_1").duplicate()
	prog.area_add(prog.area_for_point(Vector3(900, 0, 900)), "rock", 50)
	prog.area_add(prog.area_for_point(Vector3(0, 0, 200)), "soil_removed", 50)
	check(prog.area_state("area_1")["rock"] == a1_before["rock"] and prog.area_state("area_1")["soil_removed"] == a1_before["soil_removed"], "work outside every ring changes no contract")
	# ---- completing a ring unlocks the next, with a reward and the plan follows
	prog.cleanup["done"] = true
	var money0: int = st.money
	var done_ids := []
	prog.area_completed.connect(func(id): done_ids.append(id))
	prog.area_add("area_1", "soil_removed", 999)
	prog.area_add("area_1", "soil_hauled", 999)
	prog.area_add("area_1", "rock", 999)
	await frames(3)
	check(prog.area_complete("area_1") and "area_1" in done_ids and st.money >= money0 + 120, "completing ring 1 pays its reward once (+$%d)" % (st.money - money0))
	check(prog.area_available("area_2") or prog.area_available("area_3"), "the next ring opens")
	key(game, KEY_Q)
	await frames(3)
	texts.clear()
	for l in game.plan_view.find_children("*", "Label", true, false):
		texts.append(str(l.text))
	joined = " ".join(texts)
	check(joined.contains("RING 1  DONE") and joined.contains("ACTIVE"), "the plan shows ring 1 done and the next ring active")
	key(game, KEY_Q)
	await frames(2)
	# ---- saving: tools in hand, outlines, ramps
	st.equipped = "ramp_plan"
	game.set_plan_outlines(false)
	var snap: Dictionary = st.snapshot()
	check(snap["equipped"] == "ramp_plan" and snap["plan_outlines"] == false and snap.has("ramps"), "the save carries the tool in hand, the outline switch and the ramps")
	game._save()
	st.equipped = "shovel"
	game.set_plan_outlines(true)
	game._load()
	await frames(5)
	check(st.equipped == "ramp_plan" and not st.plan_outlines and prog.area_complete("area_1"), "load restores the tool in hand, the outline switch and the finished ring")
	# an older save (none of the new fields) loads with sensible defaults
	var old := QuarryState.new()
	var old_data: Dictionary = QuarryState.new().snapshot()
	old_data.erase("ramps")
	old_data.erase("plan_outlines")
	old_data["gear"] = ["sledgehammer"]
	check(old.restore(old_data), "a save from before this overhaul still restores")
	check(old.ramps.is_empty() and old.plan_outlines, "...with no ramps and outlines on")
	clean_saves()                                   # leave no save behind: other suites start new games
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
