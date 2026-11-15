extends SceneTree
## Headless validation of the Blender wheel loader: nodes, orientation, ground contact, budget, hulls, and the lift + tilt cylinders over every
## baked clip and over a grid of blade angles (runtime solver). Exit 0 = pass. Writes docs/audit/loader_validation.json.
##   godot --headless --path . --script res://tools/validate_loader.gd      (GLB must be imported once)

const REQUIRED := ["Shake", "Rear", "Front", "FrontBody", "Lift", "Bucket", "Cab", "CabGlass", "CabInterior", "SteeringWheel", "Joystick", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR",
	"LiftCyl_L_Barrel", "LiftCyl_L_Rod", "LiftCyl_R_Barrel", "LiftCyl_R_Rod", "TiltCyl_Barrel", "TiltCyl_Rod", "Lamp_Cab", "Marker_BucketLoad", "Marker_Lip", "Marker_Seat", "Marker_Eye",
	"Marker_ExhaustTip", "Pin_LiftBase_L", "Pin_LiftBase_R", "Pin_LiftRod_L", "Pin_LiftRod_R", "Pin_TiltBase", "Pin_TiltRod", "Pin_Pivot", "Pin_BucketPivot", "ColHull_Body"]
const CLIPS := ["Idle", "EngineStart", "EngineStop", "LiftUpDown", "BucketTilt", "Steer", "ScoopCycle", "DumpCycle", "Drive"]
const TOL := 0.008
const MAX_TRIS := 9000
const MAX_SURFACES := 110

var failures: Array = []
var report := {}
var rig: LoaderRig

func fail(msg: String) -> void:
	failures.append(msg)
	print("FAIL  ", msg)

func ok(msg: String) -> void:
	print("ok    ", msg)

func _initialize() -> void:
	rig = LoaderRig.new()
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
	var d := n("Lift").global_position.distance_to(n("Pin_Pivot").global_position)
	if d > TOL:
		fail("lift arm origin %.4f m from the tower pivot" % d)
	else:
		ok("the arms pivot on the tower")
	if rig._wheels.size() != 4:
		fail("expected 4 wheels, found %d" % rig._wheels.size())
	else:
		ok("four large wheels")

func _geometry() -> void:
	var hub := n("Wheel_FL").global_position
	if absf(hub.y - LoaderKin.WHEEL_R) > 0.01:
		fail("wheel hub height %.3f (expected %.3f)" % [hub.y, LoaderKin.WHEEL_R])
	else:
		ok("wheels sit on y=0")
	if n("Marker_Lip").global_position.z >= -1.5 or n("Marker_Seat").global_position.z <= 0.0:
		fail("orientation: the bucket must face -Z with the cab behind")
	else:
		ok("bucket faces -Z, cab behind the hinge")
	rig.set_arm(0.0, -0.05)
	var low := n("Marker_Lip").global_position.y
	rig.set_arm(0.0, 0.0)
	if low > 0.2 or low < -0.1:
		fail("lowered bucket lip is %.2f m above the ground" % low)
	else:
		ok("a lowered bucket rests on the ground (lip %.2f m)" % low)
	rig.set_steer(1.0)
	var tilt := absf(n("Wheel_FL").global_position.x - n("Wheel_RL").global_position.x)
	rig.set_steer(0.0)
	if tilt < 0.2:
		fail("the front frame does not articulate")
	else:
		ok("the frame articulates about the centre hinge")

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
	if rig.collision_hulls().size() != 1:
		fail("expected 1 collision hull")
	else:
		ok("convex collision hull")

func _hyd_error() -> float:
	var e := 0.0
	for tag in ["L", "R"]:
		e = maxf(e, n("LiftCyl_%s_Barrel" % tag).global_position.distance_to(n("Pin_LiftBase_" + tag).global_position))
		e = maxf(e, n("LiftCyl_%s_Rod" % tag).global_position.distance_to(n("Pin_LiftRod_" + tag).global_position))
		var d := -n("LiftCyl_%s_Rod" % tag).position.z
		if d < LoaderKin.LIFT_RANGE.x - 0.02 or d > LoaderKin.LIFT_RANGE.y + 0.02:
			e = maxf(e, 1.0)
	e = maxf(e, n("TiltCyl_Barrel").global_position.distance_to(n("Pin_TiltBase").global_position))
	e = maxf(e, n("TiltCyl_Rod").global_position.distance_to(n("Pin_TiltRod").global_position))
	var dt := -n("TiltCyl_Rod").position.z
	if dt < LoaderKin.TILT_RANGE.x - 0.02 or dt > LoaderKin.TILT_RANGE.y + 0.02:
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
	for ai in 11:
		for bi in 11:
			rig.set_arm(LoaderKin.LIFT_MAX * ai / 10.0, lerpf(LoaderKin.TILT_MIN, LoaderKin.TILT_MAX, bi / 10.0))
			worst = maxf(worst, _hyd_error())
			count += 1
	report["solver"] = {"poses": count, "worst_pin_error_m": snappedf(worst, 0.00001)}
	print("solver grid: %d poses, worst pin error %.5f m" % [count, worst])
	if worst > TOL:
		fail("runtime solver: pins detach by %.4f m" % worst)
	else:
		ok("runtime solver keeps every pin connected")
	rig.set_arm(0.0, 0.0)

func _finish() -> void:
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var f := FileAccess.open("res://docs/audit/loader_validation.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print(failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
