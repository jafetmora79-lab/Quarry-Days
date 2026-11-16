extends SceneTree
## The Production Overview in Quarry OS: every placed machine is listed as running, idle or blocked, with the reason (no operator, output full, belt not
## connected, destination full ...), read live from the simulation.
##   godot --headless --fixed-fps 60 -s tests/test_production_overview.gd

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

func row_of(rows: Array, name: String) -> Dictionary:
	for r in rows:
		if str(r["name"]) == name:
			return r
	return {}

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 6:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var st = game.state
	var biz = game.business
	var o := Vector3(40.0, 0.0, 40.0)
	st.new_crusher(o + Vector3(4.2, 0, 0), PI * 0.5, 1)
	game._create_crusher(st.crushers.size() - 1)
	var ci: int = st.crushers.size() - 1
	var bin: int = biz.add_output(o + Vector3(0, 0, -4.0), 0.0)
	game._create_output(bin)
	var m: int = biz.add_conveyor(o, 0.0, "merger")
	game._create_conveyor(m)
	var o1: int = biz.add_conveyor(o + Vector3(0, 0, -2.0), 0.0)
	game._create_conveyor(o1)
	var a: int = biz.add_conveyor(o + Vector3(2, 0, 0), PI * 0.5)
	game._create_conveyor(a)
	var lone: int = biz.add_conveyor(o + Vector3(30, 0, 30), 0.0)
	game._create_conveyor(lone)
	biz.compute_links()
	var rows: Array = biz.production_overview()
	check(rows.size() == st.crushers.size() + biz.conveyors.size() + biz.outputs.size(), "every placed machine is listed (%d rows)" % rows.size())
	var cr := row_of(rows, "Crusher #%d" % (ci + 1))
	check(str(cr.get("state", "")) == "idle" and str(cr["reason"]).contains("No limestone"), "an empty crusher is idle: %s" % str(cr.get("reason")))
	st.crushers[ci]["hopper"] = 6
	cr = row_of(biz.production_overview(), "Crusher #%d" % (ci + 1))
	check(str(cr["state"]) == "blocked" and str(cr["reason"]).contains("operator"), "limestone but nobody running it: blocked (%s)" % str(cr["reason"]))
	st.crushers[ci]["hopper"] = 0
	st.crushers[ci]["input"] = 4
	st.start_crusher(ci)
	cr = row_of(biz.production_overview(), "Crusher #%d" % (ci + 1))
	check(str(cr["state"]) == "running", "a crusher that is crushing is running (%s)" % str(cr["reason"]))
	st.crushers[ci]["running"] = false
	st.crushers[ci]["input"] = 0
	var lr := row_of(biz.production_overview(), "Conveyor #%d" % (lone + 1))
	check(str(lr["state"]) == "blocked" and str(lr["reason"]).contains("Not connected"), "a belt standing alone is blocked: %s" % str(lr["reason"]))
	var br := row_of(biz.production_overview(), "Output storage #%d" % (bin + 1))
	check(str(br["state"]) == "idle" and str(br["reason"]) == "Empty", "an empty bin is idle")
	# material flowing
	st.crushers[ci]["output"] = 12
	for i in 60:
		biz.tick_conveyors(0.1)
	var ar := row_of(biz.production_overview(), "Conveyor #%d" % (a + 1))
	check(str(ar["state"]) == "running", "a belt carrying stone is running (%s)" % str(ar["reason"]))
	var mr := row_of(biz.production_overview(), "Merger #%d" % (m + 1))
	check(str(mr["state"]) in ["running", "idle"] and mr["name"] == "Merger #%d" % (m + 1), "the merger is listed as a merger")
	# full bin: the line blocks and says why
	biz.outputs[bin]["items"]["crushed_stone"] = biz.output_capacity()
	for i in 600:
		biz.tick_conveyors(0.1)
	br = row_of(biz.production_overview(), "Output storage #%d" % (bin + 1))
	check(str(br["state"]) == "blocked" and str(br["reason"]).contains("Full"), "a full bin is blocked: %s" % str(br["reason"]))
	var blocked_belt := false
	for r in biz.production_overview():
		if str(r["kind"]) == "conveyor" and str(r["state"]) == "blocked" and str(r["reason"]).contains("full"):
			blocked_belt = true
	check(blocked_belt, "and the belt into it reports the destination is full")
	# the page
	game.management.os.open_app("production")
	await process_frame
	await process_frame
	var w = game.management.os.window_of("production")
	var txt := ""
	if w != null and w.page != null:
		for l in w.page.content.find_children("*", "Label", true, false):
			txt += (l as Label).text + " "
	check(txt.contains("PRODUCTION OVERVIEW") and txt.contains("BLOCKED") and txt.contains("Merger #"), "the Production page shows the overview with BLOCKED rows and the merger")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
