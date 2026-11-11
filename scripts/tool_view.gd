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

const BASE := {0: Vector3(0.34, -0.36, -0.62), 1: Vector3(0.36, -0.38, -0.66), 2: Vector3(0.36, -0.38, -0.68), 3: Vector3(0.26, -0.27, -0.5), 4: Vector3(0.18, -0.5, -0.66)}

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
	var base: Vector3 = BASE.get(tier, Vector3(0.36, -0.36, -0.66))
	var rot := Vector3(0.12, 0, 0)
	var off := Vector3.ZERO
	if phase >= 0.0:
		phase += delta / duration
		var p := phase
		var ang := 0.12
		if p < 0.42:                                  # wind-up: ease out, head goes up and back
			var a := p / 0.42
			ang = lerpf(0.12, 1.15, 1.0 - pow(1.0 - a, 3.0))
			off = Vector3(0.03, 0.06, 0.06) * a
		elif p < 0.58:                                # strike: accelerate into the rock
			var a := (p - 0.42) / 0.16
			ang = lerpf(1.15, -0.95, a * a)
			off = Vector3(lerpf(0.03, -0.05, a), lerpf(0.06, -0.02, a), lerpf(0.06, -0.14, a))
		else:                                         # recover: ease back with a small settle
			var a := clampf((p - 0.58) / 0.42, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - a, 3.0)
			ang = lerpf(-0.95, 0.12, e) + sin(a * PI) * 0.06
			off = Vector3(-0.05, -0.02, -0.14).lerp(Vector3.ZERO, e)
		if p >= 0.58 and not impact_done:
			impact_done = true
			if on_impact.is_valid():
				on_impact.call()
		rot.x = ang
		rot.z = -0.35 * sin(clampf(p, 0.0, 1.0) * PI)
		if phase >= 1.0:
			phase = -1.0
	if deflect_t > 0.0:
		deflect_t = maxf(0.0, deflect_t - delta)
		rot.x += sin(deflect_t / 0.3 * PI) * 0.5
		off += Vector3(0, 0.04, 0.06) * sin(deflect_t / 0.3 * PI)
	# power tools: vibration and push while running
	if tier >= 3:
		var v := op_blend
		var amp := 0.006 if tier == 3 else 0.014
		off += Vector3(sin(_t * 91.0) * amp, sin(_t * 113.0) * amp * (2.2 if tier == 4 else 1.0), -0.04 * v) * v
		rot.x = 0.04 if tier == 3 else 0.1
		if spinner:
			if tier == 3:
				spinner.rotate_z(delta * 40.0 * v)
			else:
				spinner.position.y = -0.42 - absf(sin(_t * 56.0)) * 0.035 * v
	position = base + bob + off + Vector3(0, -lower, 0)
	pivot.rotation = rot

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
			MeshKit.extrude_into(steel, prof, 0.045, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.5, 0)))
		2: # reinforced pickaxe: longer, steel collars, painted head with hardened tips
			_box(wood, Vector3(0, 0.24, 0), Vector3(0.04, 0.6, 0.045))
			for y in [0.06, 0.38]:
				_box(steel, Vector3(0, y, 0), Vector3(0.05, 0.035, 0.055))
			var prof := PackedVector2Array([Vector2(-0.32, -0.03), Vector2(-0.04, 0.04), Vector2(0.04, 0.04), Vector2(0.32, -0.03), Vector2(0.24, -0.06), Vector2(0.0, -0.02), Vector2(-0.24, -0.06)])
			MeshKit.extrude_into(paint, prof, 0.06, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.55, 0)))
			_box(steel, Vector3(0, 0.52, -0.31), Vector3(0.05, 0.05, 0.06))
			_box(steel, Vector3(0, 0.52, 0.31), Vector3(0.05, 0.05, 0.06))
			paint_key = "PaintRed"
		3: # power drill: pistol grip, body pointing forward (-Z), chuck + spinning bit
			_box(paint, Vector3(0, 0.12, -0.04), Vector3(0.1, 0.13, 0.3))
			_box(dark, Vector3(0, 0.0, 0.05), Vector3(0.07, 0.17, 0.08), Vector2(0.9, 0.9))
			_box(paint, Vector3(0, -0.1, 0.06), Vector3(0.11, 0.06, 0.14))      # battery
			_box(steel, Vector3(0, 0.12, -0.22), Vector3(0.07, 0.07, 0.07))      # chuck
		4: # jackhammer: tall body, T-handle on top, chisel down
			_box(steel, Vector3(0, 0.0, 0), Vector3(0.5, 0.05, 0.05))           # T-handle
			for x in [-0.22, 0.22]:
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
		n.rotation.x = -0.5 # lean the hammer so the chisel points at the crosshair
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n
