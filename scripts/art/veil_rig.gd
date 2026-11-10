extends RefCounted
class_name VeilRig
## Procedural body animation for THE VEIL humanoid rig (adapted from THE VEIL's game/npc/npc_animator.gd).
## Every motion is defined in skeleton space (up, the character's real forward measured from foot -> toes,
## right) and converted into each bone's local frame, so no bone-axis convention is assumed.
## States: idle, walk (speed-driven cycle), carry, and one work loop per quarry profession.

var skel: Skeleton3D
var F := Vector3(0, 0, 1)
var U := Vector3.UP
var R := Vector3.RIGHT
var _b := {}
var _rest := {}
var _pinv := {}
var _prest := {}
var _phase := 0.0
var _t := 0.0
var _walk := 0.0
var _work := 0.0
var _carry := 0.0
var _seed := 0.0
var _hip_h := 0.95

func setup(skeleton: Skeleton3D, seed := 0.0) -> void:
	skel = skeleton
	_seed = seed
	for i in skel.get_bone_count():
		_b[skel.get_bone_name(i)] = i
	if bone("LeftToes") >= 0 and bone("LeftFoot") >= 0:
		var f := (_gp("LeftToes").origin - _gp("LeftFoot").origin) + (_gp("RightToes").origin - _gp("RightFoot").origin)
		f.y = 0.0
		if f.length() > 0.001:
			F = f.normalized()
	R = F.cross(U).normalized()
	_build_rest()
	if bone("Hips") >= 0:
		_hip_h = skel.get_bone_global_rest(bone("Hips")).origin.y

func bone(n: String) -> int:
	return _b.get(n, -1)

func _gp(n: String) -> Transform3D:
	return skel.get_bone_global_pose(bone(n))

func _dir(a: String, b: String) -> Vector3:
	return (_gp(b).origin - _gp(a).origin).normalized()

func _apply_global(i: int, q: Quaternion) -> void:
	var p := skel.get_bone_parent(i)
	var pb := skel.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
	var lb := Basis(skel.get_bone_pose_rotation(i))
	skel.set_bone_pose_rotation(i, (pb.inverse() * Basis(q) * pb * lb).get_rotation_quaternion())

## Arms brought down from the A-pose to the sides with a small elbow bend (THE VEIL rest pose).
func _build_rest() -> void:
	for side in ["Left", "Right"]:
		var ua := bone(side + "UpperArm")
		var la := bone(side + "LowerArm")
		if ua < 0 or la < 0:
			continue
		var out := signf(_gp(side + "UpperArm").origin.dot(R))
		if out == 0.0:
			out = -1.0 if side == "Left" else 1.0
		var want := (-U * cos(deg_to_rad(9.0)) + R * out * sin(deg_to_rad(9.0)) + F * 0.04).normalized()
		_apply_global(ua, Quaternion(_dir(side + "UpperArm", side + "LowerArm"), want))
		var want2 := (-U * cos(deg_to_rad(12.0)) + F * sin(deg_to_rad(12.0)) + R * out * 0.03).normalized()
		_apply_global(la, Quaternion(_dir(side + "LowerArm", side + "Hand"), want2))
	for i in skel.get_bone_count():
		_rest[i] = Basis(skel.get_bone_pose_rotation(i))
		var p := skel.get_bone_parent(i)
		var pb := skel.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
		_prest[i] = pb
		_pinv[i] = pb.inverse()

func _q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))

func _pose_bone(n: String, q: Quaternion) -> void:
	var i := bone(n)
	if i < 0:
		return
	skel.set_bone_pose_rotation(i, (_pinv[i] * Basis(q) * _prest[i] * _rest[i]).get_rotation_quaternion())

## state: "idle" | "walk" | "work"; work_kind: profession; speed in m/s; carrying = holding a load.
func pose(delta: float, state: String, speed: float, work_kind: String, carrying: bool) -> void:
	_t += delta
	_walk = move_toward(_walk, 1.0 if state == "walk" else 0.0, delta * 5.0)
	_work = move_toward(_work, 1.0 if state == "work" else 0.0, delta * 4.0)
	_carry = move_toward(_carry, 1.0 if carrying and state != "work" else 0.0, delta * 4.0)
	if state == "walk":
		_phase += delta * clampf(speed, 0.6, 4.0) * 3.6
	var t := _t + _seed
	var w := _walk
	var ph := _phase
	var br := sin(t * TAU * 0.28)
	var sway := sin(t * 0.37) * (1.0 - w)
	# work loops (0..1 cycle) -----------------------------------------------------------------
	var arm := {"lu": 0.0, "lf": 0.0, "ru": 0.0, "rf": 0.0, "lo": 0.0, "ro": 0.0}
	var lean := 0.0
	var knee := 0.0
	var k := _work
	match work_kind:
		"miner":
			var c := fposmod(t * 0.95, 1.0)
			var raise := smoothstep(0.0, 0.55, c) * (1.0 - smoothstep(0.72, 0.86, c))
			var a := lerpf(38.0, 158.0, raise)
			arm["ru"] = a
			arm["lu"] = a - 6.0
			arm["rf"] = 25.0 + 30.0 * raise
			arm["lf"] = 35.0 + 30.0 * raise
			arm["lo"] = 14.0
			lean = lerpf(16.0, -4.0, raise)
			knee = 10.0
		"operator":
			var c := sin(t * 2.6)
			arm["ru"] = 50.0 + c * 6.0
			arm["lu"] = 44.0 - c * 6.0
			arm["rf"] = 55.0 + c * 10.0
			arm["lf"] = 60.0 - c * 8.0
			lean = 8.0
		"hauler":
			var c := 0.5 + 0.5 * sin(t * 2.4)
			arm["ru"] = 55.0 + 20.0 * c
			arm["lu"] = 55.0 + 20.0 * c
			arm["rf"] = 30.0
			arm["lf"] = 30.0
			lean = 22.0 + 20.0 * c
			knee = 18.0 * c
		"clerk":
			arm["lu"] = 38.0
			arm["lf"] = 78.0
			arm["ru"] = 34.0 + sin(t * 3.0) * 4.0
			arm["rf"] = 86.0 + sin(t * 11.0) * 6.0
			arm["ro"] = -8.0
			lean = 4.0
	# carrying a load in front (miner / hauler between pick-up and delivery)
	var cu := 52.0 * _carry
	var cf := 64.0 * _carry
	# torso ---------------------------------------------------------------------------------
	_pose_bone("Hips", _q(F, sway * 1.4) * _q(U, sin(ph) * 4.0 * w))
	_pose_bone("Spine", _q(R, -br * 0.7 - lean * k * 0.5) * _q(U, -sin(ph) * 2.5 * w))
	_pose_bone("Chest", _q(R, -br * 1.4 - lean * k * 0.35 - 3.0 * _carry))
	_pose_bone("UpperChest", _q(R, -br * 0.8 - lean * k * 0.15) * _q(U, -sin(ph) * 3.0 * w))
	_pose_bone("Neck", _q(R, lean * k * 0.25))
	_pose_bone("Head", _q(R, lean * k * 0.25 + sin(t * 0.5) * 2.0 * (1.0 - k)) * _q(U, sin(t * 0.23 + _seed) * 6.0 * (1.0 - w) * (1.0 - k)))
	# arms -----------------------------------------------------------------------------------
	for side in ["Left", "Right"]:
		var out := -1.0 if side == "Left" else 1.0
		var opp := -1.0 if side == "Left" else 1.0
		var s := "l" if side == "Left" else "r"
		var swing := sin(ph) * opp * 22.0 * w * (1.0 - _carry)
		var idle := sin(t * 0.9 + out) * 1.5 * (1.0 - w)
		var up: float = lerpf(swing + idle + cu, float(arm[s + "u"]), k)
		var fore: float = lerpf(4.0 * w + maxf(swing, 0.0) * 0.6 + cf, float(arm[s + "f"]), k)
		_pose_bone(side + "UpperArm", _q(R, up) * _q(F, -out * (float(arm[s + "o"]) * k + 6.0 * _carry)))
		_pose_bone(side + "LowerArm", _q(R, fore))
	# legs -----------------------------------------------------------------------------------
	for side in ["Left", "Right"]:
		var sg := 1.0 if side == "Left" else -1.0
		var c := sin(ph) * sg
		_pose_bone(side + "UpperLeg", _q(R, c * 24.0 * w + knee * k))
		_pose_bone(side + "LowerLeg", _q(R, -maxf(-cos(ph) * sg, 0.0) * 38.0 * w - maxf(c, 0.0) * 8.0 * w - knee * k * 1.6))
		_pose_bone(side + "Foot", _q(R, -c * 10.0 * w + knee * k * 0.6))
	skel.position.y = absf(sin(ph)) * 0.025 * w - knee * k * 0.003

## Attach `node` to a hand so that in the rest pose it has `rest_basis` in skeleton space
## (independent of the bone's own axes). Uses the reference rig's hand socket when present.
func attach(node: Node3D, side: String, rest_basis: Basis, offset: Vector3) -> BoneAttachment3D:
	var name := "Socket_%sHand" % side
	var bi := bone(name)
	if bi < 0:
		name = side + "Hand"
		bi = bone(name)
	if bi < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = name
	skel.add_child(ba)
	var rest := skel.get_bone_global_rest(bi)
	node.transform = Transform3D(rest.basis.orthonormalized().inverse() * rest_basis, rest.basis.orthonormalized().inverse() * offset)
	ba.add_child(node)
	return ba
