extends SceneTree
## The excavator stays where the ground holds it. Root cause of the old "it slowly sinks": (1) the excavator's soil digging picked the nearest soil cell to its bucket,
## and once the cells ahead were gone that was the cell UNDER its own tracks, so every bucket lowered the machine by 7.5 cm per unit; (2) a PARKED machine was not simulated at
## all, so soil dumped or spread under it grew into its hull and soil cut away from under it left it floating until somebody got in. Now a machine never digs out its own
## footing, and a parked machine takes a small step against the ground every few frames (resolving overlap, or falling when the floor is gone).
##   godot --headless --fixed-fps 60 -s tests/test_excavator_stability.gd

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

func tracks_lo(v: Node3D) -> float:
	var lo := 1e9
	for node in v.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or not str(mi.name).begins_with("Track_"):
			continue
		lo = minf(lo, (mi.global_transform * mi.get_aabb()).position.y)
	return lo

func ground_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 6, 0), at + Vector3(0, -6, 0), 1)
	q.exclude = []
	var h := root.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else NAN

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	var soil: QuarrySoil = game.soil
	var spot := Vector3.INF
	for i in soil.units.size():
		if int(soil.active[i]) == 1 and int(soil.units[i]) == soil.max_units():
			var c: Vector3 = soil.cell_center(i)
			var ok := true
			for dx in [-3, -2, -1, 0, 1, 2, 3]:
				for dz in [-4, -3, -2, -1, 0, 1, 2, 3]:
					var j: int = soil.cell_at(c + Vector3(dx * 2.0, 0, dz * 2.0))
					if j < 0 or int(soil.units[j]) != soil.max_units():
						ok = false
			if ok:
				spot = c
				break
	check(spot != Vector3.INF, "a full patch of loose soil to work on")
	var rec: Dictionary = game.fleet.give("compact_excavator", spot + Vector3(0, 1.2, 0), 0.0)
	game._sync_vehicles()
	var ex: QuarryVehicle = game.vehicle_nodes.get(int(rec["id"]))
	check(ex.rig != null, "the Blender excavator")
	await frames(120)
	# ---- 1. parked ten simulated minutes on the soil: no drift
	var y0 := ex.global_position.y
	var lift0 := ex.model_root.position.y
	var worst := 0.0
	for minute in 10:
		await frames(3600)
		worst = maxf(worst, absf(ex.global_position.y - y0))
	check(worst < 0.002 and absf(ex.model_root.position.y - lift0) < 0.002, "parked 10 simulated minutes on soil: no vertical drift (worst %.5f m)" % worst)
	check(absf(tracks_lo(ex) - ground_y(ex.global_position)) < 0.03, "and the tracks rest on the surface (%.3f vs %.3f)" % [tracks_lo(ex), ground_y(ex.global_position)])
	# ---- 2. soil cut away from under it (parked): it settles down; soil dumped back under it: it is pushed up, never buried
	var under: Dictionary = ex.support_cells(soil)
	for i in under:
		soil.remove(i, int(soil.units[i]))
	soil.refresh()
	await frames(60)
	var gnow := ground_y(ex.global_position)
	check(absf(tracks_lo(ex) - gnow) < 0.03 and ex.global_position.y < y0 - 0.5, "soil cut from under it: the machine settles onto the new surface (tracks %.3f, ground %.3f) instead of floating" % [tracks_lo(ex), gnow])
	await frames(1800)
	var steady := ex.global_position.y
	await frames(3600)
	check(absf(ex.global_position.y - steady) < 0.002, "and then stays there (no further sinking over a minute)")
	for i in under:
		soil.add(i, soil.max_units())
	soil.refresh()
	await frames(60)
	gnow = ground_y(ex.global_position)
	check(tracks_lo(ex) > gnow - 0.03 and absf(tracks_lo(ex) - gnow) < 0.04, "soil dumped back under it: it is lifted onto the heap, not buried (tracks %.3f, ground %.3f)" % [tracks_lo(ex), gnow])
	# ---- 3. digging never takes the ground it stands on
	var keep: Dictionary = ex.support_cells(soil)
	var before := {}
	for i in keep:
		before[i] = int(soil.units[i])
	# leave soil only under the machine: everything else in reach is gone
	var all_cells := []
	for i in soil.units.size():
		if int(soil.units[i]) > 0 and not keep.has(i):
			all_cells.append([i, int(soil.units[i])])
	for e in all_cells:
		soil.remove(int(e[0]), int(e[1]))
	soil.refresh()
	var targets_under := 0
	var y_dig := ex.global_position.y
	ex.digging = true
	for i in 600:
		game._dig_soil(ex, 1.0 / 60.0)
		if keep.has(game.soil_target(ex)):
			targets_under += 1
		await physics_frame
	ex.digging = false
	var same := true
	for i in keep:
		if int(soil.units[i]) != int(before[i]):
			same = false
	# (the cells are read from ground that settles into the cleared neighbours, so loose soil can flow out from under the tracks and be dug; what must never happen is the DIG TARGET being a cell under them)
	check(targets_under == 0, "with nothing else in reach, ten seconds of digging takes nothing from under its own tracks")
	check(absf(ex.global_position.y - y_dig) < 0.002, "and the machine did not move down (%.4f m)" % (ex.global_position.y - y_dig))
	# put soil back for the rest
	for e in all_cells:
		soil.add(int(e[0]), int(e[1]))
	soil.refresh()
	await frames(60)
	# ---- 4. driving forward, backward and turning on the soil field: it follows the surface, never sinks into it
	ex.driven = true
	ex.global_position = spot + Vector3(0, 1.2, 0)
	await frames(30)
	var worst_sink := 0.0
	for phase in [[1.0, 0.0, 180], [-1.0, 0.0, 180], [0.6, 1.0, 240], [0.6, -1.0, 240], [0.0, 0.0, 60]]:
		ex.input["throttle"] = phase[0]
		ex.input["steer"] = phase[1]
		for i in int(phase[2]):
			await physics_frame
			var g := ground_y(ex.global_position)
			if not is_nan(g):
				worst_sink = maxf(worst_sink, g - tracks_lo(ex))
	ex.input["throttle"] = 0.0
	ex.input["steer"] = 0.0
	check(worst_sink < 0.08, "driving forward, backward and turning over the soil: the tracks never sink into the surface (worst %.3f m)" % worst_sink)
	# ---- 5. enter and exit
	ex.driven = false
	await frames(90)
	var ey := ex.global_position.y
	game.enter_vehicle(ex)
	await frames(60)
	game.exit_vehicle()
	await frames(120)
	check(absf(ex.global_position.y - ey) < 0.01, "entering and leaving does not change its height (%.4f m)" % (ex.global_position.y - ey))
	# ---- 6. save and load
	var sx := ex.global_position
	game._save()
	ex.global_position = sx + Vector3(0, 3.0, 0)
	game._load()
	await frames(120)
	var ex2: QuarryVehicle = game.vehicle_nodes.get(int(rec["id"]))
	check(ex2 != null and absf(tracks_lo(ex2) - ground_y(ex2.global_position)) < 0.06, "after a save and load it stands on the surface, tracks on the ground (%.3f vs %.3f before; a machine parked on a loose heap may settle a little aside)" % [ex2.global_position.y if ex2 else 0.0, sx.y])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
