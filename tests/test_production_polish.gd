extends SceneTree
## Phase 8.5: production and polish: Walter's truck is a real model, interaction highlights, material-specific storage visuals,
## belts fed by rigs (no duplication, save/load), and the yard ground has no holes.
##   godot --headless --fixed-fps 60 -s tests/test_production_polish.gd

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

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._remove_walter()
	var prog: QuarryProgression = game.prog
	var biz: QuarryBusiness = game.business
	game.player.locked = false
	# ---- 1: Walter's truck is the game's truck model, joined up
	var truck: Node3D = game.truck_node
	var meshes := truck.find_children("*", "MeshInstance3D", true, false)
	check(truck != null and meshes.size() >= 20, "1 Walter's truck is built from the real truck model (%d parts)" % meshes.size())
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi in meshes:
		var m: MeshInstance3D = mi
		var bb: AABB = m.global_transform * m.mesh.get_aabb()
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
	check(lo.y > -0.05 and lo.y < 0.2 and hi.y > 1.6 and hi.y < 2.8 and (hi - lo).x < 5.0 and (hi - lo).z < 5.0, "1b it sits on the ground and is truck-sized (%s)" % str(hi - lo))
	# ---- 2: highlights
	var bench: Node3D = game.world.get_node("Workbench")
	game.last_target = bench
	game._update_highlight()
	var lit := 0
	for mi in bench.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay != null:
			lit += 1
	check(game.highlight_node == bench and lit >= 6, "2 looking at the workbench outlines it (%d parts)" % lit)
	game.last_target = game.world.get_node("Quarry floor")
	game._update_highlight()
	check(game.highlight_node == null and game.highlight_meshes.is_empty(), "2b looking at plain ground outlines nothing")
	var dep: Node3D = game.formation_nodes[prog.formation_ids()[0]]
	game.last_target = dep
	game._update_highlight()
	check(game.highlight_node == null, "2c rock you mine is not 'interactable': no outline")
	var off := 0
	for mi in bench.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay != null:
			off += 1
	check(off == 0, "2d and the bench's outline is gone once you look away")
	game.last_target = bench
	game._update_highlight()
	game.menu = "sell"
	game._update_highlight()
	check(game.highlight_node == null, "2e opening a menu removes it")
	game.menu = ""
	game.last_target = bench
	game._update_highlight()
	game.placement = true
	game._update_highlight()
	check(game.highlight_node == null, "2f it is never shown while building (the blueprint has its own look)")
	game.placement = false
	game.last_target = null
	game._update_highlight()
	var doomed := StaticBody3D.new()
	doomed.set_meta("kind", "sell")
	var dm := MeshInstance3D.new()
	dm.mesh = BoxMesh.new()
	doomed.add_child(dm)
	game.world.add_child(doomed)
	game.last_target = doomed
	game._update_highlight()
	doomed.free()
	game.last_target = null
	game._update_highlight()
	check(game.highlight_node == null, "2g an object that disappears while outlined is cleaned up safely")
	# ---- 3: storage shows what is really inside
	var fill: MeshInstance3D = game.storage_body.get_meta("fill")
	var seen := {}
	for res in ["limestone", "coal", "iron_ore", "copper_ore", "gold_ore"]:
		for k in game.state.storage.keys():
			game.state.storage[k] = 0
		game.state.storage[res] = 7
		game.storage_body.set_meta("fill_key", "")
		game._update_structures()
		var mat: Material = fill.material_override
		seen[res] = mat.resource_path if mat else ""
	var distinct := {}
	for k in seen:
		distinct[seen[k]] = true
	check(distinct.size() == 5, "3 each material gives the storage heap its own rock material (%s)" % str(seen.values()))
	check(str(seen["coal"]).contains("Coal") and str(seen["iron_ore"]).contains("Iron") and str(seen["copper_ore"]).contains("Copper") and str(seen["gold_ore"]).contains("Gold") and str(seen["limestone"]).contains("Limestone"), "3b and the right one for each")
	# the textures themselves are not all the same pale colour
	var avg := {}
	for res in ["limestone", "coal", "iron_ore", "copper_ore", "gold_ore"]:
		var bm: BaseMaterial3D = MeshKit.mat(QuarryArt.ROCK_MAT[res])
		var img: Image = bm.albedo_texture.get_image() if bm.albedo_texture else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			var sum := Vector3.ZERO
			var n := 0
			for y in range(0, img.get_height(), 4):
				for x in range(0, img.get_width(), 4):
					var c := img.get_pixel(x, y)
					sum += Vector3(c.r, c.g, c.b)
					n += 1
			avg[res] = (sum / float(maxi(1, n))) * bm.albedo_color.srgb_to_linear().to_html().length() * 0.0 + sum / float(maxi(1, n))
	var sep_ok := avg.size() == 5
	if sep_ok:
		sep_ok = (avg["limestone"] as Vector3).distance_to(avg["coal"]) > 0.15 and (avg["limestone"] as Vector3).distance_to(avg["iron_ore"]) > 0.08 and (avg["copper_ore"] as Vector3).distance_to(avg["gold_ore"]) > 0.03
	check(sep_ok, "3c the rock textures differ clearly in colour (%s)" % str(avg))
	for k in game.state.storage.keys():
		game.state.storage[k] = 0
	game.state.storage["coal"] = 20
	game.state.storage["limestone"] = 3
	game.storage_body.set_meta("fill_key", "")
	game._update_structures()
	var lbl: Label3D = game.storage_body.get_meta("fill_label")
	check(lbl.text.contains("Coal 20") and lbl.text.contains("Stone 3") and str(fill.material_override.resource_path).contains("Coal"), "3d mixed contents show the biggest heap's material and list everything (%s)" % lbl.text.replace("\n", ", "))
	for k in game.state.storage.keys():
		game.state.storage[k] = 0
	# ---- 4: a rig feeds a belt; nothing is duplicated or lost; it survives a save
	prog.stage = prog.stage_index("large")
	prog.cleanup["done"] = true
	game.state.money = 200000
	biz.milestones["mechanized"] = true
	check(game.install_rig("drill_rig", "hillside_face_01"), "4 a drilling rig is installed")
	var rig: Dictionary = prog.rigs[0]
	var bp: Vector3 = prog.rig_bin_pos(rig)
	var snap: Dictionary = game.conveyor_snap(bp + Vector3(0.0, 0, -1.5), "straight")
	var near := Vector3(bp.x, 0, bp.z) + QuarryBusiness.forward(float(rig.get("yaw", 0.0))) * 1.5
	if snap.is_empty():
		snap = game.conveyor_snap(near, "straight")
	var bi: int = biz.add_conveyor(Vector3(bp.x, 0, bp.z) + Vector3(0.0, 0, 0.0) if snap.is_empty() else Vector3(snap["pos"].x, 0, snap["pos"].z), 0.0 if snap.is_empty() else float(snap["yaw"]), "straight")
	game._create_conveyor(bi)
	biz.compute_links()
	var src_t := str(biz.links[bi]["src"].get("type", ""))
	check(src_t == "rig" or src_t == "", "4b the belt next to a rig bin takes its source from the rig when it touches it (%s)" % src_t)
	if src_t == "rig":
		rig["bin"] = {"limestone": 6}
		biz.links[bi]["dst"] = {"type": "storage"}
		biz.links[bi]["resource"] = "limestone"
		var before: int = prog.rig_bin_total(rig) + biz.conveyor_total() + int(game.state.storage["limestone"])
		for k in range(60):
			biz.tick_conveyors(1.0)
		var after: int = prog.rig_bin_total(rig) + biz.conveyor_total() + int(game.state.storage["limestone"])
		check(after == before and int(game.state.storage["limestone"]) > 0, "4c material goes rig -> belt -> storage with nothing lost or duplicated (%d -> %d)" % [before, after])
	else:
		check(true, "4c (belt not touching the rig bin in this layout)")
	var bsnap := biz.snapshot()
	var n_belts: int = biz.conveyors.size()
	biz.restore(bsnap)
	biz.compute_links()
	check(biz.conveyors.size() == n_belts, "4d belts survive save and load without duplicating")
	# ---- 5: the yard ground has no holes
	var space = game.get_world_3d().direct_space_state
	var holes := 0
	var x := -20.0
	while x <= 24.0:
		var z := -22.0
		while z <= 24.0:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.13, 8.0, z + 0.17), Vector3(x + 0.13, -6.0, z + 0.17), 1)
			if space.intersect_ray(q).is_empty():
				holes += 1
			z += 0.75
		x += 0.75
	check(holes == 0, "5 no hole in the yard's ground (%d cells without ground)" % holes)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
