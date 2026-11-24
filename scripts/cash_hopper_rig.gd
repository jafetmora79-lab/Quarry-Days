extends Node3D
class_name MeshyHopperRig
## The Meshy Cash Hopper in its three upgrade looks, and its procedural animation.
##   tier 0  the small old hopper: the first model (13-bone skeleton, no clips of its own), tinted worn grey, one lantern, green terminal screen
##   tier 1  the Motorized Hopper: a second model (hazard stripes, a slanted status window on top, a lit tube): more light, an amber screen and a status window
##   tier 2  the Industrial Hopper: a third, dark steel model: the most light (lanterns, tube, rear beacons, a light in the open tray), a gold-and-cyan screen
## The two newer models are static meshes; tools/split_meshy_hopper.py cuts them into Body / Tray / Funnel nodes so the same clips can drive them.
## Clips (the Blender hopper's names, so CashHopperView plays any model the same way) are procedural:
##   the roll-up shutter over the payout slot opens, then the tray slides out (back-out ease); the funnel shivers while it works and thumps on each sale.
## On top of the models: a live plate screen (HopperPlateScreen, skinned per tier), the status window (HopperTopScreen, tiers 1-2), lantern glow + light that pulse,
## and the cash: the real amount as bills and coins, lying in the tray before it opens.

signal tick                                          ## the plate's counted number stepped (every tier's screen feeds this one)

const GLBS := ["res://assets/world/WLD_QD_cash_hopper_meshy.glb", "res://assets/world/WLD_QD_cash_hopper_t2.glb", "res://assets/world/WLD_QD_cash_hopper_t3.glb"]
const FIT := 1.25                                    ## the models are 1.7 units tall: the game's hopper stands about 2.1 m
## Per tier, in the model's own space (+Z is the model's front, y = 0 the base).
const CFG := [
	{"skeleton": true, "plate": Vector3(0.0, 0.685, 0.52), "plate_size": Vector2(0.62, 0.27), "shutter": Vector3(0.0, 0.445, 0.468), "tray_top": Vector3(0.0, 0.40, 0.64),
		"closed": -0.34, "slide": 0.30, "top": Vector3.ZERO, "tint": Color(0.66, 0.66, 0.70), "tray_light": 0.0, "glow": 1.0,
		"lamps": [[Vector3(-0.505, 1.21, 0.31), 0.5]]},
	{"skeleton": false, "plate": Vector3(0.0, 0.685, 0.575), "plate_size": Vector2(0.62, 0.27), "shutter": Vector3(0.0, 0.475, 0.55), "tray_top": Vector3(0.0, 0.33, 0.70),
		"closed": -0.35, "slide": 0.20, "top": Vector3(0.0, 1.045, 0.565), "tint": Color(1, 1, 1), "tray_light": 0.7, "glow": 1.3,
		"lamps": [[Vector3(-0.505, 1.19, 0.36), 0.5], [Vector3(0.505, 1.19, 0.36), 0.5], [Vector3(0.52, 0.88, 0.62), 0.42]]},
	{"skeleton": false, "plate": Vector3(0.0, 0.685, 0.678), "plate_size": Vector2(0.62, 0.27), "shutter": Vector3(0.0, 0.475, 0.63), "tray_top": Vector3(0.0, 0.33, 0.70),
		"closed": -0.35, "slide": 0.20, "top": Vector3(0.0, 1.055, 0.65), "tint": Color(1, 1, 1), "tray_light": 1.0, "glow": 1.7,
		"lamps": [[Vector3(-0.505, 1.19, 0.36), 0.5], [Vector3(0.505, 1.19, 0.36), 0.5], [Vector3(0.52, 0.88, 0.64), 0.42], [Vector3(-0.70, 0.87, -0.49), 0.34],
			[Vector3(0.70, 0.87, -0.49), 0.34], [Vector3(-0.70, 0.87, 0.55), 0.2], [Vector3(0.70, 0.87, 0.55), 0.2]]}]
const CLIP_LEN := {"Idle": 0.0, "SaleRegistered": 0.45, "Processing": 0.9, "Counting": 1.2, "DrawerOpen": 0.5, "DrawerClose": 0.45, "ReturnToIdle": 0.35}
## The markers CashHopperView expects (game space: front is -Z).
const MARKERS := {
	"Attach_Body": Vector3(0, 0.0, 0), "Attach_InputFunnel": Vector3(0, 1.72, 0), "Attach_Processor": Vector3(0, 0.7, 0.0),
	"Attach_ConveyorIn": Vector3(0, 0.7, 1.1), "Attach_RockSpawn": Vector3(0, 2.55, 0), "Attach_Audio": Vector3(0, 1.2, 0),
	"Attach_FloatText": Vector3(0, 2.75, 0), "Attach_Display": Vector3(0, 0.856, -0.596), "Attach_SaleDisplay": Vector3(0, 0.856, -0.596), "Attach_Sign": Vector3(0, 0.856, -0.596),
	"Pivot_Flywheel": Vector3(0.97, 0.85, 0.0), "Pivot_Flap": Vector3(0, 1.2, 0.0)}
const TRAY_POINT := Vector3(0, 0.5, -1.0)            ## game space: just in front of the open tray (sparks, the sound of the click)

var model: Node3D                                    ## the turned and scaled holder of the three tier models (CashHopperView uses it as its `model`)
var tier := -1                                       ## the look shown now
var screen: HopperPlateScreen                        ## the active tier's plate screen
var top_screen: HopperTopScreen                      ## the active tier's status window (null on tier 0)
var shutter_open := 0.0                              ## 0 the slot is covered by the roll-up shutter .. 1 rolled up (it opens before the tray moves and closes after it)
var tray_open := 0.0                                 ## 0 closed .. 1 fully out (can overshoot a little)
var _vars: Array = []                                ## per tier: {root, cfg, screen, top, shutter, glows, lights, tray_light, tray, funnel, skel + bone data}
var _v: Dictionary = {}                              ## the active one
var _shake := 0.0                                    ## funnel shiver now / wanted
var _shake_to := 0.0
var _flap := 0.0                                     ## the thump on a sale: an angle (skeleton) / a dip (node models), springing back to 0
var _flap_v := 0.0
var _t := 0.0
var _bills: Array = []                               ## {n: the bill, land: where it lies on the tray (tray closed), shown}
var _bill_mesh: BoxMesh
var _coin_mesh: CylinderMesh
var _denom_mats := {}
var _lamp_level := 0.5
var _tween: Tween

static func available() -> bool:
	return ResourceLoader.exists(GLBS[0])

## Loads every tier's model that exists (tier 0 is required); the others fall back to tier 0's model if their file is missing.
func build() -> bool:
	model = Node3D.new()
	model.name = "Model"
	model.rotation.y = PI                                        # the models' front is +Z; the game's hopper faces -Z
	model.scale = Vector3.ONE * FIT
	add_child(model)
	_build_bills()
	for ti in range(CFG.size()):
		var path: String = GLBS[ti]
		var v := _make_variant(ti, path if ResourceLoader.exists(path) else "")
		if v.is_empty():
			if ti == 0:
				return false
			v = _vars[0]
		_vars.append(v)
	set_tier(1)
	set_process(true)
	return true

## Cuts loose pieces out of a model's mesh: a piece is a connected set of triangles (welded vertices) whose box matches [centre, size] (in the model's own space) within 1 cm.
func _drop_pieces(root: Node3D, pieces: Array) -> void:
	var inv := root.global_transform.affine_inverse()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mesh := m.mesh as ArrayMesh
		if mesh == null:
			continue
		var xf := inv * m.global_transform
		for si in range(mesh.get_surface_count()):
			var arr := mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				continue
			var par := PackedInt32Array()
			par.resize(verts.size())
			for i in verts.size():
				par[i] = i
			var seen := {}
			for i in verts.size():
				var key := Vector3i((verts[i] * 2000.0).round())
				if seen.has(key):
					par[_uf(par, i)] = _uf(par, int(seen[key]))
				else:
					seen[key] = i
			for t in range(0, idx.size(), 3):
				par[_uf(par, idx[t])] = _uf(par, idx[t + 1])
				par[_uf(par, idx[t + 1])] = _uf(par, idx[t + 2])
			var lo := {}
			var hi := {}
			for t in range(0, idx.size(), 3):
				var r := _uf(par, idx[t])
				for k in 3:
					var p: Vector3 = xf * verts[idx[t + k]]
					lo[r] = Vector3(minf(lo[r].x, p.x), minf(lo[r].y, p.y), minf(lo[r].z, p.z)) if lo.has(r) else p
					hi[r] = Vector3(maxf(hi[r].x, p.x), maxf(hi[r].y, p.y), maxf(hi[r].z, p.z)) if hi.has(r) else p
			var drop := {}
			for r in lo:
				var c: Vector3 = (lo[r] + hi[r]) * 0.5
				var sz: Vector3 = hi[r] - lo[r]
				for pc in pieces:
					if c.distance_to(pc[0]) < 0.01 and sz.distance_to(pc[1]) < 0.01:
						drop[r] = true
			if drop.is_empty():
				continue
			var keep := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				if not drop.has(_uf(par, idx[t])):
					keep.append(idx[t])
					keep.append(idx[t + 1])
					keep.append(idx[t + 2])
			var a2 := arr.duplicate()
			a2[Mesh.ARRAY_INDEX] = keep
			var nm := ArrayMesh.new()
			nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			nm.surface_set_material(0, mesh.surface_get_material(si))
			m.mesh = nm
			return

static func _uf(par: PackedInt32Array, x: int) -> int:
	while par[x] != x:
		par[x] = par[par[x]]
		x = par[x]
	return x

func _make_variant(ti: int, path: String) -> Dictionary:
	var cfg: Dictionary = CFG[ti]
	if path == "":
		return {}
	var ps = load(path)
	if not (ps is PackedScene):
		return {}
	var root := (ps as PackedScene).instantiate() as Node3D
	if root == null:
		return {}
	root.name = "Tier%d" % ti
	model.add_child(root)
	root.visible = false
	var v := {"root": root, "cfg": cfg, "glows": [], "lights": [], "tray": null, "funnel": null, "skel": null}
	if bool(cfg["skeleton"]):
		var sks := root.find_children("*", "Skeleton3D", true, false)
		if sks.is_empty():
			return {}
		var skel := sks[0] as Skeleton3D
		v["skel"] = skel
		v["b_tray"] = skel.find_bone("Bone_006")
		v["b_funnel"] = skel.find_bone("Bone_002")
		v["b_flap"] = skel.find_bone("Bone_003")
		if int(v["b_tray"]) < 0 or int(v["b_funnel"]) < 0 or int(v["b_flap"]) < 0:
			return {}
		v["tray_rest"] = skel.get_bone_rest(int(v["b_tray"])).origin
		v["funnel_rest"] = skel.get_bone_rest(int(v["b_funnel"])).origin
		v["flap_rest"] = skel.get_bone_rest(int(v["b_flap"])).basis.get_rotation_quaternion()
		v["tray_par"] = _parent_inv(skel, int(v["b_tray"]))        # the parent bones' (inverse) rest orientations turn a model-space direction into the bone's local one
		v["funnel_par"] = _parent_inv(skel, int(v["b_funnel"]))
		v["flap_par"] = _parent_inv(skel, int(v["b_flap"]))
	else:
		v["tray"] = root.get_node_or_null("Tray")
		v["funnel"] = root.get_node_or_null("Funnel")
		if v["tray"] == null or v["funnel"] == null:
			return {}
	if ti == 0:
		_drop_pieces(root, [[Vector3(0.428, 0.209, 0.443), Vector3(0.319, 0.232, 0.12)]])       # the stray green wedge beside the shutter (it poked out of the front and flickered as the tray moved)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).extra_cull_margin = 1.0               # skinned / moved parts: the rest-pose bounds are not the moving bounds
		var m := mi as MeshInstance3D
		for i in range(m.mesh.get_surface_count() if m.mesh != null else 0):
			var base := m.mesh.surface_get_material(i) as StandardMaterial3D
			if base != null and (cfg["tint"] as Color) != Color(1, 1, 1):          # (tier 0 is the old worn grey)
				var dup := base.duplicate() as StandardMaterial3D
				dup.albedo_color = cfg["tint"]
				m.set_surface_override_material(i, dup)
	var screen_n := HopperPlateScreen.new()
	screen_n.name = "PlateScreen"
	screen_n.setup(cfg["plate_size"], ti)
	screen_n.position = (cfg["plate"] as Vector3) + Vector3(0.0, 0.0, 0.009)       # a hair in front of the bezel: coplanar with it, its corners flickered (z-fighting) as the view moved
	screen_n.rotation.y = PI                                          # (the screen's quad faces -Z in its own frame; the model's front is +Z)
	root.add_child(screen_n)
	screen_n.tick.connect(func(): tick.emit())
	v["screen"] = screen_n
	if (cfg["top"] as Vector3) != Vector3.ZERO:
		var top := HopperTopScreen.new()
		top.name = "TopScreen"
		top.setup(Vector2(0.5, 0.17), ti)
		top.position = cfg["top"]
		top.rotation = Vector3(-0.3, PI, 0.0)
		root.add_child(top)
		v["top"] = top
	v["shutter"] = _build_shutter(root, cfg)
	_build_lamps(v)
	if float(cfg["tray_light"]) > 0.0:
		var tl := OmniLight3D.new()                                   # a warm light that spills out of the open tray
		tl.light_color = Color(1.0, 0.78, 0.4)
		tl.omni_range = 1.8
		tl.shadow_enabled = false
		tl.light_energy = 0.0
		tl.position = (cfg["tray_top"] as Vector3) + Vector3(0, 0.25, 0.25)
		root.add_child(tl)
		v["tray_light"] = tl
	return v

func _parent_inv(skel: Skeleton3D, bone: int) -> Basis:
	var p := skel.get_bone_parent(bone)
	return skel.get_bone_global_rest(p).basis.inverse() if p >= 0 else Basis.IDENTITY

## A roll-up shutter of steel slats over the payout slot, so a closed hopper looks closed (the models' slot is an open gap).
func _build_shutter(root: Node3D, cfg: Dictionary) -> Node3D:
	var sh := Node3D.new()
	sh.name = "Shutter"
	sh.position = cfg["shutter"]                                     # its top edge: the underside of the yellow bar above the slot
	root.add_child(sh)
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
		sh.add_child(b)
	var bottom := MeshInstance3D.new()                               # the yellow bottom rail
	var rm := BoxMesh.new()
	rm.size = Vector3(0.64, 0.022, 0.026)
	bottom.mesh = rm
	bottom.material_override = rim
	bottom.position = Vector3(0.0, -0.016 - 0.031 * 7.0 - 0.004, 0.003)
	sh.add_child(bottom)
	return sh

func _build_lamps(v: Dictionary) -> void:
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
	for e in v["cfg"]["lamps"]:
		var p: Vector3 = e[0]
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(float(e[1]), float(e[1]))
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = gt
		m.albedo_color = Color(1.0, 0.62, 0.2, 0.3)
		q.material_override = m
		q.position = p + Vector3(0, 0.0, 0.04)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(v["root"] as Node3D).add_child(q)
		(v["glows"] as Array).append(q)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.2)
		l.omni_range = 2.4
		l.shadow_enabled = false
		l.position = p + Vector3(0, 0.15, 0.1)
		(v["root"] as Node3D).add_child(l)
		(v["lights"] as Array).append(l)

## One look per denomination, so the pile on the tray can be read: $500 purple, $100 blue, $20 green, $5 pale grey-green; $1 is a gold coin.
const DENOMS := [500, 100, 20, 5, 1]
const DENOM_COLOR := {500: Color(0.62, 0.40, 0.78), 100: Color(0.30, 0.62, 0.80), 20: Color(0.42, 0.74, 0.40), 5: Color(0.66, 0.76, 0.68)}
const PILE_CAP := 8                                    ## the tallest pile drawn (the plate's breakdown line always has the exact count)

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

# ------------------------------------------------------------------ tiers

## Shows tier `ti`'s model, screen, status window and lights (the others are hidden); the tray closes and the shutter drops.
func set_tier(ti: int) -> void:
	ti = clampi(ti, 0, _vars.size() - 1)
	if ti == tier:
		return
	tier = ti
	_clear_bills()
	for k in range(_vars.size()):
		(_vars[k]["root"] as Node3D).visible = false
	_v = _vars[ti]
	(_v["root"] as Node3D).visible = true
	screen = _v["screen"]
	top_screen = _v["top"] if _v.has("top") else null
	set_lamp(_lamp_level)

## Kept for CashHopperView's call: the tier decides everything (model, tint, lights, screens).
func apply_tier(ti: int) -> void:
	set_tier(ti)

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
			_flap_v = -1.0                                               # the funnel thumps
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
	var top: Vector3 = _v["cfg"]["tray_top"]
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
				b.position = Vector3(px + randf_range(-0.03, 0.03), top.y + 0.006 + 0.007 * float(k % 3), top.z + randf_range(-0.07, 0.07))
				b.rotation = Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
			else:
				b.mesh = _bill_mesh
				b.position = Vector3(px + randf_range(-0.004, 0.004), top.y + 0.004 + 0.0075 * float(k), top.z + randf_range(-0.006, 0.006))
				b.rotation = Vector3(0.0, yaw + randf_range(-0.04, 0.04), 0.0)
			b.material_override = _denom_mats[denom]
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.visible = false
			(_v["root"] as Node3D).add_child(b)
			_bills.append({"n": b, "land": b.position, "shown": false})

func _tray_offset() -> float:
	return lerpf(float(_v["cfg"]["closed"]), float(_v["cfg"]["slide"]), tray_open)

func _clear_bills() -> void:
	for e in _bills:
		var b := (e as Dictionary)["n"] as MeshInstance3D
		if is_instance_valid(b):
			b.queue_free()
	_bills.clear()

# ------------------------------------------------------------------ lamps

## 0..~3 (the view flashes it): how bright the lanterns and lamps burn. Each tier has more of them, and burns brighter.
func set_lamp(level: float) -> void:
	_lamp_level = level
	if _v.is_empty():
		return
	var gk := float(_v["cfg"]["glow"])
	for g in _v["glows"]:
		(g.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.62, 0.2, clampf((0.12 + 0.3 * level) * gk, 0.0, 0.9))
		g.scale = Vector3.ONE * (0.8 + 0.25 * minf(level, 3.0))
	for l in _v["lights"]:
		(l as OmniLight3D).light_energy = (0.05 + 0.3 * level) * gk

# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	if _v.is_empty():
		return
	_t += delta
	_shake = move_toward(_shake, _shake_to, delta * 3.0)
	var k := 55.0                                                       # the thump: a spring with damping, kicked by an impulse
	_flap_v += (-k * _flap - 7.0 * _flap_v) * delta
	_flap += _flap_v * delta
	_flap = clampf(_flap, -0.9, 0.9)
	var cfg: Dictionary = _v["cfg"]
	var sh := _v["shutter"] as Node3D
	sh.scale.y = maxf(1.0 - shutter_open, 0.001)
	sh.visible = shutter_open < 0.98
	var off := _tray_offset()
	var j := Vector3(sin(_t * 71.0) * 0.007, sin(_t * 53.0) * 0.005, sin(_t * 61.0) * 0.004) * _shake
	var rz := sin(_t * 47.0) * 0.012 * _shake
	if bool(cfg["skeleton"]):
		var skel := _v["skel"] as Skeleton3D
		skel.set_bone_pose_position(int(_v["b_tray"]), (_v["tray_rest"] as Vector3) + (_v["tray_par"] as Basis) * Vector3(0, 0, off))
		skel.set_bone_pose_position(int(_v["b_funnel"]), (_v["funnel_rest"] as Vector3) + (_v["funnel_par"] as Basis) * j)
		skel.set_bone_pose_rotation(int(_v["b_funnel"]), Quaternion(Vector3.BACK, rz))
		var axis := ((_v["flap_par"] as Basis) * Vector3.RIGHT).normalized()
		skel.set_bone_pose_rotation(int(_v["b_flap"]), Quaternion(axis, _flap) * (_v["flap_rest"] as Quaternion))
	else:
		(_v["tray"] as Node3D).position = Vector3(0, 0, off)
		var fn := _v["funnel"] as Node3D
		fn.position = j + Vector3(0, _flap * 0.06, 0)
		fn.rotation.z = rz
	var tl = _v.get("tray_light")
	if tl != null:
		(tl as OmniLight3D).light_energy = float(cfg["tray_light"]) * clampf(tray_open, 0.0, 1.0)
		(tl as OmniLight3D).position.z = float((cfg["tray_top"] as Vector3).z) + off
	for e in _bills:                                                    # the cash rides the tray
		var d := e as Dictionary
		var b := d["n"] as MeshInstance3D
		if not is_instance_valid(b):
			continue
		b.position = (d["land"] as Vector3) + Vector3(0, 0, off)
		var out := tray_open > 0.3                                      # shown once the tray is far enough out to see into
		if out != b.visible:
			b.visible = out
			if out and not bool(d["shown"]):
				d["shown"] = true
				b.scale = Vector3.ONE * 0.5
				create_tween().tween_property(b, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
