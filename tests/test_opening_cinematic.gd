extends SceneTree
## The opening cinematic: the drive in Walt's pickup (road, tunnel, yard), the deed handoff, the walk to the excavator, the skip path (same final state at any moment), no replay on
## an existing save, no duplicate deed, the camera / controls / HUD restored.
##   godot --headless --fixed-fps 60 -s tests/test_opening_cinematic.gd
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
func make(drive: bool):
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = drive
	root.add_child(game)
	return game
func esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	return ev
func wait_until(game, cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await physics_frame
		n += 1
	return n

func run() -> void:
	# ---------------------------------------------------------------- data
	var game = make(true)
	await process_frame
	await frames(6)
	var cine: Array = game.prog.walter_cfg().get("cinematic", [])
	var said := ""
	for l in cine:
		said += str(l["text"]) + "|"
	for s in ["why are we going to your old workplace", "Retired from working for somebody else", "a hole in a mountain", "forty years of work", "rough around the edges",
			"what exactly am I supposed to do with it", "It's yours now", "you're giving me the quarry", "good fishing rod", "Get that old machine running"]:
		check(said.contains(s), "the script has the line: " + s)
	var total := 0.0
	for l in cine:
		total += float(l["dur"])
	check(total >= 85.0 and total <= 150.0, "the lines and beats add up to %.0f s; with the fades, the walk and the first-job shot the opening is about 2 minutes" % total)
	check(game.opening_scene != null and game.opening_scene.phase == "drive", "the opening starts with the drive")
	var sc = game.opening_scene
	check(game.player.locked and game.walter_intro_running, "the player is locked in the pickup")
	# the route: a road, a through tunnel, the yard
	check(sc.path.size() > 150 and sc.path_len > 180.0 and sc.path_len < 330.0, "the route is %.0f m long" % sc.path_len)
	var in_tunnel := false
	for q in sc.path:
		if q.x > -110.0 and q.x < -30.0 and absf(q.z - 25.4) < 0.5:
			in_tunnel = true
	check(in_tunnel, "the route runs straight through the tunnel")
	var clear := true
	for q in sc.path:
		if q.x > -112.0 and q.x < -27.0 and absf(q.z - 25.4) > 3.0:
			clear = false
	check(clear, "the route stays inside the tunnel's 6.8 m")
	var rig = game.truck_node
	check(game.walter_node.get_parent() == rig and game.truck_node.get_meta("pickup")["interior"].visible, "Walt sits in the cab; the cab is furnished")
	var start: Vector3 = rig.global_position
	var eye0: Vector3 = game.player.camera.global_position
	await frames(240)
	check(rig.global_position.distance_to(start) > 10.0, "the pickup is driving (%.1f m after 4 s)" % rig.global_position.distance_to(start))
	var eye1: Vector3 = game.player.camera.global_position
	var rel: Vector3 = rig.global_transform.affine_inverse() * eye1
	check(rel.distance_to(PickupModel.EYE + Vector3(0, 0, 0)) < 0.2, "the player's eyes stay on the passenger seat (%.2f off)" % rel.distance_to(PickupModel.EYE))
	# limited look-around
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(-9000, -9000)
	sc._input(mm)
	check(absf(sc.look_yaw) <= 1.001 and sc.look_pitch >= -0.43 and sc.look_pitch <= 0.39, "looking round is limited (yaw %.2f pitch %.2f)" % [sc.look_yaw, sc.look_pitch])
	sc.look_yaw = 0.0
	sc.look_pitch = 0.0
	# dialogue order
	var seen := []
	await wait_until(game, func():
		if game.walter_dialog != null and game.walter_dialog.visible:
			var t := str(game.walter_dialog.lines[game.walter_dialog.index].get("text", ""))
			if seen.is_empty() or seen[seen.size() - 1] != t:
				seen.append(t)
		return rig.global_position.x < -100.0 and sc.clock > 20.0, 60 * 40)
	check(seen.size() >= 2 and seen[0].contains("Grandpa, why are we going"), "the player's first line comes first")
	# in the tunnel
	await wait_until(game, func(): return rig.global_position.x > -100.0 and absf(rig.global_position.z - 25.4) < 1.0, 60 * 30)
	check(rig.global_position.x > -100.0 and game.delivery.far_gate != null and not game.delivery.far_gate.visible, "the far service gate is open for the drive")
	check(rig.get_node("Pickup/Headlights").visible, "the headlights are on in the tunnel")
	check(game.truck_node.collision_layer == 0, "the pickup is no obstacle while it drives")
	# to the end of the drive
	await wait_until(game, func(): return sc.phase != "drive", 60 * 50)
	check(sc.phase == "exit" or sc.phase == "yard", "the drive ends by itself (clock %.1f s of %.1f)" % [sc.clock, sc.drive_total])
	await wait_until(game, func(): return sc.phase == "yard", 60 * 4)
	await frames(5)
	check(game.truck_node.global_position.distance_to(truck_spot(game)) < 0.1, "the pickup is parked at its spot (%s)" % str(game.truck_node.global_position))
	check(not game.truck_node.get_meta("pickup")["interior"].visible and game.delivery.far_gate.visible, "the cab and the far gate are put back")
	check(game.walter_node.get_parent() == game.world and game.walter_node.scale.is_equal_approx(Vector3.ONE), "Walt stands in the yard")
	check(game.walter_dialog != null and game.walter_dialog.lines[0]["text"].contains("rough around the edges"), "the yard conversation starts")
	# deed handoff
	await wait_until(game, func(): return sc.deed != null, 60 * 25)
	check(sc.deed != null and sc.deed.get_parent() == game.world, "the deed leaves Walt's pocket")
	var labels := []
	for c in sc.deed.find_children("*", "Label3D", true, false):
		labels.append(c.text)
	check("PROPERTY DEED" in labels and "GREYHAVEN QUARRY" in labels and "Walter" in labels, "the deed has its heading, the quarry's name and Walt's signature")
	await wait_until(game, func(): return sc.deed_given, 60 * 10)
	check(sc.deed.get_parent() == game.player.camera and sc.hands != null and sc.hands.get_parent() == game.player.camera, "the deed is held in the player's hands in front of the camera")
	check(absf(sc.deed.position.x) < 0.01 and sc.deed.position.z < -0.3 and sc.deed.position.z > -0.5, "the paper is at reading distance")
	check(bool(game.prog.story.get("deed_received", false)), "the deed is recorded as received")
	var journal_n: int = game.prog.story["journal"].size()
	# the rest of the yard scene
	await wait_until(game, func(): return sc.phase == "post_walk" or sc.phase == "post", 60 * 40)
	check(sc.deed == null and game.player.camera.rotation.x > -0.05, "the deed is put away and the camera comes back level")
	check(game.walter_mode == "to_post" or game.walter_mode == "waiting", "Walt walks to the old excavator")
	await wait_until(game, func(): return sc.phase == "post", 60 * 20)
	check(game.walter_node.global_position.distance_to(post_spot(game)) < 0.6, "Walt arrives at the excavator (%.2f m off)" % game.walter_node.global_position.distance_to(post_spot(game)))
	check(game.walter_dialog != null and str(game.walter_dialog.lines[0]["text"]).begins_with("Get that old machine running"), "his instructions are given at the excavator")
	await wait_until(game, func(): return game.walter_dialog == null, 60 * 20)
	await wait_until(game, func(): return not game.est_running, 60 * 14)
	await frames(20)
	game.hud.close_card()
	if game.walter_dialog != null:
		game.walter_dialog.skip()                     # (Grandpa now says the first-day tips himself instead of a note card)
	await frames(10)
	check(bool(game.prog.story["intro_seen"]) and not game.player.locked and not game.walter_intro_running, "the intro is over: the player is free")
	check(game.player.camera.current and absf(game.player.camera.rotation.z) < 0.001 and not game.est_running, "the player's own camera is back, level")
	check(game.prog.story["journal"].size() >= journal_n and game.prog.journal_add("handover") == false, "the handover is in the journal once")
	check(game.walter_node != null and game.walter_node.global_position.distance_to(post_spot(game)) < 0.7, "Walt waits at the excavator")
	check(not bool(game.prog.excavator_state()["started"]) and str(game.prog.excavator_state().get("carry", "")) == "", "the excavator is not repaired for the player")
	check(game.hud.fade_alpha() < 0.01, "the screen is not left black")
	game.queue_free()
	await process_frame

	# ---------------------------------------------------------------- skip at any time -> the same playable state
	for stage in ["start", "tunnel", "yard", "deed"]:
		var g2 = make(true)
		await process_frame
		await frames(6)
		var s2 = g2.opening_scene
		if stage == "tunnel":
			await wait_until(g2, func(): return g2.truck_node.global_position.x < -60.0 and g2.truck_node.global_position.x > -100.0, 60 * 40)
		elif stage == "yard":
			await wait_until(g2, func(): return s2.phase == "yard", 60 * 70)
		elif stage == "deed":
			await wait_until(g2, func(): return s2.deed != null, 60 * 100)
		g2._unhandled_input(esc()) if g2.walter_dialog == null else g2.walter_dialog.skip()
		await frames(5)
		await frames(20)
		g2.hud.close_card()
		await frames(10)
		var tag := "skip at the %s: " % stage
		check(bool(g2.prog.story["intro_seen"]) and not g2.player.locked and g2.walter_dialog == null and not g2.walter_intro_running, tag + "the player is free and the intro is done")
		check(g2.truck_node.global_position.distance_to(truck_spot(g2)) < 0.1 and g2.truck_node.collision_layer == 1, tag + "the pickup is parked, solid")
		check(not g2.truck_node.get_meta("pickup")["interior"].visible and g2.delivery.far_gate.visible, tag + "the cab and the far gate are put back")
		check(g2.walter_node != null and g2.walter_node.get_parent() == g2.world and g2.walter_node.global_position.distance_to(post_spot(g2)) < 0.7, tag + "Walt stands at the excavator")
		check(bool(g2.prog.story.get("deed_received", false)), tag + "the deed is theirs, once")
		check(g2.player.camera.current and absf(g2.player.camera.rotation.z) < 0.001 and absf(g2.player.camera.position.y - 1.58) < 0.001 and g2.hud.fade_alpha() < 0.01, tag + "camera, view and screen are back to normal")
		check(g2.player.global_position.distance_to(post_spot(g2)) < 3.5, tag + "the player stands beside Walt at the excavator (%s)" % str(g2.player.global_position))
		check(not bool(g2.prog.excavator_state()["started"]), tag + "the excavator is still to be repaired")
		g2._refresh_stage_hud()
		check(game_objective_ok(g2), tag + "the first objective is on screen ('%s')" % g2.hud.objective_label.text)
		g2.queue_free()
		await process_frame

	# ---------------------------------------------------------------- headless default: starts outside (no drive), no replay on a seen intro
	var g3 = make(false)
	await process_frame
	await frames(8)
	check(g3.opening_scene != null and g3.opening_scene.phase == "yard", "without the drive the opening starts at the yard")
	g3.queue_free()
	await process_frame
	var g4 = make(true)
	g4.prog.story["intro_seen"] = true
	g4.prog.story["deed_received"] = true
	await process_frame
	await frames(30)
	check(g4.opening_scene == null and not g4.walter_intro_running, "no replay once the intro has been seen")
	g4.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

func truck_spot(g) -> Vector3:
	var p: Array = g.prog.walter_cfg()["truck"]["pos"]
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
func post_spot(g) -> Vector3:
	var p: Array = g.prog.opening_cfg()["grandpa"]["pos"]
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func game_objective_ok(g) -> bool:
	var t := str(g.hud.objective_label.text).to_lower()
	return g.hud.objective_label.is_visible_in_tree() and (t.contains("excavator") or t.contains("repair") or t.contains("overburden"))
