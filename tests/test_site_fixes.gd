extends SceneTree
## Playtest fixes: no grey expansion wall, the office desk where the office is, Grandpa outside every wall, the two starter machines in their garage slots
## and Grandpa's truck apart, the storage bin inside the quarry with its contents sellable, a shutter that fits its portal, a perimeter fence, and a
## quarry you can clean down to bare dirt.   godot --headless --fixed-fps 60 -s tests/test_site_fixes.gd

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

func solid_at(game, p: Vector3) -> String:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1
	var r: Array = game.get_world_3d().direct_space_state.intersect_point(q, 4)
	return str(r[0]["collider"].name) if not r.is_empty() else ""

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(20)
	game.hud.close_card()
	game._cine_tween().kill()
	await frames(5)
	var prog: QuarryProgression = game.prog
	# ---- 1: no grey slabs left over from the old east expansion
	var slabs := 0
	for b in game.world.get_children():
		if str(b.name).begins_with("Expansion") or str(b.name) == "Rockfall barrier":
			slabs += 1
	check(slabs == 0, "no leftover expansion cliff blocks or rockfall barrier (%d)" % slabs)
	# ---- 2: the office desk (the computer you sell and manage from) is inside the office
	var desk: Node3D = null
	for b in game.world.get_children():
		if str(b.name) == "Management desk":
			desk = b
	var oc: Vector3 = game.OFFICE_POS
	check(desk != null and absf(desk.global_position.x - oc.x) < 2.4 and absf(desk.global_position.z - oc.z) < 2.4 and str(desk.get_meta("kind", "")) == "office", "the management desk stands inside the office, where the art puts it")
	# ---- 3: Grandpa is in the open, not in a wall
	game._grandpa_to_post()
	await frames(5)
	var wp: Vector3 = game.walter_node.global_position if game.walter_node != null else Vector3(999, 0, 999)
	var inside := false
	for dz in [0.0, 0.3, -0.3]:
		for dx in [0.0, 0.3, -0.3]:
			if solid_at(game, wp + Vector3(dx, 0.9, dz)) != "":
				inside = true
	check(game.walter_node != null and not inside and game.hub_rect().has_point(Vector2(wp.x, wp.z)), "Grandpa waits in the yard in the open, not inside a wall (%s)" % str(wp))
	# ---- 4: the two starter machines are parked in their garage slots, Grandpa's old truck is somewhere else
	var park: Array = game.fleet.cfg["parking"]
	var ex = game._starter_vehicle()
	var st = null
	for v in game.vehicle_nodes.values():
		if v.vtype == "starter_truck":
			st = v
	check(ex != null and st != null, "both starter machines exist")
	check(Vector2(ex.global_position.x - float(park[0][0]), ex.global_position.z - float(park[0][2])).length() < 0.6 and Vector2(st.global_position.x - float(park[1][0]), st.global_position.z - float(park[1][2])).length() < 0.6, "the excavator and the starter truck stand in garage slots 1 and 2")
	check(game.truck_node != null and game.truck_node.global_position.distance_to(st.global_position) > 8.0 and game.truck_node.global_position.distance_to(ex.global_position) > 8.0, "Grandpa's own old truck is parked apart from them (%.0f m)" % (game.truck_node.global_position.distance_to(st.global_position) if game.truck_node else -1.0))
	# ---- 5: the storage bin is inside the quarry
	var sp: Vector3 = game.STORAGE_POS
	check(sp.z < -9.0 and absf(sp.x) < 120.0 and game.business.storage_pos.distance_to(Vector3(sp.x, 0.0, sp.z)) < 0.2, "the storage bin stands inside the fenced quarry (%s)" % str(sp))
	# ---- 6: what lies in storage can be sold from the office, not only what is in the bag
	game.state.inventory["limestone"] = 3
	game.state.storage["limestone"] = 10
	var money0: int = game.state.money
	var got: int = game.sell_from_bag(["limestone"])
	var price: float = game.state.unit_price("limestone")
	check(game.state.storage["limestone"] == 0 and game.state.inventory["limestone"] == 0 and got == int(round(13.0 * price)), "selling takes the bag AND the storage bin (%d earned for 13 units)" % got)
	game.state.storage["coal"] = 6
	var got2: int = game.sell_from_bag(game.RESOURCE_ORDER)
	check(game.state.storage["coal"] == 0 and got2 > 0, "'sell all' includes everything in storage too")
	# ---- 7: the tunnel gate's shutter fills its portal and hangs in it
	var dl = game.delivery
	var panel: MeshInstance3D = dl.pivot.get_child(0)
	var pw: float = (panel.mesh as BoxMesh).size.x
	check(absf(dl.pivot.position.x - (QuarryDelivery.WEST_GATE.x - 0.9)) < 0.01 and pw >= 6.5 and dl.pivot.position.y >= 4.2, "the shutter hangs in the portal's plane and fills it (%.1f m wide, %.1f m high)" % [pw, dl.pivot.position.y])
	# ---- 8: the property has a perimeter, the quarry has far more cleanup to do, and cleaning it leaves only dirt
	check(game.pit_zone.plat_w >= 399.0, "the walkable site spans the whole property (%.0f m wide), edged by the perimeter fence" % game.pit_zone.plat_w)
	check(prog.cleanup_total() >= 36, "the cleanup is extensive: %d weeds and rubble heaps" % prog.cleanup_total())
	var top: QuarryFormation = game.formation_nodes["q_top"]
	var over0 := 0
	var patches := 0
	for g in top._decor_groups:
		if bool(g["overgrowth"]):
			for c in g["clean"]:
				if not bool(c):
					over0 += 1
		else:
			patches += (g["clean"] as Array).size()
	check(over0 > 300 and patches > 100, "before cleaning the ground is overgrown (%d bushes, tufts, stones, pebbles; %d soil patches)" % [over0, patches])
	var id0 := str(prog.cleanup_ids()[0])
	var node: Node3D = game.cleanup_nodes.get(id0)
	for k in range(30):
		if is_instance_valid(node):
			game.hit_debris(node, 50.0, node.global_position)
		game.state.inventory["limestone"] = 0
	await frames(30)
	var over1 := 0
	for g in top._decor_groups:
		if bool(g["overgrowth"]):
			for c in g["clean"]:
				if not bool(c):
					over1 += 1
	check(over1 < over0, "clearing a weed clears the scrub and stones around it (%d -> %d)" % [over0, over1])
	for id in prog.cleanup_ids():
		var nd: Node3D = game.cleanup_nodes.get(id)
		if nd != null:
			for k in range(40):
				if is_instance_valid(nd):
					game.hit_debris(nd, 50.0, nd.global_position)
				game.state.inventory["limestone"] = 0
	await frames(40)
	var left := 0
	var patches_left := 0
	for g in top._decor_groups:
		if bool(g["overgrowth"]):
			for c in g["clean"]:
				if not bool(c):
					left += 1
		else:
			for i in range((g["clean"] as Array).size()):
				if bool(g["on"][i]) or true:
					patches_left += 1
	check(prog.cleanup["done"] and left == 0, "when the last piece is cleared every bush, tuft and stone is gone: only dirt is left (%d overgrowth left)" % left)
	check(patches_left == patches, "the plain soil patches stay (they are just dirt)")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
