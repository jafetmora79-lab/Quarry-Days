extends RefCounted
class_name BuildingModels
## The yard buildings' shells, modelled in Blender (tools/building_models/build_buildings.py -> assets/buildings/BLD_QD_<Name>.glb). The glTF materials carry only a
## NAME; the project's own materials are swapped in here (the Veil siding / drywall / trim / foundation textures, the corrugated roof, clean glass), so a Blender
## building looks like the rest of the yard. Returns null when the model is missing so the caller keeps the procedural shell it had before.

const DIR := "res://assets/buildings/"
const COLOURS := {"DarkWood": Color(0.30, 0.20, 0.12), "Green": Color(0.25, 0.5, 0.25), "FlowerR": Color(0.85, 0.25, 0.2), "FlowerY": Color(0.95, 0.8, 0.25),
	"Door": Color(0.36, 0.24, 0.14), "Chimney": Color(0.50, 0.28, 0.22), "Fabric": Color(0.30, 0.44, 0.46), "FabricRed": Color(0.62, 0.28, 0.22), "Tv": Color(0.08, 0.10, 0.14), "Paint": Color(0.90, 0.78, 0.20)}

static func material_for(name: String, roof_key: String) -> Material:
	match name:
		"Siding": return load(QuarryArt.M_SIDING)
		"Plaster": return load(QuarryArt.M_DRYWALL)
		"Trim": return load(QuarryArt.M_TRIM)
		"Concrete": return load(QuarryArt.M_FOUNDATION)
		"Roof": return MeshKit.mat(roof_key)
		"Roof2": return MeshKit.mat("SteelPlate")
		"Glass": return load(QuarryArt.M_GLASS)
		"Wood": return load(QuarryArt.M_WOOD)
		"Lamp": return MeshKit.flat(Color(1.0, 0.86, 0.55), 1.2)
		"SteelGreen", "PaintOrange", "PaintRed": return MeshKit.mat(name)
		"Steel": return MeshKit.mat("SteelPlate")
		"Industrial": return load(QuarryArt.M_INDUSTRIAL)
		"Corrugated": return MeshKit.mat("Corrugated")
		"Hazard": return MeshKit.mat("Hazard")
	if COLOURS.has(name):
		return MeshKit.flat(COLOURS[name])
	return ToolModels.material_for(name)

static func load_model(name: String, roof_key := "CorrugatedRed") -> Node3D:
	var path := DIR + "BLD_QD_%s.glb" % name
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.name = "Building_" + name
	# one mesh node with one surface per material (the game's mesh-node budget counts nodes, not surfaces)
	var merged := ArrayMesh.new()
	var roof_mesh := ArrayMesh.new()                    # a holder named "Roof" stays its own mesh (the garage's roof is hidden while a machine is driven inside)
	var olds: Array = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		var in_roof := false
		while cur != null and cur != n:
			if str(cur.name) == "Roof":
				in_roof = true
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var dest: ArrayMesh = roof_mesh if in_roof else merged
		for si in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(si)
			var mat := material_for(src.resource_name, roof_key) if src != null else null
			var arr := m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				verts[i] = xf * verts[i]
			for i in norms.size():
				norms[i] = (xf.basis * norms[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			dest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var idx := dest.get_surface_count() - 1
			if mat != null:
				dest.surface_set_material(idx, mat)
			dest.surface_set_name(idx, src.resource_name if src != null else "")
		olds.append(m)
	for m in olds:
		m.get_parent().remove_child(m)
		m.free()
	var body := MeshInstance3D.new()
	body.name = "Shell"
	body.mesh = merged
	body.set_meta("art", true)
	n.add_child(body)
	if roof_mesh.get_surface_count() > 0:
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		roof.mesh = roof_mesh
		roof.set_meta("art", true)
		n.add_child(roof)
		n.set_meta("roof", roof)
	return n
