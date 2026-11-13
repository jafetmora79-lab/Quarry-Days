extends SceneTree
## Animation audit (animation overhaul, Phase A): measures, from the real model builders, whether moving parts stay attached while
## they move, whether hinges sit where the parts meet, and whether the first-person hands close on real geometry.
##   godot --headless -s tools/animation_audit.gd            writes docs/audit/animation_audit.json
## A "gap" is the smallest distance between the vertices of a moving part and the vertices of what it is hinged to (metres).
## Gaps over GAP_LIMIT are reported as detached; parts that overlap report 0.

const GAP_LIMIT := 0.045
var report := {}

func _initialize() -> void:
	call_deferred("run")

func points(n: Node3D, skip: Array = []) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var skipped := false
		for s in skip:
			if s != null and (s == m or s.is_ancestor_of(m)):
				skipped = true
		if skipped:
			continue
		var xf: Transform3D = m.global_transform
		for si in range(m.mesh.get_surface_count()):
			var arr := m.mesh.surface_get_arrays(si)
			if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
				continue
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var step := maxi(1, vs.size() / 300)
			for i in range(0, vs.size(), step):
				out.append(xf * vs[i])
	return out

## Triangles (3 points each) of every visible mesh under n, in world space; `points()` above holds the sampled vertices.
func tris(n: Node3D, skip: Array = []) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var skipped := false
		for s in skip:
			if s != null and (s == m or s.is_ancestor_of(m)):
				skipped = true
		if skipped:
			continue
		var xf: Transform3D = m.global_transform
		for si in range(m.mesh.get_surface_count()):
			var arr := m.mesh.surface_get_arrays(si)
			if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
				continue
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null and idx.size() > 0:
				for i in idx:
					out.append(xf * vs[i])
			else:
				for v in vs:
					out.append(xf * v)
	return out

func closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)

func dist_to_tris(p: Vector3, t: PackedVector3Array) -> float:
	var best := INF
	for i in range(0, t.size(), 3):
		var q := closest_on_tri(p, t[i], t[i + 1], t[i + 2])
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
	return sqrt(best)

## Surface-to-surface distance between two parts (0 when they touch or overlap closely), vertices against triangles both ways.
func gap(a, b) -> float:
	var pa: PackedVector3Array = a[0]
	var ta: PackedVector3Array = a[1]
	var pb: PackedVector3Array = b[0]
	var tb: PackedVector3Array = b[1]
	if pa.is_empty() or pb.is_empty():
		return INF
	var best := INF
	for p in pa:
		best = minf(best, dist_to_tris(p, tb))
	for p in pb:
		best = minf(best, dist_to_tris(p, ta))
	return best

func part(n: Node3D, skip: Array = []) -> Array:
	return [points(n, skip), tris(n, skip)]

func note(group: String, name: String, g: float, extra := "") -> void:
	# interpenetrating solids (a pin through a housing) have no surface gap but a real overlap: they count as attached when close
	if not report.has(group):
		report[group] = []
	var ok := g <= GAP_LIMIT
	report[group].append({"check": name, "gap_m": snappedf(g, 0.001) if g < INF else -1.0, "ok": ok, "note": extra})
	print("%s %-22s %-44s gap %.3f m %s" % ["ok  " if ok else "FAIL", group, name, g if g < INF else -1.0, extra])

func vehicle_node(kind: String) -> Node3D:
	var pv := QuarryPreview.PreviewVehicle.new()
	pv.model_root = Node3D.new()
	pv.add_child(pv.model_root)
	match kind:
		"loader": VehicleModels.loader(pv)
		"excavator": VehicleModels.excavator(pv)
		_: VehicleModels.truck(pv)
	root.add_child(pv)
	return pv

func run() -> void:
	# ---------------------------------------------------------------- excavator joints through their whole range
	var ex = vehicle_node("excavator")
	var poses := {"rest": [0.0, 0.0, 0.0, 0.0], "boom raised": [1.1, 0.0, 0.0, 0.0], "boom lowered": [-0.55, 0.0, 0.0, 0.0], "stick out": [0.3, 0.7, 0.0, 0.0],
		"stick in": [0.3, -0.7, 0.0, 0.0], "bucket curled": [0.3, 0.2, 0.8, 0.0], "bucket dumped": [0.3, 0.2, -1.1, 0.0], "cab swung": [0.3, 0.2, 0.0, 2.2]}
	for k in poses:
		var p: Array = poses[k]
		ex.arm.rotation.x = p[0]
		ex.stick.rotation.x = p[1]
		ex.bucket.rotation.x = -p[0] - p[1] + p[2]
		ex.turret.rotation.y = p[3]
		await physics_frame
		var arm_pts := part(ex.arm, [ex.stick])
		var stick_pts := part(ex.stick, [ex.bucket])
		var bucket_pts := part(ex.bucket)
		var body_pts := part(ex.turret, [ex.arm])
		note("excavator", "boom -> cab/body [" + k + "]", gap(arm_pts, body_pts))
		note("excavator", "stick -> boom [" + k + "]", gap(stick_pts, arm_pts))
		note("excavator", "bucket -> stick [" + k + "]", gap(bucket_pts, stick_pts))
	ex.queue_free()
	# ---------------------------------------------------------------- truck bed hinge
	var tr = vehicle_node("truck")
	for tilt in [0.0, 0.5, 0.95]:
		tr.bed.rotation.x = -0.95 * smoothstep(0.0, 0.95, tilt)
		await physics_frame
		var bed_pts := part(tr.bed, [tr.bed_load])
		var chassis := part(tr.model_root, [tr.bed, tr.bed_load])
		note("truck", "bed hinge -> chassis [tilt %.2f]" % tilt, gap(bed_pts, chassis))
		# the raised bed must clear the cab: no bed vertex inside the cab's box
		var cab_clear := true
		var cab_box := AABB(Vector3(-1.0, 0.55, -2.32), Vector3(2.0, 1.7, 1.37))
		for q in bed_pts[0]:
			var l: Vector3 = tr.model_root.global_transform.affine_inverse() * q
			if cab_box.grow(-0.02).has_point(l):
				cab_clear = false
		report["truck"].append({"check": "bed clears the cab [tilt %.2f]" % tilt, "ok": cab_clear})
		print("%s truck  bed clears cab at tilt %.2f" % ["ok  " if cab_clear else "FAIL", tilt])
	tr.queue_free()
	# ---------------------------------------------------------------- loader arm and bucket
	var ld = vehicle_node("loader")
	for lift in [0.0, 0.5, 1.0]:
		ld.arm.rotation.x = lerpf(-0.12, 0.75, lift)
		ld.bucket.rotation.x = -ld.arm.rotation.x + 0.4 * lift
		await physics_frame
		var arm_pts2 := part(ld.arm, [ld.bucket])
		var body2 := part(ld.model_root, [ld.arm])
		note("loader", "lift arm -> chassis [lift %.1f]" % lift, gap(arm_pts2, body2))
		note("loader", "bucket -> lift arm [lift %.1f]" % lift, gap(part(ld.bucket), arm_pts2))
	ld.queue_free()
	# ---------------------------------------------------------------- crushers: moving internals touch the housing
	for tier in [1, 2]:
		var art := QuarryArt.new()
		var holder := Node3D.new()
		root.add_child(holder)
		art.crusher_model(holder, 0.0, tier)
		var moving: Array = []
		if holder.has_meta("flywheels"):
			moving.append_array(holder.get_meta("flywheels"))
		if holder.has_meta("jaw"):
			moving.append(holder.get_meta("jaw"))
		var static_pts := part(holder, moving)
		var k := 0
		for mv in moving:
			k += 1
			note("crusher tier %d" % tier, "moving part %d -> housing" % k, gap(part(mv), static_pts))
		holder.queue_free()
	# ---------------------------------------------------------------- hand tools: the hands close on real geometry
	for id in GearModels.IDS:
		var tool_n := GearModels.build_tool(id)
		root.add_child(tool_n)
		var pose: Dictionary = GearModels.POSE[id]
		var tp := tris(tool_n)
		for h in pose.get("hands", []):
			note("tool grip", "%s %s hand" % [id, h[0]], dist_to_tris(h[1], tp))
		note("tool tip", "%s working tip on the model" % id, dist_to_tris(pose.get("tip", Vector3.ZERO), tp))
		tool_n.queue_free()
	var f := FileAccess.open("res://docs/audit/animation_audit.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	var bad := 0
	var total := 0
	for g in report:
		for r in report[g]:
			total += 1
			if not r["ok"]:
				bad += 1
	print("ANIMATION AUDIT: %d checks, %d failing" % [total, bad])
	print("RESULT: %d checks, %d failures" % [total, bad])
	quit(1 if bad > 0 else 0)
