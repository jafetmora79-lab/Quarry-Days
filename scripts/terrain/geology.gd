extends RefCounted
class_name QuarryGeology
## What lies under the quarry ground. A deterministic function (x, z, depth) -> material built from the game's own formation layout (so every resource stays exactly where
## the quarry puts it) plus the strata table in data/geology.json for ground outside any formation. Nothing is stored per vertex: the terrain stores only how deep it has been dug.
##
##   layers_at(x, z)        -> [[top_y, bottom_y, material_id], ...] from the surface down (cached per 2 m block)
##   material_at(x, z, y)   -> the natural material at absolute height y ("" above the surface)
##   props(id)              -> the material's data (hardness, repose, units_per_m3, sound set, ...)

const PATH := "res://data/geology.json"
const BLOCK := 2.0

static var _data := {}

var materials := {}                       ## id -> dictionary
var order: Array = []                     ## ids in shader slot order
var bed_y := -17.0
var natural_top := 0.0
var clay_below := 0.4
var prog                                  ## QuarryProgression or null (then only the default strata apply)
var _cache := {}
var _formations: Array = []

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data

func _init(p = null) -> void:
	var d := data()
	bed_y = float(d.get("bed_y", -17.0))
	natural_top = float(d.get("natural_top", 0.0))
	clay_below = float(d.get("clay_below", 0.4))
	for m in d["materials"]:
		materials[str(m["id"])] = m
		order.append(str(m["id"]))
	prog = p
	if prog != null:
		for id in prog.formation_ids():
			if str(prog.fdef(id).get("world", "")) == "filled" and not prog.is_arc(id):
				_formations.append(str(id))

func props(id: String) -> Dictionary:
	return materials.get(id, materials[order[0]])

## Material data without building a geology (for the audio table).
static func material_props(id: String) -> Dictionary:
	for m in data()["materials"]:
		if str(m["id"]) == id:
			return m
	return data()["materials"][0]

func index_of(id: String) -> int:
	return maxi(0, order.find(id))

func hardness(id: String) -> int:
	return int(props(id).get("hardness", 0))

## Material id for a game resource (topsoil -> "topsoil", crushed_stone -> "gravel").
func material_of_resource(res: String) -> String:
	for id in order:
		if str(materials[id]["resource"]) == res:
			return id
	return "gravel" if res == "crushed_stone" else "limestone"

func layers_at(x: float, z: float) -> Array:
	var key := Vector2i(int(floor(x / BLOCK)), int(floor(z / BLOCK)))
	if _cache.has(key):
		return _cache[key]
	var out := _compute(Vector3((float(key.x) + 0.5) * BLOCK, 0.0, (float(key.y) + 0.5) * BLOCK))
	_cache[key] = out
	return out

func _compute(p: Vector3) -> Array:
	var raw: Array = []                    # [top, bottom, id] from every formation column here
	for fid in _formations:
		var col: int = prog.cell_index_at(fid, p)
		if col < 0:
			continue
		var tiers: int = prog.column_tiers(fid, col)
		if tiers <= 0:
			continue
		var f: Dictionary = prog.fdef(fid)
		var bottom: float = prog.column_pos(fid, col).y
		var top: float = bottom + float(tiers) * float(f["tier_h"])
		raw.append([top, bottom, str(f["resource"])])
	if raw.is_empty():
		return _default_layers(p)
	raw.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	var cursor := natural_top
	for r in raw:
		var mid := material_of_resource(str(r[2]))
		var top: float = minf(float(r[0]), cursor)
		if top <= float(r[1]) + 0.0001:
			continue
		if top < cursor - 0.0001:                                  # a gap between formations: whatever limestone lies there
			out.append([cursor, top, "limestone"])
		if mid == "topsoil":                                       # the lower part of the topsoil is clay
			var clay_top := float(r[1]) + clay_below
			if top - float(r[1]) > clay_below + 0.2:
				out.append([top, clay_top, "topsoil"])
				out.append([clay_top, float(r[1]), "clay"])
			else:
				out.append([top, float(r[1]), "topsoil"])
		else:
			out.append([top, float(r[1]), mid])
		cursor = float(r[1])
	out.append_array(_deep_layers(p, cursor))                      # under the formations the rock is the bedrock with its ore bodies, not a plain slab
	return out

## Ground outside every formation: soil, clay and gravel of uneven thickness over limestone bedrock that carries localized ore bodies (see _deep_layers).
func _default_layers(p := Vector3.ZERO) -> Array:
	var out: Array = []
	var y := natural_top
	for s in data()["default_strata"]:
		var m := str(s["material"])
		if m != "topsoil" and m != "clay" and m != "gravel":
			break
		var t: float = float(s["thickness"]) * _thickness_factor(p, m)
		if t > 0.05:
			out.append([y, y - t, m])
			y -= t
	out.append_array(_deep_layers(p, y))
	return out

## Thickness variation of the loose layers: the topsoil thins and thickens, the clay comes and goes, the gravel lies in lenses.
func _thickness_factor(p: Vector3, m: String) -> float:
	match m:
		"topsoil": return 0.65 + 0.7 * _vnoise(p.x / 9.0, p.z / 9.0, 11)
		"clay": return 0.2 + 1.4 * _vnoise(p.x / 7.0, p.z / 7.0, 12)
		_: return 0.15 + 1.6 * _vnoise(p.x / 11.0, p.z / 11.0, 13)

## The bedrock under `from_y`: limestone with ore BODIES in it, each one a lens of limited extent (a broad thin coal seam, a pocket of iron, a narrow tilted copper vein, a rare gold
## pocket deep down), not a floor-to-floor cake. Which bodies lie where comes from a seeded hash of the ground, so it is the same everywhere in every game. Order of priority when two
## overlap: gold, copper, iron, coal.
const BODIES := [
	{"mat": "gold_ore", "grid": 19.0, "prob": 0.5, "rx": [3.0, 6.5], "rz": [3.0, 6.5], "thick": [1.6, 3.2], "depth": [-14.0, -12.0], "salt": 40},
	{"mat": "copper_ore", "grid": 21.0, "prob": 0.7, "rx": [2.5, 4.0], "rz": [10.0, 17.0], "thick": [1.4, 2.6], "depth": [-12.5, -9.0], "salt": 30},
	{"mat": "iron_ore", "grid": 20.0, "prob": 0.75, "rx": [5.0, 9.0], "rz": [4.5, 8.0], "thick": [1.8, 3.2], "depth": [-10.0, -6.0], "salt": 20},
	{"mat": "coal", "grid": 28.0, "prob": 0.85, "rx": [11.0, 20.0], "rz": [7.0, 13.0], "thick": [0.9, 2.2], "depth": [-7.0, -3.6], "salt": 10},
]

func _deep_layers(p: Vector3, from_y: float) -> Array:
	var spans: Array = []                                           # [top, bottom, id], highest priority first
	for b in BODIES:
		var best := _body_at(p, b)
		if best.is_empty():
			continue
		var top: float = minf(float(best[0]), from_y)
		var bottom: float = maxf(float(best[1]), bed_y)
		if top - bottom < 0.15:
			continue
		spans.append([top, bottom, str(b["mat"])])
	# resolve overlaps in priority order: what a better ore already holds, the next one does not take
	var taken: Array = []
	var placed: Array = []
	for sp in spans:
		var segs: Array = [[float(sp[0]), float(sp[1])]]
		for t in taken:
			var nxt: Array = []
			for sg in segs:
				if sg[1] >= t[0] or sg[0] <= t[1]:
					nxt.append(sg)
				else:
					if sg[0] > t[0]:
						nxt.append([sg[0], t[0]])
					if sg[1] < t[1]:
						nxt.append([t[1], sg[1]])
			segs = nxt
		for sg in segs:
			if float(sg[0]) - float(sg[1]) >= 0.15:
				placed.append([sg[0], sg[1], sp[2]])
				taken.append([sg[0], sg[1]])
	placed.sort_custom(func(a, c): return a[0] > c[0])
	var out: Array = []
	var cursor := from_y
	for l in placed:
		if float(l[0]) < cursor - 0.0001:
			out.append([cursor, l[0], "limestone"])
		out.append(l)
		cursor = float(l[1])
	if cursor > bed_y + 0.0001:
		out.append([cursor, bed_y, "limestone"])
	return out

## The body of one kind that lies under (x, z): [top, bottom] or [].
func _body_at(p: Vector3, b: Dictionary) -> Array:
	var g: float = b["grid"]
	var gx := int(floor(p.x / g))
	var gz := int(floor(p.z / g))
	var best := 0.0
	var best_c := 0.0
	var salt: int = b["salt"]
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cx := gx + dx
			var cz := gz + dz
			if _h(cx, cz, salt) > float(b["prob"]):
				continue
			var ctr := Vector2((float(cx) + 0.15 + 0.7 * _h(cx, cz, salt + 1)) * g, (float(cz) + 0.15 + 0.7 * _h(cx, cz, salt + 2)) * g)
			var rx := lerpf(float(b["rx"][0]), float(b["rx"][1]), _h(cx, cz, salt + 3))
			var rz := lerpf(float(b["rz"][0]), float(b["rz"][1]), _h(cx, cz, salt + 4))
			var ang := _h(cx, cz, salt + 5) * PI
			var d := Vector2(p.x, p.z) - ctr
			var u := (d.x * cos(ang) + d.y * sin(ang)) / rx
			var v := (-d.x * sin(ang) + d.y * cos(ang)) / rz
			var q := u * u + v * v
			if q >= 1.0:
				continue
			var t := lerpf(float(b["thick"][0]), float(b["thick"][1]), _h(cx, cz, salt + 6)) * pow(1.0 - q, 0.6)
			t *= 0.75 + 0.5 * _vnoise(p.x / 4.0, p.z / 4.0, salt + 7)             # ragged edges: the lens is not a clean ellipse
			if t > best:
				best = t
				best_c = lerpf(float(b["depth"][0]), float(b["depth"][1]), _h(cx, cz, salt + 8)) + (_vnoise(p.x / 14.0, p.z / 14.0, salt + 9) - 0.5) * 1.2
	if best < 0.15:
		return []
	return [best_c + best * 0.5, best_c - best * 0.5]

## Seeded lattice hash in 0..1 (the same on every machine).
func _h(ix: int, iz: int, salt: int) -> float:
	var n: int = (ix * 73856093) ^ (iz * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(abs(n) % 10007) / 10007.0

## Smooth value noise in 0..1 at lattice scale 1.
func _vnoise(x: float, z: float, salt: int) -> float:
	var ix := int(floor(x))
	var iz := int(floor(z))
	var fx := x - float(ix)
	var fz := z - float(iz)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := lerpf(_h(ix, iz, salt), _h(ix + 1, iz, salt), fx)
	var c := lerpf(_h(ix, iz + 1, salt), _h(ix + 1, iz + 1, salt), fx)
	return lerpf(a, c, fz)

func material_at(x: float, z: float, y: float) -> String:
	for l in layers_at(x, z):
		if y <= float(l[0]) + 0.00001 and y >= float(l[1]) - 0.00001:
			return str(l[2])
	return ""

## The layer [top, bottom, id] that lies just under a natural surface at height y (the layer a spade would cut next).
func layer_below(x: float, z: float, y: float) -> Array:
	var last: Array = []
	for l in layers_at(x, z):
		last = l
		if y > float(l[1]) + 0.0001 and y <= float(l[0]) + 0.0001:
			return l
	if not last.is_empty() and y <= float(last[1]) + 0.0001:
		return [float(last[1]), bed_y, "limestone"]
	return [natural_top, bed_y, "limestone"]

## The natural material just under a surface that has been dug down to height y.
func material_below(x: float, z: float, y: float) -> String:
	return str(layer_below(x, z, y)[2])

func clear_cache() -> void:
	_cache.clear()
