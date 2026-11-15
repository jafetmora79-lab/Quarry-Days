extends SceneTree
## Headless validation of the Blender excavator in Godot.
##   godot --headless --path . --script res://tools/validate_excavator.gd
## Checks node names, ground contact / facing / size, materials, triangle + draw-call budget, collision hulls, every baked clip
## (pins stay connected, rods stay inside their strokes) and the runtime solver over a grid of joint angles.
## Exit code 0 = all checks passed. Writes docs/audit/excavator_validation.json.

const REQUIRED := ["Turret", "Boom", "Stick", "Bucket", "Undercarriage", "Track_L", "Track_R", "Sprocket_L", "Idler_L", "Roller_L0", "CabFrame", "CabGlass", "CabInterior",
	"TurretBody", "Exhaust", "ExhaustCap", "Joystick_L", "Joystick_R", "Lamp_Cab_L", "Lamp_Boom", "BoomCyl_L_Barrel", "BoomCyl_L_Rod", "BoomCyl_R_Barrel", "BoomCyl_R_Rod",
	"StickCyl_Barrel", "StickCyl_Rod", "BucketCyl_Barrel", "BucketCyl_Rod", "IdlerLink_L", "BucketLink_L", "Marker_BucketTip", "Marker_BucketLoad", "Marker_Seat", "Marker_Eye",
	"ColHull_Tracks", "ColHull_Upper", "ColHull_Cab"]
const CLIPS := ["Idle", "EngineStart", "EngineStop", "Swing", "BoomUpDown", "StickInOut", "BucketCurlDump", "TrackDrive", "DigCycle", "TruckLoad"]
var STROKES := {"BoomCyl_L": ExcavatorKin.CYL_RANGES["BoomCyl"], "BoomCyl_R": ExcavatorKin.CYL_RANGES["BoomCyl"], "StickCyl": ExcavatorKin.CYL_RANGES["StickCyl"], "BucketCyl": ExcavatorKin.CYL_RANGES["BucketCyl"]}
const TOL := 0.008          # metres: pin coincidence tolerance (baked clips are linear between 2-frame samples)
const MAX_TRIS := 9000
const MAX_SURFACES := 110

var failures: Array = []
var report := {}
var rig: ExcavatorRig

func fail(msg: String) -> void:
	failures.append(msg)
	print("FAIL  ", msg)

func ok(msg: String) -> void:
	print("ok    ", msg)

func _initialize() -> void:
	rig = ExcavatorRig.new()
	root.add_child(rig)
	await process_frame
	await process_frame
	if rig.model == null:
		fail("GLB did not load")
		_finish()
		return
	_check_nodes()
	_check_bounds()
	_check_materials_and_budget()
	_check_collision()
	_check_clips()
	_check_solver_grid()
	_finish()

func n(node_name: String) -> Node3D:
	return rig.model.find_child(node_name, true, false) as Node3D

func _check_nodes() -> void:
	var missing := []
	for r in REQUIRED:
		if n(r) == null:
			missing.append(r)
	if missing.is_empty():
		ok("%d required nodes present" % REQUIRED.size())
	else:
		fail("missing nodes: %s" % str(missing))
	# hinge pivots must sit on the mechanical pins (node origin == pin marker)
	for pair in [["Boom", "Pin_BoomFoot"], ["Stick", "Pin_Elbow"], ["Bucket", "Pin_BucketPin"]]:
		var a := n(pair[0])
		var b := n(pair[1])
		if a == null or b == null:
			fail("pivot pair %s missing" % str(pair))
			continue
		var d := a.global_position.distance_to(b.global_position)
		if d > TOL:
			fail("%s origin is %.4f m from %s" % [pair[0], d, pair[1]])
		else:
			ok("%s pivots on %s (%.5f m)" % [pair[0], pair[1], d])

func _mesh_aabb(root_node: Node) -> AABB:
	var box := AABB()
	var first := true
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name.begins_with("ColHull") or mi.name.begins_with("CabGlass"):
			continue
		var a := mi.global_transform * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box

func _check_bounds() -> void:
	rig.stop_clips()
	var bb := _mesh_aabb(rig.model)
	var tracks_aabb := (n("Track_L") as MeshInstance3D).get_aabb()
	if absf(tracks_aabb.position.y + n("Track_L").global_position.y) > 0.01:
		fail("ground contact: track bottom at %.3f (expected 0)" % (tracks_aabb.position.y + n("Track_L").global_position.y))
	else:
		ok("tracks sit on y=0")
	report["bounds"] = {"min": [bb.position.x, bb.position.y, bb.position.z], "size": [bb.size.x, bb.size.y, bb.size.z]}
	print("bounds min=%s size=%s" % [bb.position, bb.size])
	if bb.position.y < -0.2:
		fail("something hangs %.3f m below the ground at rest" % bb.position.y)
	var tip := n("Marker_BucketTip")
	if tip.global_position.z >= -1.2:
		fail("boom does not point toward -Z (tip z=%.2f)" % tip.global_position.z)
	else:
		ok("faces -Z (bucket tip z=%.2f)" % tip.global_position.z)
	if absf(n("Track_L").global_position.x + n("Track_R").global_position.x) > 0.01:
		fail("tracks not symmetric about x=0")
	var tl := (n("Track_L") as MeshInstance3D).get_aabb()
	var width := (n("Track_R").global_position.x - n("Track_L").global_position.x) + tl.size.x
	report["footprint"] = {"track_length": tl.size.z, "width_over_tracks": width}
	print("track length %.2f m, width over tracks %.2f m (old procedural model: 3.3 x 2.0)" % [tl.size.z, width])

func _check_materials_and_budget() -> void:
	var tris := 0
	var surfaces := 0
	var meshes := 0
	var bad := 0
	var grime := 0
	for node in rig.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name.begins_with("ColHull"):
			continue
		meshes += 1
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var m := mi.get_active_material(s) as StandardMaterial3D
			if m == null:
				bad += 1
			elif m.vertex_color_use_as_albedo:
				grime += 1
	report["budget"] = {"mesh_instances": meshes, "surfaces": surfaces, "triangles": tris}
	print("budget: %d mesh instances, %d surfaces (~draw calls), %d triangles" % [meshes, surfaces, tris])
	if bad > 0:
		fail("%d surfaces without a material" % bad)
	else:
		ok("every surface has a material")
	if tris > MAX_TRIS:
		fail("triangles %d > %d" % [tris, MAX_TRIS])
	else:
		ok("triangle budget (%d <= %d)" % [tris, MAX_TRIS])
	if surfaces > MAX_SURFACES:
		fail("surfaces %d > %d" % [surfaces, MAX_SURFACES])
	else:
		ok("draw-call budget (%d <= %d surfaces)" % [surfaces, MAX_SURFACES])
	if grime == 0:
		fail("no surface uses vertex-colour grime")
	else:
		ok("%d surfaces carry vertex-colour grime" % grime)

func _check_collision() -> void:
	var hulls := rig.collision_hulls()
	if hulls.size() != 3:
		fail("expected 3 collision hulls, got %d" % hulls.size())
	else:
		ok("3 convex collision hulls")

func _pin(pin_name: String) -> Vector3:
	return n(pin_name).global_position

func _link_end(link: String, length: float) -> Vector3:
	return n(link).global_transform * Vector3(0, 0, -length)

## Distances (m) that must be ~0 whatever the pose: every cylinder pinned at both ends and the 4-bar closed at J.
func _connection_errors() -> Dictionary:
	var e := {}
	e["boom_L_base"] = n("BoomCyl_L_Barrel").global_position.distance_to(_pin("Pin_BoomCylBase_L"))
	e["boom_R_base"] = n("BoomCyl_R_Barrel").global_position.distance_to(_pin("Pin_BoomCylBase_R"))
	e["boom_L_rod"] = n("BoomCyl_L_Rod").global_position.distance_to(_pin("Pin_BoomCylRod_L"))
	e["boom_R_rod"] = n("BoomCyl_R_Rod").global_position.distance_to(_pin("Pin_BoomCylRod_R"))
	e["stick_base"] = n("StickCyl_Barrel").global_position.distance_to(_pin("Pin_StickCylBase"))
	e["stick_rod"] = n("StickCyl_Rod").global_position.distance_to(_pin("Pin_StickCylRod"))
	e["bucket_base"] = n("BucketCyl_Barrel").global_position.distance_to(_pin("Pin_BucketCylBase"))
	var stick := n("Stick")
	var rod := stick.to_local(n("BucketCyl_Rod").global_position)
	for t in ["L", "R"]:
		e["idler_K_" + t] = n("IdlerLink_" + t).global_position.distance_to(_pin("Pin_IdlerK_" + t))
		e["bucketlink_L_" + t] = n("BucketLink_" + t).global_position.distance_to(_pin("Pin_BucketL_" + t))
		var ie := stick.to_local(_link_end("IdlerLink_" + t, ExcavatorKin.LINK_IDLER_LEN))
		var be := stick.to_local(_link_end("BucketLink_" + t, ExcavatorKin.LINK_BUCKET_LEN))
		# the links and the cylinder rod sit at different x on the shared pin; compare in the (y, z) plane
		e["J_idler_" + t] = Vector2(ie.y - rod.y, ie.z - rod.z).length()
		e["J_bucket_" + t] = Vector2(be.y - rod.y, be.z - rod.z).length()
	return e

func _stroke_problems() -> Array:
	var out := []
	for k in STROKES:
		var d := -n(k + "_Rod").position.z
		var r: Vector2 = STROKES[k]
		if d < r.x - 0.02 or d > r.y + 0.02:
			out.append("%s stroke %.3f outside %.2f..%.2f" % [k, d, r.x, r.y])
	return out

func _check_clips() -> void:
	var worst_all := 0.0
	var clip_report := {}
	for clip in CLIPS:
		if not rig.player.has_animation(clip):
			fail("clip %s missing" % clip)
			continue
		var anim := rig.player.get_animation(clip)
		var worst := 0.0
		var bad := 0
		var samples := 48
		for i in samples + 1:
			rig.player.play(clip)
			rig.player.seek(anim.length * float(i) / samples, true)
			var errs := _connection_errors()
			for k in errs:
				worst = maxf(worst, errs[k])
			if not _stroke_problems().is_empty():
				bad += 1
		rig.player.stop()
		clip_report[clip] = {"length_s": snappedf(anim.length, 0.001), "worst_pin_error_m": snappedf(worst, 0.00001), "stroke_violations": bad}
		print("clip %-15s %5.2fs  worst pin error %.5f m  stroke violations %d" % [clip, anim.length, worst, bad])
		if worst > TOL:
			fail("%s: pins detach by %.4f m" % [clip, worst])
		if bad > 0:
			fail("%s: rod outside its stroke at %d samples" % [clip, bad])
		worst_all = maxf(worst_all, worst)
	report["clips"] = clip_report
	ok("clips checked (worst pin error %.5f m)" % worst_all)

func _check_solver_grid() -> void:
	rig.player.stop()
	var lim := ExcavatorKin.LIMITS
	var worst := 0.0
	var count := 0
	var stroke_bad := 0
	for bi in 7:
		for si in 7:
			for ki in 7:
				var b: float = lerpf(lim["boom"].x, lim["boom"].y, bi / 6.0)
				var s: float = lerpf(lim["stick"].x, lim["stick"].y, si / 6.0)
				var k: float = lerpf(lim["bucket"].x, lim["bucket"].y, ki / 6.0)
				rig.set_pose(0.4, b, s, k)
				var errs := _connection_errors()
				for key in errs:
					worst = maxf(worst, errs[key])
				if not _stroke_problems().is_empty():
					stroke_bad += 1
				count += 1
	report["solver_grid"] = {"poses": count, "worst_pin_error_m": snappedf(worst, 0.00001), "stroke_violations": stroke_bad}
	print("solver grid: %d poses, worst pin error %.5f m, stroke violations %d" % [count, worst, stroke_bad])
	if worst > TOL:
		fail("runtime solver: pins detach by %.4f m" % worst)
	else:
		ok("runtime solver keeps pins connected over %d poses" % count)
	if stroke_bad > 0:
		fail("runtime solver: %d poses leave a rod outside its stroke" % stroke_bad)
	rig.set_pose(0, ExcavatorKin.REST["boom"], ExcavatorKin.REST["stick"], ExcavatorKin.REST["bucket"])

func _finish() -> void:
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var f := FileAccess.open("res://docs/audit/excavator_validation.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print(failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
