extends SceneTree
## Sorting table: rocks on the surface in their own colours, a clerk assigned to the table sorts with a sorting pose while the table's real timer runs,
## sorted rock lands in the tray of its own mineral, and nothing is created or lost.   godot --headless --fixed-fps 60 -s tests/test_sorting.gd
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
func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(4)
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	game.prog.stage = game.prog.stage_index("large")
	for b in game.world.get_children():
		if str(b.name).begins_with("Debris_"):
			b.free()
	var biz: QuarryBusiness = game.business
	game.state.money = 99000
	var pos := Vector3(-8, 0, 6)
	var i: int = biz.add_output(pos, 0.0, "sorter")
	game._create_output(i)
	await frames(3)
	var o: Dictionary = biz.outputs[i]
	# ---- A: the rocks on the table follow the real contents
	var body: Node3D = game.output_nodes[i]
	await frames(3)
	var vis: Dictionary = body.get_meta("sort_vis")
	var shown := 0
	for r in vis["raws"]:
		shown += 1 if r.visible else 0
	check(shown == 0 and not vis["hop"].visible, "A an empty table shows no rocks")
	o["items"]["coal"] = 7
	o["items"]["limestone"] = 3
	await frames(3)
	shown = 0
	for r in vis["raws"]:
		shown += 1 if r.visible else 0
	check(shown >= 1, "A rocks lie on the working surface when it holds rock (%d)" % shown)
	var coal_mat = MeshKit.mat("RockCoal")
	check((vis["raws"][0] as MeshInstance3D).material_override == coal_mat, "A they show the colour of what is there (coal is charcoal)")
	check(not (body.get_meta("fill") as MeshInstance3D).visible, "A the old single heap no longer hides the table")
	# ---- B: a clerk assigned to the table
	game.state.clock_minutes = 600.0
	biz.hire("petra")
	game._sync_workers()
	var e: Dictionary = biz.employees[0]
	check(biz.assign(int(e["id"]), {"station": "sorter", "index": i}), "B a clerk can be assigned to the sorting table")
	check(not biz.assign(int(e["id"]), {"station": "sorter", "index": 5}) and not biz.assign(int(e["id"]), {"station": "sorter"}), "B an invalid table is refused")
	biz.assign(int(e["id"]), {"station": "sorter", "index": i})
	var w = game.worker_nodes[int(e["id"])]
	w.global_position = pos + Vector3(0, 0.1, 1.8)
	var total0: int = game.state.total(o["items"])
	var seen := {"sort": false, "hop": false}
	var f := await frames(60 * 40, func():
		if w.anim == "sort":
			seen["sort"] = true
		if (vis["hop"] as MeshInstance3D).visible:
			seen["hop"] = true
		return biz.sorter_sorted(i, "coal") >= 7)
	var saw_sort: bool = seen["sort"]
	var saw_hop: bool = seen["hop"]
	print("sorted after %d frames, anim saw sort=%s hop=%s task=%s" % [f, str(saw_sort), str(saw_hop), str(e["task"])])
	check(saw_sort, "B the clerk worked the table with the sorting pose while the batch ran")
	check(saw_hop, "B a rock visibly travelled from the raw tray to the sorting tray")
	check(biz.sorter_sorted(i, "coal") == 7, "B the real sorting finished: 7 coal sorted")
	check(game.state.total(o["items"]) == total0, "B no rock was created or lost (%d)" % total0)
	await frames(30)
	check((vis["piles"]["coal"] as MeshInstance3D).visible and (vis["piles"]["coal"] as MeshInstance3D).material_override == coal_mat, "C the sorted coal lies in the coal tray, in charcoal")
	check(not (vis["piles"]["iron_ore"] as MeshInstance3D).visible, "C other trays stay empty")
	# ---- D: nothing to sort: the clerk waits, no sorting animation
	await frames(600, func(): return biz.sorter_sorted(i, "limestone") >= 3)
	await frames(120)
	check(w.anim != "sort" and not biz.sorter_busy(i), "D with nothing left to sort the clerk stops sorting")
	check(biz.sorter_sorted(i, "limestone") == 3 and game.state.total(o["items"]) == total0, "D limestone sorted too, still nothing created (%d)" % total0)
	# ---- E: saving keeps the assignment
	var snap: Dictionary = biz.snapshot()
	var b2 := QuarryBusiness.new(game.state, biz.cfg)
	b2.restore(snap)
	check(JSON.stringify(b2.employees[0]["assignment"]) == JSON.stringify({"station": "sorter", "index": i}), "E the table assignment survives a save")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
