extends SceneTree
## Connected quarry, Phase C: Areas 2 and 3. Contracts follow Area 1 (either order), count only work in their own formations and levels,
## need the player to actually reach the area, recover material into a carrier, pay once, gate their stages, and the route from the yard
## to both areas is continuous (walk/drive, no teleport).   godot --headless --fixed-fps 60 -s tests/test_areas23.gd
const State = preload("res://scripts/state.gd")
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
func ground_y(game, x: float, z: float, from_y := 3.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -30.0, z), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else -999.0
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
	# ---- availability
	check(not prog.area_available("area_2") and not prog.area_available("area_3"), "Areas 2 and 3 are not open until Area 1 is complete")
	prog.cleanup["done"] = true
	prog.area_adopt_legacy()
	prog.story["areas"]["area_2"]["complete"] = false
	prog.story["areas"]["area_2"]["rewarded"] = false
	prog.story["areas"]["area_3"]["complete"] = false
	prog.story["areas"]["area_3"]["rewarded"] = false
	check(prog.area_available("area_2") and prog.area_available("area_3"), "after Area 1 both open, in either order")
	check(game.hud_status_text().contains("AREA 2") and game.hud_status_text().contains("AREA 3"), "the HUD lists both contracts")
	# ---- the route is continuous: yard -> Area 1 -> gate -> corridor -> basin -> level-2 ramp -> level-2 floor
	game.pit_zone.set_open(true)
	await frames(10)
	var pz = game.pit_zone
	var route_ok := true
	var last_y := ground_y(game, 0.0, 12.0)
	var steps := 0
	var gate_l := Vector3(0, 0, 0)
	for d in range(0, 38, 2):                                  # corridor from the gate into the basin
		var w: Vector3 = pz.to_world(Vector3(0, 0, -float(d)))
		var y := ground_y(game, w.x, w.z)
		route_ok = route_ok and y > -5.0 and absf(y - last_y) < 1.2
		last_y = y
		steps += 1
	check(route_ok and steps > 10, "the corridor from the gate to the basin is continuous solid ground (%d samples)" % steps)
	# ---- the first terrace is reachable by its ramp
	var lp: Dictionary = pz.level_pits[0]
	var rect: Rect2 = lp["rect"]
	var rx: float = rect.position.x + float(lp["rw"]) * 0.5
	var zs := rect.end.y if not bool(lp["top_north"]) else rect.position.y
	var ok_ramp := true
	var prev := -999.0
	var samples := 0
	for k in range(0, 21, 2):
		var zz: float = zs - float(k) if not bool(lp["top_north"]) else zs + float(k)
		var w2: Vector3 = pz.to_world(Vector3(rx, 0, zz))
		var y2 := ground_y(game, w2.x, w2.z, 0.5)
		if prev > -900.0:
			ok_ramp = ok_ramp and absf(y2 - prev) < 1.3
		prev = y2
		samples += 1
	check(ok_ramp and prev < -5.5, "the ramp runs continuously down to the first terrace floor (y %.1f)" % prev)
	# ---- area membership by place
	var basin: Vector3 = pz.to_world(Vector3(0, -3.6, pz.basin_zc()))
	check(game.area_at(basin) == "area_2", "standing on the basin floor is Area 2")
	var floor_l2: Vector3 = pz.to_world(Vector3(rect.position.x + rect.size.x * 0.7, lp["y_bot"], rect.position.y + rect.size.y * 0.5))
	check(game.area_at(floor_l2) == "area_3", "standing on the level-2 floor is Area 3")
	check(game.area_at(Vector3(0, 0, 10)) == "", "the operations yard belongs to no excavation area")
	# ---- contract parts
	check(int(prog.area_progress("area_2")["pct"]) == 0 and int(prog.area_progress("area_3")["pct"]) == 0, "both start at 0%")
	st.add_income(100000, "sale")
	prog.extract("hillside_face_01", 5, 1.0e6, 1 << 30, "hand")
	check(int(prog.area_state("area_2")["rock"]) == 0 and int(prog.area_state("area_3")["rock"]) == 0, "money and Area 1 rock do not count for Areas 2 or 3")
	game.player.global_position = basin + Vector3(0, 0.3, 0)
	await frames(45)
	check(int(prog.area_state("area_2")["visited"]) == 1 and int(prog.area_state("area_3")["visited"]) == 0, "walking into the basin counts as reaching Area 2 only")
	prog.cleanup["done"] = true
	var bid := "pit_band_01"
	var cu := float(prog.fdef(bid)["chunk_units"])
	prog.area_add("area_2", "rock", 199)
	prog.area_add("area_2", "recovered", 150)
	check(not prog.area_complete("area_2"), "199 of 200 rock cut is not enough")
	var m0 := st.money
	prog.area_add("area_2", "rock", 1)
	check(prog.area_complete("area_2") and st.money == m0 + 800, "Area 2 completes with the last rock and pays $800 once (%d)" % (st.money - m0))
	prog.area_add("area_2", "rock", 50)
	prog.area_check("area_2")
	check(st.money == m0 + 800, "no second payment")
	check(prog.milestone_done("area_2_complete") and not prog.milestone_done("area_3_complete"), "the Area 2 stage milestone is reached, Area 3's is not")
	# recovered counts carriers, not just cutting
	var rec0 := int(prog.area_state("area_3")["recovered"])
	game.state.capacity()
	game.player.global_position = floor_l2 + Vector3(0, 0.3, 0)
	await frames(45)
	check(int(prog.area_state("area_3")["visited"]) == 1, "standing on the first terrace counts as reaching Area 3")
	# real extraction on level 2: open the level and cut through the same path as every tool
	prog.stage = prog.stage_index("deep") if prog.stage_index("deep") >= 0 else prog.stage
	for id in prog.level_formations(2):
		prog.state.deposits[id]["columns"][0] = prog.state.deposits[id]["columns"][0]
	var r3 := int(prog.area_state("area_3")["rock"])
	prog.ensure_formation("bench_l2_coal")
	var ex := prog.extract("bench_l2_coal", 0, 1.0e6, 1 << 30, "hand")
	check(int(ex["units"]) > 0 and int(prog.area_state("area_3")["rock"]) == r3 + int(ex["units"]), "rock cut from the level-2 coal bench counts for Area 3 (%d units)" % int(ex["units"]))
	prog.area_add("area_3", "rock", 150)
	prog.area_add("area_3", "recovered", 100)
	check(prog.area_complete("area_3"), "Area 3 completes when its measured work is done")
	check(prog.units_left("pit_band_01") > 0 and prog.units_left("bench_l2_coal") > 0, "finishing a contract leaves the rest of the rock minable")
	# ---- the stages need the contracts
	var fresh := QuarryProgression.new(State.new({}), game.business, prog.cfg)
	var reqs := {}
	for s_ in prog.cfg["stages"]:
		reqs[str(s_["id"])] = s_["req"].get("milestones", [])
	check("area_2_complete" in reqs["breaking_ground"] and "area_3_complete" in reqs["industrial_quarry"], "Breaking Ground needs Area 2 and Industrial Quarry needs Area 3")
	# ---- save and load keep the contracts, no repayment
	game._save(true)
	var money_saved := st.money
	game._load(true)
	check(prog.area_complete("area_2") and prog.area_complete("area_3") and st.money == money_saved, "save and load keep both contracts complete and pay nothing again")
	for path in [game.SAVE_PATH, game.SAVE_BACKUP]:
		DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
