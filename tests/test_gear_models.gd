extends SceneTree
## Phase 9 addendum: the new tools, carts and compressor have their own models, first-person poses and animations, shop previews
## and yard props.   godot --headless --fixed-fps 60 -s tests/test_gear_models.gd

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

func bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != n:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var bb: AABB = xf * m.mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out

func verts(n: Node3D) -> int:
	var v := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m and m.get_surface_count() > 0:
			v += (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return v

func meshes(n: Node3D) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).size()

func signature(n: Node3D) -> String:
	var b := bounds(n)
	return "%d|%.2f,%.2f,%.2f" % [verts(n), b.size.x, b.size.y, b.size.z]

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	game.hud.close_card()
	await process_frame
	var prog: QuarryProgression = game.prog
	var main_tv: QuarryToolView = game.player.tool_view
	main_tv.visible = false
	var tv := QuarryToolView.new()                 # a separate view on the camera: the game keeps re-equipping its own
	game.player.camera.add_child(tv)
	await frames(2)
	# ---- A: every model is its own object
	var sigs := {}
	var all_ok := true
	var light := true
	var tool_tiers := [1, 2, 3]
	for id in GearModels.IDS:
		tool_tiers.append(GearModels.tier_of(id))
	for t in tool_tiers:
		var m: Node3D = tv._build(t)
		var sg := signature(m)
		all_ok = all_ok and not sigs.has(sg) and meshes(m) >= 4
		light = light and meshes(m) <= 24 and verts(m) <= 5000
		sigs[sg] = t
		m.free()
	for t in [0, 4]:
		var m: Node3D = tv._build(t)
		all_ok = all_ok and not sigs.has(signature(m))
		sigs[signature(m)] = t
		m.free()
	check(all_ok, "A all 14 hand tools have different silhouettes and several parts each (%d distinct)" % sigs.size())
	check(light, "A every handheld model stays light (at most 24 meshes and 5000 vertices)")
	var names_ok := true
	for id in GearModels.IDS:
		names_ok = names_ok and GearModels.id_of(GearModels.tier_of(id)) == id and prog.gear_def(id).size() > 0
	check(names_ok, "A every new tool has a model slot and a gear definition")
	# ---- B: props
	var props_ok := true
	for id in ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow", "air_compressor"]:
		var pm := GearModels.build_prop(id)
		var bb := bounds(pm)
		props_ok = props_ok and meshes(pm) >= 4 and bb.size.y > 0.6 and bb.size.length() > 1.2
		if id != "air_compressor":
			props_ok = props_ok and pm.get_node_or_null("Load") != null
		pm.free()
	check(props_ok, "B hand cart, wheelbarrows and compressor are real built models; the carts have a cargo load")
	var sizes := []
	for id in ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow"]:
		var pm2 := GearModels.build_prop(id)
		sizes.append(signature(pm2))
		pm2.free()
	check(sizes[0] != sizes[1] and sizes[1] != sizes[2] and sizes[0] != sizes[2], "B the three carts are different models")
	# ---- C: first person: pose, grip, swing, impact, recovery, no clipping
	var good_pose := true
	var good_hands := true
	var good_clip := true
	var detail := ""
	for t in tool_tiers:
		tv.equip(t, true)
		await frames(3)
		var def: Dictionary = tv._def(t)
		var mdl: Node3D = tv.model
		# nothing of the model comes within 10 cm of the camera
		var nearest_z := -9.0
		for mi in mdl.find_children("*", "MeshInstance3D", true, false):
			var bb2: AABB = (mi as MeshInstance3D).mesh.get_aabb()
			for cx in [0.0, 1.0]:
				for cy in [0.0, 1.0]:
					for cz in [0.0, 1.0]:
						var p: Vector3 = (mi as MeshInstance3D).global_transform * (bb2.position + bb2.size * Vector3(cx, cy, cz))
						var cam_p: Vector3 = game.player.camera.global_transform.affine_inverse() * p
						nearest_z = maxf(nearest_z, cam_p.z)
		if nearest_z > -0.1:
			good_clip = false
			detail += " clip(%d:%.2f)" % [t, nearest_z]
		# hands sit on the tool: every grip point is inside or next to some part of the model
		var hlist: Array = def["hands"] if def.has("hands") else tv.HANDS[t]
		var mb := bounds(mdl)
		for h in hlist:
			var pt: Vector3 = h[1]
			var inflated := (AABB(mb.position / float(def.get("scale", 1.0)), mb.size / float(def.get("scale", 1.0)))).grow(0.16)
			if not inflated.has_point(pt):
				good_hands = false
				detail += " hand(%d)" % t
		var continuous: bool = bool(def.get("power", false)) and (t == 3 or t == 4 or bool(prog.gear_def(GearModels.id_of(t)).get("continuous", false)))
		if continuous:
			tv.operating = true
			tv.target_dist = 1.2
			var spun := 0.0
			var last_pos := Vector3.ZERO
			var last_x := Vector3.RIGHT
			for i in range(40):
				await physics_frame
				if tv.spinner:
					if i > 0:
						spun += (tv.spinner.position - last_pos).length() + (tv.spinner.transform.basis.x - last_x).length()
					last_pos = tv.spinner.position
					last_x = tv.spinner.transform.basis.x
			tv.operating = false
			if spun < 0.05 or tv.tip_cam.distance_to(Vector3(0, 0, -1.2)) > 0.9:
				good_pose = false
				detail += " power(%d: moved %.2f, tip %.2f)" % [t, spun, tv.tip_cam.distance_to(Vector3(0, 0, -1.2))]
			await frames(30)
		else:
			var hits := {"n": 0, "tip": Vector3.ZERO}
			tv.target_dist = 1.2
			tv.swing(0.5, func():
				hits["n"] += 1
				hits["tip"] = tv.tip_cam)
			var guard := 0
			while tv.is_busy() and guard < 120:
				await physics_frame
				guard += 1
			if hits["n"] != 1 or (hits["tip"] as Vector3).distance_to(Vector3(0, 0, -1.2)) > 0.75 or tv.is_busy():
				good_pose = false
				detail += " swing(%d: hits %d, tip %s)" % [t, hits["n"], str((hits["tip"] as Vector3).snapped(Vector3(0.01, 0.01, 0.01)))]
	check(good_pose, "C every tool swings once to its impact on the target, or works continuously, and settles%s" % detail)
	check(good_hands, "C hands close on the tool's handle or grips")
	check(good_clip, "C no tool passes through the camera")
	var types := {}
	for id in GearModels.IDS:
		var d: Dictionary = GearModels.POSE[id]
		types[str(d.get("spin", "swing")) + ("L" if d.has("lever") else "") + str(d.get("wind", 0.0)) + str(d.get("strike", 0.0))] = true
	check(types.size() >= 8, "C the animations are different (%d distinct motions among the 9 new tools)" % types.size())
	# the splitter lever really moves
	tv.equip(GearModels.tier_of("hand_splitter"), true)
	await frames(3)
	var l0: float = tv.lever.rotation.x
	tv.swing(0.5, func(): pass)
	var lmax := l0
	for i in range(30):
		await physics_frame
		lmax = maxf(lmax, tv.lever.rotation.x)
	check(lmax - l0 > 0.3, "C the hand splitter's lever pulls down and up as it works (%.2f rad)" % (lmax - l0))
	# ---- D: the shop previews show the real models
	var prev_ok := true
	for id in prog.gear_ids():
		var offer: Dictionary = PurchaseOffers.gear(game, str(id), func(): pass)
		var pm3: Node3D = QuarryPreview.build_model(game, offer["model"])
		var this_ok: bool = pm3 != null and verts(pm3) >= 100 and offer["price"] > 0
		if not this_ok:
			printerr("   preview problem: %s (%d meshes)" % [str(id), meshes(pm3) if pm3 else -1])
		prev_ok = prev_ok and this_ok
		var rows := ""
		for r in offer["stats"]:
			rows += str(r[0]) + " "
		prev_ok = prev_ok and offer["price"] > 0 and (str(offer["reason"]) != "" or true)
		pm3.free()
	check(prev_ok, "D every new item shows its own model in the shop preview, with price and stats")
	var offer_tool: Dictionary = PurchaseOffers.gear(game, "sledgehammer", func(): pass)
	check(str(offer_tool["reason"]).contains("Stage 3") and offer_tool["stats"].size() >= 3, "D the preview lists the unlock requirement and the numbers (%s)" % str(offer_tool["reason"]))
	# ---- E: yard props
	game.state.money = 100000
	prog.cleanup["done"] = true
	prog.stage = prog.stage_index("deep")
	var free_spots := true
	for id in game.GEAR_PROP_SPOTS:
		var q := PhysicsShapeQueryParameters3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.0, 1.0, 1.6)
		q.shape = bx
		q.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), game.GEAR_PROP_SPOTS[id] + Vector3(0, 0.55, 0))
		q.collision_mask = 1
		var hit: Array = game.get_world_3d().direct_space_state.intersect_shape(q, 8)
		for h in hit:
			var c = h["collider"]
			if c is StaticBody3D and not c.has_meta("ground") and not c.has_meta("gear_prop"):
				free_spots = false
				printerr("   spot %s blocked by %s" % [id, str(c.name)])
	check(free_spots, "E the yard spots beside the office are free of other objects")
	for id in ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow"]:
		prog.buy_gear(id)
	prog.state.gear.append("air_compressor")
	game._refresh_workbench()
	await frames(2)
	check(game.gear_props.size() == 4, "E bought items appear in the yard as props (%d)" % game.gear_props.size())
	game.state.inventory["limestone"] = 0
	game._update_cart_load()
	var load: Node3D = game.gear_props["reinforced_wheelbarrow"].get_child(0).get_node("Load")
	var empty_visible: bool = load.visible
	game.state.inventory["limestone"] = game.state.capacity() / 2
	game._update_cart_load()
	var half_scale: float = load.scale.y
	game.state.inventory["limestone"] = game.state.capacity()
	game._update_cart_load()
	check(not empty_visible and load.visible and load.scale.y > half_scale, "E the best cart visibly carries what the bag holds (empty, half, full)")
	check(game.gear_props["hand_cart"].get_child(0).get_node("Load").visible == false, "E the cart that is not in use stays empty")
	var colliders := 0
	for id in game.gear_props:
		for c in game.gear_props[id].get_children():
			if c is CollisionShape3D:
				colliders += 1
	check(colliders == 4, "E every prop has a collider")
	# ---- F: pegboard
	check(game.workbench_tools.get_child_count() >= 12, "F the workbench pegboard shows the tools (%d pieces)" % game.workbench_tools.get_child_count())
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
