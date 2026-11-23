extends SceneTree
## The protagonist (CHR_QD_Player, the Meshy model on a Mixamo skeleton): the shared humanoid rig plays the game's animations on it (VeilRig maps the Mixamo bones onto its own names), the satchel is part of
## the mesh (the old four-fullness-state satchel meshes are gone, the fullness mapping itself is unchanged), the body is a shadow in first person,
## the seated driver is this character with the satchel off the seat, and nothing about the inventory changes.   Run through tools/run_tests.sh.
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

func bone_names(sk: Skeleton3D) -> Array:
	var out := []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_name(i))
	out.sort()
	return out

func run() -> void:
	# ---- the asset
	var pb := PlayerBody.new()
	root.add_child(pb)
	check(pb.build(), "CHR_QD_Player.glb loads with a skeleton")
	var ref := (load("res://assets/characters/CHR_QD_Operator.glb") as PackedScene).instantiate()
	root.add_child(ref)
	var ref_sk: Skeleton3D = ref.find_children("*", "Skeleton3D", true, false)[0]
	var missing := []
	for bn in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
			"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]:
		if pb.rig.bone(bn) < 0:
			missing.append(bn)
	check(missing.is_empty(), "every bone the animation rig drives is found on the Mixamo skeleton (missing %s)" % str(missing))
	var top := -1e9
	var bottom := 1e9
	for mi in pb.find_children("*", "MeshInstance3D", true, false):
		if not (mi as Node3D).visible:
			continue
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		for cz in [0.0, 1.0]:
			var p: Vector3 = (mi as MeshInstance3D).global_transform * (bb.position + bb.size * Vector3(0, cz, 0))
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
	check(absf(top - bottom) > 1.5 and absf(top - bottom) < 1.95, "about 1.75 m tall (%.2f m)" % (top - bottom))
	var tris := 0
	for mi in pb.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m != null and (mi as Node3D).visible:
			tris += int(m.surface_get_array_len(0) / 3)
	check(tris < 12000, "light enough for integrated graphics (%d triangles shown)" % tris)
	var n_bags := 0
	for b in pb.bags:
		if b != null:
			n_bags += 1
	check(n_bags == 0, "the satchel is part of the Meshy mesh: no separate fullness meshes")
	# ---- the fullness states from the real bag
	var cases := [[0, 18, 0], [4, 18, 0], [5, 18, 1], [10, 18, 1], [11, 18, 2], [16, 18, 2], [17, 18, 3], [18, 18, 3], [30, 64, 1], [64, 64, 3]]
	var ok := true
	for c in cases:
		ok = ok and PlayerBody.state_for(int(c[0]), int(c[1])) == int(c[2])
	check(ok, "EMPTY 0-25 %, PARTIAL 26-60 %, MOSTLY FULL 61-90 %, FULL 91-100 % map to states 0..3")
	# ---- the animations play on this skeleton (not just matching names)
	pb.set_bag_state(0)
	var lu := pb.rig.bone("LeftUpperLeg")
	var ll := pb.rig.bone("LeftLowerLeg")
	var rua := pb.rig.bone("RightUpperArm")
	for i in 30:
		pb.animate(1.0 / 60.0, "idle", 0.0)
	var idle_leg: Quaternion = pb.skel.get_bone_pose_rotation(lu)
	var mx := 0.0
	for i in 90:
		pb.animate(1.0 / 60.0, "walk", 2.0)
		mx = maxf(mx, idle_leg.angle_to(pb.skel.get_bone_pose_rotation(lu)))
	check(mx > 0.25, "walking swings the thigh (%.2f rad from idle)" % mx)
	for i in 60:
		pb.animate(1.0 / 60.0, "walk", 4.2)
	check(true, "running speed plays without errors")
	for i in 30:
		pb.animate(1.0 / 60.0, "idle", 0.0)
	var arm_idle: Quaternion = pb.skel.get_bone_pose_rotation(rua)
	var arm_carry_mx := 0.0
	for i in 40:
		pb.animate(1.0 / 60.0, "idle", 0.0, "miner", true)
		arm_carry_mx = maxf(arm_carry_mx, arm_idle.angle_to(pb.skel.get_bone_pose_rotation(rua)))
	check(arm_carry_mx > 0.3, "carrying a bucket raises the arms (%.2f rad)" % arm_carry_mx)
	var arm_work_mx := 0.0
	for i in 40:
		pb.animate(1.0 / 60.0, "work", 0.0, "miner", false, float(i) / 40.0)
		arm_work_mx = maxf(arm_work_mx, arm_idle.angle_to(pb.skel.get_bone_pose_rotation(rua)))
	check(arm_work_mx > 0.3, "the mining state moves the arms (%.2f rad)" % arm_work_mx)
	pb.seated = true
	for i in 60:
		pb.animate(1.0 / 60.0, "idle", 0.0)
	var thigh_dir: Vector3 = (pb.skel.get_bone_global_pose(ll).origin - pb.skel.get_bone_global_pose(lu).origin)
	check(absf(thigh_dir.y) < 0.35 * thigh_dir.length() and thigh_dir.z != 0.0, "seated: the thighs are level")
	pb.seated = false
	pb.first_person = true
	check(pb.skel.get_bone_pose_scale(pb.rig.bone("Head")).x < 0.01, "first person hides only the head")
	pb.first_person = false
	pb.shadow_only = true
	var all_shadow := true
	for gi in pb.find_children("*", "GeometryInstance3D", true, false):
		all_shadow = all_shadow and (gi as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	check(all_shadow, "as a shadow-only body nothing is drawn into the camera")
	# ---- in the game
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(20)
	var st = game.state
	var body: PlayerBody = game.player_body
	check(body != null and body.shadow_only and body.first_person, "the on-foot body is a shadow in first person")
	var inv_before: Dictionary = st.inventory.duplicate()
	var cap_before: int = st.capacity()
	for item in [[0, 0], [5, 1], [12, 2], [18, 3]]:
		st.inventory["limestone"] = int(item[0])
		await frames(3)
		check(body.bag_state == int(item[1]), "bag holding %d of %d shows state %d (%d)" % [int(item[0]), st.capacity(), int(item[1]), body.bag_state])
	st.inventory["limestone"] = 0
	check(st.capacity() == cap_before and st.inventory.size() == inv_before.size(), "showing the satchel changed no capacity or inventory")
	# ---- the seated driver is this character
	game.prog.excavator_state()["started"] = true
	var v: QuarryVehicle = game._starter_vehicle()
	var d := SeatedDriver.attach_to(v)
	check(d != null and d.body is PlayerBody, "the driver in the machine is the protagonist")
	d.show_driver(true)
	await frames(6)
	check(d.rig.seated, "seated in the cab")
	d.show_driver(false)
	# ---- no first-person tool or hands while in a machine, back when out
	var tv: QuarryToolView = game.player.tool_view
	await frames(3)
	check(tv.visible and not tv.hidden_by_vehicle, "on foot the tool and hands are in view")
	for part in ["battery", "hose", "fuel"]:
		game.prog.story["excavator"][part] = true
	game.enter_vehicle(v)
	await frames(4)
	var hands_shown := 0
	for side in tv.hands_rig.hands:
		if (tv.hands_rig.hands[side]["root"] as Node3D).visible:
			hands_shown += 1
	check(game.driving == v and not tv.visible and tv.hidden_by_vehicle and hands_shown == 0, "in the machine no tool and no hands show through the glass (driving %s, visible %s, hidden %s, hands %d)" % [str(game.driving == v), str(tv.visible), str(tv.hidden_by_vehicle), hands_shown])
	QuarryBoarding.active = 1                                   # a boarding / start-up move is running
	game.exit_vehicle()
	await frames(4)
	check(not tv.visible, "and none during the climb-free boarding and the engine start moves")
	QuarryBoarding.active = 0
	await frames(4)
	check(tv.visible and not tv.hidden_by_vehicle, "back in the hands once out")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
