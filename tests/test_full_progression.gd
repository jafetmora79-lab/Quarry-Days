extends SceneTree
## Connected quarry, Phase E (headless): from a new game to the last stage by satisfying every requirement for real, in order - including
## all six area contracts and the quarry levels - to prove the whole chain can be finished and that no stage opens early.
##   godot --headless --fixed-fps 60 -s tests/test_full_progression.gd
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
## Cuts a level's rock down to `frac` of its units by emptying columns (what months of mining do), without paying anything.
func excavate(prog: QuarryProgression, level: int, frac: float) -> void:
	for id in prog.level_formations(level):
		prog.ensure_formation(id)
		var total := prog.max_units(id)
		var left := prog.units_left(id)
		for i in range(prog.column_count(id)):
			if float(total - left) / float(total) >= frac:
				break
			left -= prog.column_units(id, i)
			prog.state.deposits[id]["columns"][i] = 0
		prog._sync_stock(prog.state.deposits[id])
func contract(prog: QuarryProgression, id: String) -> void:
	var c: Dictionary = prog.area_def(id)["contract"]
	prog.cleanup["done"] = true
	for k in c:
		match k:
			"rock": prog.area_add(id, "rock", int(c[k]))
			"recovered": prog.area_add(id, "recovered", int(c[k]))
			"shipped": prog.area_add(id, "shipped", int(c[k]))
			"soil_removed": prog.area_add(id, "soil_removed", int(c[k]))
			"soil_hauled": prog.area_add(id, "soil_hauled", int(c[k]))
			"visit": prog.area_visit(id)
	if str(c.get("debris", "")) == "all":
		for cid in prog.cleanup_ids():
			prog.clear_cleanup_item(str(cid))
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
	var stages: Array = prog.stages()
	check(stages.size() == 12 and prog.stage == 0, "a new game starts at stage 1 of 12")
	for i in range(1, stages.size()):
		var req: Dictionary = stages[i]["req"]
		# 1. satisfy everything EXCEPT money first: the stage must not open yet
		for k in req:
			match k:
				"tool": st.tool_tier = maxi(st.tool_tier, int(req[k]))
				"employees":
					st.money = 100000
					while game.business.employees.size() < int(req[k]):
						game.business.hire("rosa" if game.business.employees.is_empty() else "dmitri")
				"crushers":
					while st.crushers.size() < int(req[k]):
						st.crushers.append({"running": false})
				"quarry_level":
					for lv in range(1, int(req[k])):
						excavate(prog, lv, 0.62)
					prog.check_levels()
				"milestones":
					for m in req[k]:
						match str(m):
							"cleanup_done": prog.cleanup["done"] = true
							"excavator_running": prog.story["excavator"].merge({"battery": true, "hose": true, "fuel": true, "started": true, "granted": true}, true)
							"soil_hauled": st.soil_dumped = 24
							"workshop_upgrade": st.upgrades["larger_backpack"] = true
							"crusher_built":
								if st.crushers.is_empty():
									st.crushers.append({"running": false})
								prog.story["milestones"]["crusher_built"] = true
							_:
								if str(m).begins_with("area_"):
									var aid := str(m).replace("_complete", "")
									for pre in prog.area_def(aid).get("requires", []):
										if not prog.area_complete(str(pre)):
											contract(prog, str(pre))
									contract(prog, aid)
									prog.area_visit(aid)
				"owns":
					st.tool_tier = maxi(st.tool_tier, 2)
					for o in req[k]:
						if not prog.owns(str(o)):
							st.gear.append(str(o))
				"discover":
					for r in req[k]:
						st.lifetime["mined"][str(r)] = 5
				"delivered":
					for r in req[k]:
						st.lifetime["sold"][str(r)] = int(req[k][r])
		prog.check_stages()
		var earned_needed := int(req.get("earned", 0))
		if earned_needed > 0:
			check(prog.stage < i, "stage %d (%s) does not open before the money is earned" % [i + 1, str(stages[i]["id"])])
			st.add_income(earned_needed - st.earned + 1, "sale")
		prog.check_stages()
		if prog.stage < i:
			print("UNMET ", str(stages[i]["id"]), " ", str(prog.requirement_progress(i)))
		check(prog.stage >= i, "stage %d (%s) opens once every requirement is met" % [i + 1, str(stages[i]["id"])])
	check(prog.stage == 11, "the last stage (Quarry Empire) is reached")
	var done := 0
	for a in prog.area_defs():
		if prog.area_complete(str(a["id"])):
			done += 1
	check(done == 6, "all six area contracts were completed on the way (%d)" % done)
	check(prog.units_left("q_top" if prog.filled_world() else "hillside_face_01") > 0 and prog.units_left("q_a5_gold" if prog.filled_world() else "bench_l4_gold") > 0, "completing them left the rest of the rock in place")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
