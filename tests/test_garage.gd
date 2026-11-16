extends SceneTree
## The Blender machinery garage keeps the working logic and fixes the geometry: it is the Blender model (with its own roof holder the game hides while a machine is
## inside), every machine type fits a parking slot in the row, a vehicle-sized box (the tallest machine plus margin) sweeps in through the open front at every bay and
## through the 5.4 x 3.7 m service doorway at the back, the ceiling stands clear of the tallest machine and the door height, the walls stay solid, and the concrete slab
## the machines drive on is still the recorded ground layer.
##   godot --headless --fixed-fps 60 -s tests/test_garage.gd

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

func clear_sweep(game, size: Vector3, a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = size
	var n := int(a.distance_to(b) / 0.25) + 1
	for i in n + 1:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.transform = Transform3D(Basis(), a.lerp(b, float(i) / float(n)))
		q.collision_mask = 1
		for h in space.intersect_shape(q, 8):
			var c = h["collider"]
			if c is StaticBody3D and not c.has_meta("ground") and not str(c.name).ends_with("door panel") and str(c.name) not in ["Quarry floor", "Expansion floor"]:
				return false
	return true

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
	await physics_frame
	var art = game.art
	var ox: float = game.GARAGE_DX
	var x0 := -4.7 + ox
	var x1 := 14.5 + ox
	var z0 := 14.9
	var z1 := 22.4
	check(art.root.get_node_or_null("Building_Garage") != null, "the Blender garage is in the game")
	check(art.garage_roof != null and art.garage_roof.get_parent() != null and str(art.garage_roof.get_parent().name) == "Building_Garage", "its roof is a separate node the game can hide while a machine is inside")
	# parking: every machine type has a slot in the garage row, inside the walls
	var types: Array = game.fleet.types()
	var tallest := 0.0
	var widest := 0.0
	for t in types:
		var sp: Array = game.fleet.spec(str(t))["size"]
		tallest = maxf(tallest, float(sp[1]))
		widest = maxf(widest, float(sp[0]))
		var slot = game.free_parking_slot(str(t))
		check(slot != null and slot.x > x0 and slot.x < x1 and slot.z > z0 and slot.z < z1, "%s: has a parking slot in the garage row (%s)" % [t, str(slot)])
	# the ceiling: its underside is above the tallest machine and the doorway
	var u_min: float = art.garage_under(z1, z0, z1)
	check(u_min >= tallest + 0.5 and u_min > 3.7 + 0.5, "the ceiling (%.2f m at its lowest) clears the tallest machine (%.2f m) and the 3.7 m doorway" % [u_min, tallest])
	check(u_min <= 5.2, "and is not a hangar (%.2f m)" % u_min)
	# access: a box as wide as the widest machine, as tall as the tallest, sweeps in from the apron at several bays and out through the back doorway
	var sz := Vector3(widest + 0.3, tallest, 2.0)
	var ok := true
	for bx in [x0 + 2.5, (x0 + x1) * 0.5 - 4.0, (x0 + x1) * 0.5 + 3.0, x1 - 2.5]:
		if not clear_sweep(game, sz, Vector3(bx, tallest * 0.5 + 0.1, z0 - 4.0), Vector3(bx, tallest * 0.5 + 0.1, z0 + 2.5)):
			ok = false
			printerr("   blocked at bay x %.1f" % bx)
	check(ok, "a machine-sized box drives in through the open front at four bays")
	var gdx: float = QuarryDelivery.DOOR_X + ox
	check(clear_sweep(game, Vector3(QuarryDelivery.DOOR_W - 0.6, 3.5, 2.0), Vector3(gdx, 1.85, z1 + 3.0), Vector3(gdx, 1.85, z1 - 3.0)), "and through the 5.4 m x 3.7 m service doorway at the back")
	# solid: the side walls, the back wall beside the doorway, the workbench
	check(not clear_sweep(game, Vector3(1.0, 1.5, 1.0), Vector3(x0 - 1.0, 1.0, 18.0), Vector3(x0 + 1.0, 1.0, 18.0)), "the west wall is solid")
	check(not clear_sweep(game, Vector3(1.0, 1.5, 1.0), Vector3(x1 - 1.0, 1.0, 17.0), Vector3(x1 + 1.0, 1.0, 17.0)), "the east wall is solid")
	check(not clear_sweep(game, Vector3(1.0, 1.5, 1.0), Vector3(x1 - 3.0, 1.0, z1 - 1.5), Vector3(x1 - 3.0, 1.0, z1 + 1.0)), "the back wall beside the doorway is solid")
	# the floor: the slab is a recorded ground layer at the height the machines follow
	var yv: float = art.visual_ground_y((x0 + x1) * 0.5, 19.0)
	check(absf(yv - 0.075) < 0.02, "the concrete slab is the visible ground the machines ride on (%.3f m)" % yv)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
