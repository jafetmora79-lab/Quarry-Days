extends SceneTree
## Heights of the excavator's turret top surface on a grid (turret-local x, z) by ray-triangle tests against the real meshes.
func _initialize():
	call_deferred("run")
func tris_of(root: Node) -> Array:
	var out := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		for s in range(m.mesh.get_surface_count()):
			var arr = m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var gt: Transform3D = m.global_transform
			if idx != null and idx.size() > 0:
				for i in range(0, idx.size(), 3):
					out.append([gt * v[idx[i]], gt * v[idx[i+1]], gt * v[idx[i+2]]])
			else:
				for i in range(0, v.size(), 3):
					out.append([gt * v[i], gt * v[i+1], gt * v[i+2]])
	return out
func top_y(tris: Array, x: float, z: float) -> float:
	var best := -INF
	var from := Vector3(x, 6.0, z)
	for t in tris:
		var h = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, t[0], t[1], t[2])
		if h != null and (h as Vector3).y > best:
			best = (h as Vector3).y
	return best
func run():
	var rig := ExcavatorRig.new()
	root.add_child(rig)
	await process_frame
	var turret := rig.model.find_child("Turret", true, false) as Node3D
	var tris := tris_of(turret)
	print("TRIS ", tris.size())
	for z in [-0.8, -0.62, -0.4, -0.2, 0.0, 0.3, 0.6, 0.9, 1.2]:
		var line := "TOP z=%5.2f :" % z
		for x in [-0.9, -0.6, -0.3, 0.0, 0.3, 0.55, 0.7, 0.88, 1.0]:
			line += " %5.2f" % top_y(tris, x, z)
		print(line)
	quit()
