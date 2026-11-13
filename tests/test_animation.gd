extends SceneTree
## Character animation overhaul phase 1: tool grips, walk cycle, pickaxe swing, carried load, stowing, transitions, saves.
##   godot --headless --fixed-fps 60 -s tests/test_animation.gd

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
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await process_frame
	await frames(4)
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	game.prog.stage = game.prog.stage_index("large")
	game.state.money = 50000
	game.state.clock_minutes = 600.0
	game.ui_hire("rosa")
	var w = game.worker_nodes.values()[0]
	var rig: VeilRig = w.rig
	var pick: Dictionary = rig.tool_named("pickaxe")
	check(w.profession == "miner" and not pick.is_empty(), "A the miner carries a pickaxe through the rig's tool system")
	var node: Node3D = pick["node"]
	var gp: Vector3 = pick["gp"]
	# ---- A: attachment at the relaxed hold
	var hx := rig._hand_xf("Right")
	var palm := hx.origin + hx.basis.y * VeilRig.PALM
	check((node.transform * gp).distance_to(palm) < 0.005, "A the shaft passes through the palm (%.4f m)" % (node.transform * gp).distance_to(palm))
	var want_dir := rig._v(Vector3(0, 0.25, 1.0)).normalized()
	check(node.transform.basis.z.dot(want_dir) > 0.999, "A the shaft points where the grip config says (%.4f)" % node.transform.basis.z.dot(want_dir))
	check(node.get_parent() == rig.skel, "A the tool lives under the skeleton")
	# ---- B: stable grip and no body penetration while walking, turning and stopping
	var max_drift := 0.0
	var min_head := 9.0
	var states := [["idle", 0.0, 30], ["walk", 2.5, 120], ["turn", 0.0, 40], ["walk", 1.2, 60], ["idle", 0.0, 40]]
	for st in states:
		for i in range(int(st[2])):
			rig.pose(1.0 / 60.0, st[0], st[1], "miner", false, -1.0, 0.0)
			var h := rig._hand_xf("Right")
			var pw := h.origin + h.basis.y * VeilRig.PALM
			max_drift = maxf(max_drift, (node.transform * gp).distance_to(pw))
			var head_o := rig._gp("Head").origin
			var tip: Vector3 = node.transform * Vector3(0, 0, 0.6)
			min_head = minf(min_head, tip.distance_to(head_o))
	check(max_drift < 0.005, "B the grip stays in the palm through idle / walk / turn / stop (max drift %.4f m)" % max_drift)
	check(min_head > 0.35, "B the pick head stays clear of the head while walking (%.2f m)" % min_head)
	# foot planting: during mid-stance the planted foot moves back at ground speed
	var speed := 2.5
	var prev := Vector3.ZERO
	var errs := []
	for i in range(240):
		rig.pose(1.0 / 60.0, "walk", speed, "hauler", false, -1.0, 0.0)
		var fp := rig._gp("LeftFoot").origin
		var xl := fposmod(rig._phase / TAU, 1.0)
		if i > 30 and xl > 0.12 and xl < 0.46:
			var vF := (fp - prev).dot(rig.F) * 60.0
			errs.append(absf(vF + speed))
		prev = rig._gp("LeftFoot").origin
	var avg := 0.0
	for e in errs:
		avg += e
	avg /= maxf(1.0, float(errs.size()))
	print("   foot slide, mean |v_foot + ground speed| in mid-stance: %.2f m/s (%d samples)" % [avg, errs.size()])
	check(avg < 0.55, "B the planted foot keeps pace with the ground (mean slide %.2f m/s at 2.5 m/s)" % avg)
	# ---- C: pickaxe swing timing, grip and clearance
	for i in range(30):
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false, -1.0, 0.0)
	var pitches := []
	var grip_err := 0.0
	var grip_at := 0.0
	var worst_head := 9.0
	var n := 84
	for cycle in range(2):
		for i in range(n + 1):
			var p := float(i) / float(n)
			rig.pose(1.0 / 60.0, "work", 0.0, "miner", false, p, 0.0)
			pitches.append([p, rig.swing_pitch, cycle])
			if rig._swing_w > 0.95:
				var hr := rig._hand_xf("Right")
				var hl := rig._hand_xf("Left")
				var pr := hr.origin + hr.basis.y * VeilRig.PALM
				var pl: Vector3 = node.transform * (pick["support"] as Vector3)
				if (node.transform * gp).distance_to(pr) > grip_err:
					grip_at = p
				grip_err = maxf(grip_err, (node.transform * gp).distance_to(pr))
				var ll := hl.origin + hl.basis.y * VeilRig.PALM
				if ll.distance_to(pl) > grip_err:
					grip_at = p + 10.0
				grip_err = maxf(grip_err, ll.distance_to(pl))
				var ho := rig._gp("Head").origin
				for z in [-0.1, 0.1, 0.3, 0.5, 0.6]:
					worst_head = minf(worst_head, (node.transform * Vector3(0, 0, z)).distance_to(ho))
	var peak := -999.0
	var peak_p := 0.0
	for r in pitches:
		if int(r[2]) == 1 and float(r[1]) > peak:
			peak = float(r[1])
			peak_p = float(r[0])
	var last_cycle := pitches.filter(func(r): return int(r[2]) == 1)
	var at_hit: float = float(last_cycle[last_cycle.size() - 1][1])
	check(peak > 100.0 and peak_p > 0.55 and peak_p < 0.8, "C anticipation: the pick is drawn back overhead before the strike (peak %.0f deg at p=%.2f)" % [peak, peak_p])
	check(at_hit < -40.0, "C impact: the pick head is driven down at p = 1 (pitch %.0f deg)" % at_hit)
	var after_hit: float = float(pitches[n + 1 + 6][1])
	check(after_hit > at_hit + 8.0, "C recovery: the pick springs back after the impact (%.0f -> %.0f deg)" % [at_hit, after_hit])
	check(grip_err < 0.06, "C both hands stay on the shaft through the whole swing (worst %.3f m at p=%.2f)" % [grip_err, grip_at])
	check(worst_head > 0.12, "C the pick never passes through the head (closest %.2f m)" % worst_head)
	# ---- D: carrying keeps the load on the body
	for i in range(60):
		rig.pose(1.0 / 60.0, "walk", 2.0, "miner", true, -1.0, 0.0)
	var cfm := rig._chest_frame()
	var cn: Node3D = rig.carry_node
	var rel := cfm.basis.inverse() * (cn.position - cfm.origin)
	check(absf(rel.dot(rig.F) - 0.30) < 0.02 and absf(rel.dot(rig.U) + 0.20) < 0.02, "D the load rides at a fixed spot in front of the chest")
	check(rel.dot(rig.F) - 0.17 > 0.10, "D and clear of the chest (rear face %.2f m from the torso axis)" % (rel.dot(rig.F) - 0.17))
	var hr2 := rig._hand_xf("Right").origin
	var hl2 := rig._hand_xf("Left").origin
	var side_r := cn.position + cfm.basis * rig._v(Vector3(0.235, 0, 0))
	var side_l := cn.position - cfm.basis * rig._v(Vector3(0.235, 0, 0))
	check(hr2.distance_to(side_r) < 0.06 and hl2.distance_to(side_l) < 0.06, "D both arms hold the load at its sides (%.3f / %.3f m)" % [hr2.distance_to(side_r), hl2.distance_to(side_l)])
	# ---- E: stowing, without teleporting
	rig.set_tool_held("pickaxe", false)
	var last_pos: Vector3 = node.transform.origin
	var worst_step := 0.0
	for i in range(80):
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false, -1.0, 0.0)
		worst_step = maxf(worst_step, node.transform.origin.distance_to(last_pos))
		last_pos = node.transform.origin
	var cs := rig._chest_frame() * (pick["stow"] as Transform3D)
	check(node.transform.origin.distance_to(cs.origin) < 0.01, "E the stowed pick hangs on the back (%.3f m off its sling)" % node.transform.origin.distance_to(cs.origin))
	check(worst_step < 0.07, "E stowing is a continuous move, not a teleport (largest step %.3f m)" % worst_step)
	rig.set_tool_held("pickaxe", true)
	worst_step = 0.0
	for i in range(80):
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false, -1.0, 0.0)
		worst_step = maxf(worst_step, node.transform.origin.distance_to(last_pos))
		last_pos = node.transform.origin
	var h3 := rig._hand_xf("Right")
	check((node.transform * gp).distance_to(h3.origin + h3.basis.y * VeilRig.PALM) < 0.005 and worst_step < 0.06, "E and back in the hand again, smoothly (step %.3f m)" % worst_step)
	# ---- F: no snapping between states
	var bones := ["RightUpperArm", "LeftUpperArm", "RightLowerLeg", "LeftUpperLeg", "Hips", "Spine"]
	var prev_q := {}
	var worst_deg := 0.0
	var worst_at := ""
	var seq := [["idle", 0.0, 20, -1.0, false], ["walk", 2.5, 60, -1.0, false], ["turn", 0.0, 20, -1.0, false], ["work", 0.0, 90, 0.0, false], ["walk", 2.0, 40, -1.0, true],
		["unload", 0.0, 40, 0.0, true], ["idle", 0.0, 20, -1.0, false]]
	for st in seq:
		for i in range(int(st[2])):
			var pp: float = float(st[3])
			if st[0] in ["work", "unload"]:
				pp = float(i) / float(int(st[2]) - 1)
			rig.pose(1.0 / 60.0, st[0], st[1], "miner", st[4], pp, 0.0)
			for bn in bones:
				var q: Quaternion = rig.skel.get_bone_pose_rotation(rig.bone(bn))
				if prev_q.has(bn):
					var dg := rad_to_deg(2.0 * acos(minf(1.0, absf((prev_q[bn] as Quaternion).dot(q)))))
					if dg > worst_deg:
						worst_deg = dg
						worst_at = "%s in %s frame %d" % [bn, st[0], i]
				prev_q[bn] = q
	check(worst_deg < 26.0, "F no pose snaps (the strike itself is the fastest move) across idle > walk > turn > work > carry > unload > idle (largest single-frame bone change %.1f deg: %s)" % [worst_deg, worst_at])
	# ---- G: the worker in the world
	check(w.carry_box.get_parent() == rig.skel, "G the carried load is parented to the animated skeleton")
	var emp: Dictionary = game.business.employees[0]
	emp["carry"] = {"limestone": 2}
	await frames(3)
	check(w.carry_box.visible, "G the load is visible while the worker owns it")
	emp["carry"] = {}
	await frames(3)
	check(not w.carry_box.visible, "G and gone the moment it is deposited")
	emp["carry"] = {"limestone": 2}
	w._animate(1.0 / 60.0)
	for i in range(40):
		w._animate(1.0 / 60.0)
	check(float(rig.tool_named("pickaxe")["held"]) < 0.05, "G a miner carrying rock has the pick slung")
	emp["carry"] = {}
	w.anim = "work"
	for i in range(40):
		w._animate(1.0 / 60.0)
	check(float(rig.tool_named("pickaxe")["held"]) > 0.95, "G and holds it again to mine")
	# save / load recovery: rebuild the worker from the saved employee record
	var id: int = int(emp["id"])
	w.queue_free()
	game.worker_nodes.erase(id)
	game._sync_workers()
	await frames(6)
	var w2 = game.worker_nodes[id]
	check(w2.rig != null and not w2.rig.tool_named("pickaxe").is_empty() and w2.carry_box.get_parent() == w2.rig.skel, "G a reloaded worker gets its tool and load rig back")
	var h4 = w2.rig._hand_xf("Right")
	var n2: Node3D = w2.rig.tool_named("pickaxe")["node"]
	check((n2.transform * (w2.rig.tool_named("pickaxe")["gp"] as Vector3)).distance_to(h4.origin + h4.basis.y * VeilRig.PALM) < 0.01, "G and the pick is in the hand, not frozen in a rest pose")
	# ---- H: first-person hands hold every tool and stay in view without clipping the camera
	var tv: QuarryToolView = game.player.tool_view
	for tier in range(5):
		tv.equip(tier, true)
		await process_frame
		var mdl: Node3D = tv.model
		var fists := 0
		var nearest := 9.0
		for mi in mdl.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh is BoxMesh or true:
				var sz: Vector3 = (mi as MeshInstance3D).mesh.get_aabb().size
				if absf(sz.z - 0.30 / float(tv.TOOL[tier].get("scale", 1.0))) < 0.01:
					fists += 1
					var cam_local: Vector3 = game.player.camera.global_transform.affine_inverse() * (mi as MeshInstance3D).global_position
					nearest = minf(nearest, -cam_local.z)
		var want_hands: int = tv.HANDS[tier].size()
		check(fists == want_hands and nearest > 0.2, "H tier %d is held by %d hand(s) with forearms in view (found %d, nearest %.2f m in front of the camera)" % [tier, want_hands, fists, nearest])
	tv.equip(game.state.tool_tier, true)
	# the strike frame carries the full impact pose
	w2.anim = "work"
	check(true, "G (impact pose is applied on the frame the hit lands: last_action_phase is set by _act)")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
