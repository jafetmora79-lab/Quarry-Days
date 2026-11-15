extends SceneTree
## Headless validation of the Blender bulldozer: nodes, orientation, ground contact, budget, hulls, and the lift + tilt cylinders over every
## baked clip and over a grid of blade angles (runtime solver). Exit 0 = pass. Writes docs/audit/bulldozer_validation.json.
##   godot --headless --path . --script res://tools/validate_bulldozer.gd      (GLB must be imported once)

const REQUIRED := ["Shake", "Lift", "Blade", "Body", "Cab", "CabGlass", "CabInterior", "Undercarriage", "Track_L", "Track_R", "Sprocket_L", "Sprocket_R", "Idler_L", "Roller_L0",
	"Carrier_R1", "LiftCyl_L_Barrel", "LiftCyl_L_Rod", "LiftCyl_R_Barrel", "LiftCyl_R_Rod", "TiltCyl_Barrel", "TiltCyl_Rod", "Lever_L", "Lever_R", "Lamp_Head_L", "Lamp_Head_R",
	"Marker_Edge", "Marker_Pile", "Marker_Seat", "Marker_Eye", "Marker_ExhaustTip", "Pin_LiftBase_L", "Pin_LiftBase_R", "Pin_LiftRod_L", "Pin_LiftRod_R", "Pin_TiltBase", "Pin_TiltRod",
	"Pin_Trunnion", "ColHull_Body", "ColHull_Blade"]
const CLIPS := ["Idle", "EngineStart", "EngineStop", "BladeUpDown", "BladeTilt", "PushCycle", "Drive", "Turn"]
const TOL := 0.004
const MAX_TRIS := 9000
const MAX_SURFACES := 110

var failures: Array = []
var report := {}
var rig: DozerRig

func fail(msg: String) -> void:
	failures.append(msg)
	print("FAIL  ", msg)

func ok(msg: String) -> void:
	print("ok    ", msg)

func _initialize() -> void:
	rig = DozerRig.new()
	root.add_child(rig)
	await process_frame
	await process_frame
	if rig.model == null:
		fail("GLB did not load")
		_finish()
		return
	_nodes()
	_geometry()
	_budget()
	_clips()
	_grid()
	_finish()

func n(nm: String) -> Node3D:
	return rig.model.find_child(nm, true, false) as Node3D

func _nodes() -> void:
	var missing := []
	for r in REQUIRED:
		if n(r) == null:
			missing.append(r)
	if missing.is_empty():
		ok("%d required nodes present" % REQUIRED.size())
	else:
		fail("missing nodes: %s" % str(missing))
	var d := n("Lift").global_position.distance_to(n("Pin_Trunnion").global_position)
	if d > TOL:
		fail("lift frame origin %.4f m from the trunnion pin" % d)
	else:
		ok("the C-frame pivots on the trunnions")

func _geometry() -> void:
	var tr := n("Track_L") as MeshInstance3D
	var bottom := tr.global_position.y + tr.get_aabb().position.y
	if absf(bottom) > 0.01:
		fail("track bottom at %.3f (expected 0)" % bottom)
	else:
		ok("tracks sit on y=0")
	if n("Marker_Edge").global_position.z >= -1.5 or n("Lamp_Head_L").global_position.z >= -1.0:
		fail("orientation: blade and hood must face -Z")
	else:
		ok("blade and hood face -Z")
	var edge := n("Marker_Edge").global_position.y
	report["edge_height_rest"] = edge
	print("blade edge height at rest: %.2f m (arm angle %.2f)" % [edge, rig.blade_alpha])
	rig.set_blade(-0.08, 0.0)
	var low := n("Marker_Edge").global_position.y
	rig.set_blade(0.2, 0.0)
	if low > 0.1:
		fail("lowered blade edge is %.2f m above the ground" % low)
	else:
		ok("a lowered blade reaches the ground (edge %.2f m)" % low)

func _budget() -> void:
	var tris := 0
	var surfaces := 0
	var bad := 0
	for node in rig.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name.begins_with("ColHull"):
			continue
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			if mi.get_active_material(s) == null:
				bad += 1
	report["budget"] = {"surfaces": surfaces, "triangles": tris}
	print("budget: %d surfaces (~draw calls), %d triangles" % [surfaces, tris])
	if bad > 0:
		fail("%d surfaces without a material" % bad)
	if tris > MAX_TRIS or surfaces > MAX_SURFACES:
		fail("over budget (tris %d, surfaces %d)" % [tris, surfaces])
	else:
		ok("within budget")
	if rig.collision_hulls().size() != 2:
		fail("expected 2 collision hulls")
	else:
		ok("2 convex collision hulls")

func _hyd_error() -> float:
	var e := 0.0
	for tag in ["L", "R"]:
		e = maxf(e, n("LiftCyl_%s_Barrel" % tag).global_position.distance_to(n("Pin_LiftBase_" + tag).global_position))
		e = maxf(e, n("LiftCyl_%s_Rod" % tag).global_position.distance_to(n("Pin_LiftRod_" + tag).global_position))
		var d := -n("LiftCyl_%s_Rod" % tag).position.z
		if d < DozerKin.LIFT_RANGE.x - 0.02 or d > DozerKin.LIFT_RANGE.y + 0.02:
			e = maxf(e, 1.0)
	e = maxf(e, n("TiltCyl_Barrel").global_position.distance_to(n("Pin_TiltBase").global_position))
	e = maxf(e, n("TiltCyl_Rod").global_position.distance_to(n("Pin_TiltRod").global_position))
	var dt := -n("TiltCyl_Rod").position.z
	if dt < DozerKin.TILT_RANGE.x - 0.02 or dt > DozerKin.TILT_RANGE.y + 0.02:
		e = maxf(e, 1.0)
	return e

func _clips() -> void:
	var cr := {}
	for clip in CLIPS:
		if not rig.player.has_animation(clip):
			fail("clip %s missing" % clip)
			continue
		var anim := rig.player.get_animation(clip)
		var worst := 0.0
		for i in 49:
			rig.player.play(clip)
			rig.player.seek(anim.length * float(i) / 48.0, true)
			worst = maxf(worst, _hyd_error())
		rig.player.stop()
		cr[clip] = {"length_s": snappedf(anim.length, 0.001), "worst_pin_error_m": snappedf(worst, 0.00001)}
		print("clip %-12s %5.2fs  worst pin error %.5f m" % [clip, anim.length, worst])
		if worst > TOL:
			fail("%s: cylinder pins detach by %.4f m" % [clip, worst])
	report["clips"] = cr

func _grid() -> void:
	rig.player.stop()
	var worst := 0.0
	var count := 0
	for ai in 13:
		for ti in 9:
			rig.set_blade(lerpf(DozerKin.LIFT_MIN, DozerKin.LIFT_MAX, ai / 12.0), lerpf(-DozerKin.TILT_MAX, DozerKin.TILT_MAX, ti / 8.0))
			worst = maxf(worst, _hyd_error())
			count += 1
	report["solver"] = {"poses": count, "worst_pin_error_m": snappedf(worst, 0.00001)}
	print("solver grid: %d poses, worst pin error %.5f m" % [count, worst])
	if worst > TOL:
		fail("runtime solver: pins detach by %.4f m" % worst)
	else:
		ok("runtime solver keeps every pin connected")
	rig.set_blade(0.2, 0.0)

func _finish() -> void:
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var f := FileAccess.open("res://docs/audit/bulldozer_validation.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print(failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
