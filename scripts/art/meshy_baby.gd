extends RefCounted
class_name MeshyBaby
## The baby ankylosaur (assets/world/WLD_QD_dino_baby.glb): Meshy made it as one static mesh, so it is rigged here, at load time: a skeleton with the
## same bone names as the big Meshy dinosaur (so QuarryCompanion drives both the same way), skin weights worked out from where each vertex sits
## (legs by corner, the tail in five links, neck and head), and a generated walk clip (diagonal legs swing, the body bobs).
## The file's dinosaur faces +Z with the tail toward -Z, 0.253 long, feet on y = 0.

const PATH := "res://assets/world/WLD_QD_dino_baby.glb"
const CLIP := "walk"
const LENGTH := 0.667                      ## the walk clip's length (one gait cycle), like the big one's

const LEG_TOP := 0.046                     ## the hip height; below it the legs take over from the body
const HIP_X := 0.036
const FRONT_Z := 0.055
const REAR_Z := -0.045
const TAIL_FROM := -0.06                   ## the tail starts behind this z and runs to the tip
const TAIL_TO := -0.127
const NECK_FROM := 0.075
const HEAD_FROM := 0.1

## bone name -> [parent, rest position (file space)]
const BONES := [
	["root", "", Vector3(0, 0.06, 0)],
	["chest", "root", Vector3(0, 0.06, 0.03)],
	["hips", "root", Vector3(0, 0.06, -0.03)],
	["rearLeg.L_01", "hips", Vector3(HIP_X, LEG_TOP, REAR_Z)],
	["rearLeg.R_01", "hips", Vector3(-HIP_X, LEG_TOP, REAR_Z)],
	["frontUpr.L", "chest", Vector3(HIP_X, LEG_TOP, FRONT_Z)],
	["frontUpr.R", "chest", Vector3(-HIP_X, LEG_TOP, FRONT_Z)],
	["tail1", "hips", Vector3(0, 0.07, -0.06)],
	["tail2", "tail1", Vector3(0, 0.07, -0.077)],
	["tail3", "tail2", Vector3(0, 0.068, -0.094)],
	["tail4", "tail3", Vector3(0, 0.065, -0.11)],
	["tail_05", "tail4", Vector3(0, 0.064, -0.122)],
	["neck1", "chest", Vector3(0, 0.07, 0.07)],
	["neck2", "neck1", Vector3(0, 0.07, 0.088)],
	["head", "neck2", Vector3(0, 0.07, 0.102)],
]
const TAIL_BONES := ["tail1", "tail2", "tail3", "tail4", "tail_05"]

static func available() -> bool:
	return ResourceLoader.exists(PATH)

## A Node3D holding the skinned mesh, its Skeleton3D and an AnimationPlayer with the "walk" clip; null when the file is missing or unreadable.
static func build() -> Node3D:
	if not available():
		return null
	var src := (load(PATH) as PackedScene).instantiate() as Node3D
	var mi: MeshInstance3D = null
	for m in src.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh is ArrayMesh:
			mi = m
			break
	if mi == null:
		src.free()
		return null
	var t := Transform3D()
	var cur: Node = mi
	while cur != null and cur != src and cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	var mesh := mi.mesh as ArrayMesh
	var arr := mesh.surface_get_arrays(0)
	var mat := mesh.surface_get_material(0)
	src.free()
	var root := Node3D.new()
	root.name = "dino_baby"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	root.add_child(skel)
	var index := {}
	for b in BONES:
		var i := skel.get_bone_count()
		skel.add_bone(str(b[0]))
		index[str(b[0])] = i
		var pos: Vector3 = b[2]
		if str(b[1]) != "":
			var pi: int = index[str(b[1])]
			skel.set_bone_parent(i, pi)
			pos -= _rest_pos(str(b[1]))
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, pos))
	skel.reset_bone_poses()
	var skin := Skin.new()
	for i in skel.get_bone_count():
		skin.add_bind(i, skel.get_bone_global_rest(i).affine_inverse())
	# skin weights
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	var nv := PackedVector3Array()
	nv.resize(verts.size())
	for v in verts.size():
		var p := t * verts[v]
		nv[v] = p
		var w := _weights(p)
		var k := 0
		for name in w:
			if k >= 4:
				break
			bones[v * 4 + k] = int(index[name])
			weights[v * 4 + k] = float(w[name])
			k += 1
		while k < 4:
			bones[v * 4 + k] = 0
			weights[v * 4 + k] = 0.0
			k += 1
	var a2 := arr.duplicate()
	a2[Mesh.ARRAY_VERTEX] = nv
	if norms.size() == verts.size():
		var nn := PackedVector3Array()
		nn.resize(norms.size())
		for v in norms.size():
			nn[v] = (t.basis * norms[v]).normalized()
		a2[Mesh.ARRAY_NORMAL] = nn
	a2[Mesh.ARRAY_TANGENT] = null
	a2[Mesh.ARRAY_BONES] = bones
	a2[Mesh.ARRAY_WEIGHTS] = weights
	var nm := ArrayMesh.new()
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
	nm.surface_set_material(0, mat)
	var node := MeshInstance3D.new()
	node.name = "Body"
	node.mesh = nm
	node.skin = skin
	root.add_child(node)
	node.skeleton = node.get_path_to(skel)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation(CLIP, _clip(skel))
	ap.add_animation_library("", lib)
	return root

static func _rest_pos(name: String) -> Vector3:
	for b in BONES:
		if str(b[0]) == name:
			return b[2]
	return Vector3.ZERO

static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## {bone name: weight} for a vertex at p (file space, after the mesh's own transform); the weights add up to 1.
static func _weights(p: Vector3) -> Dictionary:
	var out := {}
	var rest := 1.0
	# neck and head (front)
	var hw := _smooth(HEAD_FROM - 0.012, HEAD_FROM + 0.012, p.z)
	var nw := _smooth(NECK_FROM - 0.012, NECK_FROM + 0.012, p.z) - hw
	if hw > 0.0:
		out["head"] = hw
	if nw > 0.0:
		out["neck2"] = nw * 0.5
		out["neck1"] = nw * 0.5
	rest -= hw + nw
	# tail: five links
	var tw := _smooth(TAIL_FROM + 0.012, TAIL_FROM - 0.012, p.z) * minf(1.0, rest)
	if tw > 0.0:
		var u := clampf((TAIL_FROM - p.z) / (TAIL_FROM - TAIL_TO), 0.0, 0.999) * 4.0
		var k := int(floor(u))
		var f := u - float(k)
		out[TAIL_BONES[k]] = out.get(TAIL_BONES[k], 0.0) + tw * (1.0 - f)
		out[TAIL_BONES[k + 1]] = out.get(TAIL_BONES[k + 1], 0.0) + tw * f
		rest -= tw
	# legs: the lower part away from the middle belongs to the leg at its corner
	var lw := _smooth(LEG_TOP + 0.006, LEG_TOP - 0.012, p.y) * _smooth(0.012, 0.03, absf(p.x)) * maxf(rest, 0.0)
	if lw > 0.0:
		var side := "L" if p.x > 0.0 else "R"
		var leg: String = ("frontUpr." + side) if p.z > (FRONT_Z + REAR_Z) * 0.5 else ("rearLeg." + side + "_01")
		out[leg] = lw
		rest -= lw
	if rest > 0.0001:
		out["chest" if p.z > 0.0 else "hips"] = rest
	return out

## One gait cycle: the legs swing in diagonal pairs about the hip, the whole body bobs twice and rolls a little.
static func _clip(skel: Skeleton3D) -> Animation:
	var a := Animation.new()
	a.length = LENGTH
	a.loop_mode = Animation.LOOP_LINEAR
	var steps := 8
	var legs := {"frontUpr.L": 0.0, "rearLeg.R_01": 0.0, "frontUpr.R": PI, "rearLeg.L_01": PI}
	var path := "Skeleton3D"
	for name in legs:
		var ti := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(ti, NodePath("%s:%s" % [path, name]))
		for s in steps + 1:
			var ph := float(s) / float(steps) * TAU + float(legs[name])
			a.rotation_track_insert_key(ti, LENGTH * float(s) / float(steps), Quaternion(Vector3.RIGHT, sin(ph) * 0.5))
	var ri := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(ri, NodePath("%s:root" % path))
	var root_rest := skel.get_bone_rest(skel.find_bone("root")).origin
	for s in steps + 1:
		var ph := float(s) / float(steps) * TAU
		a.position_track_insert_key(ri, LENGTH * float(s) / float(steps), root_rest + Vector3(0, absf(sin(ph)) * 0.006, 0))
	return a
