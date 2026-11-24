extends RefCounted
class_name BucketView
## The bucket, built hollow: a tapered steel wall with a textured (rusty, worn) INSIDE, a rolled rim, ribs, a base ring and a wire bail. What is in it is drawn from what it really holds,
## layer by layer from the bottom: soil as a smooth heaped mound, gravel as loose small stones, rock as blocky chunks, ore as chunks with the mineral showing - each in its own material.
## `set_load(model, {resource: units}, capacity)` redraws the contents (only when they changed). Used by the bucket in the hands, the placed buckets and the hotbar picture.

const H := 0.43                       ## height of the wall (the Meshy pail at MESHY_S; the contents are drawn into these dimensions)
const R0 := 0.145                     ## outer radius at the base
const R1 := 0.16                      ## outer radius at the rim
const WALL := 0.012
const FLOOR_Y := 0.03
const MESHY := "res://assets/tools/meshy/bucket_meshy_unused.glb"      ## the Meshy pail: hollow, rusty steel, a wire bail with a wooden grip (the procedural pail below is the fallback)
const MESHY_S := 0.45
static var _meshy_cache := {}

const MATS := {"topsoil": "ExcavatedDirt", "soil": "ExcavatedDirt", "clay": "Clay", "gravel": "RockGravel", "crushed_stone": "RockGravel", "limestone": "RockLimestone",
	"coal": "RockCoal", "iron_ore": "RockIron", "copper_ore": "RockCopper", "gold_ore": "RockGold"}

static var _steel: StandardMaterial3D
static var _inner: Material
static var _rim: StandardMaterial3D
static var _handle: StandardMaterial3D

static func _mats() -> void:
	if _steel != null:
		return
	_steel = MeshKit.flat(Color(0.46, 0.49, 0.51))
	_rim = MeshKit.flat(Color(0.30, 0.32, 0.35))
	_handle = MeshKit.flat(Color(0.16, 0.16, 0.17))
	var sp: Material = MeshKit.mat("SteelPlate")
	if sp is StandardMaterial3D:
		var d := (sp as StandardMaterial3D).duplicate() as StandardMaterial3D
		d.albedo_color = Color(0.66, 0.5, 0.4)                        # worn, rusty inside
		_inner = d
	else:
		_inner = MeshKit.flat(Color(0.3, 0.24, 0.2))

static func _r_at(y: float, inner := false) -> float:
	var t := clampf(y / H, 0.0, 1.0)
	return lerpf(R0, R1, t) - (WALL if inner else 0.0)

## The bucket: Node3D "bucket" with meta "fill" (the holder the contents are drawn into). Origin: the middle of the base, on the ground.
static func build() -> Node3D:
	_mats()
	var n := Node3D.new()
	n.name = "bucket"
	var mp: Variant = _meshy_part()
	if mp != null:
		var mroot := Node3D.new()
		mroot.name = "Body"
		n.add_child(mroot)
		var mi := MeshInstance3D.new()
		mi.mesh = mp["mesh"]
		mi.transform = mp["xf"]
		mroot.add_child(mi)
		var mfill := Node3D.new()
		mfill.name = "Fill"
		n.add_child(mfill)
		n.set_meta("fill", mfill)
		return n
	var seg := 10
	var outer := MeshKit.Soup.new()
	var inner := MeshKit.Soup.new()
	var rim := MeshKit.Soup.new()
	var i0 := R0 - WALL
	var i1 := R1 - WALL
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var c0 := Vector2(cos(a0), sin(a0))
		var c1 := Vector2(cos(a1), sin(a1))
		outer.quad(Vector3(c0.x * R0, 0, c0.y * R0), Vector3(c1.x * R0, 0, c1.y * R0), Vector3(c1.x * R1, H, c1.y * R1), Vector3(c0.x * R1, H, c0.y * R1))               # the outer wall
		inner.quad(Vector3(c0.x * i0, FLOOR_Y, c0.y * i0), Vector3(c0.x * i1, H, c0.y * i1), Vector3(c1.x * i1, H, c1.y * i1), Vector3(c1.x * i0, FLOOR_Y, c1.y * i0))        # the inside, facing in
		inner.tri(Vector3(0, FLOOR_Y, 0), Vector3(c1.x * i0, FLOOR_Y, c1.y * i0), Vector3(c0.x * i0, FLOOR_Y, c0.y * i0))                                                      # the floor inside
		outer.tri(Vector3(0, 0, 0), Vector3(c0.x * R0, 0, c0.y * R0), Vector3(c1.x * R0, 0, c1.y * R0))                                                                         # the underside
		rim.quad(Vector3(c0.x * i1, H, c0.y * i1), Vector3(c0.x * R1, H, c0.y * R1), Vector3(c1.x * R1, H, c1.y * R1), Vector3(c1.x * i1, H, c1.y * i1))                       # the lip
	var lip := []
	for k in range(seg + 1):
		var a := TAU * k / seg
		lip.append(Vector3(cos(a) * (R1 + 0.004), H + 0.004, sin(a) * (R1 + 0.004)))
	MeshKit.tube_into(rim, lip, 0.013, 4)                                                      # the rolled rim
	for y in [0.12, 0.23]:                                                                     # two pressed ribs
		var ring := []
		for k in range(seg + 1):
			var a2 := TAU * k / seg
			ring.append(Vector3(cos(a2) * (_r_at(y) + 0.004), y, sin(a2) * (_r_at(y) + 0.004)))
		MeshKit.tube_into(outer, ring, 0.009, 3)
	var base_ring := []
	for k in range(seg + 1):
		var a3 := TAU * k / seg
		base_ring.append(Vector3(cos(a3) * (R0 + 0.005), 0.014, sin(a3) * (R0 + 0.005)))
	MeshKit.tube_into(rim, base_ring, 0.014, 3)
	var bail := MeshKit.Soup.new()
	var pts := []
	for i in range(0, 9):
		var a4 := PI * i / 8.0
		pts.append(Vector3(cos(a4) * (R1 + 0.01), H - 0.01 + sin(a4) * 0.19, 0.0))
	MeshKit.tube_into(bail, pts, 0.01, 4)
	for sx in [-1.0, 1.0]:
		MeshKit.box_into(rim, Vector3(sx * (R1 + 0.012), H - 0.015, 0.0), Vector3(0.03, 0.04, 0.05))     # the ears
	var root := Node3D.new()
	root.name = "Body"
	n.add_child(root)
	MeshKit.inst(root, outer.mesh(), _steel)
	MeshKit.inst(root, inner.mesh(), _inner)
	MeshKit.inst(root, rim.mesh(), _rim)
	MeshKit.inst(root, bail.mesh(), _handle)
	var fill := Node3D.new()
	fill.name = "Fill"
	n.add_child(fill)
	n.set_meta("fill", fill)
	return n

## The Meshy pail's mesh and the transform that stands it on y = 0, centred, at MESHY_S; null when the file is missing.
static func _meshy_part() -> Variant:
	if _meshy_cache.has("p"):
		return _meshy_cache["p"]
	var out: Variant = null
	if ResourceLoader.exists(MESHY):
		var src := (load(MESHY) as PackedScene).instantiate() as Node3D
		for m in src.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			var t := Transform3D()
			var cur: Node = mi
			while cur != null and cur != src and cur is Node3D:
				t = (cur as Node3D).transform * t
				cur = cur.get_parent()
			var ab: AABB = t * mi.mesh.get_aabb()
			var c := ab.get_center()
			out = {"mesh": mi.mesh, "xf": Transform3D(Basis.from_scale(Vector3.ONE * MESHY_S), Vector3(-c.x, -ab.position.y, -c.z) * MESHY_S) * t}
			break
		src.free()
	_meshy_cache["p"] = out
	return out

# ------------------------------------------------------------------ contents

static func kind_of(res: String) -> String:
	if res in ["gravel", "crushed_stone"]:
		return "gravel"
	return PileModels.kind_of(res)

static func total_of(load: Dictionary) -> int:
	var n := 0
	for k in load:
		n += int(load[k])
	return n

static func _sig(load: Dictionary, cap: int) -> String:
	var keys := load.keys()
	keys.sort()
	var s := str(cap)
	for k in keys:
		s += "|%s:%d" % [str(k), int(load[k])]
	return s

## Draws what the bucket holds. `model` is the node build() returned. Does nothing when the load is unchanged.
static func set_load(model: Node3D, load: Dictionary, cap: int) -> void:
	if model == null or not model.has_meta("fill"):
		return
	var fill: Node3D = model.get_meta("fill")
	var sig := _sig(load, cap)
	if fill.has_meta("sig") and fill.get_meta("sig") == sig:
		return
	fill.set_meta("sig", sig)
	for c in fill.get_children():
		fill.remove_child(c)
		c.queue_free()
	var total := total_of(load)
	if total <= 0 or cap <= 0:
		return
	var frac := clampf(float(total) / float(cap), 0.0, 1.0)
	var top_y := FLOOR_Y + (H - 0.03 - FLOOR_Y) * frac + 0.01                         # the surface level: the bottom of the pail up to just under the rim
	var order := load.keys()
	order.sort_custom(func(a, b): return int(load[a]) > int(load[b]))
	var layers := []                                                                   # [resource, from_y, to_y], the biggest share at the bottom
	var y := FLOOR_Y
	for r in order:
		if int(load[r]) <= 0:
			continue
		var ny := y + (top_y - FLOOR_Y) * float(int(load[r])) / float(total)
		layers.append([str(r), y, ny])
		y = ny
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + total
	for li in layers.size():
		var res: String = layers[li][0]
		var y0: float = layers[li][1]
		var y1: float = layers[li][2]
		var mat := MeshKit.mat(MATS.get(res, "ExcavatedDirt"))
		var slab := MeshKit.Soup.new()
		_slab(slab, y0 - 0.002, maxf(y1, y0 + 0.012))
		MeshKit.inst(fill, slab.mesh(), mat)
		if li == layers.size() - 1:
			_surface(fill, res, maxf(y1, y0 + 0.012), frac, rng, mat)

## A disc-shaped layer filling the inside of the pail between two heights.
static func _slab(s: MeshKit.Soup, y0: float, y1: float) -> void:
	var seg := 10
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var c0 := Vector2(cos(a0), sin(a0))
		var c1 := Vector2(cos(a1), sin(a1))
		var r0a := _r_at(y0, true) - 0.002
		var r1a := _r_at(y1, true) - 0.002
		s.quad(Vector3(c0.x * r0a, y0, c0.y * r0a), Vector3(c1.x * r0a, y0, c1.y * r0a), Vector3(c1.x * r1a, y1, c1.y * r1a), Vector3(c0.x * r1a, y1, c0.y * r1a))
		s.tri(Vector3(0, y1, 0), Vector3(c1.x * r1a, y1, c1.y * r1a), Vector3(c0.x * r1a, y1, c0.y * r1a))

## The top of the load, shaped like what it is: a soil mound, loose gravel, blocky rock chunks (ore chunks with the mineral showing).
static func _surface(fill: Node3D, res: String, y: float, frac: float, rng: RandomNumberGenerator, mat: Material) -> void:
	var kind := kind_of(res)
	var rr := _r_at(y, true) - 0.012
	var s := MeshKit.Soup.new()
	match kind:
		"dirt":
			MeshKit.inst(fill, PileModels.dirt_mesh(rr * 0.9, 0.035 + 0.08 * frac, int(rng.seed)), mat, Vector3(0, y - 0.004, 0))
		"gravel":
			for i in range(34):
				var a := rng.randf() * TAU
				var d := rr * sqrt(rng.randf()) * 0.95
				var sz := rng.randf_range(0.018, 0.034)
				PileModels.chunk_into(s, Vector3(cos(a) * d, y + sz * 0.15 + (0.012 + 0.02 * frac) * (1.0 - d / rr), sin(a) * d), Vector3(sz * 1.3, sz, sz * 1.2), rng)
			MeshKit.inst(fill, s.mesh(), mat)
		_:
			var count := 9 + int(5.0 * frac)
			for i in range(count):
				var a2 := rng.randf() * TAU
				var d2 := rr * sqrt(rng.randf()) * 0.82
				var sz2 := rng.randf_range(0.04, 0.075)
				PileModels.chunk_into(s, Vector3(cos(a2) * d2, y + sz2 * 0.25 + (0.03 + 0.05 * frac) * (1.0 - d2 / rr), sin(a2) * d2), Vector3(sz2 * 1.2, sz2 * 0.9, sz2 * 1.1), rng)
			MeshKit.inst(fill, s.mesh(), mat)
			if kind == "ore":
				var o := MeshKit.Soup.new()
				for j in range(5):
					var a3 := rng.randf() * TAU
					var d3 := rr * sqrt(rng.randf()) * 0.7
					var sz3 := rng.randf_range(0.022, 0.04)
					PileModels.chunk_into(o, Vector3(cos(a3) * d3, y + 0.05 + 0.04 * frac, sin(a3) * d3), Vector3(sz3 * 1.2, sz3, sz3), rng)
				MeshKit.inst(fill, o.mesh(), MeshKit.flat(QuarryTheme.RES_COLORS.get(res, Color(0.9, 0.7, 0.2)), 0.12))

## Old single-heap dressing: no longer used (the contents are drawn from what the bucket really holds, see set_load).
static func dress(_fill: Node3D, _frac: float, _tint: Color) -> void:
	pass

static func fraction_of(total: int, cap: int) -> float:
	if total <= 0 or cap <= 0:
		return 0.0
	var rem := total % cap
	return float(rem) / float(cap) if rem > 0 else 1.0

static func count_of(total: int, cap: int) -> int:
	return 0 if total <= 0 or cap <= 0 else (total + cap - 1) / cap
