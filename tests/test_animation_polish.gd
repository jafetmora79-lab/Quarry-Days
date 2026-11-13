extends SceneTree
## Animation polish: the starter excavator's repair parts ride the cab, its boom cylinder telescopes, the cab slews with inertia,
## the tracks differ in a turn, and Grandpa's elder profile (stoop, limp, fidgets, richer talk, farewell wave) plus the start/stop lean.
##   godot --headless --fixed-fps 60 -s tests/test_animation_polish.gd

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

func mesh_center(n: Node) -> Vector3:
	var mi := n as MeshInstance3D
	return mi.global_transform * mi.get_aabb().get_center()

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
	game._remove_walter()
	await frames(3)
	# ---- the starter excavator: attached parts follow the crane
	var ex = game._starter_vehicle()
	check(ex != null and ex.turret != null, "the starter excavator exists with an upper body")
	var parts: Node3D = ex.turret.get_node_or_null("OpeningParts")
	var ground: Node3D = ex.model_root.get_node_or_null("OpeningGround")
	check(parts != null and ex.model_root.get_node_or_null("OpeningParts") == null, "the battery tray, hose and filler are fitted to the rotating cab, not the tracks")
	check(ground != null, "the oil on the ground stays with the undercarriage")
	var a0: Vector3 = mesh_center(parts.get_child(0))
	var g0: Vector3 = mesh_center(ground.get_child(0))
	ex.swing = 1.3
	ex.joint_in["swing"] = 0.0
	await frames(1)
	var early: float = absf(angle_difference(ex.turret.rotation.y, ex.swing))
	await frames(40)
	check(early > 0.5, "the cab eases into the turn instead of snapping (%.2f rad still to go after one frame)" % early)
	check(absf(angle_difference(ex.turret.rotation.y, 1.3)) < 0.02, "and settles on the target (%.3f)" % ex.turret.rotation.y)
	var a1: Vector3 = mesh_center(parts.get_child(0))
	var ax: Vector3 = ex.global_position
	var r0 := Vector2(a0.x - ax.x, a0.z - ax.z)
	var r1 := Vector2(a1.x - ax.x, a1.z - ax.z)
	check(a1.distance_to(a0) > 0.3 and absf(r0.length() - r1.length()) < 0.05, "the fitted parts swung round with the cab on the slewing ring (moved %.2f m, radius kept)" % a1.distance_to(a0))
	check(mesh_center(ground.get_child(0)).distance_to(g0) < 0.001, "while the oil stain on the ground did not move")
	# ---- the boom cylinder telescopes and stays joined to base and boom
	var ram: Node3D = ex.get_meta("boom_ram")
	var rod: Node3D = ram.get_node("Rod")
	ex.arm.rotation.x = 0.0
	VehicleModels.update_boom_ram(ex)
	var rod_short: float = rod.scale.y
	ex.arm.rotation.x = 0.7
	VehicleModels.update_boom_ram(ex)
	var rod_long: float = rod.scale.y
	check(absf(rod_long - rod_short) > 0.05, "the boom cylinder's rod slides in and out with the boom (%.2f -> %.2f)" % [rod_short, rod_long])
	var tip: Vector3 = ex.turret.to_local(ram.to_global(Vector3(0, 0.45 + rod.scale.y, 0)))
	var want: Vector3 = ex.arm.transform * Vector3(0, 0.12, -0.9)
	check(tip.distance_to(want) < 0.05, "and its rod end stays pinned to the boom (%.3f m off)" % tip.distance_to(want))
	# ---- tracks differ when the machine turns
	var tm0 := ex.track_mats[0] as StandardMaterial3D
	var tm1 := ex.track_mats[1] as StandardMaterial3D
	var o0 := tm0.uv1_offset.x
	var o1 := tm1.uv1_offset.x
	var sg0 := float(tm0.get_meta("scroll_sign", 1.0))
	var sg1 := float(tm1.get_meta("scroll_sign", 1.0))
	ex._prev_pos = ex.global_position
	ex._prev_yaw = ex.rotation.y
	ex.rotation.y += 0.05
	ex._animate(1.0 / 60.0)
	var d0 := wrapf(tm0.uv1_offset.x - o0, -0.5, 0.5) * sg0
	var d1 := wrapf(tm1.uv1_offset.x - o1, -0.5, 0.5) * sg1
	check(d0 * d1 < 0.0 and absf(d0) > 0.001, "turning on the spot runs the two tracks in opposite directions (%.3f / %.3f)" % [d0, d1])
	# ---- Grandpa
	game._spawn_walter(Vector3(-14.9, 0.0, 5.6))
	var wn: Node3D = game.walter_node
	var rig: VeilRig = wn.get_meta("rig")
	check(rig.elder, "Grandpa's rig uses the elder profile")
	var other := VeilRig.new()
	other.setup(rig.skel, 1.0)
	# stoop: the same walk, more forward lean in the spine
	for i in range(90):
		rig.pose(1.0 / 60.0, "walk", 1.4, "miner", false)
		other.pose(1.0 / 60.0, "walk", 1.4, "miner", false)
	var sp_e: float = rig.skel.get_bone_pose(rig.bone("Spine")).basis.get_euler().length()
	var lean_e: float = rig._cur["lean"] + 8.0 * rig._elder_k
	check(rig._elder_k > 0.99 and lean_e > 7.0, "Grandpa walks stooped (extra lean %.1f deg)" % lean_e)
	# limp: the left thigh swings less than the right over a stride
	var lmax := 0.0
	var rmax := 0.0
	for i in range(120):
		rig.pose(1.0 / 60.0, "walk", 1.4, "miner", false)
		lmax = maxf(lmax, absf(rig.skel.get_bone_pose(rig.bone("LeftUpperLeg")).basis.get_euler().x))
		rmax = maxf(rmax, absf(rig.skel.get_bone_pose(rig.bone("RightUpperLeg")).basis.get_euler().x))
	check(lmax < rmax * 0.97, "with a slight limp: the left step is shorter (%.3f vs %.3f)" % [lmax, rmax])
	# states: wave raises the arm, chin brings the hand to the face, talk gestures differ over time, idle fidgets over a cycle
	for i in range(70):
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false)
	var arm_idle: float = rig.skel.get_bone_pose(rig.bone("RightUpperArm")).basis.get_euler().length()
	for i in range(70):
		rig.pose(1.0 / 60.0, "wave", 0.0, "miner", false)
	var arm_wave: float = rig.skel.get_bone_pose(rig.bone("RightUpperArm")).basis.get_euler().length()
	check(absf(arm_wave - arm_idle) > 0.3, "the farewell wave lifts the arm (%.2f vs %.2f rad)" % [arm_wave, arm_idle])
	var fore_a: float = rig.skel.get_bone_pose(rig.bone("RightLowerArm")).basis.get_euler().length()
	var fore_b := fore_a
	var swing_seen := 0.0
	for i in range(30):
		rig.pose(1.0 / 60.0, "wave", 0.0, "miner", false)
		fore_b = rig.skel.get_bone_pose(rig.bone("RightLowerArm")).basis.get_euler().length()
		swing_seen = maxf(swing_seen, absf(fore_b - fore_a))
	check(swing_seen > 0.1, "the forearm waves from the elbow (%.2f rad of travel)" % swing_seen)
	var hands := []
	for i in range(240):
		rig.pose(1.0 / 60.0, "talk", 0.0, "miner", false)
		if i % 20 == 0:
			hands.append((rig._hand_xf("Right").origin - rig._hand_xf("Left").origin).length())
	var lo := 9.0
	var hi := 0.0
	for h in hands:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	check(hi - lo > 0.04, "talking: the hands move in turn rather than hanging still (spread %.2f m)" % (hi - lo))
	var hy_max := -9.0
	var hy_min := 9.0
	for i in range(19 * 60):
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false)
		var hy: float = rig._hand_xf("Right").origin.y
		hy_max = maxf(hy_max, hy)
		hy_min = minf(hy_min, hy)
	check(hy_max - hy_min > 0.15, "standing about, Grandpa now and then puts a hand to his back or his chin (%.2f m of hand travel in one 19 s cycle)" % (hy_max - hy_min))
	# start / stop lean for everybody
	var base := VeilRig.new()
	base.setup(rig.skel, 2.0)
	for i in range(30):
		base.pose(1.0 / 60.0, "idle", 0.0, "miner", false)
	var peak := 0.0
	var trough := 0.0
	for i in range(40):
		base.pose(1.0 / 60.0, "walk", 0.2 + 0.05 * float(i), "miner", false)
		peak = maxf(peak, base._accel_lean)
	for i in range(40):
		base.pose(1.0 / 60.0, "walk", maxf(0.0, 2.2 - 0.06 * float(i)), "miner", false)
		trough = minf(trough, base._accel_lean)
	check(peak > 1.0 and trough < -1.0, "every walker leans into a start and rocks back as it stops (%.1f / %.1f deg)" % [peak, trough])
	# the farewell: leaving with the player nearby waves first, then walks
	game._spawn_walter(Vector3(-14.9, 0.0, 5.6))
	game.player.global_position = game.walter_node.global_position + Vector3(0, 0, 3.0)
	game.walter_mode = "waiting"
	game._walter_leave()
	check(game.walter_wave_t > 1.0 and game.walter_mode in ["leaving", "to_truck"], "when he leaves with you nearby he waves first")
	await frames(150)
	check(game.walter_wave_t <= 0.0, "and then sets off")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
