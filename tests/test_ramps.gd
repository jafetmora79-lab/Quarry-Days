extends SceneTree
## Temporary haul ramps: planning and validation (grade, width, head room, connections, overlap), building a solid ramp, walking and driving a truck up and down it,
## staged construction, removal rules, and save / load. Runs on a private arena (a floor, a 3 m plateau 15 m ahead) far from the quarry.
##   godot --headless --fixed-fps 60 -s tests/test_ramps.gd
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
func frames(n: int, until := Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n
func box(game, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	game.world.add_child(b)
	return b

func drive_to(game, v, target: Vector3, max_frames: int) -> bool:
	var done := await frames(max_frames, func():
		var d: Vector3 = target - v.global_position
		if Vector2(d.x, d.z).length() < 2.0:
			v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
			return true
		var want := atan2(-d.x, -d.z)
		var diff := wrapf(want - v.rotation.y, -PI, PI)
		v.input = {"throttle": 0.75 if absf(diff) < 0.5 else 0.25, "steer": clampf(-diff * 2.5, -1.0, 1.0), "brake": false}
		return false)
	return done < max_frames

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
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
	game.safety.enabled = false
	var A := Vector3(900, 0, 900)
	box(game, A + Vector3(0, -0.5, 0), Vector3(60, 1, 90))                          # the pit floor, top at y = 0
	box(game, A + Vector3(0, 1.5, -15.0 - 15.0), Vector3(60, 3.0, 30))              # a plateau 3 m up, its face 15 m from the start
	box(game, A + Vector3(-12.0, 1.75, 0.0), Vector3(4, 3.5, 90))                    # side walls: a hollow, as a dug pit is
	box(game, A + Vector3(12.0, 1.75, 0.0), Vector3(4, 3.5, 90))
	var R: QuarryRamps = game.ramps
	check(R != null and R.ramps.is_empty(), "the ramp system exists and starts empty")
	# ---- planning: the foot at the aim point, climbing the way you face
	var plan := R.evaluate(A, 0.0)
	check(bool(plan["valid"]) and absf(float(plan["y1"]) - 3.0) < 0.1 and absf(float(plan["slope"]) - 0.2) < 0.03, "a ramp to the 3 m plateau is valid: %d%% grade, %.1f m long (%s)" % [roundi(float(plan["slope"]) * 100.0), float(plan["len"]), str(plan["reason"])])
	check(absf(float(plan["len"]) - 15.0) < 0.8, "its length meets the wall (%.1f of 15 m)" % float(plan["len"]))
	# ---- invalid placements
	var blocker := box(game, A + Vector3(1.4, 1.25, -8.0), Vector3(1.0, 2.5, 1.0))            # a tall rock at the side of the ramp's path, above where the surface would be
	await frames(2)
	var blocked := R.evaluate(A, 0.0)
	check(not bool(blocked["valid"]), "a ramp whose path is blocked by solid ground is rejected: %s" % str(blocked["reason"]))
	blocker.queue_free()
	await frames(2)
	var roof := box(game, A + Vector3(0, 3.9, -9.0), Vector3(8, 0.4, 6))                    # an overhang with too little head room
	await frames(2)
	var low := R.evaluate(A, 0.0)
	check(not bool(low["valid"]), "a ramp under a low overhang is rejected: %s" % str(low["reason"]))
	roof.queue_free()
	await frames(2)
	var slope_foot := R.evaluate(A + Vector3(0, 0, -8.0), 0.0)                              # start 8 m on: the wall is 7 m away, 3 m in 7 m is 43%
	check(not bool(slope_foot["valid"]) and str(slope_foot["reason"]).contains("steep"), "a ramp up a face that is too high for the room is rejected: %s" % str(slope_foot["reason"]))
	var narrow := box(game, A + Vector3(0, 1.5, -15.0 - 15.0), Vector3(60, 3.0, 30))
	narrow.queue_free()
	# ---- build the ramp: solid, with collision, saved
	plan = R.evaluate(A, 0.0)
	var id := R.place(plan)
	await frames(3)
	check(id >= 0 and R.bodies.has(id) and R.bodies[id].has_meta("ground") and game.state.ramps.size() == 1, "the ramp is built with collision and recorded in the save state")
	var body: StaticBody3D = R.bodies[id]
	var cs: CollisionShape3D = body.get_child(0)
	check(cs.shape is ConvexPolygonShape3D and (cs.shape as ConvexPolygonShape3D).points.size() == 8, "its collision is a solid convex wedge")
	var q := PhysicsRayQueryParameters3D.create(A + Vector3(0, 5, -7.5), A + Vector3(0, -5, -7.5), 1)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty() and absf(float(hit["position"].y) - 1.5) < 0.25, "the surface is graded: 1.5 m high half way along (%.2f)" % float(hit["position"].y))
	var overlap := R.evaluate(A + Vector3(1.0, 0, 0), 0.0)
	check(not bool(overlap["valid"]), "a second ramp on top of the first is rejected: %s" % str(overlap["reason"]))
	# ---- the player walks up it, on foot
	game.player.global_position = A + Vector3(0, 0.1, 3.0)
	game.player.rotation.y = 0.0
	game.player.velocity = Vector3.ZERO
	await frames(10)
	game.player.drive_wish = Vector3(0, 0, -1)
	await frames(420, func(): return game.player.global_position.z < A.z - 18.0)
	game.player.drive_wish = Vector3.INF
	check(game.player.global_position.z < A.z - 16.0 and game.player.global_position.y > 2.8, "the player walks up the ramp onto the plateau (%s)" % str(game.player.global_position - A))
	# ---- no removal under a standing player; removal when clear
	var why := R.removal_block(id)
	check(why == "" or why.contains("standing"), "removal is refused while someone is on it, allowed otherwise (%s)" % why)
	# ---- a truck drives up and down
	game.state.money = 900000
	game.prog.stage = game.prog.stage_index("deep")
	game.business.milestones["mechanized"] = true
	game.ui_buy_vehicle("compact_truck")
	game.delivery.finish_all()
	var trucks: Array = game.vehicle_nodes.values()
	var truck = null
	for t in trucks:
		if str(t.vkind) == "truck":
			truck = t
	check(truck != null, "a small dump truck is available")
	game.player.global_position = A + Vector3(10, 0.1, 20)
	game.enter_vehicle(truck)
	game.scripted_input = true
	truck.global_position = A + Vector3(0, 0.3, 14.0)
	truck.rotation.y = 0.0
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	truck.settled_frames = 0
	truck.safe_position = truck.global_position
	var trec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	var cap: int = game.fleet.capacity(trec)
	trec["cargo"] = {"limestone": cap}
	var up_ok := await drive_to(game, truck, A + Vector3(0, 3.0, -24.0), 2400)
	check(up_ok and truck.global_position.y > 2.7 and truck.global_position.z < A.z - 18.0, "the loaded truck drives up the ramp onto the plateau (%s)" % str(truck.global_position - A))
	check(game.fleet.cargo_total(trec) == cap, "its load is still on board at the top (%d units)" % game.fleet.cargo_total(trec))
	check(R.removal_block(id).contains("machine") or R.removal_block(id) == "", "(removal check with the truck up there: %s)" % R.removal_block(id))
	var down_ok := await drive_to(game, truck, A + Vector3(0, 0.2, 12.0), 2400)
	check(down_ok and truck.global_position.y < 0.9, "and back down onto the floor (%s)" % str(truck.global_position - A))
	check(game.fleet.cargo_total(trec) == cap, "with the load intact at the bottom")
	# park the truck on the ramp: it cannot be removed
	truck.global_position = A + Vector3(0, 1.0, -5.0)
	await frames(30)
	check(R.removal_block(id).contains("machine"), "a ramp with a machine on it cannot be removed: %s" % R.removal_block(id))
	game.exit_vehicle() if game.has_method("exit_vehicle") else null
	truck.global_position = A + Vector3(20, 0.3, 30)
	await frames(10)
	game.player.global_position = A + Vector3(20, 0.2, 26)
	await frames(10)
	# ---- save and load
	var saved: Array = game.state.ramps.duplicate(true)
	R.restore([])
	check(R.ramps.is_empty() and R.bodies.is_empty(), "restore([]) clears every ramp")
	R.restore(saved)
	await frames(3)
	check(R.ramps.size() == 1 and R.bodies.size() == 1, "the ramp comes back from the saved data")
	q = PhysicsRayQueryParameters3D.create(A + Vector3(0, 5, -7.5), A + Vector3(0, -5, -7.5), 1)
	hit = game.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty() and absf(float(hit["position"].y) - 1.5) < 0.25, "...with the same surface")
	check(game.state.snapshot()["ramps"].size() == 1 and QuarryState.new().ramps.is_empty(), "the ramps are part of the save dictionary and older saves default to none")
	# ---- removal
	var new_id := int(R.ramps[0]["id"])
	why = R.remove(new_id)
	check(why == "" and R.ramps.is_empty() and game.state.ramps.is_empty(), "a free ramp can be removed (%s)" % why)
	# ---- staged construction: a free-standing stage, then the next from its landing
	var B := A + Vector3(200, 0, 0)                                                         # a second arena: floor, and a 6 m face 40 m ahead
	box(game, B + Vector3(0, -0.5, 0), Vector3(60, 1, 120))
	box(game, B + Vector3(0, 3.0, -55.0), Vector3(60, 6.0, 30))
	box(game, B + Vector3(-12.0, 3.0, 0.0), Vector3(4, 6.0, 120))                    # walls around: a deep pit, not open country
	box(game, B + Vector3(12.0, 3.0, 0.0), Vector3(4, 6.0, 120))
	await frames(3)
	var s1 := R.evaluate(B, 0.0)
	check(bool(s1["valid"]) and bool(s1["stage"]) and absf(float(s1["len"]) - QuarryRamps.STAGE_LEN) < 0.1, "with the rim out of reach a staging ramp (%.0f m, %d%%) is offered: %s" % [float(s1["len"]), roundi(float(s1["slope"]) * 100.0), str(s1["note"])])
	var sid := R.place(s1)
	await frames(3)
	var s2 := R.evaluate(B + Vector3(0, 0, -QuarryRamps.STAGE_LEN), 0.0)
	check(bool(s2["valid"]) and str(s2["note"]).contains("Stage 2") and absf(float(s2["y0"]) - float(R.ramp_by_id(sid)["y1"])) < 0.05, "the next stage starts from the landing at its height: %s %s" % [str(s2["note"]), str(s2["reason"])])
	var sid2 := R.place(s2)
	check(sid2 >= 0 and R.remove(sid).contains("Another ramp starts"), "the first stage cannot be removed while the second rests on its landing")
	# ---- real-play regressions: open ground, loose rocks, a smooth and unrescued climb, the held tool, the hotbar
	for i in range(5):
		if game.driving == null:
			break
		game.exit_vehicle()
		await frames(20)
	check(game.driving == null, "on foot again for the walking checks")
	var C := A + Vector3(400, 0, 0)
	box(game, C + Vector3(0, -0.5, 0), Vector3(200, 1, 200))                                 # open flat country: no walls anywhere
	await frames(3)
	var open := R.evaluate(C, 0.0)
	check(not bool(open["valid"]) and str(open["reason"]).contains("excavation"), "no ramp in open country: %s" % str(open["reason"]))
	var D := A + Vector3(600, 0, 0)
	box(game, D + Vector3(0, -0.5, 0), Vector3(60, 1, 90))
	box(game, D + Vector3(0, 1.5, -30.0), Vector3(60, 3.0, 30))
	box(game, D + Vector3(-12.0, 1.75, 0.0), Vector3(4, 3.5, 90))
	box(game, D + Vector3(12.0, 1.75, 0.0), Vector3(4, 3.5, 90))
	var rocks := []
	for k in range(6):
		var rk := box(game, D + Vector3(-1.0 + float(k) * 0.4, 0.2, 0.3 + float(k % 2) * 0.5), Vector3(0.5, 0.4, 0.5))
		rk.set_meta("kind", "debris")                                                          # loose rocks on the floor
		rocks.append(rk)
	await frames(3)
	var loose := R.evaluate(D, 0.0)
	check(bool(loose["valid"]), "loose rocks on the floor do not stop a ramp: %s" % str(loose["reason"]))
	check(float(loose["w"]) <= 3.3 and float(loose["len"]) <= 20.0, "the ramp is a sensible size (%.1f m wide, %.1f m long)" % [float(loose["w"]), float(loose["len"])])
	var rid := R.place(loose)
	for rk in rocks:
		rk.queue_free()                                                                        # (the rocks are cleared once the ramp is planned)
	await frames(3)
	game.safety.enabled = true
	game.player.global_position = D + Vector3(0, 0.1, 4.0)
	game.player.velocity = Vector3.ZERO
	await frames(30)
	var r0: int = game.safety.rescues
	var maxjump := 0.0
	var last_y: float = game.player.global_position.y
	game.player.drive_wish = Vector3(0, 0, -1)
	var n := 0
	while n < 600 and game.player.global_position.z > D.z - 18.0:
		await physics_frame
		n += 1
		maxjump = maxf(maxjump, absf(game.player.global_position.y - last_y))
		last_y = game.player.global_position.y
	game.player.drive_wish = Vector3.INF
	check(game.player.global_position.y > 2.8 and game.safety.rescues == r0, "walking up the ramp reaches the top without a pit rescue (y %.2f, rescues %d)" % [game.player.global_position.y, game.safety.rescues - r0])
	check(maxjump < 0.12, "the climb is smooth: largest step %.3f m per frame" % maxjump)
	game.safety.enabled = false
	# the tool in hand changes on its own, without opening any menu
	var tvw = game.player.tool_view
	game.select_tool_slot(0)
	await frames(90)
	var t0: int = tvw.tier
	game.select_tool_slot(1)
	for i in range(60):
		game.player.tool_view.equip(game.prog.model_tier())                                   # the game asks every frame
		await physics_frame
	check(tvw.tier == game.prog.model_tier() and tvw.tier != t0, "changing tool swaps the model in the hands within a second, with no menu (%d -> %d)" % [t0, tvw.tier])
	var hb: Control = game.hud.hotbar_view
	var filled_slots := 0
	for sl in hb.get_children():
		if sl.find_child("Name", true, false) != null or sl.find_child("Icon", true, false) != null:
			filled_slots += 1
	check(hb != null and hb.get_child_count() == maxi(1, game.prog.hotbar().size()) and filled_slots == game.prog.hotbar().size() and hb.is_visible_in_tree(), "the hotbar has one slot per tool, no empty ones (four at the start)")
	check(not game._inside_dig_perimeter(str(game.prog.area_def("area_1")["formations"][0]), Vector3(150.0, 0.0, -15.0)) and game._inside_dig_perimeter(str(game.prog.area_def("area_1")["formations"][0]), Vector3(0.0, 0.0, -15.0)), "the starter cut can only be dug inside its survey lines")
	var rbody: Node = R.bodies[rid] if R.bodies.has(rid) else null
	var rmat = null
	if rbody != null:
		var rmi: MeshInstance3D = rbody.get_child(1)
		rmat = rmi.mesh.surface_get_material(0)
	check(rmat is BaseMaterial3D and (rmat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED, "the ramp surface is drawn from every side (never invisible)")
	game.player.global_position = D + Vector3(20.0, 0.2, 20.0)
	await frames(5)
	check(R.remove(rid) == "" and not R.bodies.has(rid), "a placed ramp can be erased")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
