extends RefCounted
class_name MeshyCarts
## The Meshy wheelbarrows and hand cart (assets/tools/meshy_carts/<cart id>.glb). Each file is one static mesh (the two barrows also carry a generic auto-rig that is not used). The wheel is found as the
## separate pieces of the mesh that sit inside the wheel's cylinder, split out into its own node so it can turn, and the rest becomes the "Body" that tips about the axle.
## Result: the node layout QuarryCart already knows (Body at the axle, Wheel / Wheel_L / Wheel_R with a "radius" meta), facing -Z with the wheel in front, handles toward +Z (the hand cart's pull bar toward -Z).
## `wheel`: the wheel's axle in the file's own units (x along the cart, y up) plus its radius and the z range(s) of its disc; `scale` brings it to game size; `load`: pile position / size relative to the axle.

const SPEC := {
	"wheelbarrow": {"scale": 0.55, "axle": Vector2(-0.918, 0.405), "radius": 0.425, "zr": [Vector2(-0.215, 0.215)], "load": Vector3(0, 0.30, 0.31), "load_size": Vector3(0.6, 0.3, 0.7)},
	"reinforced_wheelbarrow": {"scale": 0.52, "axle": Vector2(-1.085, 0.519), "radius": 0.535, "zr": [Vector2(-0.175, 0.175)], "load": Vector3(0, 0.30, 0.41), "load_size": Vector3(0.66, 0.3, 0.75)},
	"hand_cart": {"scale": 1.7, "axle": Vector2(0.306, -0.017), "radius": 0.172, "zr": [Vector2(0.18, 0.25), Vector2(-0.25, -0.18)], "load": Vector3(0, 0.1, -0.1), "load_size": Vector3(0.55, 0.2, 0.75)},
}
const PATH := "res://assets/tools/meshy_carts/%s.glb"
static var _cache := {}                                   ## id -> {body: ArrayMesh, wheels: [ArrayMesh per z range]}

static func available(id: String) -> bool:
	return SPEC.has(id) and ResourceLoader.exists(PATH % id)

## The cart as a node tree, or null when the file is missing or no wheel could be found.
static func build(id: String) -> Node3D:
	if not available(id):
		return null
	if not _cache.has(id):
		_cache[id] = _split(id)
	var parts: Dictionary = _cache[id]
	if parts.is_empty():
		return null
	var sp: Dictionary = SPEC[id]
	var s: float = sp["scale"]
	var ax: Vector2 = sp["axle"]
	var root := Node3D.new()
	root.name = "Meshy_" + id
	# file space (x along the cart, wheel toward -x; z across) -> game space (wheel toward -Z): turned -90 degrees about Y, scaled; the wheel's axle ends up at (0, ax.y * s, ax.x * s)
	var turn := Basis(Vector3.UP, -PI * 0.5) * Basis.from_scale(Vector3.ONE * s)
	var axle_game := Vector3(0.0, ax.y * s, ax.x * s)
	var body := Node3D.new()
	body.name = "Body"
	body.position = axle_game
	root.add_child(body)
	var bm := MeshInstance3D.new()
	bm.mesh = parts["body"]
	bm.transform = Transform3D(turn, Vector3.ZERO) * Transform3D.IDENTITY
	bm.position = -axle_game
	body.add_child(bm)
	body.set_meta("load_local", sp["load"])
	body.set_meta("load_size", sp["load_size"])
	var wheels: Array = parts["wheels"]
	for i in wheels.size():
		var w := Node3D.new()
		w.name = "Wheel" if wheels.size() == 1 else ("Wheel_L" if i == 0 else "Wheel_R")
		w.position = axle_game
		w.set_meta("radius", float(sp["radius"]) * s)
		root.add_child(w)
		var wm := MeshInstance3D.new()
		wm.mesh = wheels[i]
		wm.transform = Transform3D(turn, Vector3.ZERO)
		wm.position = -axle_game
		w.add_child(wm)
	return root

## Splits the file's mesh: connected pieces (welded vertices) that lie entirely inside a wheel's cylinder become that wheel, everything else the body.
static func _split(id: String) -> Dictionary:
	var sc := load(PATH % id) as PackedScene
	if sc == null:
		return {}
	var inst := sc.instantiate()
	var mi: MeshInstance3D = null
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh is ArrayMesh:
			mi = m
			break
	if mi == null:
		inst.free()
		return {}
	var mesh := mi.mesh as ArrayMesh
	var arr := mesh.surface_get_arrays(0)
	var mat := mesh.surface_get_material(0)
	inst.free()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var par := PackedInt32Array()
	par.resize(verts.size())
	for i in verts.size():
		par[i] = i
	var seen := {}
	for i in verts.size():
		var key := Vector3i((verts[i] * 2000.0).round())
		if seen.has(key):
			par[_find(par, i)] = _find(par, int(seen[key]))
		else:
			seen[key] = i
	for t in range(0, idx.size(), 3):
		par[_find(par, idx[t])] = _find(par, idx[t + 1])
		par[_find(par, idx[t + 1])] = _find(par, idx[t + 2])
	var lo := {}
	var hi := {}
	for t in range(0, idx.size(), 3):
		var r := _find(par, idx[t])
		for k in 3:
			var p := verts[idx[t + k]]
			lo[r] = Vector3(minf(lo[r].x, p.x), minf(lo[r].y, p.y), minf(lo[r].z, p.z)) if lo.has(r) else p
			hi[r] = Vector3(maxf(hi[r].x, p.x), maxf(hi[r].y, p.y), maxf(hi[r].z, p.z)) if hi.has(r) else p
	var sp: Dictionary = SPEC[id]
	var ax: Vector2 = sp["axle"]
	var rad: float = sp["radius"]
	var zr: Array = sp["zr"]
	var group := {}                                          # component root -> wheel index
	for r in lo:
		var a: Vector3 = lo[r]
		var b: Vector3 = hi[r]
		for wi in zr.size():
			var z: Vector2 = zr[wi]
			if a.z >= z.x - 0.004 and b.z <= z.y + 0.004 and a.x >= ax.x - rad and b.x <= ax.x + rad and a.y >= ax.y - rad and b.y <= ax.y + rad:
				group[r] = wi
	if group.is_empty():
		return {}
	var parts_idx: Array = []
	for i in zr.size() + 1:
		parts_idx.append(PackedInt32Array())
	for t in range(0, idx.size(), 3):
		var g: int = int(group.get(_find(par, idx[t]), zr.size()))
		parts_idx[g].append(idx[t])
		parts_idx[g].append(idx[t + 1])
		parts_idx[g].append(idx[t + 2])
	var made := []
	for i in parts_idx.size():
		var a2 := arr.duplicate()
		a2[Mesh.ARRAY_INDEX] = parts_idx[i]
		a2[Mesh.ARRAY_BONES] = null
		a2[Mesh.ARRAY_WEIGHTS] = null
		var nm := ArrayMesh.new()
		nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		nm.surface_set_material(0, mat)
		made.append(nm)
	return {"body": made[zr.size()], "wheels": made.slice(0, zr.size())}

static func _find(par: PackedInt32Array, x: int) -> int:
	while par[x] != x:
		par[x] = par[par[x]]
		x = par[x]
	return x
