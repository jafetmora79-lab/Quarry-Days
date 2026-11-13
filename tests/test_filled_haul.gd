extends SceneTree
## The FILLED quarry: a FULLY LOADED haul truck (HAUL_TRUCK=truck|heavy_truck|industrial_truck, default the biggest) drives from the yard
## down the basin ramp, along the staging lane, down the centred level-2, -3 and -4 ramps and floor roads, turns round on the lowest floor and
## climbs all the way back to the yard gate with its whole load.   godot --headless --fixed-fps 60 -s tests/test_filled_haul.gd

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

func ground_y(game, lx: float, lz: float, y_from := 6.0) -> float:
	var w: Vector3 = game.pit_zone.to_world(Vector3(lx, y_from, lz))
	var q := PhysicsRayQueryParameters3D.create(w, w + Vector3(0, -40.0, 0), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else -99.0

func zero_formation(game, id: String, pattern := 0) -> void:
	var prog: QuarryProgression = game.prog
	prog.init_formation(id)
	var d: Dictionary = prog.state.deposits[id]
	for i in range(d["columns"].size()):
		var dim: Vector2i = prog.dims(id)
		var kill := pattern == 0 or (pattern == 1 and ((i % dim.x) + (i / dim.x)) % 2 == 0) or (pattern == 2 and (i / dim.x) < dim.y / 2)
		if kill:
			d["columns"][i] = 0
	prog._sync_stock(d)
	game._refresh_deposit(id)

## Drives a machine through pit-local waypoints (x, z) with the real controls, slow enough to take the corners.
func drive_route(game, v, route: Array, max_frames: int, cap := 3.2) -> bool:
	var pz = game.pit_zone
	var st := {"i": 0}
	var done := await frames(max_frames, func():
		var target: Vector3 = pz.to_world(Vector3(route[st["i"]].x, 0.0, route[st["i"]].y))
		var d: Vector3 = target - v.global_position
		if Vector2(d.x, d.z).length() < 2.2:
			st["i"] += 1
			if st["i"] >= route.size():
				v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
				return true
			return false
		var want := atan2(-d.x, -d.z)
		var diff := wrapf(want - v.rotation.y, -PI, PI)
		var thr := 0.7 if absf(diff) < 0.5 else 0.3
		if v.speed > cap or (absf(diff) > 0.5 and v.speed > 1.8):
			thr = 0.0
		v.input = {"throttle": thr, "steer": clampf(-diff * 2.5, -1.0, 1.0), "brake": false}
		return false)
	return done < max_frames

## The haul road, down: pit-local (x, z) waypoints through the new geometry.
const DOWN := [Vector2(0.0, -44.0), Vector2(0.0, -58.0), Vector2(0.0, -71.0), Vector2(-8.0, -74.5), Vector2(-30.0, -74.5), Vector2(-44.0, -76.0), Vector2(-48.0, -86.0),
	Vector2(-48.0, -104.0), Vector2(-48.0, -128.0), Vector2(-46.0, -145.0), Vector2(-36.0, -146.0), Vector2(0.0, -146.0), Vector2(32.0, -146.0), Vector2(40.0, -142.0),
	Vector2(40.0, -124.0), Vector2(40.0, -104.0), Vector2(36.0, -97.0), Vector2(14.0, -96.0), Vector2(-14.0, -96.0), Vector2(-24.0, -98.0), Vector2(-24.0, -108.0), Vector2(-24.0, -122.0)]

func walk(game, route: Array, label: String) -> bool:
	var pz = game.pit_zone
	var pl = game.player
	for wp in route:
		var gl: Vector3 = pz.to_world(Vector3(wp.x, 0.0, wp.y))
		var t := 0
		while t < 1800:
			var d := Vector3(gl.x - pl.global_position.x, 0, gl.z - pl.global_position.z)
			if d.length() < 0.5:
				break
			pl.drive_wish = d
			await physics_frame
			t += 1
		pl.drive_wish = Vector3.ZERO
		if t >= 1800:
			var kc := KinematicCollision3D.new()
			var dd := Vector3(gl.x - pl.global_position.x, 0, gl.z - pl.global_position.z).normalized()
			var hit: bool = pl.test_move(pl.global_transform, dd * 0.3, kc)
			pl.drive_wish = Vector3.INF
			printerr("   %s: stuck before %s at %s; blocked by %s %s" % [label, str(wp), str(pz.to_loc(pl.global_position)), (kc.get_collider().name if hit and kc.get_collider() else "nothing"), str(kc.get_normal()) if hit else ""])
			return false
	pl.drive_wish = Vector3.INF
	return true

func run() -> void:
	for path in ["user://quarry_save.json", "user://quarry_save.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	game.hud.close_card()
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(20)
	game.hud.close_card()
	game._remove_walter()
	var prog: QuarryProgression = game.prog
	var pz: QuarryPitZone = game.pit_zone
	prog.cleanup["done"] = true
	game._sync_pit_gate()
	game.safety.enabled = false
	check(prog.filled_world() and pz.level_pits.size() == 3, "the new world is the filled quarry with the shells of levels 2, 3 and 4")
	# the player digs: level 1 (all three layers) goes, then half of each deeper level, so every level opens (its haul road is cut by the survey)
	for id in ["q_l1_top", "q_l1_gravel", "q_l1_rock"]:
		zero_formation(game, id)
	prog.check_levels()
	check(prog.quarry_level == 2, "cutting the surface layers opens level 2 (%d)" % prog.quarry_level)
	for id in ["q_l2_coal", "q_l2_iron"]:
		zero_formation(game, id, 1)
	prog.check_levels()
	check(prog.quarry_level == 3, "cutting level 2 opens level 3 (%d)" % prog.quarry_level)
	for id in ["q_l3_iron", "q_l3_copper"]:
		zero_formation(game, id, 1)
	prog.check_levels()
	check(prog.quarry_level == 4, "cutting level 3 opens level 4 (%d)" % prog.quarry_level)
	await frames(10)
	prog.stage = prog.stage_index("deep")
	game.state.money = 900000
	game.state.tool_tier = 3
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	var ttype: String = OS.get_environment("HAUL_TRUCK") if OS.get_environment("HAUL_TRUCK") != "" else "industrial_truck"
	game.ui_buy_vehicle(ttype)
	game.delivery.finish_all()
	var truck = null
	for v in game.vehicle_nodes.values():
		if v.vtype == ttype:
			truck = v
	check(truck != null, "the %s is bought" % ttype)
	game.player.global_position = pz.to_world(Vector3(-6.0, 0.2, -38.0))
	game.enter_vehicle(truck)
	game.scripted_input = true
	truck.global_position = pz.to_world(Vector3(0.0, 0.2, -38.0))
	truck.rotation.y = pz.global_rotation.y
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	truck.settled_frames = 0
	truck.safe_position = truck.global_position
	var trec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	var cap: int = game.fleet.capacity(trec)
	trec["cargo"] = {"copper_ore": cap}
	check(game.fleet.cargo_total(trec) == cap and cap > 0, "the truck is loaded to capacity (%d units)" % cap)
	var low := 0.0
	var seen := {2: false, 3: false, 4: false}
	var route_ok := true
	for wp in DOWN:
		var ok := await drive_route(game, truck, [wp], 2400)
		route_ok = route_ok and ok
		var ly: float = pz.to_loc(truck.global_position).y
		low = minf(low, ly)
		if ly < -6.8: seen[2] = true
		if ly < -10.4: seen[3] = true
		if ly < -14.0: seen[4] = true
		if not ok:
			var kc := KinematicCollision3D.new()
			var hit: bool = truck.test_move(truck.global_transform, truck.forward() * 0.4, kc)
			printerr("   truck stopped before %s at %s yaw %.2f speed %.2f floor %s; ahead: %s" % [str(wp), str(pz.to_loc(truck.global_position)), truck.rotation.y, truck.speed, str(truck.is_on_floor()), (str(kc.get_collider().name) + " " + str(kc.get_collider().get_parent().name) if hit and kc.get_collider() else "nothing")])
			break
	check(route_ok and seen[2] and seen[3] and seen[4], "loaded: from the yard the truck drives down to level 4 (lowest %.2f)" % low)
	var back := DOWN.duplicate()
	back.reverse()
	back.remove_at(0)
	truck.rotation.y += PI        # turned round on the lowest floor
	var up_ok := true
	for wp in back:
		var ok := await drive_route(game, truck, [wp], 2400)
		up_ok = up_ok and ok
		if not ok:
			var kc := KinematicCollision3D.new()
			var hit: bool = truck.test_move(truck.global_transform, truck.forward() * 0.4, kc)
			printerr("   truck stopped (up) before %s at %s speed %.2f; ahead: %s" % [str(wp), str(pz.to_loc(truck.global_position)), truck.speed, (str(kc.get_collider().name) + " " + str(kc.get_collider().get_parent().name) if hit and kc.get_collider() else "nothing")])
			break
	var top: Vector3 = pz.to_loc(truck.global_position)
	check(up_ok and top.y > -0.8 and top.z > -47.5, "loaded: and climbs all the way back out to the plateau (z %.1f, y %.2f)" % [top.z, top.y])
	check(game.fleet.cargo_total(trec) == cap and int(trec["cargo"].get("copper_ore", 0)) == cap, "the whole load is still on board: nothing was lost on the ramps")
	# on out of the corridor and to the yard gate
	var yard_ok := true
	for wp in [Vector2(0.0, -30.0), Vector2(0.0, -12.0), Vector2(0.0, 2.0)]:
		yard_ok = yard_ok and await drive_route(game, truck, [wp], 2400)
	var gl: Vector3 = pz.to_loc(truck.global_position)
	check(yard_ok and gl.z > -6.0, "loaded: it drives the corridor to the quarry gate (z %.1f)" % gl.z)
	check(int(trec["cargo"].get("copper_ore", 0)) == cap, "and arrives with its full load")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
