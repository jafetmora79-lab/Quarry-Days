extends SceneTree
## Headless validation of the Blender dump truck in Godot.
##   godot --headless --path . --script res://tools/validate_truck.gd
## Nodes, orientation, ground contact, budget, hulls, the tipping ram + tailgate over every baked clip and the runtime solver.
## Needs the GLB imported once (open the editor / run `godot --editor --quit-after 600`). Exit 0 = pass. Writes docs/audit/truck_validation.json.

const REQUIRED := ["Sprung", "Shake", "Bed", "Tailgate", "BedCyl_Barrel", "BedCyl_Rod", "Chassis", "Cab", "CabGlass", "CabInterior", "SteeringWheel", "Steer_L", "Steer_R",
	"Wheel_FL", "Wheel_FR", "Wheel_R1L", "Wheel_R1R", "Wheel_R2L", "Wheel_R2R", "Axles", "Lamp_Head_L", "Lamp_Head_R", "Marker_BedLoad", "Marker_Dust", "Marker_Seat",
	"Marker_Eye", "Marker_ExhaustTip", "Pin_RamBase", "Pin_RamRod", "Pin_BedHinge", "ColHull_Chassis", "ColHull_Cab", "ColHull_Bed"]
const CLIPS := ["Idle", "EngineStart", "EngineStop", "DumpUp", "DumpDown", "DumpCycle", "Drive", "Steer"]
const TOL := 0.004
const MAX_TRIS := 9000
const MAX_SURFACES := 100

var failures: Array = []
var report := {}
var rig: TruckRig

func fail(msg: String) -> void:
	failures.append(msg)
	print("FAIL  ", msg)

func ok(msg: String) -> void:
	print("ok    ", msg)

func _initialize() -> void:
	rig = TruckRig.new()
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

func n(node_name: String) -> Node3D:
	return rig.model.find_child(node_name, true, false) as Node3D

func _nodes() -> void:
	var missing := []
	for r in REQUIRED:
		if n(r) == null:
			missing.append(r)
	if missing.is_empty():
		ok("%d required nodes present" % REQUIRED.size())
	else:
		fail("missing nodes: %s" % str(missing))
	var d := n("Bed").global_position.distance_to(n("Pin_BedHinge").global_position)
	if d > TOL:
		fail("bed hinge origin %.4f m from its pin" % d)
	else:
		ok("bed pivots on the hinge pin")
	if n("Wheel_FL") == null or rig._wheels.size() != 6:
		fail("expected 6 wheels, found %d" % rig._wheels.size())
	else:
		ok("six wheels (steered front pair + tandem rear)")

func _geometry() -> void:
	# wheel bottoms on the ground: tyre radius below the hub
	var hub := n("Wheel_FL").global_position
	if absf(hub.y - TruckKin.WHEEL_R) > 0.01:
		fail("wheel hub height %.3f (expected %.3f)" % [hub.y, TruckKin.WHEEL_R])
	else:
		ok("wheels sit on y=0")
	if n("Lamp_Head_L").global_position.z >= -1.5 or n("Marker_Dust").global_position.z <= 1.5:
		fail("orientation: cab must face -Z and the tailgate +Z")
	else:
		ok("cab faces -Z, tailgate at +Z")
	if absf(n("Wheel_FL").global_position.x + n("Wheel_FR").global_position.x) > 0.01:
		fail("wheels not symmetric")
	var bb := AABB()
	var first := true
	for node in rig.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name.begins_with("ColHull") or not mi.visible:
			continue
		var a := mi.global_transform * mi.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	report["bounds"] = {"min": [bb.position.x, bb.position.y, bb.position.z], "size": [bb.size.x, bb.size.y, bb.size.z]}
	print("bounds size=", bb.size, " (nominal 2.2 x 1.8 x 4.6 before scaling)")

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
	if rig.collision_hulls().size() != 3:
		fail("expected 3 collision hulls")
	else:
		ok("3 convex collision hulls")

func _ram_error() -> float:
	var e := n("BedCyl_Barrel").global_position.distance_to(n("Pin_RamBase").global_position)
	e = maxf(e, n("BedCyl_Rod").global_position.distance_to(n("Pin_RamRod").global_position))
	var d := -n("BedCyl_Rod").position.z
	if d < TruckKin.RAM_RANGE.x - 0.02 or d > TruckKin.RAM_RANGE.y + 0.02:
		e = maxf(e, 1.0)               # stroke outside its range counts as a failure
	return e

func _clips() -> void:
	var clip_report := {}
	for clip in CLIPS:
		if not rig.player.has_animation(clip):
			fail("clip %s missing" % clip)
			continue
		var anim := rig.player.get_animation(clip)
		var worst := 0.0
		for i in 49:
			rig.player.play(clip)
			rig.player.seek(anim.length * float(i) / 48.0, true)
			worst = maxf(worst, _ram_error())
		rig.player.stop()
		clip_report[clip] = {"length_s": snappedf(anim.length, 0.001), "worst_ram_pin_error_m": snappedf(worst, 0.00001)}
		print("clip %-12s %5.2fs  worst ram pin error %.5f m" % [clip, anim.length, worst])
		if worst > TOL:
			fail("%s: ram detaches by %.4f m" % [clip, worst])
	report["clips"] = clip_report

func _grid() -> void:
	rig.player.stop()
	var worst := 0.0
	var gate_ok := true
	for i in 41:
		var th := TruckKin.BED_MAX * i / 40.0
		rig.set_bed_angle(th)
		worst = maxf(worst, _ram_error())
		if i == 0 and absf(n("Tailgate").rotation.x) > 0.001:
			gate_ok = false                       # latched shut at rest
		if i == 40 and absf(n("Tailgate").rotation.x - TruckKin.GATE_OPEN) > 0.001:
			gate_ok = false                       # fully open when tipped
	report["solver"] = {"worst_ram_pin_error_m": snappedf(worst, 0.00001), "gate_ok": gate_ok}
	print("solver: worst ram pin error %.5f m, tailgate %s" % [worst, "ok" if gate_ok else "WRONG"])
	if worst > TOL:
		fail("runtime solver: ram detaches by %.4f m" % worst)
	if not gate_ok:
		fail("tailgate does not latch at rest / open when tipped")
	rig.set_bed_angle(0.0)

func _finish() -> void:
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var f := FileAccess.open("res://docs/audit/truck_validation.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print(failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
