extends Node3D
class_name MeshyHopperRig
## The rigged Cash Hopper (a Meshy model with a 13-bone skeleton and no animation clips of its own). This node loads it, stands it the way the game's hopper stands
## (front toward -Z, about 1.9 m wide) and plays the payout as procedural "clips" on three of its bones:
##   Bone_006  the payout tray / chute at the front: slides out (back-out ease, a little overshoot) and back in
##   Bone_002  the funnel bowl: shivers while it works, jolts on a sale
##   Bone_003  the grate under the funnel: kicks open on each sale (flap)
## plus things the model has no bones for: the front plate is covered by a live HopperPlateScreen, the two lanterns get glow + light that pulse, and the cash that comes out
## (paper bills that arc out of the slot and land on the tray, with the tray carrying them back in when it closes).
## The clip names are the Blender hopper's, so CashHopperView plays either model the same way.

const GLB := "res://assets/world/WLD_QD_cash_hopper_meshy.glb"
const FIT := 1.25                                    ## the model is 1.5 m wide as delivered; the game's hopper slot is about 1.9 m
const SLIDE := 0.30                                  ## how far past its modelled position the tray comes out when open (model metres)
const TRAY_CLOSED := -0.34                           ## where it rests when closed: pushed in, its front flush under the plate (the model's own pose has it half out)
const PLATE_POS := Vector3(0.0, 0.685, 0.52)        ## the front plate's centre in the model's own space (+Z is the model's front)
const PLATE_SIZE := Vector2(0.62, 0.27)
const LAMPS := [Vector3(-0.505, 1.21, 0.31), Vector3(0.505, 1.21, 0.31)]
const TRAY_TOP := Vector3(0.0, 0.40, 0.64)           ## where bills lie on the tray when it is closed (they ride it out and in)
const TIER_TINT := [Color(0.66, 0.66, 0.70), Color(1, 1, 1), Color(1.0, 0.80, 0.72)]    ## small old grey / motorized / industrial rust
const CLIP_LEN := {"Idle": 0.0, "SaleRegistered": 0.45, "Processing": 0.9, "Counting": 1.2, "DrawerOpen": 0.5, "DrawerClose": 0.45, "ReturnToIdle": 0.35}
## The markers CashHopperView expects (game space: front is -Z).
const MARKERS := {
	"Attach_Body": Vector3(0, 0.0, 0), "Attach_InputFunnel": Vector3(0, 1.72, 0), "Attach_Processor": Vector3(0, 0.7, 0.0),
	"Attach_ConveyorIn": Vector3(0, 0.7, 1.1), "Attach_RockSpawn": Vector3(0, 2.55, 0), "Attach_Audio": Vector3(0, 1.2, 0),
	"Attach_FloatText": Vector3(0, 2.75, 0), "Attach_Display": Vector3(0, 0.856, -0.596), "Attach_SaleDisplay": Vector3(0, 0.856, -0.596), "Attach_Sign": Vector3(0, 0.856, -0.596),
	"Pivot_Flywheel": Vector3(0.97, 0.85, 0.0), "Pivot_Flap": Vector3(0, 1.2, 0.0)}
const TRAY_POINT := Vector3(0, 0.5, -1.0)            ## game space: just in front of the open tray (sparks, the sound of the click)

var model: Node3D                                    ## the Meshy scene, turned and scaled (CashHopperView uses this as its `model`)
var skel: Skeleton3D
var screen: HopperPlateScreen
var shutter_open := 0.0                              ## 0 the slot is covered by the roll-up shutter .. 1 rolled up (it opens before the tray moves and closes after it)
var _shutter: Node3D
var tray_open := 0.0                                 ## 0 closed .. 1 fully out (can overshoot a little)
var _b_tray := -1
var _b_funnel := -1
var _b_flap := -1
var _tray_rest := Vector3.ZERO
var _funnel_rest := Vector3.ZERO
var _flap_rest := Quaternion.IDENTITY
var _tray_par := Basis.IDENTITY                      ## the parent bones' (inverse) rest orientations: they turn a model-space direction into the bone's local one
var _funnel_par := Basis.IDENTITY
var _flap_par := Basis.IDENTITY
var _shake := 0.0                                    ## funnel shiver now / wanted
var _shake_to := 0.0
var _flap := 0.0                                     ## flap angle now (springs back to 0)
var _flap_v := 0.0
var _t := 0.0
var _bills: Array = []                               ## {n: the bill, land: where it lies on the tray (tray closed), landed: it stopped flying}
var _bill_mesh: BoxMesh
var _bill_mat: StandardMaterial3D
var _glows: Array = []
var _lights: Array = []
var _lamp_level := 0.5
var _lamps_on := 2
var _tween: Tween
var _tint := 1

static func available() -> bool:
	return ResourceLoader.exists(GLB)

func build() -> bool:
	var ps = load(GLB)
	if not (ps is PackedScene):
		return false
	model = (ps as PackedScene).instantiate() as Node3D
	if model == null:
		return false
	model.rotation.y = PI                                        # the model's front is +Z; the game's hopper faces -Z
	model.scale = Vector3.ONE * FIT
	add_child(model)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return false
	skel = sks[0] as Skeleton3D
	_b_tray = skel.find_bone("Bone_006")
	_b_funnel = skel.find_bone("Bone_002")
	_b_flap = skel.find_bone("Bone_003")
	if _b_tray < 0 or _b_funnel < 0 or _b_flap < 0:
		return false
	_tray_rest = skel.get_bone_rest(_b_tray).origin
	_funnel_rest = skel.get_bone_rest(_b_funnel).origin
	_flap_rest = skel.get_bone_rest(_b_flap).basis.get_rotation_quaternion()
	_tray_par = _parent_inv(_b_tray)
	_funnel_par = _parent_inv(_b_funnel)
	_flap_par = _parent_inv(_b_flap)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).extra_cull_margin = 1.0               # skinned: the bounds of the rest pose are not the bounds of the moving one
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_build_screen()
	_build_shutter()
	_build_lamps()
	_build_bills()
	set_process(true)
	return true

func _parent_inv(bone: int) -> Basis:
	var p := skel.get_bone_parent(bone)
	return skel.get_bone_global_rest(p).basis.inverse() if p >= 0 else Basis.IDENTITY

func _build_screen() -> void:
	screen = HopperPlateScreen.new()
	screen.name = "PlateScreen"
	screen.setup(PLATE_SIZE)
	screen.position = PLATE_POS
	screen.rotation.y = PI                                            # (the screen's quad faces -Z in its own frame; the model's front is +Z)
	model.add_child(screen)

## A roll-up shutter of steel slats over the payout slot, so a closed hopper looks closed (the model's slot is an open gap). It hangs from the yellow bar above the slot and rolls up.
func _build_shutter() -> void:
	_shutter = Node3D.new()
	_shutter.name = "Shutter"
	_shutter.position = Vector3(0.0, 0.445, 0.468)                       # its top edge: the underside of the yellow bar
	model.add_child(_shutter)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.19, 0.27)
	m.metallic = 0.55
	m.roughness = 0.5
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.95, 0.62, 0.10)
	for i in range(7):
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.62, 0.028, 0.018)
		b.mesh = bm
		b.material_override = m
		b.position = Vector3(0.0, -0.016 - 0.031 * float(i), 0.0)
		_shutter.add_child(b)
	var bottom := MeshInstance3D.new()                                   # the yellow bottom rail
	var rm := BoxMesh.new()
	rm.size = Vector3(0.64, 0.022, 0.026)
	bottom.mesh = rm
	bottom.material_override = rim
	bottom.position = Vector3(0.0, -0.016 - 0.031 * 7.0 - 0.004, 0.003)
	bottom.name = "Rail"
	_shutter.add_child(bottom)

func _build_lamps() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	for p in LAMPS:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.5)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = gt
		m.albedo_color = Color(1.0, 0.62, 0.2, 0.3)
		m.no_depth_test = false
		q.material_override = m
		q.position = p + Vector3(0, 0.0, 0.04)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(q)
		_glows.append(q)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.2)
		l.omni_range = 2.4
		l.shadow_enabled = false
		l.position = p + Vector3(0, 0.15, 0.1)
		model.add_child(l)
		_lights.append(l)
	set_lamp(_lamp_level)

## One look per denomination, so the pile on the tray can be read: $500 purple, $100 blue, $20 green, $5 pale grey-green; $1 is a gold coin.
const DENOMS := [500, 100, 20, 5, 1]
const DENOM_COLOR := {500: Color(0.62, 0.40, 0.78), 100: Color(0.30, 0.62, 0.80), 20: Color(0.42, 0.74, 0.40), 5: Color(0.66, 0.76, 0.68)}
const PILE_CAP := 8                                    ## the tallest pile drawn (the plate's breakdown line always has the exact count)
var _denom_mats := {}
var _coin_mesh: CylinderMesh

func _build_bills() -> void:
	_bill_mesh = BoxMesh.new()
	_bill_mesh.size = Vector3(0.082, 0.006, 0.17)                       # the long side lies along the tray's depth, so five piles fit side by side
	_coin_mesh = CylinderMesh.new()
	_coin_mesh.top_radius = 0.03
	_coin_mesh.bottom_radius = 0.03
	_coin_mesh.height = 0.008
	_coin_mesh.radial_segments = 10
	for d in DENOM_COLOR:
		var c: Color = DENOM_COLOR[d]
		var img := Image.create(9, 17, false, Image.FORMAT_RGBA8)
		for y in range(17):
			for x in range(9):
				var edge := x == 0 or y == 0 or x == 8 or y == 16
				var mid := (x >= 3 and x <= 5) and (y >= 6 and y <= 10)
				img.set_pixel(x, y, c.darkened(0.55) if edge else (c.lightened(0.45) if mid else c))
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.roughness = 0.9
		m.emission_enabled = true                                      # a faint glow so the money reads in shadow
		m.emission = c
		m.emission_energy_multiplier = 0.2
		_denom_mats[d] = m
	var coin := StandardMaterial3D.new()
	coin.albedo_color = Color(1.0, 0.80, 0.28)
	coin.metallic = 0.8
	coin.roughness = 0.35
	_denom_mats[1] = coin

## The cash for `money`, exactly: [[denomination, count], ...] largest first (greedy over $500 / $100 / $20 / $5 / $1: the pieces always add up to the amount).
static func breakdown(money: int) -> Array:
	var left := maxi(money, 0)
	var out := []
	for d in DENOMS:
		var n := left / int(d)
		if n > 0:
			out.append([int(d), n])
			left -= n * int(d)
	return out

## "2x$500  1x$100  3x$20" for the plate.
static func breakdown_text(money: int) -> String:
	var parts := []
	for e in breakdown(money):
		parts.append("%dx$%d" % [int(e[1]), int(e[0])])
	return "  ".join(parts)

# ------------------------------------------------------------------ the clips

## Plays a clip (the Blender hopper's names); returns how long it takes at that speed.
func play(clip: String, speed := 1.0) -> float:
	if not CLIP_LEN.has(clip):
		return 0.0
	var d: float = float(CLIP_LEN[clip]) / maxf(speed, 0.05)
	match clip:
		"Idle":
			_shake_to = 0.0
		"SaleRegistered":
			_flap_v = -1.0                                               # the grate kicks: a small thump (the bowl rides on it)
			_shake = 1.0
			_shake_to = 0.7
		"Processing":
			_shake_to = 1.0
		"Counting":
			_shake_to = 0.35
		"DrawerOpen":
			_shake_to = 0.0
			_drawer(true, d)
		"DrawerClose":
			_drawer(false, d)
		"ReturnToIdle":
			_shake_to = 0.0
	return d

## Opening: the shutter rolls up (a quick ratchet), THEN the tray slides out (back-out ease, a little overshoot). Closing is the reverse: tray in, then the shutter comes down.
func _drawer(open: bool, secs: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var sh := minf(0.16, secs * 0.32)
	var tr := maxf(secs - sh, 0.05)
	if open:
		_tween.tween_property(self, "shutter_open", 1.0, sh).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "tray_open", 1.0, tr).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(self, "tray_open", 0.0, tr).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "shutter_open", 0.0, sh).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_clear_bills)

## The cash is already IN the tray: `money` is laid out as its real bills and coins, one pile per denomination (taller piles for more of them, up to PILE_CAP),
## so what lies in the tray adds up to the amount on the plate. The pieces stay hidden inside while the tray is closed and show as it slides out; the money is never
## seen coming out of the screen. Called again with a bigger running total (sales that ride an open drawer) it rebuilds the piles for the new total.
func pay_out(money: int) -> void:
	_clear_bills()
	var groups := breakdown(money)
	var slots := groups.size()
	for gi in range(slots):
		var denom: int = groups[gi][0]
		var count: int = mini(int(groups[gi][1]), PILE_CAP)
		var px := (float(gi) - float(slots - 1) * 0.5) * 0.095
		var yaw := randf_range(-0.12, 0.12)
		for k in range(count):
			var b := MeshInstance3D.new()
			if denom == 1:                                              # dollar coins: a loose little heap, not a stack
				b.mesh = _coin_mesh
				b.position = Vector3(px + randf_range(-0.03, 0.03), TRAY_TOP.y + 0.006 + 0.007 * float(k % 3), TRAY_TOP.z + randf_range(-0.07, 0.07))
				b.rotation = Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
			else:
				b.mesh = _bill_mesh
				b.position = Vector3(px + randf_range(-0.004, 0.004), TRAY_TOP.y + 0.004 + 0.0075 * float(k), TRAY_TOP.z + randf_range(-0.006, 0.006))
				b.rotation = Vector3(0.0, yaw + randf_range(-0.04, 0.04), 0.0)
			b.material_override = _denom_mats[denom]
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.visible = false
			model.add_child(b)
			_bills.append({"n": b, "land": b.position, "shown": false})

func _tray_offset() -> float:
	return lerpf(TRAY_CLOSED, SLIDE, tray_open)

func _clear_bills() -> void:
	for e in _bills:
		var b := (e as Dictionary)["n"] as MeshInstance3D
		if is_instance_valid(b):
			b.queue_free()
	_bills.clear()

# ------------------------------------------------------------------ lamps, tiers

## 0..~3 (the view flashes it): how bright the lanterns burn.
func set_lamp(level: float) -> void:
	_lamp_level = level
	for i in range(_glows.size()):
		var on: bool = i < _lamps_on
		var g := _glows[i] as MeshInstance3D
		g.visible = on
		(g.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.62, 0.2, clampf(0.12 + 0.3 * level, 0.0, 0.85))
		g.scale = Vector3.ONE * (0.8 + 0.25 * minf(level, 3.0))
		var l := _lights[i] as OmniLight3D
		l.visible = on
		l.light_energy = 0.05 + 0.3 * level

## Tier 0 old grey with one lantern, 1 the standard colours with both, 2 rust-red with both.
func apply_tier(ti: int) -> void:
	ti = clampi(ti, 0, TIER_TINT.size() - 1)
	_tint = ti
	_lamps_on = 1 if ti == 0 else 2
	set_lamp(_lamp_level)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.get_parent() == null:
			continue
		if not m.mesh.get_surface_count() > 0:
			continue
		for i in range(m.mesh.get_surface_count()):
			var base := m.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var dup := base.duplicate() as StandardMaterial3D
			dup.albedo_color = TIER_TINT[ti]
			m.set_surface_override_material(i, dup)

# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	if skel == null:
		return
	_t += delta
	_shake = move_toward(_shake, _shake_to, delta * 3.0)
	var k := 55.0                                                       # the flap: a spring with damping, kicked by an impulse
	_flap_v += (-k * _flap - 7.0 * _flap_v) * delta
	_flap += _flap_v * delta
	_flap = clampf(_flap, -0.9, 0.9)
	if _shutter != null:
		_shutter.scale.y = maxf(1.0 - shutter_open, 0.001)
		_shutter.visible = shutter_open < 0.98
	var tray_v := Vector3(0, 0, _tray_offset())                      # model-space offsets
	skel.set_bone_pose_position(_b_tray, _tray_rest + _tray_par * tray_v)
	var j := Vector3(sin(_t * 71.0) * 0.007, sin(_t * 53.0) * 0.005, sin(_t * 61.0) * 0.004) * _shake
	skel.set_bone_pose_position(_b_funnel, _funnel_rest + _funnel_par * j)
	var rz := sin(_t * 47.0) * 0.012 * _shake
	skel.set_bone_pose_rotation(_b_funnel, Quaternion(Vector3.BACK, rz))
	var axis := (_flap_par * Vector3.RIGHT).normalized()
	skel.set_bone_pose_rotation(_b_flap, Quaternion(axis, _flap) * _flap_rest)
	for e in _bills:                                                    # resting bills ride the tray
		var d := e as Dictionary
		var b := d["n"] as MeshInstance3D
		if not is_instance_valid(b):
			continue
		b.position = (d["land"] as Vector3) + Vector3(0, 0, _tray_offset())
		var out := tray_open > 0.3                                      # shown once the tray is far enough out to see into
		if out != b.visible:
			b.visible = out
			if out and not bool(d["shown"]):
				d["shown"] = true
				b.scale = Vector3.ONE * 0.5
				create_tween().tween_property(b, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
