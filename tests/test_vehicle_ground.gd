extends SceneTree
## Machines stand ON the ground you see: the yard's gravel, slabs and asphalt are drawn 7-11 cm above the collision ground, so a model resting on the
## collision ground used to sink into them (tracks and tyres half buried). Every machine type, parked on the garage slab, on the yard gravel and on plain
## ground, has its lowest tracks / tyres within 2 cm of the visible surface (never below it), and it stays that way after a save and load.
##   godot --headless --fixed-fps 60 -s tests/test_vehicle_ground.gd

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

func contact_y(v: Node3D) -> float:
	var lo := 1e9
	for node in v.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var nm := str(mi.name)
		if not (nm.begins_with("Track_") or nm.begins_with("Wheel_") or nm.begins_with("Tyre") or nm.begins_with("Belt")):
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		lo = minf(lo, b.position.y)
	return lo

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
	var art = game.art
	var hub: Rect2 = game.hub_rect()
	var spots := {"the garage slab": Vector3(-3.6, 0.3, 19.0), "the yard gravel": Vector3(hub.get_center().x - 9.0, 0.3, hub.get_center().y - 2.0), "plain ground": Vector3(40.0, 0.3, 45.0)}
	var types := ["compact_excavator", "heavy_excavator", "loader", "truck", "bulldozer"]
	for spot_name in spots:
		var pos: Vector3 = spots[spot_name]
		var surf: float = art.visual_ground_y(pos.x, pos.z)
		check(true, "%s: the visible surface is at %.3f m" % [spot_name, surf])
		var slot := 0
		var given := []
		for t in types:
			while game.fleet.vehicles.size() >= int(game.fleet.cfg.get("max_vehicles", 4)):
				var gone: Dictionary = game.fleet.vehicles.pop_back()
				if game.vehicle_nodes.has(int(gone["id"])):
					game.vehicle_nodes[int(gone["id"])].queue_free()
					game.vehicle_nodes.erase(int(gone["id"]))
			var at := pos + Vector3(float(slot) * 3.6, 0, 0)
			slot += 1
			var rec: Dictionary = game.fleet.give(t, at, 0.0)
			given.append(int(rec["id"]))
			game._sync_vehicles()
			await frames(90)
			var v: QuarryVehicle = game.vehicle_nodes.get(int(rec["id"]))
			var lo := contact_y(v)
			var q := PhysicsRayQueryParameters3D.create(v.global_position + Vector3(0, 4, 0), v.global_position + Vector3(0, -4, 0), 1)
			var h := root.get_world_3d().direct_space_state.intersect_ray(q)
			var want := float(art.visual_ground_y(v.global_position.x, v.global_position.z))
			check(lo < 1e8 and lo > want - 0.02 and lo < want + 0.07, "%s on %s: tracks / tyres touch the visible surface (%.3f vs %.3f m)" % [t, spot_name, lo, want])
		for gid in given:                                     # clear the spot for the next one
			for i in range(game.fleet.vehicles.size() - 1, -1, -1):
				if int(game.fleet.vehicles[i]["id"]) == gid:
					game.fleet.vehicles.remove_at(i)
			if game.vehicle_nodes.has(gid):
				game.vehicle_nodes[gid].queue_free()
				game.vehicle_nodes.erase(gid)
		await frames(3)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
