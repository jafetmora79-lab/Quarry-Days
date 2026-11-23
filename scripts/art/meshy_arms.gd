extends Node3D
class_name MeshyArms
## The protagonist's real arms in first person: an arms-only copy of the Meshy character (only the triangles skinned to the arm, forearm, hand and finger bones), on its own copy
## of the skeleton, hung under the camera. FPHands still works out where every hand closes round the tool (FPTools); this node then aims the model's arm bones at those points with a
## two-bone solver (the shoulders sit where the real ones would: below and beside the eyes) and curls the hand round the shaft. The old procedural hands are only kept as the targets.

const MODEL := "res://assets/characters/CHR_QD_Player.glb"
const ARM_SCALE := 1.3                                   ## the arms are a little longer than life so every grip is within reach
const SHOULDER_MID := Vector3(0.0, -0.27, 0.12)          ## between the shoulders, camera space (behind and below the eyes: the shoulder seam never shows)
const HAND_LEN := 0.095                                  ## wrist to the first finger joint, model units
const CURL := [62.0, 78.0, 52.0]                         ## fist: proximal, middle, distal finger joint (degrees), scaled by the grip preset
const HAND_FLEX := 6.0                                   ## degrees the whole hand folds toward the palm in a full grip (the fingers do the rest)
const TWIST_SHARE := 0.8                                 ## how much of the hand's roll the forearm takes
const THUMB_CURL := [18.0, 24.0, 16.0]

var skel: Skeleton3D
var body: Node3D
var _ok := false
var _ids := {}                                           ## "Right" / "Left" -> {arm, fore, hand, mid: [3], thumb: [3]}
var last_reach := {}                                     ## side -> how far (m) the wrist ended from where the grip wanted it, for tests and tuning

func build() -> bool:
	var ps := load(MODEL) as PackedScene
	if ps == null:
		return false
	body = ps.instantiate()
	VeilRig.face_forward(body)
	add_child(body)
	var found := body.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	skel = found[0]
	for side in ["Right", "Left"]:
		var p: String = "mixamorig_" + side
		var d := {"arm": skel.find_bone(p + "Arm"), "fore": skel.find_bone(p + "ForeArm"), "hand": skel.find_bone(p + "Hand"), "mid": [], "thumb": [], "fingers": []}
		for i in 3:
			d["mid"].append(skel.find_bone(p + "HandMiddle%d" % (i + 1)))
			d["thumb"].append(skel.find_bone(p + "HandThumb%d" % (i + 1)))
		for fn in ["Index", "Middle", "Ring", "Pinky"]:
			var chain := []
			for i in 3:
				chain.append(skel.find_bone(p + "Hand%s%d" % [fn, i + 1]))
			d["fingers"].append(chain)
		for k in ["arm", "fore", "hand"]:
			if int(d[k]) < 0:
				return false
		_ids[side] = d
	if not _keep_arms_only():
		return false
	body.transform = Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3.ONE * ARM_SCALE), Vector3.ZERO)
	skel.reset_bone_poses()
	var mid := (skel.get_bone_global_rest(_ids["Right"]["arm"]).origin + skel.get_bone_global_rest(_ids["Left"]["arm"]).origin) * 0.5
	body.position = SHOULDER_MID - body.transform * (skel.transform * mid)
	for gi in body.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ap in body.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free()
	visible = false
	_ok = true
	return true

## Replaces the body mesh by one with only the triangles whose three corners are (mostly) weighted to the arms: the sleeves, gloves and fingers, nothing of the torso.
func _keep_arms_only() -> bool:
	var mi: MeshInstance3D = null
	for m in body.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh is ArrayMesh and (m as MeshInstance3D).skin != null:
			mi = m
			break
	if mi == null:
		return false
	var skin := mi.skin
	var in_arm := {}                                      # skeleton bone -> true for every bone below an arm bone
	for side in _ids:
		var q := [int(_ids[side]["arm"])]
		while not q.is_empty():
			var b: int = q.pop_back()
			in_arm[b] = true
			for c in skel.get_bone_children(b):
				q.append(c)
	var mesh := mi.mesh as ArrayMesh
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var per := bones.size() / maxi(1, verts.size())
	var bind_arm := {}
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = skel.find_bone(skin.get_bind_name(i))
		bind_arm[i] = in_arm.has(b)
	var arm_w := PackedFloat32Array()
	arm_w.resize(verts.size())
	for v in verts.size():
		var s := 0.0
		for k in per:
			if bind_arm.get(bones[v * per + k], false):
				s += weights[v * per + k]
		arm_w[v] = s
	var keep := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if arm_w[idx[t]] > 0.5 and arm_w[idx[t + 1]] > 0.5 and arm_w[idx[t + 2]] > 0.5:
			keep.append(idx[t])
			keep.append(idx[t + 1])
			keep.append(idx[t + 2])
	if keep.is_empty():
		return false
	arr[Mesh.ARRAY_INDEX] = keep
	var flags: int = 134217728 if per == 8 else 0         # ARRAY_FLAG_USE_8_BONE_INFLUENCES
	var nm := ArrayMesh.new()
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	nm.surface_set_material(0, mesh.surface_get_material(0))
	mi.mesh = nm
	return true

func _set_global_basis(b: int, gb: Basis) -> void:
	var p := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(p).basis if p >= 0 else Basis()
	skel.set_bone_pose_rotation(b, (pb.inverse() * gb).orthonormalized().get_rotation_quaternion())

## One frame: aim both arms at the grips FPHands worked out. Hidden when neither hand is on a tool.
func update(hands: FPHands, want: bool) -> void:
	if not _ok:
		return
	skel.reset_bone_poses()
	var any := false
	for key in ["R", "L"]:
		var side := "Right" if key == "R" else "Left"
		var h: Dictionary = hands.hands[key]
		if bool(h.get("active", false)) and h.has("solve") and want:
			any = true
			_solve(side, h["solve"], hands, key == "R")
		else:
			skel.set_bone_pose_scale(int(_ids[side]["arm"]), Vector3.ONE * 0.001)
	visible = any

func _solve(side: String, s: Dictionary, hands: FPHands, right: bool) -> void:
	var d: Dictionary = _ids[side]
	var inv := skel.global_transform.affine_inverse()
	var gx := hands.global_transform
	var pc: Vector3 = inv * (gx * (s["pc"] as Vector3))
	var e0: Vector3 = (inv.basis * (gx.basis * (s["e0"] as Vector3))).normalized()
	var e1: Vector3 = (inv.basis * (gx.basis * (s["e1"] as Vector3))).normalized()
	# the hand: fingers go round the shaft along e1, the palm faces the shaft (-e0)
	var f_w := e1
	var n_w := (-e0 - f_w * (-e0).dot(f_w)).normalized()
	var x_w := f_w.cross(n_w)
	var rest_hand := skel.get_bone_global_rest(d["hand"])
	var f_r := (skel.get_bone_global_rest(d["mid"][0]).origin - rest_hand.origin).normalized() if int(d["mid"][0]) >= 0 else Vector3.DOWN
	var inward := Vector3(-1.0 if rest_hand.origin.x > 0.0 else 1.0, 0, 0)          # in the A-pose the palms face the body
	var n_r := (inward - f_r * inward.dot(f_r)).normalized()
	var x_r := f_r.cross(n_r)
	var pre: Dictionary = s.get("pre", {})
	var k := clampf(float(pre.get("curl", 1.0)) * (1.15 - float(s.get("r", 0.02)) * 9.0), 0.45, 1.1) * (1.0 + 0.1 * float(s.get("tight", 0.0)))
	# a little fold of the whole hand under the finger curl
	var flex := Basis(x_w, deg_to_rad(HAND_FLEX * k))
	var delta := flex * Basis(f_w, n_w, x_w) * Basis(f_r, n_r, x_r).inverse()
	var target := pc - (flex * f_w) * HAND_LEN * 0.7
	# two-bone solve from the real shoulder to the wrist
	var sh := skel.get_bone_global_rest(d["arm"]).origin
	var el0 := skel.get_bone_global_rest(d["fore"]).origin
	var l1 := sh.distance_to(el0)
	var l2 := el0.distance_to(rest_hand.origin)
	var to_t := target - sh
	var dist := clampf(to_t.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.004)
	var dir := to_t.normalized()
	var wrist := sh + dir * dist
	var pole_cam := Vector3(0.55 if right else -0.55, -1.0, 0.15)
	var pole: Vector3 = (inv.basis * (global_transform.basis * pole_cam)).normalized()
	var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var hgt := sqrt(maxf(0.0, l1 * l1 - x * x))
	var side_v := pole - dir * pole.dot(dir)
	side_v = side_v.normalized() if side_v.length() > 0.01 else Vector3.DOWN
	var elbow := sh + dir * x + side_v * hgt
	var rest_arm := skel.get_bone_global_rest(d["arm"])
	var rest_fore := skel.get_bone_global_rest(d["fore"])
	_set_global_basis(d["arm"], Basis(_from_to((el0 - sh).normalized(), (elbow - sh).normalized())) * rest_arm.basis)
	var fore_gb := Basis(_from_to((rest_hand.origin - el0).normalized(), (wrist - elbow).normalized())) * rest_fore.basis
	var hand_gb := delta * rest_hand.basis
	# the forearm takes most of the hand's roll about its own axis, so the wrist is not wrung like a cloth
	var ax_l := (rest_fore.basis.inverse() * (rest_hand.origin - el0)).normalized()
	var rel := (fore_gb.inverse() * hand_gb).get_rotation_quaternion()
	var twist := 2.0 * atan2(Vector3(rel.x, rel.y, rel.z).dot(ax_l), rel.w)
	if twist > PI:
		twist -= TAU
	elif twist < -PI:
		twist += TAU
	_set_global_basis(d["fore"], fore_gb * Basis(ax_l, twist * TWIST_SHARE))
	_set_global_basis(d["hand"], hand_gb)
	last_reach[side] = (to_t.length() - dist) * ARM_SCALE
	# the fingers wrap round the shaft: every joint turns about the knuckle line, toward the palm
	var cum := 0.0
	for chain in d["fingers"]:
		cum = 0.0
		for i in 3:
			var b: int = chain[i]
			if b < 0:
				break
			cum += deg_to_rad(CURL[i] * k)
			_set_global_basis(b, Basis(x_w, cum) * delta * skel.get_bone_global_rest(b).basis)
	cum = 0.0
	for i in 3:
		var b: int = d["thumb"][i]
		if b < 0:
			break
		cum += deg_to_rad(THUMB_CURL[i] * k)
		_set_global_basis(b, Basis(x_w, cum) * delta * skel.get_bone_global_rest(b).basis)

static func _from_to(a: Vector3, b: Vector3) -> Quaternion:
	var dt := a.dot(b)
	if dt > 0.99999:
		return Quaternion.IDENTITY
	if dt < -0.99999:
		var ax := a.cross(Vector3.RIGHT)
		if ax.length() < 0.001:
			ax = a.cross(Vector3.UP)
		return Quaternion(ax.normalized(), PI)
	return Quaternion(a.cross(b).normalized(), acos(clampf(dt, -1.0, 1.0)))
