extends RefCounted
class_name EquipModels
## The production machinery (crushers, hopper, bins, storage, every belt piece), modelled in Blender (tools/equipment_models/build_equipment.py ->
## assets/equipment/EQP_QD_<key>.glb). Each file is: Body (every static part) plus named holders at their hinges (Flywheel_L / Flywheel_R / Jaw / Mantle spin or swing,
## EndCap_In / EndCap_Out are shown while that belt end is unconnected). glTF materials carry only a NAME; the project's own materials are swapped in here.
## `attach` puts a model into a parent node, ground at the parent's y + g, and returns the pieces the game animates. Returns {} when the file is missing so the
## caller can keep the procedural builder it had before.

const DIR := "res://assets/equipment/"

static func path_of(key: String) -> String:
	return DIR + "EQP_QD_%s.glb" % key

static func has(key: String) -> bool:
	return ResourceLoader.exists(path_of(key))

static func material_for(name: String) -> Material:
	match name:
		"Lamp": return MeshKit.flat(Color(1.0, 0.86, 0.55), 1.2)
		"Bright": return MeshKit.mat(QuarryArt.M_BRUSHED)
		"Rubber": return MeshKit.mat(QuarryArt.M_RUBBER)
		"SteelGreen", "SteelPlate", "PaintYellow", "PaintOrange", "PaintRed", "Hazard", "Belt":
			return MeshKit.mat(name)
	return ToolModels.material_for(name)

## Merges every MeshInstance3D below `holder` into one mesh node (a surface per material, baked relative to the holder) plus, if it has any, a separate "Belt" node.
static func _merge(holder: Node3D) -> Dictionary:
	var parts := {"Mesh": ArrayMesh.new(), "Belt": ArrayMesh.new()}
	var olds: Array = []
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != holder:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		for si in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(si)
			var nm: String = src.resource_name if src != null else ""
			var arr := m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				verts[i] = xf * verts[i]
			for i in norms.size():
				norms[i] = (xf.basis * norms[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			var dst: ArrayMesh = parts["Belt"] if nm == "Belt" else parts["Mesh"]
			dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var idx := dst.get_surface_count() - 1
			var mat := material_for(nm)
			if mat != null:
				dst.surface_set_material(idx, mat)
			dst.surface_set_name(idx, nm)
		olds.append(m)
	for m in olds:
		m.get_parent().remove_child(m)
		m.free()
	var out := {}
	for k in ["Mesh", "Belt"]:
		var am: ArrayMesh = parts[k]
		if am.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = k
		mi.mesh = am
		mi.set_meta("art", true)
		holder.add_child(mi)
		out[k] = mi
	return out

## Adds model `key` under `parent`. Returns {"root": Node3D, "belt": MeshInstance3D or null, "parts": {holder name: Node3D}} or {}.
static func attach(parent: Node3D, key: String, g: float) -> Dictionary:
	if not has(key):
		return {}
	var ps := load(path_of(key)) as PackedScene
	if ps == null:
		return {}
	var n := ps.instantiate() as Node3D
	if n.get_child_count() == 1 and str(n.get_child(0).name).begins_with("QD_"):
		var inner := n.get_child(0) as Node3D                       # the glTF root wraps the model's own root
		n.remove_child(inner)
		n.free()
		n = inner
	n.name = "Equip_" + key
	var parts := {}
	var belt: MeshInstance3D = null
	for c in n.get_children():
		if not c is Node3D:
			continue
		var merged := _merge(c as Node3D)
		parts[str(c.name)] = c
		if merged.has("Belt"):
			belt = merged["Belt"]
	n.position = Vector3(0, g, 0)
	parent.add_child(n)
	return {"root": n, "belt": belt, "parts": parts}
