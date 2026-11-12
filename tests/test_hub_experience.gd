extends SceneTree
## Phase 8.3: the industrial hub experience: worker variety and looks, the hiring greeting, idle remarks, the physical workbench
## and its panel, and size-aware equipment parking.
##   godot --headless --fixed-fps 60 -s tests/test_hub_experience.gd

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

func texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	if node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		texts(c, out)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._remove_walter()
	var prog: QuarryProgression = game.prog
	var biz: QuarryBusiness = game.business
	game.player.locked = false
	game.state.money = 500000
	# ---- 1: candidates and looks
	var cands: Array = biz.cfg["candidates"]
	var f := 0
	var m := 0
	for c in cands:
		if str(c["gender"]) == "f":
			f += 1
		else:
			m += 1
	check(cands.size() == 12 and f >= 5 and m >= 5, "1 twelve candidates, both feminine and masculine (%d f, %d m)" % [f, m])
	prog.stage = prog.stage_index("deep")
	game.state.clock_minutes = 600.0
	biz.payroll_minute = 600
	game.ui_hire("rosa")
	game.ui_hire("dmitri")
	game.ui_hire("ines")
	var es: Array = biz.employees
	check(es.size() == 3 and es[0]["look"] is Dictionary and es[0]["gender"] == "f" and es[1]["gender"] == "m", "1b a hire keeps the candidate's gender and gets a stored look")
	var keys := ["gender", "hair", "hair_tone", "skin", "height", "outfit", "accessory"]
	var has_all := true
	for e in es:
		for k in keys:
			has_all = has_all and e["look"].has(k)
	check(has_all, "1c every look has gender, hair style and colour, skin, height, outfit and an accessory")
	# ---- 2: it shows on the model
	for n in game.worker_nodes.values():
		n.queue_free()
	game.worker_nodes.clear()
	es[0]["look"]["accessory"] = "hardhat"
	es[0]["look"]["hair"] = "ponytail"
	es[1]["look"]["accessory"] = "glasses"
	es[1]["look"]["hair"] = "short"
	es[2]["look"]["accessory"] = "bandana"
	es[2]["look"]["hair"] = "long"
	game._sync_workers()
	await frames(4)
	var w0 = game.worker_nodes[int(es[0]["id"])]
	var w1 = game.worker_nodes[int(es[1]["id"])]
	var gear0 = w0.find_child("HeadGear", true, false)
	var gear1 = w1.find_child("HeadGear", true, false)
	check(gear0 != null and gear0.get_child_count() >= 4, "2 a feminine worker with a ponytail and hard hat has them on her head socket (%d parts)" % (gear0.get_child_count() if gear0 else 0))
	check(gear1 != null and gear1.get_child_count() >= 2, "2b a masculine worker with glasses has them (%d parts)" % (gear1.get_child_count() if gear1 else 0))
	check(w0.model.get_child(0).scale.x < w0.model.get_child(0).scale.y and absf(w1.model.get_child(0).scale.x - w1.model.get_child(0).scale.y) < 0.001, "2c the feminine build is slighter, the masculine is the base model")
	var tinted := false
	for mi in w0.model.find_children("*_Body", "MeshInstance3D", true, false):
		tinted = tinted or mi.material_override != null or es[0]["look"]["outfit"] == 0
	check(tinted, "2d the outfit tint is applied")
	# ---- 3: looks survive saves; older saves get a stable look
	var snap := biz.snapshot()
	biz.restore(snap)
	check(biz.employees[0]["look"]["hair"] == "ponytail" and biz.employees[0]["look"]["accessory"] == "hardhat" and biz.employees[2]["look"]["hair"] == "long", "3 looks survive save and load")
	var old := {"id": 55, "profession": "miner", "name": "Old Timer", "skill": 2}
	QuarryBusiness.ensure_identity(old)
	var look_a: Dictionary = old["look"].duplicate()
	var old2 := {"id": 55, "profession": "miner", "name": "Old Timer", "skill": 2}
	QuarryBusiness.ensure_identity(old2)
	check(look_a == old2["look"], "3b an older worker gets the same look every time")
	# ---- 4: the greeting
	var d := QuarryIntroDialog.new()
	d.setup("Alex", "friendly", "Miner")
	check(d.title.text.begins_with("ALEX") and d.body.text.contains("Alex"), "4 the new hire introduces themselves by name")
	d._next()
	check(d.title.text == "YOU" and QuarryIntroDialog.PLAYER_LINES.any(func(l): return d.body.text.contains(l)), "4b the player welcomes them (%s)" % d.body.text)
	d._next()
	check(d.name_edit.visible and d.body.text.contains("Alex"), "4c they ask about their name; the box is open")
	d.name_edit.text = "Sam"
	d._next()
	check(d.body.text.contains("Sam") and d.body.text.contains("Where do you need me"), "4d they answer with the chosen name and ask where to work")
	var got := []
	d.finished.connect(func(n: String, s: bool): got.append([n, s]))
	d._next()
	check(got.size() == 1 and got[0][0] == "Sam" and not got[0][1], "4e confirming finishes with the name")
	var d2 := QuarryIntroDialog.new()
	d2.setup("Alex", "serious", "Hauler")
	var skipped := []
	d2.finished.connect(func(n: String, s: bool): skipped.append(s))
	d2.skip_btn.pressed.emit()
	check(skipped == [true], "4f the greeting can be skipped")
	d.free()
	d2.free()
	# first-person turn toward the new hire, camera comes back
	game.introductions_enabled = true
	var w = w1
	w.e["intro_done"] = false
	game.player.global_position = Vector3(2, 0.2, 18)
	w.global_position = Vector3(8, 0, 18)
	game.player.rotation.y = 0.0
	game._start_intro(w)
	await frames(50)
	var to: Vector3 = w.global_position - game.player.global_position
	var want := atan2(-to.x, -to.z)
	check(absf(angle_difference(game.player.rotation.y, want)) < 0.15 and game.player.locked, "4g the view turns to face the new hire while the player talks")
	game._end_intro("Alex", false)
	await frames(40)
	check(not game.player.locked and absf(game.player.camera.rotation.x) < 0.02, "4h control and the camera come back smoothly")
	# ---- 5: idle remarks follow personality
	var lines := {}
	for p in QuarryBusiness.PERSONALITIES:
		lines[QuarryIntroDialog.bark_for(p, 0)] = true
	check(lines.size() == 5, "5 each personality has its own remarks")
	w0.e["intro_done"] = true
	w0.bark_t = 0.0
	game.player.global_position = w0.global_position + Vector3(3, 0.2, 0)
	w0._bark_tick(0.016)
	check(w0.bark_label != null and w0.bark_label.visible and w0.bark_label.text != "", "5b a worker near the player says something (%s)" % (w0.bark_label.text if w0.bark_label else ""))
	# ---- 6: the workbench
	var bench = game.world.get_node_or_null("Workbench")
	check(bench != null and str(bench.get_meta("kind")) == "upgrades", "6 there is a physical workbench in the office that opens the upgrades")
	var bc: Vector3 = bench.global_position
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 0.5, 0.6)
	q.shape = sh
	q.transform = Transform3D(Basis(), bc)
	q.collision_mask = 0xFFFF
	q.exclude = [bench.get_rid()]
	var hits: Array = game.get_world_3d().direct_space_state.intersect_shape(q, 6)
	var others := []
	for h in hits:
		others.append(str(h["collider"].name))
	check(others.is_empty() and bc.x - 0.75 > game.OFFICE_POS.x - 2.29 and bc.x + 0.75 < game.OFFICE_POS.x - 0.7 and bc.z - 0.35 > game.OFFICE_POS.z - 2.24, "6a the bench stands clear inside the office, left of the door, against the front wall (%s)" % str(others))
	# the way in is free: walk from the door to the management desk
	game.player.locked = false
	game.safety.enabled = false
	game.player.global_position = game.OFFICE_POS + Vector3(0.0, 0.2, -3.2)
	await frames(10)
	var reached := false
	var goal: Vector3 = game.OFFICE_POS + Vector3(0.0, 0.0, 0.5)
	for i in range(420):
		var dd := Vector3(goal.x - game.player.global_position.x, 0, goal.z - game.player.global_position.z)
		if dd.length() < 0.3:
			reached = true
			break
		game.player.drive_wish = dd
		await physics_frame
	game.player.drive_wish = Vector3.INF
	game.safety.enabled = true
	check(reached, "6a2 the player can still walk in through the office door to the desk")
	check(game.workbench_tools != null and game.workbench_tools.get_child_count() >= 12, "6b the tools hang on the pegboard (%d parts)" % game.workbench_tools.get_child_count())
	check(game.workbench_tag.text.contains("Next:") and game.workbench_tag.text.contains(str(prog.next_tool()["title"])), "6c a sign shows the next tool and its price")
	game.state.money = 5
	game._open_menu("upgrades", -1)
	await frames(3)
	var all := []
	texts(game.panel, all)
	var joined := " | ".join(all)
	check(joined.contains("WORKBENCH") and joined.contains("IN YOUR HAND") and joined.contains("NEXT ON THE PEGBOARD"), "6d the panel shows the tool in hand and the next one")
	check(joined.contains("damage a second") and joined.contains("hardness") and joined.contains("%"), "6e with damage, speed and hardness, and the gain in percent")
	check(joined.contains("Need $"), "6f too little money shows what is missing instead of a buy button")
	game._close_menu()
	game.state.money = 500000
	var tier0: int = game.state.tool_tier
	game.buy_next_tool()
	await frames(3)
	check(game.state.tool_tier == tier0 + 1 and (game.workbench_tag.text.contains(str(prog.next_tool()["title"])) if not prog.next_tool().is_empty() else true), "6g buying a tool updates the bench sign")
	while not prog.next_tool().is_empty():
		game.buy_next_tool()
	await frames(3)
	check(game.workbench_tag.text.contains("All tools owned"), "6h with everything bought the sign says so")
	# ---- 7: parking is sized by footprint
	for v in game.vehicle_nodes.values():
		v.queue_free()
	game.vehicle_nodes.clear()
	game.fleet.vehicles.clear()
	await frames(3)
	var small: Vector3 = game.free_parking_slot("loader")
	var big: Vector3 = game.free_parking_slot("industrial_truck")
	check(small != null and big != null and big.z < small.z, "7 a longer machine is parked further forward so its tail stays in line (z %.1f vs %.1f)" % [big.z, small.z])
	check(absf((small.z + 1.5) - (big.z + 2.8)) < 0.01, "7b every machine's back edge ends at the same line inside the garage")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
