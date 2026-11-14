extends SceneTree
## The objective window counts real work: clearing weeds and rubble moves the "clear the site" requirement, the stage bar and percentage, the cleanup block and
## the area percentage, in step with each other; it never shows 0% after work has been done and never 100% before everything is.
##   godot --headless --fixed-fps 60 -s tests/test_objective_progress.gd
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
func req(prog, title_part: String) -> Array:
	for r in prog.requirement_progress(prog.stage + 1):
		if str(r[0]).contains(title_part):
			return r
	return []
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(30)
	var prog: QuarryProgression = game.prog
	var total: int = prog.cleanup_total()
	check(total > 10, "there is a site to clear (%d items)" % total)
	var r0 := req(prog, "overgrown")
	check(not r0.is_empty() and int(r0[1]) == 0 and int(r0[2]) == total, "the requirement is measured in items: 0 of %d" % total)
	var bar0: float = game.hud._obj_target
	var ids: Array = prog.cleanup_ids()
	var last_pct := -1
	var last_area := -1
	var monotone := true
	for k in range(total - 1):
		prog.clear_cleanup_item(str(ids[k]))
		if k % 4 == 3 or k < 3:
			await frames(4)
			var r := req(prog, "overgrown")
			var pct: int = int(game.hud.objective_pct.text.trim_suffix("%"))
			if pct < last_pct:
				monotone = false
			last_pct = pct
			var ap: Dictionary = prog.area_progress("area_1")
			if not ap.is_empty():
				if int(ap["pct"]) < last_area:
					monotone = false
				last_area = int(ap["pct"])
			if k == 1:
				check(int(r[1]) == 2 and int(r[2]) == total, "after 2 items the requirement reads 2 of %d (not 0%%)" % total)
				check(game.hud._obj_target > bar0, "and the stage bar has moved (%.3f > %.3f)" % [game.hud._obj_target, bar0])
				check(last_pct >= 1, "and the percentage shows it (%d%%)" % last_pct)
				var rows: Array = game.hud_progress_rows()
				check(rows.size() >= 1 and str(rows[0]["value"]) == "2 / %d" % total and absf(float(rows[0]["frac"]) - 2.0 / float(total)) < 0.001, "the cleanup block says 2 / %d with a matching bar" % total)
				if not ap.is_empty():
					check(int(ap["pct"]) >= 1, "and the area contract is at least 1%% once work is done (%d%%)" % int(ap["pct"]))
	check(monotone, "every percentage only ever goes up as work is done")
	check(game.hud._obj_target < 1.0 and last_pct < 100, "one item short of done the bar and percentage are below 100%% (%d%%)" % last_pct)
	var ap2: Dictionary = prog.area_progress("area_1")
	if not ap2.is_empty():
		check(int(ap2["pct"]) < 100 or bool(ap2["complete"]), "the area contract is not 100%% before it is complete (%d%%)" % int(ap2["pct"]))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
