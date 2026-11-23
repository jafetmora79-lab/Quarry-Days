extends Node3D
class_name FPHands
## The first-person hands: ONE shared rig for every tool. Two hands, each with a forearm (sleeve, bare wrist, cuff), a wrist, a palm, four fingers of three bones and a thumb of two.
## The TOOL decides where they go: each tool lists grips (a point on its shaft, the shaft's axis and radius, a preset) and the rig wraps the fingers round that shaft analytically
## (each bone is a chord of the circle round the shaft, so the fingers touch the wood and never pass through it), puts the palm against the shaft on the side the arm comes from,
## the thumb across the front, and points the forearm at the screen-edge anchor with the wrist bend limited to a believable angle.
## Everything is computed in the tool pivot's space every frame, so the hands follow the tool through every swing; the grip presets hold the finger curl and spacing.
##
## A grip: {hand "R"/"L", at: Vector3 (model space), axis: Vector3 (model space, toward the working end), r: shaft radius (m, model space), preset: String, slide: along-shaft travel (m)}

const SKIN := Color(0.80, 0.62, 0.48)
const GLOVE := Color(0.2, 0.21, 0.25)
const SLEEVE := Color(0.27, 0.30, 0.33)
const BAND := Color(0.86, 0.86, 0.78)
const PALM_W := 0.088                    ## across the knuckles (along the shaft)
const FINGER_R := 0.0122
const BONES := [0.042, 0.028, 0.022]     ## proximal, middle, distal
const THUMB := [0.044, 0.034]
const WRIST_BEND_MAX := 1.15
const UPPER := 0.42                     ## upper arm and forearm lengths (a little long: the stylised arms reach the tool at the end of a swing)
const FORE := 0.40             ## rad: how far the forearm may bend away from the palm's line

## Grip presets: spacing between fingers along the shaft, how far round each finger goes (1 = every bone follows the shaft), thumb position and wrap, palm standoff.
## "two_hand_shaft" long wooden shafts; "striking" pickaxes and hammers (a tighter, fuller grip); "one_hand_hammer"; "bucket_handle" a thin wire bail; "powered" pistol and T handles;
## "precision" a chisel held between thumb and fingers; "placement" a staff carried loosely.
const PRESETS := {
	"two_hand_shaft": {"space": 0.021, "curl": 1.0, "thumb_z": 0.04, "thumb_wrap": 1.0, "stand": 0.0, "start": 38.0},
	"striking": {"space": 0.0205, "curl": 1.0, "thumb_z": 0.045, "thumb_wrap": 1.0, "stand": -0.001, "start": 34.0},
	"one_hand_hammer": {"space": 0.0205, "curl": 1.0, "thumb_z": 0.043, "thumb_wrap": 1.0, "stand": -0.001, "start": 34.0},
	"bucket_handle": {"space": 0.0215, "curl": 1.0, "thumb_z": 0.04, "thumb_wrap": 0.8, "stand": 0.002, "start": 30.0},
	"powered": {"space": 0.022, "curl": 0.92, "thumb_z": 0.05, "thumb_wrap": 0.9, "stand": 0.004, "start": 36.0},
	"precision": {"space": 0.016, "curl": 0.7, "thumb_z": 0.03, "thumb_wrap": 1.0, "stand": 0.0, "start": 40.0},
	"placement": {"space": 0.021, "curl": 0.85, "thumb_z": 0.04, "thumb_wrap": 0.9, "stand": 0.004, "start": 40.0},
}

static var _cyl: CylinderMesh
static var _taper: CylinderMesh
static var _m_skin: StandardMaterial3D
static var _m_glove: StandardMaterial3D
static var _m_sleeve: StandardMaterial3D
static var _m_band: StandardMaterial3D

static var model_arms := true            ## true = no hands are drawn in first person (the tool moves on its own); the rig still works out where hands would close (tests, grips)
var hands := {}                          ## "R" / "L" -> {root, palm, back, fingers: [[seg nodes]], knuckles, thumb: [seg nodes], cuff, wrist, sleeve, active}

static func _shared() -> void:
	if _cyl != null:
		return
	_cyl = CylinderMesh.new()
	_cyl.top_radius = 1.0
	_cyl.bottom_radius = 1.0
	_cyl.height = 1.0
	_cyl.radial_segments = 6
	_cyl.rings = 1
	_taper = CylinderMesh.new()
	_taper.top_radius = 0.6
	_taper.bottom_radius = 1.0
	_taper.height = 1.0
	_taper.radial_segments = 8
	_taper.rings = 1
	_m_skin = MeshKit.flat(SKIN)
	_m_glove = MeshKit.flat(GLOVE)
	_m_sleeve = MeshKit.flat(SLEEVE)
	_m_band = MeshKit.flat(BAND)

func _ready() -> void:
	name = "FPHands"
	_shared()
	for side in ["R", "L"]:
		hands[side] = _make_hand()
	visible = true

func _mi(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.layers = 0 if model_arms else 1
	parent.add_child(m)
	return m

## Shows or hides the procedural hand meshes (they are the fallback when the real arms cannot be built).
func set_visuals(on: bool) -> void:
	model_arms = not on
	for m in find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).layers = 1 if on else 0

func _make_hand() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var h := {"root": root, "active": false}
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	h["palm"] = _mi(root, box, _m_glove)
	h["back"] = _mi(root, box, _m_glove)
	var fingers := []
	var knuckles := []
	for f in 4:
		var segs := []
		for b in 3:
			segs.append(_mi(root, _cyl, _m_glove if b < 2 else _m_skin))
		fingers.append(segs)
		knuckles.append(_mi(root, _cyl, _m_glove))
	h["fingers"] = fingers
	h["knuckles"] = knuckles
	h["thumb"] = [_mi(root, _cyl, _m_glove), _mi(root, _cyl, _m_skin)]
	h["cuff"] = _mi(root, _cyl, _m_glove)
	h["wrist"] = _mi(root, _cyl, _m_skin)
	h["band"] = _mi(root, _cyl, _m_band)
	h["sleeve"] = _mi(root, _taper, _m_sleeve)
	h["upper"] = _mi(root, _cyl, _m_sleeve)
	return h

## Places a unit cylinder node as a segment from a to b with radius r.
static func seg(n: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		n.visible = false
		return
	n.visible = true
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	n.transform = Transform3D(Basis(x * r, y * l, z * r), (a + b) * 0.5)

func hide_all() -> void:
	for k in hands:
		hands[k]["root"].visible = false
		hands[k]["active"] = false

## Poses the hands for this frame. `grips` are model-space grips (see above); `model_xf` the tool model's transform in the pivot's space; `anchors` {"R": Vector3, "L": Vector3}: where each
## forearm comes from (pivot space); `toward_cam` the direction from the tool to the camera (pivot space); `tight` 0..1 squeezes the fists (a blow lands); `slide` {"R": m, "L": m} extra travel along the shaft.
func pose(grips: Array, model_xf: Transform3D, anchors: Dictionary, toward_cam: Vector3, tight: float, slide: Dictionary) -> void:
	var used := {}
	for g in grips:
		var side: String = g["hand"]
		if used.has(side) or not hands.has(side):
			continue
		used[side] = true
		var h: Dictionary = hands[side]
		h["root"].visible = true
		h["active"] = true
		var gx: Transform3D = g.get("xf", model_xf)
		var gg: Dictionary = g.duplicate()
		if g.has("side"):
			gg["side"] = (gx.basis * (g["side"] as Vector3)).normalized()
		var a: Vector3 = (gx.basis * (g["axis"] as Vector3)).normalized()
		var sc := gx.basis.get_scale().x
		var along := (g["axis"] as Vector3).normalized() * float(slide.get(side, 0.0)) * float(g.get("slide", 0.0))
		var c: Vector3 = gx * ((g["at"] as Vector3) + along)
		var r: float = float(g.get("r", 0.02)) * sc
		_place(h, c, a, r, anchors[side], anchors["pole_" + side], anchors.get("cam_o", Vector3.ZERO), anchors.get("cam_back", Vector3.ZERO), toward_cam, PRESETS.get(str(g.get("preset", "two_hand_shaft")), PRESETS["two_hand_shaft"]), tight, side == "R", gg)
	for side in hands:
		if not used.has(side):
			hands[side]["root"].visible = false
			hands[side]["active"] = false

func _place(h: Dictionary, c: Vector3, a: Vector3, r: float, anchor: Vector3, pole_dir: Vector3, cam_o: Vector3, cam_back: Vector3, toward_cam: Vector3, pre: Dictionary, tight: float, right: bool, g: Dictionary) -> void:
	# the circle round the shaft: e0 toward the arm (the palm side), e1 round the rear of the shaft (away from the camera)
	var to_arm := anchor - c
	var e0 := (to_arm - a * to_arm.dot(a))
	if e0.length() < 0.05:
		e0 = Vector3.RIGHT - a * a.dot(Vector3.RIGHT)
	if g.has("side") and (g["side"] as Vector3).length() > 0.1:
		e0 = (g["side"] as Vector3)
		e0 = e0 - a * e0.dot(a)
	e0 = e0.normalized()
	var e1 := a.cross(e0).normalized()
	if e1.dot(-toward_cam) < 0.0:
		e1 = -e1                                                  # the fingers go round the back of the shaft
	var R := r + FINGER_R + float(pre["stand"]) - 0.003 * tight
	var space: float = pre["space"]
	var start := deg_to_rad(float(pre["start"]))
	var curl: float = pre["curl"]
	var knuckle_pts := []
	for i in 4:
		var z := (1.5 - float(i)) * space * (1.0 if g.get("flip_fingers", false) == false else -1.0)
		var th := start
		var prev := c + a * z + (e0 * cos(th) + e1 * sin(th)) * R
		var segs: Array = h["fingers"][i]
		knuckle_pts.append(prev)
		var rad := FINGER_R * (1.0 - 0.06 * i)
		for b in 3:
			var d_th: float = BONES[b] * (1.0 - 0.06 * i) / R * curl
			th += d_th
			var nxt := c + a * z + (e0 * cos(th) + e1 * sin(th)) * R
			seg(segs[b], prev, nxt, rad * (1.0 - 0.1 * b))
			prev = nxt
		var k: MeshInstance3D = h["knuckles"][i]
		seg(k, knuckle_pts[i] - a * 0.0, knuckle_pts[i] + e0 * 0.012, FINGER_R * 1.25)
	# the thumb: from the palm's front edge across the front of the shaft
	var tz := float(pre["thumb_z"])
	var tth := -deg_to_rad(float(pre["start"]))
	var tprev := c + a * tz + (e0 * cos(tth) + e1 * sin(tth)) * (R + 0.002)
	var tw: float = pre["thumb_wrap"]
	for b in 2:
		tth -= THUMB[b] / R * tw
		var tn := c + a * (tz - 0.004 * (b + 1)) + (e0 * cos(tth) + e1 * sin(tth)) * (R + 0.002)
		seg(h["thumb"][b], tprev, tn, FINGER_R * (1.25 - 0.2 * b))
		tprev = tn
	# the palm lies against the shaft on the arm's side; the back of the hand outside it
	var pc := c + e0 * (r + 0.016)
	h["palm"].transform = Transform3D(Basis(a * PALM_W, e0 * 0.026, e1 * 0.062), pc + e1 * 0.004)
	h["back"].transform = Transform3D(Basis(a * PALM_W * 0.9, e0 * 0.016, e1 * 0.05), pc + e0 * 0.016 + e1 * 0.004)
	h["solve"] = {"pc": pc, "e0": e0, "e1": e1, "a": a, "r": r, "pre": pre, "tight": tight}
	# wrist and arm: a two-bone arm from the wrist back to the shoulder (anchor), the elbow bent out and down; the wrist bend away from the palm's line is limited
	var shoulder: Vector3 = anchor
	var wrist := pc + e0 * 0.05
	var to_sh := shoulder - wrist
	var dist := to_sh.length()
	var dir_s := to_sh / maxf(dist, 0.001)
	var ang := acos(clampf(dir_s.dot(e0), -1.0, 1.0))
	var wd := dir_s                                                   # the direction the forearm leaves the wrist
	var l1 := maxf(0.30, dist * 0.55)                                    # the arm is as long as the reach needs (stylised): a gentle bend, the elbow never swings toward the camera
	var l2 := l1
	var elbow := wrist
	var pole: Vector3 = pole_dir
	if dist >= l1 + l2 - 0.002:
		elbow = wrist + dir_s * l2                                       # out of reach: the arm is straight (the forearm stretches a little)
	else:
		var x := (l2 * l2 - l1 * l1 + dist * dist) / (2.0 * dist)          # distance from the wrist along the line to the shoulder
		var hgt := sqrt(maxf(0.0, l2 * l2 - x * x))
		var side := (pole - dir_s * pole.dot(dir_s))
		side = side.normalized() if side.length() > 0.01 else Vector3.DOWN
		elbow = wrist + dir_s * x + side * hgt
		wd = (elbow - wrist).normalized()
	ang = acos(clampf(wd.dot(e0), -1.0, 1.0))
	if ang > WRIST_BEND_MAX:                                              # not more than a believable bend at the wrist
		var axis_b := e0.cross(wd)
		if axis_b.length() > 0.001:
			wd = e0.rotated(axis_b.normalized(), WRIST_BEND_MAX)
			elbow = wrist + wd * (elbow - wrist).length()
	if cam_back != Vector3.ZERO:                                           # the elbow never comes nearer than 28 cm in front of the camera
		var zc := (elbow - cam_o).dot(cam_back)
		if zc > -0.28:
			elbow -= cam_back * (zc + 0.28)
			wd = (elbow - wrist).normalized()
	seg(h["cuff"], wrist - e0 * 0.02, wrist + wd * 0.045, 0.038)
	seg(h["wrist"], wrist + wd * 0.04, wrist + wd * 0.11, 0.031)
	seg(h["band"], wrist + wd * 0.095, wrist + wd * 0.12, 0.04)
	_taper_seg(h["sleeve"], elbow, wrist + wd * 0.11, 0.034)              # forearm: wide at the elbow, narrow at the wrist
	var up_end := shoulder                                                   # the shoulder anchor is below the screen edge: nothing ends in view or passes the camera
	seg(h["upper"], up_end, elbow, 0.034)

## A tapered sleeve from `far` (wide end) to `near` (narrow end).
static func _taper_seg(n: MeshInstance3D, far: Vector3, near: Vector3, r: float) -> void:
	var dd := far - near
	var l := dd.length()
	if l < 0.001:
		n.visible = false
		return
	n.visible = true
	var yv := (near - far).normalized()
	var xv := yv.cross(Vector3.FORWARD if absf(yv.z) < 0.9 else Vector3.RIGHT).normalized()
	var zv := xv.cross(yv)
	n.transform = Transform3D(Basis(xv * r, yv * l, zv * r), (far + near) * 0.5)
