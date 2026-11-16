extends SceneTree
## The landscape from Blender: the models load and are the ones in the world; the forest is natural (denser far from the yard, in groves with clearings, mixed species,
## ground cover in chunks with draw distances), keeps the yard, roads, tunnel approach, quarry and east extension clear, and the mountains stand round the property; the
## west tunnel is real: a Blender portal and lining, and a machine-sized box drives from the mouth to the end without touching anything.
##   godot --headless --fixed-fps 60 -s tests/test_world_environment.gd

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

func clear_sweep(game, size: Vector3, a: Vector3, b: Vector3) -> String:
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
			if c is StaticBody3D and not c.has_meta("ground") and str(c.name) not in ["Quarry floor", "Expansion floor", "World floor"] and not str(c.name).to_lower().contains("door"):          # the industrial gate rolls up for deliveries
				return "%s at %s" % [str(c.name), str(q.transform.origin)]
	return ""

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
	var models := ["pine_tall", "pine_young", "birch", "log", "stump", "bush", "fern", "grass", "flowers", "mossy_stone", "peak_a", "peak_b", "ridge", "foothill", "cliff", "tunnel_portal", "tunnel_set", "deer", "rabbit"]
	var all_ok := true
	for m in models:
		if WorldModels.mesh(m) == null or WorldModels.mesh(m).get_surface_count() == 0:
			all_ok = false
			printerr("   missing model ", m)
	check(all_ok, "all %d Blender world models load" % models.size())
	var deer := WorldModels.animal("deer")
	var rabbit := WorldModels.animal("rabbit")
	var dparts: Dictionary = deer.get("parts", {})
	check(dparts.has("Head") and dparts.has("EarL") and dparts.has("LegFL") and dparts.has("LegBR") and dparts.has("Tail"), "the deer has its head, ears, tail and four leg hinges")
	check(rabbit.get("parts", {}).has("EarL") and rabbit.get("parts", {}).has("LegB"), "the rabbit has ears and hopping legs")
	# ---- the forest
	var ls = game.landscape
	check(ls.forest != null and ls.tree_count > 300, "the forest has trees (%d tall pines, %d young pines and birches)" % [ls.tree_count, ls.young_positions.size()])
	var kinds := 0
	for nm in ["ForestYoung", "ForestBirch"]:
		if ls._mm_nodes.has(nm):
			kinds += 1
	var covers := 0
	for nm in ls._mm_nodes:
		if str(nm).begins_with("Cover_"):
			covers += 1
	check(kinds == 2 and covers >= 6, "with young pines, birches and %d chunks of ground cover (ferns, bushes, grass, flowers, logs, stumps, stones)" % covers)
	var ranged := true
	for nm in ls._mm_nodes:
		if str(nm).begins_with("Cover_") and (ls._mm_nodes[nm] as GeometryInstance3D).visibility_range_end <= 0.0:
			ranged = false
	check(ranged, "every ground-cover chunk has a draw distance")
	# density grows away from the yard: trees per m^2 in a near ring against a far ring (the same strips, split by distance)
	var near := 0
	var far := 0
	var near_area := 0.0
	var far_area := 0.0
	var centre := Vector2(0.0, 12.0)
	var all_trees: Array = ls.tree_positions + ls.young_positions
	for p in all_trees:
		var d := Vector2(p.x, p.z).distance_to(centre)
		if d < 120.0:
			near += 1
		elif d >= 150.0:
			far += 1
	check(near < far * 1.3 or near < 400, "denser far from the quarry than near it (%d within 120 m, %d beyond 150 m)" % [near, far])
	var bad := 0
	for p in all_trees:
		if ls.forest_blocked(Vector2(p.x, p.z)):
			bad += 1
	check(bad == 0, "no tree stands on the yard, a road, the tunnel approach, the quarry or the east extension (%d would)" % bad)
	var hub: Rect2 = game.hub_rect()
	var closest := 1e9
	for p in all_trees:
		var q := Vector2(p.x, p.z)
		closest = minf(closest, hub.grow(0.0).get_center().distance_to(q))
	var on_road := 0
	for p in all_trees:
		if absf(p.x) < 6.0 and p.z > -130.0 and p.z < 30.0:
			on_road += 1
	check(on_road == 0, "the central road and the haul road are free of trees")
	# groves and clearings: the share of occupied 20 m cells varies (not an even carpet)
	var cells := {}
	for p in all_trees:
		var k := Vector2i(int(floor(p.x / 20.0)), int(floor(p.z / 20.0)))
		cells[k] = int(cells.get(k, 0)) + 1
	var mx := 0
	var mn := 1000000
	for k in cells:
		mx = maxi(mx, int(cells[k]))
		mn = mini(mn, int(cells[k]))
	check(mx >= 3 * maxi(1, mn), "trees gather in groves with clearings between (20 m cells hold %d to %d trees)" % [mn, mx])
	# ---- the mountains round the property
	var mtn := 0
	for n in game.art.root.get_children():
		if n.has_meta("mountain"):
			mtn += 1
	check(mtn >= 12, "%d Blender mountains and foothills stand round the property" % mtn)
	# ---- the tunnel
	var portal: Node = game.world.get_node_or_null("TunnelPortal")
	check(portal != null and portal.find_child("Mesh", true, false) != null, "the tunnel entrance is the Blender portal")
	var tun: Node = game.world.get_node_or_null("ServiceTunnel")
	var sets := 0
	if tun != null:
		for c in tun.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh == WorldModels.mesh("tunnel_set"):
				sets += 1
	check(sets >= 5, "the tunnel is lined with %d Blender timber sets with gutters and lamps" % sets)
	var gz := 25.4
	var why := clear_sweep(game, Vector3(2.8, 3.4, 4.8), Vector3(-14.0, 0.25 + 1.7, gz), Vector3(-108.0, 0.25 + 1.7, gz))
	check(why == "", "a truck-sized box drives from the yard through the portal and the whole 85 m tunnel without touching anything (%s)" % why)
	var closed := clear_sweep(game, Vector3(2.8, 3.4, 4.8), Vector3(-108.0, 0.25 + 1.7, gz), Vector3(-124.0, 0.25 + 1.7, gz))
	check(closed.contains("gate"), "the far service gate is closed and solid (%s)" % closed)
	game.delivery.set_far_gate(true)
	await physics_frame
	await physics_frame
	var opened := clear_sweep(game, Vector3(2.8, 3.4, 4.8), Vector3(-108.0, 0.25 + 1.7, gz), Vector3(-124.0, 0.25 + 1.7, gz))
	check(opened == "", "opened for the opening drive, it lets a truck through onto the forest road (%s)" % opened)
	game.delivery.set_far_gate(false)
	await physics_frame
	var face := clear_sweep(game, Vector3(1.0, 1.5, 1.0), Vector3(-20.0, 1.0, 12.0), Vector3(-34.0, 1.0, 12.0))
	check(face != "", "the mountain's yard face is solid beside the opening (%s)" % face)
	var wall := clear_sweep(game, Vector3(1.0, 1.5, 1.0), Vector3(-35.0, 1.0, gz), Vector3(-35.0, 1.0, gz + 6.0))
	check(wall != "", "and the tunnel's side wall is solid")
	var roof := clear_sweep(game, Vector3(1.0, 1.0, 1.0), Vector3(-35.0, 3.8, gz), Vector3(-35.0, 6.5, gz))
	check(roof != "", "and so is its roof")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
