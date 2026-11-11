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
	if bone("LeftUpperLeg") >= 0 and bone("LeftLowerLeg") >= 0 and bone("LeftFoot") >= 0:
		_leg = 0.5 * (skel.get_bone_global_rest(bone("LeftUpperLeg")).origin.distance_to(skel.get_bone_global_rest(bone("LeftLowerLeg")).origin)
			+ skel.get_bone_global_rest(bone("LeftLowerLeg")).origin.distance_to(skel.get_bone_global_rest(bone("LeftFoot")).origin))

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

## Phase 5 animation states (all blended, nothing snaps):
##   idle, walk, turn (stepping in place), rest (arms folded, off shift), carry (load held in front),
##   work (profession action driven by `phase` 0..1 of the real task timer), pickup, unload,
##   interact (operator at the controls), monitor (operator watching a running machine),
##   paperwork (clerk between sales).
## `phase` comes from the worker's actual task timer, so the visible strike / lift / hand-over happens
## exactly when the gameplay action completes (phase 1.0).
var _cur := {}
var _turn := 0.0
var _turn_phase := 0.0
var _leg := 0.45

func _target(state: String, kind: String, p: float, t: float) -> Dictionary:
	var g := {"lu": 0.0, "lf": 0.0, "ru": 0.0, "rf": 0.0, "lo": 0.0, "ro": 0.0, "lean": 0.0, "knee": 0.0, "twist": 0.0, "head": 0.0, "w": 0.0}
	match state:
		"work":
			g["w"] = 1.0
			match kind:
				"miner":
					# wind-up over 70% of the strike timer, fast swing down, head of the pick meets the rock at 1.0
					var raise := smoothstep(0.0, 0.7, p) if p < 0.7 else 1.0 - pow((p - 0.7) / 0.3, 2.0)
					var a := lerpf(32.0, 162.0, raise)
					g["ru"] = a
					g["lu"] = a - 8.0
					g["rf"] = lerpf(18.0, 50.0, raise)
					g["lf"] = lerpf(26.0, 58.0, raise)
					g["lo"] = 14.0
					g["lean"] = lerpf(24.0, -6.0, raise)
					g["knee"] = lerpf(16.0, 6.0, raise)
					g["head"] = 10.0
				"hauler":
					var c := sin(p * PI)
					g["ru"] = 55.0 + 20.0 * c
					g["lu"] = 55.0 + 20.0 * c
					g["rf"] = 30.0
					g["lf"] = 30.0
					g["lean"] = 22.0 + 20.0 * c
					g["knee"] = 18.0 * c
				"clerk":
					# hand the goods / change across the counter, then back to the clipboard
					var h := sin(clampf(p, 0.0, 1.0) * PI)
					g["lu"] = 38.0
					g["lf"] = 78.0
					g["ru"] = lerpf(34.0, 78.0, h)
					g["rf"] = lerpf(86.0, 12.0, h)
					g["lean"] = 4.0 + 8.0 * h
					g["head"] = 6.0
				_:
					g["ru"] = 55.0
					g["lu"] = 55.0
					g["rf"] = 60.0
					g["lf"] = 60.0
					g["lean"] = 8.0
		"pickup":
			var c := sin(clampf(p, 0.0, 1.0) * PI)
			g["w"] = 1.0
			g["knee"] = 58.0 * c
			g["lean"] = 34.0 * c
			g["ru"] = 30.0 + 35.0 * c
			g["lu"] = 30.0 + 35.0 * c
			g["rf"] = 10.0
			g["lf"] = 10.0
			g["head"] = 14.0 * c
		"unload":
			var c := sin(clampf(p, 0.0, 1.0) * PI)
			g["w"] = 1.0
			g["knee"] = 30.0 * c
			g["lean"] = 26.0 * c
			g["ru"] = 52.0 + 10.0 * c
			g["lu"] = 52.0 + 10.0 * c
			g["rf"] = 64.0 - 40.0 * c
			g["lf"] = 64.0 - 40.0 * c
		"interact":
			# both hands on the control panel; the right hand pulls the start lever mid-way
			var pull := smoothstep(0.35, 0.6, p) * (1.0 - smoothstep(0.75, 0.95, p))
			g["w"] = 1.0
			g["lu"] = 58.0
			g["lf"] = 62.0
			g["ru"] = lerpf(64.0, 38.0, pull)
			g["rf"] = lerpf(58.0, 82.0, pull)
			g["lean"] = 10.0 + 4.0 * pull
			g["head"] = 8.0
		"monitor":
			g["w"] = 1.0
			g["lu"] = 14.0
			g["ru"] = 14.0
			g["lf"] = 92.0
			g["rf"] = 92.0
			g["lo"] = 28.0
			g["ro"] = 28.0
			g["lean"] = 3.0
			g["head"] = 4.0 + sin(t * 0.7) * 3.0
			g["twist"] = sin(t * 0.35) * 10.0
		"paperwork":
			g["w"] = 1.0
			g["lu"] = 38.0
			g["lf"] = 80.0
			g["ru"] = 34.0 + sin(t * 3.0) * 3.0
			g["rf"] = 88.0 + sin(t * 9.0) * 5.0
			g["ro"] = -8.0
			g["lean"] = 5.0
			g["head"] = 16.0
		"rest":
			g["w"] = 1.0
			g["lu"] = 30.0
			g["ru"] = 34.0
			g["lf"] = 112.0
			g["rf"] = 108.0
			g["lo"] = -18.0
			g["ro"] = -18.0
			g["lean"] = -3.0
			g["head"] = -4.0 + sin(t * 0.21) * 4.0
			g["twist"] = sin(t * 0.13) * 8.0
	return g

func pose(delta: float, state: String, speed: float, work_kind: String, carrying: bool, phase := -1.0) -> void:
	_t += delta
	var moving := state == "walk"
	_walk = move_toward(_walk, 1.0 if moving else 0.0, delta * 4.0)
	_turn = move_toward(_turn, 1.0 if state == "turn" else 0.0, delta * 6.0)
	_carry = move_toward(_carry, 1.0 if carrying and state in ["walk", "idle", "turn"] else 0.0, delta * 4.0)
	if moving:
		# stride matched to ground speed (about 0.73 m per step) so feet do not slide
		_phase += delta * clampf(speed, 0.0, 4.0) * 4.3
	if state == "turn":
		_turn_phase += delta * 7.0
	var t := _t + _seed
	var w := _walk
	var ph := _phase
	var br := sin(t * TAU * 0.28)
	var sway := sin(t * 0.37) * (1.0 - w)
	var p := phase if phase >= 0.0 else fposmod(t * 0.9, 1.0)
	var tgt := _target(state, work_kind, p, t)
	# exponential smoothing toward the action's target pose (transitions never snap)
	var rate := 22.0 if state == "work" and work_kind == "miner" else 12.0
	var f := 1.0 - exp(-rate * delta)
	if _cur.is_empty():
		_cur = tgt.duplicate()
	for key in tgt:
		_cur[key] = lerpf(float(_cur.get(key, 0.0)), float(tgt[key]), f)
	var k: float = _cur["w"]
	var lean: float = _cur["lean"]
	var knee: float = _cur["knee"]
	var cu := 52.0 * _carry
	var cf := 64.0 * _carry
	# torso ---------------------------------------------------------------------------------
	_pose_bone("Hips", _q(F, sway * 1.4) * _q(U, sin(ph) * 4.0 * w + float(_cur["twist"]) * 0.3))
	_pose_bone("Spine", _q(R, -br * 0.7 - lean * 0.5) * _q(U, -sin(ph) * 2.5 * w))
	_pose_bone("Chest", _q(R, -br * 1.4 - lean * 0.35 - 3.0 * _carry))
	_pose_bone("UpperChest", _q(R, -br * 0.8 - lean * 0.15) * _q(U, -sin(ph) * 3.0 * w + float(_cur["twist"]) * 0.4))
	_pose_bone("Neck", _q(R, lean * 0.25))
	_pose_bone("Head", _q(R, lean * 0.1 + float(_cur["head"]) + sin(t * 0.5) * 2.0 * (1.0 - k)) * _q(U, sin(t * 0.23 + _seed) * 6.0 * (1.0 - w) * (1.0 - k) + float(_cur["twist"]) * 0.3))
	# arms -----------------------------------------------------------------------------------
	for side in ["Left", "Right"]:
		var out := -1.0 if side == "Left" else 1.0
		var opp := -1.0 if side == "Left" else 1.0
		var s := "l" if side == "Left" else "r"
		var swing := sin(ph) * opp * 22.0 * w * (1.0 - _carry)
		var idle := sin(t * 0.9 + out) * 1.5 * (1.0 - w)
		var up: float = lerpf(swing + idle + cu, float(_cur[s + "u"]), k)
		var fore: float = lerpf(4.0 * w + maxf(swing, 0.0) * 0.6 + cf, float(_cur[s + "f"]), k)
		_pose_bone(side + "UpperArm", _q(R, up) * _q(F, -out * (float(_cur[s + "o"]) * k + 6.0 * _carry)))
		_pose_bone(side + "LowerArm", _q(R, fore))
	# legs: walk cycle, stepping turn, and a crouch that keeps both feet planted -------------
	var a := knee
	for side in ["Left", "Right"]:
		var sg := 1.0 if side == "Left" else -1.0
		var c := sin(ph) * sg
		var step := maxf(0.0, sin(_turn_phase) * sg) * 18.0 * _turn
		_pose_bone(side + "UpperLeg", _q(R, c * 24.0 * w + a + step))
		_pose_bone(side + "LowerLeg", _q(R, -maxf(-cos(ph) * sg, 0.0) * 38.0 * w - maxf(c, 0.0) * 8.0 * w - a * 1.6 - step * 1.6))
		_pose_bone(side + "Foot", _q(R, -c * 10.0 * w + a * 0.6 + step * 0.6))
	# hips drop by exactly what the bent legs lose in height (thigh rotated a, shin at -0.6a)
	var drop := _leg * (1.0 - cos(deg_to_rad(a))) + _leg * (1.0 - cos(deg_to_rad(0.6 * a)))
	skel.position.y = absf(sin(ph)) * 0.025 * w - drop

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
