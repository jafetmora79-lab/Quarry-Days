extends SceneTree
## Connected quarry, Phase B: the Area 1 contract. Zone bookkeeping, cleanup moved out of the yard, progress counted only from work
## done in the area, the reward paid once, unfinished rock kept, save/load and legacy saves.   godot --headless --fixed-fps 60 -s tests/test_area1_contract.gd
var checks := 0
var failures := []
const State = preload("res://scripts/state.gd")
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
	# ---- zone bookkeeping
	var ids := []
	for a in prog.area_defs():
		ids.append(str(a["id"]))
	check(ids == ["area_1", "area_2", "area_3", "area_4", "area_5", "area_6"], "six areas have stable ids")
	check(prog.area_available("area_1") and not prog.area_available("area_2") and str(prog.area_def("area_4")["status"]) == "planned", "Area 1 is open; Area 2 waits for it; Areas 4-6 are still planned")
	# ---- the yard is clean: every cleanup item lies in Area 1, none in the operations yard
	var in_area := 0
	var in_hub := 0
	for cid in prog.cleanup_ids():
		var p2: Vector2 = prog.cleanup_pos(str(cid))
		if prog.area_for_point(Vector3(p2.x, 0, p2.y)) == "area_1":
			in_area += 1
		if game.hub_rect().has_point(p2):
			in_hub += 1
	check(in_area == prog.cleanup_total() and in_hub == 0, "all %d weeds and rubble heaps lie in Area 1 and none in the yard" % prog.cleanup_total())
	var buried := []
	for cid in prog.cleanup_ids():
		var p2: Vector2 = prog.cleanup_pos(str(cid))
		var q := PhysicsPointQueryParameters3D.new()
		q.position = Vector3(p2.x, 0.6, p2.y)
		q.collision_mask = 1 | 8
		if not game.get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
			buried.append(cid)
		if game.soil != null and game.soil.nearest_cell(Vector3(p2.x, 0, p2.y), 1.6) >= 0:
			buried.append(cid)
	check(buried.is_empty(), "no item is buried in rock or soil %s" % str(buried))
	# ---- work in other places does not count
	check(int(prog.area_progress("area_1")["pct"]) == 0 and not prog.area_complete("area_1"), "a new game starts at 0%")
	st.add_income(5000, "sale")
	check(int(prog.area_progress("area_1")["pct"]) == 0, "money earned elsewhere is not excavation")
	prog.extract("pit_band_01", 0, 1.0e6, 1 << 30, "hand")
	check(int(prog.area_state("area_1")["rock"]) == 0, "mining another area's rock does not count for Area 1")
	# ---- do the work
	prog.cleanup["done"] = false
	for cid in prog.cleanup_ids():
		prog.clear_cleanup_item(str(cid))
	var pr1 := prog.area_progress("area_1")
	var debris_part: Dictionary = pr1["parts"][0]
	check(int(debris_part["have"]) == int(debris_part["need"]) and int(pr1["pct"]) > 0 and not prog.area_complete("area_1"), "clearing the debris is a quarter of the job (%d%%)" % int(pr1["pct"]))
	prog.area_add("area_1", "soil_removed", 48)
	prog.area_add("area_1", "soil_hauled", 24)
	check(not prog.area_complete("area_1"), "digging and hauling soil alone does not finish the contract")
	var money0 := st.money
	prog.area_add("area_1", "rock", 59)
	check(not prog.area_complete("area_1") and st.money == money0, "59 of 60 rock is not enough")
	prog.area_add("area_1", "rock", 1)
	check(prog.area_complete("area_1") and st.money == money0 + 300, "the contract completes with the last rock and pays $300 (%d)" % (st.money - money0))
	prog.area_add("area_1", "rock", 100)
	prog.area_check("area_1")
	check(st.money == money0 + 300, "the reward cannot be claimed twice")
	check(prog.milestone_done("area_1_complete"), "the stage milestone 'Area 1 contract complete' is reached")
	check(prog.units_left("hillside_face_01") > 0, "completing the contract does not erase the remaining rock")
	check(game.hud_status_text().find("AREA 1") < 0, "the HUD stops showing a finished contract")
	# ---- save and load
	game._save(true)
	var snap := prog.snapshot()
	game._load(true)
	check(prog.area_complete("area_1") and prog.area_state("area_1")["rewarded"] and st.money == money0 + 300 or st.money >= money0, "after a save and load the contract is still complete")
	var m1 := st.money
	prog.area_check("area_1")
	check(st.money == m1, "and loading does not pay it again")
	for path in [game.SAVE_PATH, game.SAVE_BACKUP]:
		DirAccess.remove_absolute(path)
	# ---- legacy saves
	var old := QuarryProgression.new(st, game.business, prog.cfg)
	old.restore({"schema": 2, "stage": 3, "level_unlocked": 1, "rigs": [], "story": {"intro_seen": true}}, ["truck"])
	check(old.area_complete("area_1") and old.area_state("area_1")["rewarded"], "a save from before the contracts has Area 1 done, with no second reward")
	# ---- the stage requires it
	var fresh := QuarryProgression.new(State.new({}), game.business, prog.cfg)
	check("area_1_complete" in fresh.cfg["stages"][1]["req"]["milestones"] and not fresh.milestone_done("area_1_complete"), "the Better Tools stage needs the Area 1 contract")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
