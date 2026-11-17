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
		return _default_layers()
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
	if cursor > bed_y + 0.0001:
		out.append([cursor, bed_y, "limestone"])
	return out

func _default_layers() -> Array:
	var out: Array = []
	var y := natural_top
	for s in data()["default_strata"]:
		var t: float = float(s["thickness"])
		out.append([y, y - t, str(s["material"])])
		y -= t
	if y > bed_y:
		out.append([y, bed_y, "limestone"])
	return out

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
