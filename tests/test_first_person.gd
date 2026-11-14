extends SceneTree
## First-person tools: chisels are held in one hand and struck by a hammer in the other (the strike lands on the chisel exactly when the damage fires),
## and no tool, hand or sleeve ever comes closer to the camera than the near clip margin, at rest or mid-swing.
##   godot --headless --fixed-fps 60 -s tests/test_first_person.gd
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
func nearest_z(tv: QuarryToolView) -> float:
	# the nearest point (largest z, camera space; the camera looks down -Z) of every mesh of the tool in the view's parent space
	var zmax := -1e9
	for mi in tv.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		var xf: Transform3D = tv.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		xf = tv.transform * (tv.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
		for cx in [0.0, 1.0]:
			for cy in [0.0, 1.0]:
				for cz in [0.0, 1.0]:
					var pnt: Vector3 = xf * (bb.position + bb.size * Vector3(cx, cy, cz))
					zmax = maxf(zmax, pnt.z)
	return zmax
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var tools := [0, 1, 2, 3, 4]
	for id in GearModels.IDS:
		tools.append(GearModels.tier_of(id))
	var worst := -1e9
	for t in tools:
		var tv := QuarryToolView.new()
		holder.add_child(tv)
		tv.equip(t, true)
		var tmax := -1e9
		var hit := {"n": 0, "d": 99.0}
		var is_chisel: bool = t >= GearModels.TIER_BASE and GearModels.id_of(t) in ["pointed_chisel", "flat_chisel"]
		var striker: Node3D = tv.model.get_meta("striker") if tv.model.has_meta("striker") else null
		check((striker != null) == is_chisel, "tool %s: a striking hand exists exactly for the chisels" % str(t))
		tv.swing(0.5, func(): hit["n"] += 1)
		var far_back := 0.0
		for f in range(60):
			var n_before: int = hit["n"]
			tv._process(1.0 / 60.0)
			if striker and hit["n"] > n_before:
				hit["d"] = absf(striker.position.y - (QuarryToolView.STRIKE_POINT.y - 0.03))     # measured on the frame the damage lands, after the pose
			tmax = maxf(tmax, nearest_z(tv))
			if striker:
				far_back = maxf(far_back, QuarryToolView.STRIKE_POINT.y - striker.position.y)
		worst = maxf(worst, tmax)
		check(hit["n"] == 1, "tool %s: one swing fires exactly one impact" % str(t))
		if striker:
			check(hit["d"] < 0.02, "tool %s: the hammer face is on the chisel when the damage lands (gap %.3f m)" % [str(t), hit["d"]])
			check(far_back > 0.2, "tool %s: the hammer is drawn back before the blow (%.2f m)" % [str(t), far_back])
		check(tmax < -0.12, "tool %s: nothing comes closer than 12 cm to the camera (nearest z %.2f)" % [str(t), tmax])
		tv.queue_free()
	print("worst nearest z over all tools: %.3f" % worst)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
