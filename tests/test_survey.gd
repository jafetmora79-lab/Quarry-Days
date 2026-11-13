extends SceneTree
## Survey-guided construction: dashed survey lines and stakes mark the starter area and the open / next quarry levels, thin and subtle, and
## disappear when their work is done; the quarry plan page lists the four levels.   godot --headless --fixed-fps 60 -s tests/test_survey.gd
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
	var g = load("res://Main.tscn").instantiate()
	g.autosave_enabled = false
	g.title_enabled = false
	g.introductions_enabled = false
	g.curfew_enabled = false
	root.add_child(g)
	await process_frame
	await frames(10)
	g.hud.close_card()
	var sv: QuarrySurvey = g.survey
	sv.refresh(true)
	var t: Array = sv.targets()
	var ids := []
	for x in t:
		ids.append(str(x["id"]))
	check("area_1" in ids, "the starter excavation is marked at the start (%s)" % str(ids))
	check("level_2" in ids and not ("level_3" in ids), "the next quarry level is marked, deeper ones are not (%s)" % str(ids))
	check(sv.rects.has("area_1") and (sv.rects["area_1"] as MeshInstance3D).mesh.get_surface_count() > 0, "the survey line is a real mesh")
	var mi: MeshInstance3D = sv.rects["area_1"]
	var aabb: AABB = mi.mesh.get_aabb()
	check(aabb.size.y < 0.1 and mi.get_child_count() == 1, "the dashes are thin ground markings (%.2f m high) with separate stakes" % aabb.size.y)
	var bw := 0.0
	for x in t:
		if x["id"] == "area_1":
			bw = (x["rect"] as Rect2).size.x
	check(aabb.size.x > bw - 1.0 and aabb.size.x < bw + 1.0, "it runs round the whole area boundary (%.1f of %.1f m)" % [aabb.size.x, bw])
	check(not mi.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "no glowing translucent slab")
	# the starter area is finished: its marking goes
	g.prog.cleanup["done"] = true
	g.prog.area_add("area_1", "soil_removed", 48)
	g.prog.area_add("area_1", "soil_hauled", 24)
	g.prog.area_add("area_1", "rock", 60)
	sv.refresh()
	check(g.prog.area_complete("area_1") and not sv.rects.has("area_1"), "when the starter area is done its survey lines are gone")
	# a new level opens: its lines turn active and the next level is marked
	g.prog.quarry_level = 2
	sv.refresh()
	ids = []
	for x in sv.targets():
		ids.append(str(x["id"]) + ":" + str(x["state"]))
	check("level_2:active" in ids and "level_3:next" in ids and not ("level_4:next" in ids or "level_4:active" in ids), "opening level 2 marks it active and level 3 next (%s)" % str(ids))
	# the quarry plan page
	g._open_menu("manage")
	g.management._set_tab("plan")
	await frames(2)
	var txt := ""
	for l in g.management.content.find_children("*", "Label", true, false):
		txt += str(l.text) + "\n"
	check(txt.contains("LEVEL 1") and txt.contains("LEVEL 4") and txt.contains("LOCKED") and txt.contains("OPEN"), "the quarry plan lists all four levels with their state")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
