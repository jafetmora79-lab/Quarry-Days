extends SceneTree
## The Blender-built tools and gloved hands: every tool model loads, wears the project's materials, has the tip and the moving parts the tool view
## expects, the hands close on their grips, and the swing / equip animation behaves (the off hand slides along the shaft, the camera-space working
## end still reaches the crosshair point, impacts still fire).
##   godot --headless --fixed-fps 60 -s tests/test_tool_models.gd

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

func aabb_of(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != n:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func run() -> void:
	var keys := []
	for t in ToolModels.LADDER:
		keys.append(ToolModels.LADDER[t])
	for id in GearModels.IDS:
		if id != "bucket":                        # (the bucket is a Blender world model held as a tool, not one of the tool-model files)
			keys.append(id)
	check(keys.size() == 16, "16 tools in all (5 ladder + 11 Phase 9): %d" % keys.size())
	var moving := {"drill": "spinner", "jackhammer": "spinner", "powered_hammer": "spinner", "pneumatic_chisel": "spinner", "hand_splitter": "lever"}
	for key in keys:
		var n := ToolModels.load_tool(key)
		check(n != null, "%s: the Blender model loads" % key)
		if n == null:
			continue
		var bb := aabb_of(n)
		check(bb.size.length() > 0.3 and bb.size.length() < 2.0, "%s: a sensible size (%.2f m)" % [key, bb.size.length()])
		var all_mapped := true
		var surfaces := 0
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s in m.mesh.get_surface_count():
				surfaces += 1
				if m.get_surface_override_material(s) == null and m.material_override == null:
					all_mapped = false
		check(all_mapped and surfaces > 0, "%s: every surface wears a project material (%d)" % [key, surfaces])
		if moving.has(key):
			check(n.has_meta(moving[key]), "%s: has its %s part" % [key, moving[key]])
		else:
			check(not n.has_meta("spinner") and not n.has_meta("lever"), "%s: no moving parts" % key)
		n.free()
	# ---- the hands
	for right in [true, false]:
		var h := ToolModels.load_hand(right)
		check(h != null, "%s hand loads" % ("right" if right else "left"))
		if h:
			var hb := aabb_of(h)
			check(hb.position.z < 0.0 and hb.end.z > 0.3, "the hand closes round the grip and the forearm runs out toward +Z (%.2f..%.2f)" % [hb.position.z, hb.end.z])
			check(hb.size.y < 0.62 and hb.size.x < 0.30, "the glove is hand-sized (%.2f x %.2f)" % [hb.size.x, hb.size.y])
			h.free()
	var hr := ToolModels.load_hand(true)
	var hl := ToolModels.load_hand(false)
	var br := aabb_of(hr)
	var bl := aabb_of(hl)
	check(absf(br.position.x + bl.end.x) < 0.01 and absf(br.end.x + bl.position.x) < 0.01, "the left glove is the right one mirrored")
	hr.free()
	hl.free()
	# ---- tips: the working end of each swung tool sits where its pose expects it
	for t in [0, 1, 2]:
		var n := ToolModels.load_tool(ToolModels.key_of(t))
		var tip: Vector3 = QuarryToolView.TOOL[t]["tip"]
		var bb := aabb_of(n)
		check(bb.grow(0.03).has_point(tip), "tier %d: the pose's working point lies on the model (%s in %s)" % [t, str(tip), str(bb)])
		n.free()
	for id in ["pointed_chisel", "flat_chisel", "repaired_pickaxe", "sledgehammer", "steel_pickaxe", "hardened_pickaxe", "hand_splitter", "shovel", "ramp_plan"]:
		var n := ToolModels.load_tool(id)
		var tip: Vector3 = GearModels.POSE[id]["tip"]
		check(aabb_of(n).grow(0.03).has_point(tip), "%s: the pose's working point lies on the model" % id)
		n.free()
	# ---- in the tool view
	var tv := QuarryToolView.new()
	root.add_child(tv)
	var tiers := [0, 1, 2, 3, 4]
	for id in GearModels.IDS:
		if id != "bucket":
			tiers.append(GearModels.tier_of(id))
	for t in tiers:
		tv.equip(t, true)
		var gm := tv.model
		check(gm != null and gm.name.begins_with("Tool_"), "tier %d is the Blender model in the tool view" % t)
		var def: Dictionary = tv._def(t)
		var want: int = FPTools.grips(ToolModels.key_of(t)).size()
		var vis := 0
		for side in tv.hands_rig.hands:
			if (tv.hands_rig.hands[side]["root"] as Node3D).visible:
				vis += 1
		check(want >= 1, "tier %d: the tool has %d grip(s) for the shared hand rig" % [t, want])
		var fired := [0]
		for i in 20:
			tv._process(1.0 / 60.0)
		vis = 0
		for side in tv.hands_rig.hands:
			if (tv.hands_rig.hands[side]["root"] as Node3D).visible:
				vis += 1
		check(vis == want, "tier %d: %d gloved hand(s) on it" % [t, vis])
		if not bool(def.get("power", false)):
			tv.swing(0.5, func(): fired[0] += 1)
			var min_slide := 0.0
			var slides := false
			for g in FPTools.grips(ToolModels.key_of(t)):
				if str(g["hand"]) == "L" and float(g.get("slide", 0.0)) > 0.0:
					slides = true
			for i in 60:
				tv._process(1.0 / 60.0)
				min_slide = minf(min_slide, tv._slide)
			check(fired[0] == 1, "tier %d: the blow lands exactly once" % t)
			if slides:
				check(min_slide < -0.02, "tier %d: the off hand slides down the shaft in the wind-up (%.3f)" % [t, min_slide])
				for i in 60:
					tv._process(1.0 / 60.0)
				check(absf(tv._slide) < 0.005, "tier %d: and settles back to its grip" % t)
		else:
			tv.operating = true
			for i in 30:
				tv._process(1.0 / 60.0)
			tv.operating = false
		check(tv.position.is_finite() and tv.pivot.rotation.is_finite(), "tier %d: the pose stays finite" % t)
	# ---- equip swap: the tool tips and drops out, the new one rises
	tv.equip(0, true)
	for i in 10:
		tv._process(1.0 / 60.0)
	tv.equip(1)
	var tilt_max := 0.0
	var swapped := false
	for i in 60:
		tv._process(1.0 / 60.0)
		tilt_max = maxf(tilt_max, tv.pivot.rotation.x - float(QuarryToolView.TOOL[0]["rest"]))
		swapped = swapped or tv.tier == 1
	check(swapped and tilt_max > 0.3, "swapping tools tips the old one away (%.2f rad) and brings the new one up" % tilt_max)
	tv.free()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
