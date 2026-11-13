extends SceneTree
## The operations yard and the quarry are separate places: a fence with one gate between them, a gravel road beyond the gate, nothing
## to dig or clear inside the yard, and the way through the gate is open to the player and to vehicles.
##   godot --headless --fixed-fps 60 -s tests/test_yard_quarry_split.gd
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
func blocked(game, a: Vector3, b: Vector3, mask := 1) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, mask)
	return not game.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var prog: QuarryProgression = game.prog
	var fz: float = QuarryArt.FENCE_Z
	var gh: float = QuarryArt.GATE_HALF
	# the fence stands across the whole yard edge, except the gate
	var fence_ok := true
	for x in [-22.0, -15.0, -8.0, -4.2, 4.2, 8.0, 15.0, 22.0]:
		fence_ok = fence_ok and blocked(game, Vector3(x, 0.8, fz + 2.0), Vector3(x, 0.8, fz - 2.0))
	check(fence_ok, "the yard fence blocks the whole north edge outside the gate")
	var gate_ok := true
	for x in [-2.5, -1.0, 0.0, 1.0, 2.5]:
		gate_ok = gate_ok and not blocked(game, Vector3(x, 0.8, fz + 2.0), Vector3(x, 0.8, fz - 2.0))
	check(gate_ok, "the gate gap is open (%.1f m wide)" % (gh * 2.0))
	# a vehicle-sized body fits through the gate
	var cap := BoxShape3D.new()
	cap.size = Vector3(3.2, 2.0, 5.0)
	var qq := PhysicsShapeQueryParameters3D.new()
	qq.shape = cap
	qq.transform = Transform3D(Basis(), Vector3(0, 1.3, fz))
	qq.collision_mask = 1 | 8
	check(game.get_world_3d().direct_space_state.intersect_shape(qq, 1).is_empty(), "a 3.2 m wide, 5 m long machine passes through the gate")
	# nothing to dig or clear in the yard; everything to clear lies beyond the fence
	var hub: Rect2 = game.hub_rect()
	var in_yard := 0
	var past_gate := 0
	for cid in prog.cleanup_ids():
		var p2: Vector2 = prog.cleanup_pos(str(cid))
		if hub.has_point(p2) or p2.y > fz:
			in_yard += 1
		else:
			past_gate += 1
	check(in_yard == 0 and past_gate == prog.cleanup_total(), "no weeds or rubble inside the yard (%d beyond the fence)" % past_gate)
	var soil_in_yard := 0
	if game.soil != null:
		for i in range(game.soil.units.size()):
			if game.soil.active[i] == 1:
				var c: Vector3 = game.soil.cell_center(i)
				if hub.has_point(Vector2(c.x, c.z)) or c.z > fz:
					soil_in_yard += 1
				if absf(c.x) < 3.5:
					soil_in_yard += 1                       # and none on the haul road itself
	check(soil_in_yard == 0, "no soil to dig inside the yard or on the road")
	for id in game.formation_nodes:
		pass
	# the road: from the gate north the ground is clear of rocks and boulders
	var road_clear := true
	for z in [-9.0, -13.0, -17.0, -21.0, -25.0]:
		for x in [-2.5, 0.0, 2.5]:
			var q := PhysicsPointQueryParameters3D.new()
			q.position = Vector3(x, 0.6, z)
			q.collision_mask = 1 | 8
			if not game.get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
				road_clear = false
	check(road_clear, "the haul road from the gate north into Area 1 is clear of rock")
	# the player can walk from the office to Area 1 through the gate
	game.player.global_position = Vector3(0.0, 0.2, 8.0)
	game.player.velocity = Vector3.ZERO
	var reached := false
	for i in range(900):
		var target := Vector3(0.0, 0.0, -14.0)
		var d: Vector3 = target - game.player.global_position
		d.y = 0.0
		var dir := d.normalized()
		game.player.velocity.x = dir.x * 4.0
		game.player.velocity.z = dir.z * 4.0
		game.player.move_and_slide()
		await physics_frame
		if game.player.global_position.z < -13.0:
			reached = true
			break
	check(reached, "the player walks from the yard through the gate into Area 1")
	check(game.area_at(game.player.global_position) == "area_1", "and is then standing in Area 1")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
