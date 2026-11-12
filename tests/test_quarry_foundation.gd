extends SceneTree
## Phase 7.1: hub boundary, four quarry levels, excavation requirements, level unlocks and the save migration.
##   godot --headless --fixed-fps 60 -s tests/test_quarry_foundation.gd

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

## Removes `fraction` of a formation's units (columns emptied from the first one), as mining would.
func excavate(prog: QuarryProgression, id: String, fraction: float) -> void:
	prog.init_formation(id)
	var want := int(float(prog.max_units(id)) * fraction)
	var d: Dictionary = prog.state.deposits[id]
	var cols: Array = d["columns"]
	var removed := 0
	for i in range(cols.size()):
		if removed >= want:
			break
		var take := mini(int(cols[i]), want - removed)
		cols[i] = int(cols[i]) - take
		removed += take
	prog._sync_stock(d)

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
	var prog: QuarryProgression = game.prog
	# ---- A: world and level definitions
	var hub: Rect2 = game.hub_rect()
	check(is_equal_approx(hub.position.x, -23.5) and is_equal_approx(hub.end.x, 23.5) and is_equal_approx(hub.position.y, -6.0) and is_equal_approx(hub.end.y, 23.5), "A the industrial hub boundary is defined in data and matches the yard")
	check(game.in_build_area(Vector3(20, 0, 10)) and not game.in_build_area(Vector3(26, 0, 10)) and not game.in_build_area(Vector3(0, 0, -8)), "A building is allowed in the hub and not outside it")
	check(prog.levels().size() == 4, "A the quarry has four levels")
	var floors := []
	var ids := {}
	var ok_mats := true
	for lv in prog.levels():
		floors.append(float(lv["floor_y"]))
		ids[str(lv["id"])] = true
		for m in lv["materials"]:
			ok_mats = ok_mats and prog.cfg["materials"].has(str(m))
	check(ids.size() == 4 and floors[0] > floors[1] and floors[1] > floors[2] and floors[2] > floors[3], "A levels have unique ids and descend (%s)" % str(floors))
	check(ok_mats, "A every planned material is an existing material definition")
	check(prog.level_built(1) and prog.level_formations(1).size() == 2, "A level 1 is the hillside face and the basin bench")
	check(prog.level_built(2) and prog.level_built(3) and prog.level_built(4), "A levels 2-4 are built (Phase 7.2)")
	check(prog.quarry_level == 1, "A a new game starts on level 1")
	# ---- B: excavation fraction
	check(prog.level_cleared_fraction(1) == 0.0, "B an untouched quarry is 0% excavated")
	excavate(prog, "pit_band_01", 0.5)
	var f1 := prog.level_cleared_fraction(1)
	var total := float(prog.max_units("hillside_face_01") + prog.max_units("pit_band_01"))
	check(absf(f1 - 0.5 * float(prog.max_units("pit_band_01")) / total) < 0.002, "B the level fraction is the removed share of its rock (%.3f)" % f1)
	check(prog.level_cleared_fraction(2) == 0.0 and prog.level_cleared_fraction(9) == 0.0, "B unbuilt and unknown levels report 0")
	# ---- C: money alone no longer advances the business
	for k in ["hillside_face_01", "pit_band_01"]:
		prog.state.deposits.erase(k)
	prog.stage = 2
	game.state.earned = 1000000
	game.state.tool_tier = 1
	game.state.money = 50000
	game.ui_hire("rosa")
	prog.check_stages()
	check(prog.stage == 2, "C with money and a crew but no excavation the business stays at stage 3 (index %d)" % prog.stage)
	var req: Array = prog.requirement_progress(3)
	var has_exc := false
	for r in req:
		has_exc = has_exc or str(r[0]).contains("quarry level 1")
	check(has_exc, "C the stage lists the excavation requirement")
	excavate(prog, "hillside_face_01", 0.12)
	prog.check_stages()
	check(prog.stage >= 3, "C cutting into the quarry face finishes it (stage index %d)" % prog.stage)
	check(prog.stage < 5, "C and the later stages still ask for more excavation (stage index %d)" % prog.stage)
	# ---- D: level unlocking
	check(prog.quarry_level == 1, "D level 2 stays closed while level 1 is mostly uncut")
	excavate(prog, "hillside_face_01", 1.0)
	excavate(prog, "pit_band_01", 1.0)
	var reached := [0]
	prog.quarry_level_reached.connect(func(n): reached[0] = n)
	prog.check_levels()
	check(prog.quarry_level == 2 and reached[0] == 2, "D level 2 opens once level 1 is cut far enough")
	prog.check_levels()
	check(prog.quarry_level == 2, "D and only one level opens at a time (level 3 needs level 2 cut)")
	# ---- E: schema and migration
	var snap: Dictionary = prog.snapshot()
	check(int(snap["schema"]) == 2 and int(snap["quarry_level"]) == 2, "E the progression save carries a schema and the quarry level")
	var old := snap.duplicate(true)
	old.erase("schema")
	old.erase("quarry_level")
	old["stage"] = 5
	old["level_unlocked"] = 2
	prog.restore(old, ["loader", "truck"])
	check(prog.stage == 5 and prog.level_unlocked == 2, "E an old save at the last stage keeps its stage and its permit")
	check(prog.quarry_level == 1 or prog.quarry_level == 2, "E and gets a valid quarry level (%d)" % prog.quarry_level)
	check(QuarryProgression.migrate(old)["schema"] == 2 and QuarryProgression.migrate(snap)["schema"] == 2, "E migration brings both formats to the current schema")
	var m1 := QuarryProgression.migrate(old)
	check(int(m1.get("stage", -1)) == 5 and m1["rigs"] == old["rigs"], "E migration never changes what the old save recorded")
	# ---- F: the HUD shows the quarry once the business stages are done
	prog.cleanup["done"] = true
	prog.stage = prog.stages().size() - 1
	game.hud.refresh_panels()
	check(game.hud.objective_label.text.contains("Quarry level"), "F at the last stage the HUD goal is the quarry (%s)" % game.hud.objective_label.text)
	check(game.hud_status_text().contains("Quarry level"), "F and the status list shows the level and its progress")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
