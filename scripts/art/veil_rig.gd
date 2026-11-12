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

## Phase 1 animation overhaul state.
const PALM := 0.075                          ## wrist (hand bone origin) to palm centre, along the hand bone's +Y
const STANCE := 0.58                         ## fraction of a leg cycle spent on the ground
const MS := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))   ## sagittal mirror (left bones are exact mirrors of right bones)
var tools: Array = []                        ## held tools, see add_tool()
var carry_node: Node3D                       ## the load carried in both arms (child of the skeleton, set by the worker)
var _l1 := 0.27
var _l2 := 0.23
var _uc0 := Basis.IDENTITY                   ## UpperChest orientation right after the arms were lowered
var _arm: Array = []                         ## bone ids of both arms: upper, lower, hand
var _qfk: Array = []
var _qcur: Array = []
var _qres: Array = []
var _swing_w := 0.0
var _reach_w := 0.0
var _rebound := 1.0
var _last_p := 0.0
var _swing_p := 0.0                          ## last swing phase (held while the swing blends out)
var _yr := 0.0
var _step_len := 0.8
var _was_work := false
var swing_pitch := 0.0                       ## current pickaxe pitch (deg), for tests

func setup(skeleton: Skeleton3D, seed := 0.0) -> void:
	skel = skeleton
	skel.force_update_all_bone_transforms()
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
	for side in ["Right", "Left"]:
		for b in ["UpperArm", "LowerArm", "Hand"]:
			_arm.append(bone(side + b))
	if bone("RightLowerArm") >= 0 and bone("RightHand") >= 0:
		_l1 = _gp("RightUpperArm").origin.distance_to(_gp("RightLowerArm").origin)
		_l2 = _gp("RightLowerArm").origin.distance_to(_gp("RightHand").origin)
	if bone("UpperChest") >= 0:
		_uc0 = _gp("UpperChest").basis.orthonormalized()
	_qfk.resize(_arm.size())
	_qcur.resize(_arm.size())
	_qres.resize(_arm.size())
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
					g["twist"] = lerpf(-5.0, 12.0, raise)     # shoulders wind back with the draw, follow through into the strike
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

## Rig components (right, up, forward) to a skeleton-space vector.
func _v(c: Vector3) -> Vector3:
	return R * c.x + U * c.y + F * c.z

## Orthonormal basis whose +Z is `z` and whose +Y is as close to `yh` as possible (X = Y x Z).
static func basis_zy(z: Vector3, yh: Vector3) -> Basis:
	var zz := z.normalized()
	var xx := yh.cross(zz)
	if xx.length() < 0.001:
		xx = Vector3.RIGHT.cross(zz)
	xx = xx.normalized()
	return Basis(xx, zz.cross(xx), zz)

func _hand_xf(side: String) -> Transform3D:
	var t := _gp(side + "Hand")
	return Transform3D(t.basis.orthonormalized(), t.origin)

## UpperChest origin and how far the chest has turned since setup (lean, twist): swing and carry targets live in this
## frame, so the work follows the torso.
func _chest_frame() -> Transform3D:
	var t := _gp("UpperChest")
	return Transform3D(t.basis.orthonormalized() * _uc0.inverse(), t.origin)

# ------------------------------------------------------------------ tools

## Attaches a hand tool. The grip is derived from the LOWERED arm pose (the pose the rig actually animates from), not
## from the imported A-pose, and is stored hand-locally, so the tool stays rigidly in the palm in every state.
## cfg: hand ("Right"/"Left"), gp (point of the tool that sits in the palm, tool space), dir/up (rig components: the
## tool's +Z and +Y at the relaxed rest hold), support (optional second grip point, tool space), stow ({pos, dir, up}
## relative to the UpperChest, rig components; optional).
func add_tool(node: Node3D, cfg: Dictionary) -> Dictionary:
	var side: String = cfg.get("hand", "Right")
	if bone(side + "Hand") < 0:
		return {}
	var hx := _hand_xf(side)
	var b0 := basis_zy(_v(cfg.get("dir", Vector3(0, 0, 1))), _v(cfg.get("up", Vector3(0, 1, 0))))
	var gp: Vector3 = cfg.get("gp", Vector3.ZERO)
	var palm := hx.origin + hx.basis.y * PALM
	var tool_xf := Transform3D(b0, palm - b0 * gp)
	var tl := {"node": node, "hand": side, "gp": gp, "support": cfg.get("support", Vector3.INF), "grip": hx.affine_inverse() * tool_xf,
		"held": 1.0, "want": true, "name": str(cfg.get("name", node.name))}
	if cfg.has("stow"):
		var st: Dictionary = cfg["stow"]
		var sb := basis_zy(_v(st["dir"]), _v(st.get("up", Vector3(0, 1, 0))))
		tl["stow"] = Transform3D(sb, _v(st["pos"]))
	skel.add_child(node)
	node.transform = tool_xf
	tools.append(tl)
	return tl

func set_tool_held(tool_name: String, want: bool) -> void:
	for tl in tools:
		if tl["name"] == tool_name:
			tl["want"] = want

## 0..1 how much of a hand's grip is currently on a tool (damps the arm swing of that hand).
func hold_amount(side: String) -> float:
	var m := 0.0
	for tl in tools:
		if tl["hand"] == side:
			m = maxf(m, smoothstep(0.0, 1.0, float(tl["held"])))
	return m

func tool_named(tool_name: String) -> Dictionary:
	for tl in tools:
		if tl["name"] == tool_name:
			return tl
	return {}

func _update_tools(delta: float) -> void:
	if tools.is_empty():
		return
	var cf := _chest_frame()
	for tl in tools:
		tl["held"] = move_toward(float(tl["held"]), 1.0 if tl["want"] else 0.0, delta * 2.5)
		var held_xf: Transform3D = _hand_xf(tl["hand"]) * (tl["grip"] as Transform3D)
		var h := smoothstep(0.0, 1.0, float(tl["held"]))
		if h < 0.999 and tl.has("stow"):
			(tl["node"] as Node3D).transform = (cf * (tl["stow"] as Transform3D)).interpolate_with(held_xf, h)
		else:
			(tl["node"] as Node3D).transform = held_xf

# ------------------------------------------------------------------ lightweight two-bone arm IK

static func _from_to(a: Vector3, b: Vector3) -> Quaternion:
	var d := a.dot(b)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		var axis := a.cross(Vector3.UP)
		if axis.length() < 0.01:
			axis = a.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(a, b)

## Moves a wrist to `target` (skeleton space) with the elbow bending toward `pole`; optionally turns the hand to `bd`.
func _solve_arm(side: String, target: Vector3, pole: Vector3, bd: Basis, orient: bool) -> void:
	var ua := bone(side + "UpperArm")
	var la := bone(side + "LowerArm")
	var hn := bone(side + "Hand")
	if ua < 0 or la < 0 or hn < 0:
		return
	var sh := skel.get_bone_global_pose(ua).origin
	var d := target - sh
	var dist := clampf(d.length(), 0.08, (_l1 + _l2) * 0.995)
	var dir := d.normalized()
	var cosa := clampf((_l1 * _l1 + dist * dist - _l2 * _l2) / (2.0 * _l1 * dist), -1.0, 1.0)
	var sina := sqrt(1.0 - cosa * cosa)
	var pp := pole - dir * pole.dot(dir)
	pp = pp.normalized() if pp.length() > 0.001 else U.cross(dir).normalized()
	var elbow := sh + dir * (cosa * _l1) + pp * (sina * _l1)
	var cur := (skel.get_bone_global_pose(la).origin - sh).normalized()
	_apply_global(ua, _from_to(cur, (elbow - sh).normalized()))
	var e2 := skel.get_bone_global_pose(la).origin
	var cur2 := (skel.get_bone_global_pose(hn).origin - e2).normalized()
	_apply_global(la, _from_to(cur2, (sh + dir * dist - e2).normalized()))
	if orient:
		var hb := skel.get_bone_global_pose(hn).basis.orthonormalized()
		_apply_global(hn, (bd * hb.inverse()).get_rotation_quaternion())

func _save_arms(into: Array) -> void:
	for k in range(_arm.size()):
		into[k] = skel.get_bone_pose_rotation(_arm[k]) if _arm[k] >= 0 else Quaternion.IDENTITY

func _load_arms(from: Array) -> void:
	for k in range(_arm.size()):
		if _arm[k] >= 0:
			skel.set_bone_pose_rotation(_arm[k], from[k])

## Skeleton-space transform of the pickaxe for a swing state: `ang` = (tool pitch, hand arc) in degrees, in the chest
## frame. Both palms sit on the shaft (gp and support), centred on a point on an arc in front of the chest.
func swing_tool_xf(tl: Dictionary, ang: Vector2, cf: Transform3D) -> Transform3D:
	var th := deg_to_rad(ang.x)
	var al := deg_to_rad(ang.y)
	var dirl := F * cos(th) + U * sin(th)
	var perp := U * cos(th) - F * sin(th)
	var mid := U * 0.06 + (F * cos(al) + U * sin(al)) * 0.34
	var tb := cf.basis * basis_zy(dirl, perp)
	var gp: Vector3 = tl["gp"]
	var sup: Vector3 = tl["support"]
	var half := (sup - gp).z * 0.5
	var palm_r := cf.origin + cf.basis * (mid - dirl * half)
	return Transform3D(tb, palm_r - tb * gp)

func _swing_arms(tl: Dictionary, txf: Transform3D, cf: Transform3D) -> void:
	var xr := txf * (tl["grip"] as Transform3D).affine_inverse()
	_solve_arm("Right", xr.origin, cf.basis * _v(Vector3(0.5, -0.8, -0.3)), xr.basis, true)
	var n := txf.basis.x
	var mn := Basis(Vector3(1, 0, 0) - 2.0 * n * n.x, Vector3(0, 1, 0) - 2.0 * n * n.y, Vector3(0, 0, 1) - 2.0 * n * n.z)
	var bl := mn * xr.basis * MS
	var palm_l := txf * (tl["support"] as Vector3)
	_solve_arm("Left", palm_l - bl.y * PALM, cf.basis * _v(Vector3(-0.5, -0.8, -0.3)), bl, true)

## (pitch, arc) of the swing for action phase p: recovery spring, anticipation, draw-back, strike (impact at p = 1).
func swing_angles(p: float) -> Vector2:
	var rd := Vector2(45.0, -20.0)
	var wd := Vector2(106.0, 58.0)
	var dr := Vector2(116.0, 63.0)
	var ht := Vector2(-50.0, -30.0)
	if p < 0.2:
		var u := p / 0.2
		var out := rd.lerp(ht, _rebound).lerp(rd, 1.0 - pow(1.0 - u, 3.0))
		out.x += sin(u * PI) * 7.0 * _rebound
		return out
	if p < 0.62:
		return rd.lerp(wd, smoothstep(0.0, 1.0, (p - 0.2) / 0.42))
	if p < 0.74:
		return wd.lerp(dr, (p - 0.62) / 0.12)
	return dr.lerp(ht, pow(clampf((p - 0.74) / 0.26, 0.0, 1.0), 2.0))

func carry_center(state: String, p: float, cf: Transform3D) -> Vector3:
	var c := sin(clampf(p, 0.0, 1.0) * PI) if state == "unload" else 0.0
	return cf.origin + cf.basis * _v(Vector3(0.0, -0.20 - 0.14 * c, 0.30 + 0.22 * c))

func _carry_arms(cen: Vector3, cf: Transform3D) -> void:
	var half := cf.basis * _v(Vector3(0.235, 0.0, 0.0))
	_solve_arm("Right", cen + half, cf.basis * _v(Vector3(0.7, -0.7, -0.2)), Basis.IDENTITY, false)
	_solve_arm("Left", cen - half, cf.basis * _v(Vector3(-0.7, -0.7, -0.2)), Basis.IDENTITY, false)

func _reach_arms(state: String, p: float) -> void:
	if state == "pickup":
		var g := _v(Vector3(0.16, 0.30, 0.58))
		_solve_arm("Right", g, _v(Vector3(0.7, -0.5, 0.0)), Basis.IDENTITY, false)
		_solve_arm("Left", g - _v(Vector3(0.32, 0.0, 0.0)), _v(Vector3(-0.7, -0.5, 0.0)), Basis.IDENTITY, false)
	else:
		# both hands on the machine's control panel in front of the chest; the right hand pulls the lever mid-way
		var pull := smoothstep(0.35, 0.6, p) * (1.0 - smoothstep(0.75, 0.95, p))
		var panel := _v(Vector3(0.0, 1.08, 0.50))
		_solve_arm("Right", panel + _v(Vector3(0.18, -0.13 * pull, -0.09 * pull)), _v(Vector3(0.7, -0.6, -0.1)), Basis.IDENTITY, false)
		_solve_arm("Left", panel - _v(Vector3(0.18, 0.0, 0.0)), _v(Vector3(-0.7, -0.6, -0.1)), Basis.IDENTITY, false)

## Leg cycle curves (x = 0..1 within one leg's cycle; 0 = heel strike). Thigh pitch is nearly linear through the
## stance, so the planted foot moves back at the ground speed instead of skating on a sine.
static func leg_curve(x: float, a: float) -> float:
	if x < STANCE:
		return a * (1.0 - 2.0 * x / STANCE)
	return -a + 2.0 * a * smoothstep(0.0, 1.0, (x - STANCE) / (1.0 - STANCE))

static func knee_curve(x: float) -> float:
	if x < STANCE:
		return 7.0 * sin(PI * x / STANCE)
	return 62.0 * pow(maxf(sin(PI * (x - STANCE) / (1.0 - STANCE)), 0.0), 1.15)

func pose(delta: float, state: String, speed: float, work_kind: String, carrying: bool, phase := -1.0, yaw_rate := 0.0) -> void:
	_t += delta
	var moving := state == "walk" and speed > 0.12
	_walk = move_toward(_walk, 1.0 if moving else 0.0, delta * 4.0)
	_turn = move_toward(_turn, 1.0 if state == "turn" else 0.0, delta * 6.0)
	_carry = move_toward(_carry, 1.0 if carrying and state in ["walk", "idle", "turn", "unload"] else 0.0, delta * 4.0)
	_yr = lerpf(_yr, clampf(yaw_rate, -4.0, 4.0), 1.0 - exp(-8.0 * delta))
	if moving:
		# stride grows with speed; a full cycle (two steps) covers 2 * step length of ground, so the planted foot keeps pace
		_step_len = lerpf(0.5, 0.9, clampf(speed / 2.5, 0.0, 1.0))
		_phase += delta * clampf(speed, 0.0, 4.0) * PI / _step_len
	if state == "turn":
		_turn_phase += delta * 7.0
	var t := _t + _seed
	var w := _walk
	var ph := _phase
	var cyc := cos(ph)
	var br := sin(t * TAU * 0.28)
	var p := phase if phase >= 0.0 else fposmod(t * 0.9, 1.0)
	var tgt := _target(state, work_kind, p, t)
	var f := 1.0 - exp(-(22.0 if state == "work" and work_kind == "miner" else 12.0) * delta)
	if _cur.is_empty():
		_cur = tgt.duplicate()
	for key in tgt:
		_cur[key] = lerpf(float(_cur.get(key, 0.0)), float(tgt[key]), f)
	var k: float = _cur["w"]
	var lean: float = _cur["lean"] + 3.0 * w * clampf(speed / 2.5, 0.0, 1.0) + 2.5 * _carry
	var knee: float = _cur["knee"]
	var cu := 20.0 * _carry
	var cf := 36.0 * _carry
	# torso ---------------------------------------------------------------------------------
	var pelvis_yaw := -cyc * 5.0 * w + float(_cur["twist"]) * 0.3
	var spine_yaw := cyc * 3.0 * w
	var chest_yaw := cyc * 2.5 * w + float(_cur["twist"]) * 0.4
	var roll := clampf(-_yr * 2.2, -6.0, 6.0) * w + sin(ph) * 1.8 * w + sin(t * 0.37) * 1.4 * (1.0 - w)
	_pose_bone("Hips", _q(F, roll) * _q(U, pelvis_yaw))
	_pose_bone("Spine", _q(R, -br * 0.7 - lean * 0.5) * _q(U, spine_yaw))
	_pose_bone("Chest", _q(R, -br * 1.4 - lean * 0.35 - 3.0 * _carry))
	_pose_bone("UpperChest", _q(R, -br * 0.8 - lean * 0.15) * _q(U, chest_yaw))
	_pose_bone("Neck", _q(R, lean * 0.25))
	# the head is stabilised against the torso turn, and looks into a turn a little ahead of the body
	var stab := -(pelvis_yaw + spine_yaw + chest_yaw - float(_cur["twist"]) * 0.7) * 0.9
	_pose_bone("Head", _q(R, lean * 0.1 + float(_cur["head"]) + sin(t * 0.5) * 2.0 * (1.0 - k)) * _q(U, stab + clampf(_yr * 7.0, -14.0, 14.0) * w + sin(t * 0.23 + _seed) * 6.0 * (1.0 - w) * (1.0 - k) + float(_cur["twist"]) * 0.3))
	# arms: relaxed swing, opposite to the legs, damped by what the hand holds ----------------
	var hold := {"Left": hold_amount("Left"), "Right": hold_amount("Right")}
	for side in ["Left", "Right"]:
		var out := -1.0 if side == "Left" else 1.0
		var s := "l" if side == "Left" else "r"
		var damp := (1.0 - _carry) * (1.0 - 0.7 * float(hold[side]))
		var swing := -cyc * out * 19.0 * w * damp                 # left arm forward when the right leg is
		var idle := sin(t * 0.9 + out) * 1.5 * (1.0 - w)
		var up: float = lerpf(swing + idle + cu, float(_cur[s + "u"]), k)
		var fore: float = lerpf(10.0 * w + maxf(swing, 0.0) * 0.7 + cf, float(_cur[s + "f"]), k)
		_pose_bone(side + "UpperArm", _q(R, up) * _q(F, -out * (float(_cur[s + "o"]) * k + 5.0 * _carry)))
		_pose_bone(side + "LowerArm", _q(R, fore))
	# legs: planted-foot walk cycle, stepping turn, and a crouch that keeps both feet planted --
	var a_amp := rad_to_deg(asin(clampf(STANCE * 2.0 * _step_len / (4.0 * _leg), 0.0, 0.9)))
	var xl := fposmod(ph / TAU, 1.0)
	var a := knee
	for side in ["Left", "Right"]:
		var sg := 1.0 if side == "Left" else -1.0
		var x := xl if side == "Left" else fposmod(xl + 0.5, 1.0)
		var th := leg_curve(x, a_amp) * w
		var kn := knee_curve(x) * w
		var step := maxf(0.0, sin(_turn_phase) * sg) * 18.0 * _turn
		var toe := 18.0 * smoothstep(0.45, STANCE, x) * (1.0 - smoothstep(STANCE, STANCE + 0.08, x)) * w
		_pose_bone(side + "UpperLeg", _q(R, th + a + step))
		_pose_bone(side + "LowerLeg", _q(R, -kn - a * 1.6 - step * 1.6))
		_pose_bone(side + "Foot", _q(R, -(th - kn) * 0.85 + a * 0.6 + step * 0.6 - toe))
	var drop := _leg * (1.0 - cos(deg_to_rad(a))) + _leg * (1.0 - cos(deg_to_rad(0.6 * a)))
	skel.position.y = 0.022 * cos(2.0 * (ph - 0.29 * TAU)) * w - drop
	# IK layers over the FK pose: pickaxe swing, load carried in both arms, hands on a control panel / the ground ----
	var cfm := _chest_frame()
	var pick := tool_named("pickaxe")
	var swinging := state == "work" and work_kind == "miner" and not pick.is_empty()
	_swing_w = move_toward(_swing_w, 1.0 if swinging else 0.0, delta * 7.0)
	var reach_on := state in ["interact"] or (state == "pickup" and work_kind == "hauler")
	var rt := clampf(sin(clampf(p, 0.0, 1.0) * PI) * 1.6, 0.0, 1.0) if state == "pickup" else 1.0
	_reach_w = move_toward(_reach_w, rt if reach_on else 0.0, delta * 6.0)
	if swinging:
		_swing_p = p
		if not _was_work:
			_rebound = 0.0                    # coming from walking: the first swing starts from the ready hold
		elif p < _last_p - 0.5:
			_rebound = 1.0                    # the last strike landed: the pick springs back before the next draw
		_last_p = p
	_was_work = swinging
	var ik_carry := _carry
	var any_ik := _swing_w > 0.001 or _reach_w > 0.001 or ik_carry > 0.001
	if carry_node:
		var ccen := carry_center(state, p, cfm)
		carry_node.transform = Transform3D(cfm.basis, ccen)
	if any_ik:
		_save_arms(_qfk)
		for k2 in range(_qfk.size()):
			_qcur[k2] = _qfk[k2]
		if ik_carry > 0.001:
			_carry_arms(carry_center(state, p, cfm), cfm)
			_save_arms(_qres)
			for k2 in range(_qres.size()):
				_qcur[k2] = (_qcur[k2] as Quaternion).slerp(_qres[k2], ik_carry)
			_load_arms(_qfk)
		if _reach_w > 0.001:
			_reach_arms(state, p)
			_save_arms(_qres)
			for k2 in range(_qres.size()):
				_qcur[k2] = (_qcur[k2] as Quaternion).slerp(_qres[k2], _reach_w)
			_load_arms(_qfk)
		if _swing_w > 0.001:
			var ang := swing_angles(clampf(_swing_p if not swinging else p, 0.0, 1.0))
			swing_pitch = ang.x
			_swing_arms(pick, swing_tool_xf(pick, ang, cfm), cfm)
			_save_arms(_qres)
			for k2 in range(_qres.size()):
				_qcur[k2] = (_qcur[k2] as Quaternion).slerp(_qres[k2], smoothstep(0.0, 1.0, _swing_w))
		_load_arms(_qcur)
	_update_tools(delta)
