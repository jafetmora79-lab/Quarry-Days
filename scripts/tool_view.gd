extends Node3D
class_name QuarryToolView
## First-person tool models (built with MeshKit in THE VEIL style) and their animation.
##  * Swing tools (hammer, pickaxes): wind-up -> fast strike -> recover. `swing()` calls `on_impact`
##    exactly when the head reaches the rock, so damage, sound and effects land on the visible hit.
##  * Power tools (drill, jackhammer): `operating` drives a continuous spin / hammer loop with vibration;
##    they ease in and out instead of snapping.
## Walking adds a gentle bob; equipping a new tool lowers the old one and raises the new one.

var tier := -1
var models := {}
var pivot: Node3D          # grip point the swing rotates around
var model: Node3D
var spinner: Node3D        # drill bit / jackhammer chisel
var phase := -1.0          # 0..1 while swinging, -1 idle
var duration := 0.5
var impact_done := true
var on_impact: Callable
var operating := false
var op_blend := 0.0
var equip_t := 1.0
var pending_tier := -1
var deflect_t := 0.0
var bob_t := 0.0
var moving := 0.0
var _t := 0.0

## Per-tool first-person pose. Camera space: -Z is forward, +X right, +Y up. Swing tools hold their handle along +Y
## from the grip; `rest`/`wind`/`strike` are pitch angles (rad) about the grip (negative = working end forward).
## `tip` is the working point in model space: the pick point, the hammer face, the bit or chisel end.
## Power tools use `rest_rot` (euler) to aim their working end at the crosshair, and `model_pitch` leans the whole model.
const TOOL := {
	0: {"grip": Vector3(0.30, -0.42, -0.55), "scale": 0.8, "rest": -0.75, "yaw": 0.2, "wind": 0.1, "strike": -1.35, "tip": Vector3(0, 0.36, -0.1)},
	1: {"grip": Vector3(0.30, -0.42, -0.55), "scale": 0.8, "rest": -0.75, "yaw": 0.2, "wind": 0.1, "strike": -1.35, "tip": Vector3(0, 0.48, -0.27)},
	2: {"grip": Vector3(0.30, -0.42, -0.55), "scale": 0.75, "rest": -0.75, "yaw": 0.2, "wind": 0.1, "strike": -1.35, "tip": Vector3(0, 0.52, -0.32)},
	3: {"grip": Vector3(0.28, -0.3, -0.5), "scale": 0.7, "rest_rot": Vector3(0.12, 0.2, 0.0), "tip": Vector3(0, 0.12, -0.46)},
	4: {"grip": Vector3(0.3, -0.12, -0.5), "scale": 0.7, "rest_rot": Vector3(0.0, 0.3, 0.0), "model_pitch": 0.8, "tip": Vector3(0, -0.61, 0)},
}
const REACH_MIN := 0.85      # the working end meets the rock this far in front of the camera, at least...
const REACH_MAX := 1.6       # ...and at most (mining reach in main.gd is just beyond this)
const MAX_CORRECTION := 0.55

var target_dist := 1.2       # distance to the rock under the crosshair (set by the game when engaged)
var tip_cam := Vector3.ZERO  # working end in camera space after the last update (for tests)
var engage := 0.0            # 0..1 how much the working end is pulled onto the crosshair point

func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)

func equip(t: int, instant := false) -> void:
	if t == tier and pending_tier < 0:
		return
	if instant or tier < 0:
		_show(t)
		equip_t = 1.0
		return
	pending_tier = t
	equip_t = 0.0

func _show(t: int) -> void:
	tier = t
	pending_tier = -1
	for k in models:
		models[k].visible = false
	if not models.has(t):
		models[t] = _build(t)
		pivot.add_child(models[t])
	model = models[t]
	model.scale = Vector3.ONE * float(TOOL[t].get("scale", 1.0))
	model.visible = true
	spinner = model.get_meta("spinner") if model.has_meta("spinner") else null
	phase = -1.0
	impact_done = true

func is_busy() -> bool:
	return phase >= 0.0

## Starts one swing lasting `d` seconds; `impact` fires at the strike moment.
func swing(d: float, impact: Callable) -> void:
	duration = maxf(0.2, d)
	phase = 0.0
	impact_done = false
	on_impact = impact

## Tool bounces off rock that is too hard.
func deflect() -> void:
	deflect_t = 0.3

func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if operating else 0.0
	op_blend = move_toward(op_blend, target, delta * (6.0 if operating else 3.0))
	if pending_tier >= 0:
		equip_t += delta * 3.2
		if equip_t >= 0.5 and pending_tier >= 0 and tier != pending_tier:
			_show(pending_tier)
			equip_t = 0.5
		elif equip_t >= 0.5:
			pending_tier = -1
	elif equip_t < 1.0:
		equip_t = minf(1.0, equip_t + delta * 3.2)
	var lower := sin(clampf(equip_t, 0.0, 1.0) * PI) * 0.45 # 0 -> dip -> 0
	bob_t += delta * (2.0 + 7.0 * moving)
	var bob := Vector3(cos(bob_t) * 0.012, absf(sin(bob_t)) * 0.016, 0) * (0.3 + moving)
	var def: Dictionary = TOOL.get(tier, TOOL[0])
	var base: Vector3 = def["grip"]
	var rot := Vector3.ZERO
	var off := Vector3.ZERO
	var rest: float = def.get("rest", 0.0)
	var weight := 0.0
	if tier < 3:
		rot.x = rest
		rot.y = float(def.get("yaw", 0.0))
		if phase >= 0.0:
			phase += delta / duration
			var p := phase
			var wind: float = def["wind"]
			var strike: float = def["strike"]
			var ang := rest
			if p < 0.42:                                  # wind-up: ease out, working end goes up and back
				var a := p / 0.42
				ang = lerpf(rest, wind, 1.0 - pow(1.0 - a, 3.0))
				off = Vector3(0.0, 0.07, -0.10) * a
			elif p < 0.58:                                # strike: accelerate onto the rock
				var a := (p - 0.42) / 0.16
				ang = lerpf(wind, strike, a * a)
				off = Vector3(0.0, lerpf(0.07, -0.03, a), lerpf(-0.10, -0.12, a))
				weight = a * a
			else:                                         # recover: ease back with a small settle
				var a := clampf((p - 0.58) / 0.42, 0.0, 1.0)
				var e := 1.0 - pow(1.0 - a, 3.0)
				ang = lerpf(strike, rest, e) + sin(a * PI) * 0.05
				off = Vector3(0.0, -0.03, -0.12).lerp(Vector3.ZERO, e)
				weight = 1.0 - clampf(a * 2.0, 0.0, 1.0)
			if p >= 0.58 and not impact_done:
				impact_done = true
				if on_impact.is_valid():
					on_impact.call()
			rot.x = ang
			rot.y = float(def.get("yaw", 0.0)) * (1.0 - 0.7 * weight)
			rot.z = 0.2 * sin(clampf(p, 0.0, 1.0) * PI)
			if phase >= 1.0:
				phase = -1.0
	else:
		var rr: Vector3 = def["rest_rot"]
		rot = rr
	if deflect_t > 0.0:
		deflect_t = maxf(0.0, deflect_t - delta)
		rot.x += sin(deflect_t / 0.3 * PI) * 0.5
		off += Vector3(0, 0.04, 0.06) * sin(deflect_t / 0.3 * PI)
	# power tools: vibration and push while running; the working end eases onto the crosshair point
	if tier >= 3:
		var v := op_blend
		var amp := 0.006 if tier == 3 else 0.014
		off += Vector3(sin(_t * 91.0) * amp, sin(_t * 113.0) * amp * (2.2 if tier == 4 else 1.0), -0.04 * v) * v
		weight = v * 0.85
		if spinner:
			if tier == 3:
				spinner.rotate_z(delta * 40.0 * v)
			else:
				spinner.position.y = -0.42 - absf(sin(_t * 56.0)) * 0.035 * v
	pivot.rotation = rot
	var placed := base + bob + off + Vector3(0, -lower, 0)
	# working end in camera space, then pull it toward the point on the crosshair ray where the rock is
	var tip_local: Vector3 = def["tip"]
	var tip_now := placed + pivot.transform.basis * (model.transform * tip_local) if model else placed
	var contact := Vector3(0, 0, -clampf(target_dist, REACH_MIN, REACH_MAX))
	var corr := (contact - tip_now)
	var cap := MAX_CORRECTION if tier < 3 else 0.1 # power tools stay in the hands: only a small nudge toward the rock
	if corr.length() > cap:
		corr = corr.normalized() * cap
	engage = weight
	position = placed + corr * weight
	tip_cam = tip_now + corr * weight

# ------------------------------------------------------------------ models (handle along +Y from the grip)

func _box(s: MeshKit.Soup, c: Vector3, size: Vector3, taper := Vector2.ONE) -> void:
	MeshKit.box_into(s, c, size, taper)

func _build(t: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Tool%d" % t
	var wood := MeshKit.Soup.new()
	var steel := MeshKit.Soup.new()
	var paint := MeshKit.Soup.new()
	var dark := MeshKit.Soup.new()
	var paint_key := "PaintYellow"
	match t:
		0: # rock hammer: short handle, square steel head
			_box(wood, Vector3(0, 0.15, 0), Vector3(0.035, 0.36, 0.04))
			_box(steel, Vector3(0, 0.36, -0.01), Vector3(0.07, 0.08, 0.17))
			_box(dark, Vector3(0, 0.0, 0), Vector3(0.045, 0.1, 0.05))   # grip tape
		1: # basic pickaxe
			_box(wood, Vector3(0, 0.22, 0), Vector3(0.035, 0.56, 0.04))
			var prof := PackedVector2Array([Vector2(-0.27, -0.02), Vector2(-0.03, 0.03), Vector2(0.03, 0.03), Vector2(0.27, -0.02), Vector2(0.2, -0.045), Vector2(0.0, -0.015), Vector2(-0.2, -0.045)])
			MeshKit.extrude_into(steel, prof, 0.045, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))) # profile is in (z, y): the points run fore and aft
		2: # reinforced pickaxe: longer, steel collars, painted head with hardened tips
			_box(wood, Vector3(0, 0.24, 0), Vector3(0.04, 0.6, 0.045))
			for y in [0.06, 0.38]:
				_box(steel, Vector3(0, y, 0), Vector3(0.05, 0.035, 0.055))
			var prof := PackedVector2Array([Vector2(-0.32, -0.03), Vector2(-0.04, 0.04), Vector2(0.04, 0.04), Vector2(0.32, -0.03), Vector2(0.24, -0.06), Vector2(0.0, -0.02), Vector2(-0.24, -0.06)])
			MeshKit.extrude_into(paint, prof, 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)))
			_box(steel, Vector3(0, 0.52, -0.31), Vector3(0.05, 0.05, 0.06))
			_box(steel, Vector3(0, 0.52, 0.31), Vector3(0.05, 0.05, 0.06))
			paint_key = "PaintRed"
		3: # power drill: pistol grip, body pointing forward (-Z), chuck + spinning bit
			_box(paint, Vector3(0, 0.12, -0.04), Vector3(0.1, 0.13, 0.3))
			_box(dark, Vector3(0, 0.0, 0.05), Vector3(0.07, 0.17, 0.08), Vector2(0.9, 0.9))
			_box(paint, Vector3(0, -0.1, 0.06), Vector3(0.11, 0.06, 0.14))      # battery
			_box(steel, Vector3(0, 0.12, -0.22), Vector3(0.07, 0.07, 0.07))      # chuck
		4: # jackhammer: tall body, T-handle on top, chisel down
			_box(steel, Vector3(0, 0.0, 0), Vector3(0.36, 0.05, 0.05))           # T-handle
			for x in [-0.15, 0.15]:
				_box(dark, Vector3(x, 0.0, 0), Vector3(0.09, 0.065, 0.065))
			_box(paint, Vector3(0, -0.22, 0), Vector3(0.14, 0.36, 0.14), Vector2(0.85, 0.85))
			_box(steel, Vector3(0, -0.06, 0.08), Vector3(0.08, 0.1, 0.06))      # valve block
			paint_key = "PaintRed"
	for pair in [[wood, QuarryArt.M_WOOD], [steel, "SteelPlate"], [paint, paint_key], [dark, QuarryArt.M_RUBBER]]:
		var s: MeshKit.Soup = pair[0]
		if s.verts.size() > 0:
			MeshKit.inst(n, s.mesh(), MeshKit.mat(pair[1]))
	if t == 3:
		var bit := Node3D.new()
		bit.position = Vector3(0, 0.12, -0.25)
		n.add_child(bit)
		var b := MeshKit.Soup.new()
		MeshKit.frustum_into(b, Vector3.ZERO, 0.014, 0.004, 0.2, 5, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
		_box(b, Vector3(0, 0, -0.1), Vector3(0.03, 0.006, 0.18))            # flute (shows rotation)
		MeshKit.inst(bit, b.mesh(), MeshKit.mat("SteelPlate"))
		n.set_meta("spinner", bit)
	elif t == 4:
		var chisel := Node3D.new()
		chisel.position = Vector3(0, -0.42, 0)
		n.add_child(chisel)
		var c := MeshKit.Soup.new()
		_box(c, Vector3(0, -0.08, 0), Vector3(0.035, 0.22, 0.035), Vector2(0.4, 0.4))
		MeshKit.inst(chisel, c.mesh(), MeshKit.mat("SteelPlate"))
		n.set_meta("spinner", chisel)
		n.rotation.x = float(TOOL[4]["model_pitch"]) # lean the body forward so the chisel points down-range at the rock
	_add_hands(n, t)
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


# ------------------------------------------------------------------ hands and forearms

## Where the fists close on each tool (model space: handle along +Y from the grip) and which way the forearm runs to
## the screen edge (camera space, -Z is forward). Hands and sleeves are children of the model, so they swing, bob and
## vibrate with it and the tool is always visibly held. Single grip on the hammer; two hands on the pickaxes, the drill
## (pistol grip + body) and the jackhammer (T-handle).
const HAND_R_DIR := Vector3(0.40, -0.53, 0.74)
const HAND_L_DIR := Vector3(-0.45, -0.45, 0.77)
const HANDS := {
	0: [["R", Vector3(0, 0.03, 0)]],
	1: [["R", Vector3(0, 0.02, 0)], ["L", Vector3(0, 0.24, 0)]],
	2: [["R", Vector3(0, 0.02, 0)], ["L", Vector3(0, 0.26, 0)]],
	3: [["R", Vector3(0, 0.0, 0.05)], ["L", Vector3(-0.065, 0.12, -0.1)]],
	4: [["R", Vector3(0.15, 0.0, 0)], ["L", Vector3(-0.15, 0.0, 0)]],
}
const SKIN := Color(0.80, 0.62, 0.48)
const SLEEVE := Color(0.30, 0.36, 0.44)

func _add_hands(n: Node3D, t: int) -> void:
	var def: Dictionary = TOOL[t]
	var pivot_b := Basis.from_euler(Vector3(float(def.get("rest", 0.0)), float(def.get("yaw", 0.0)), 0.0)) if t < 3 else Basis.from_euler(def["rest_rot"])
	var model_b := Basis.from_euler(Vector3(float(def.get("model_pitch", 0.0)), 0.0, 0.0))
	var inv := (pivot_b * model_b).inverse()
	var inv_s := 1.0 / float(def.get("scale", 1.0))
	for h in HANDS[t]:
		var right: bool = h[0] == "R"
		var dir_m: Vector3 = (inv * (HAND_R_DIR if right else HAND_L_DIR)).normalized()
		var at: Vector3 = h[1]
		var fist := MeshKit.box(Vector3(0.085, 0.085, 0.095) * inv_s)
		MeshKit.inst(n, fist, MeshKit.flat(SKIN), at)
		var cuff := MeshKit.box(Vector3(0.095, 0.095, 0.05) * inv_s)
		var basis := VeilRig.basis_zy(dir_m, Vector3.UP)
		var cf := MeshKit.inst(n, cuff, MeshKit.flat(SLEEVE), at + dir_m * 0.07 * inv_s)
		cf.basis = basis
		var arm := MeshKit.box(Vector3(0.085, 0.085, 0.42) * inv_s)
		var af := MeshKit.inst(n, arm, MeshKit.flat(SLEEVE), at + dir_m * 0.30 * inv_s)
		af.basis = basis
