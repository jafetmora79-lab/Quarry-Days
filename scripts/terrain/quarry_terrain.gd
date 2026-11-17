extends Node3D
class_name QuarryTerrain
## Real digging ground for the quarry: a heightfield of vertices CELL (0.5 m) apart over a rectangle of the world, grown out of the dig prototype (scripts/proto/dig_terrain.gd).
##
##  * NATURAL ground is not stored. Each vertex stores only how deep it has been dug (`dug`) and the LOOSE material lying on it (`loose[material]`, piles, dumped loads, broken rock).
##    What the natural ground is at any depth comes from QuarryGeology (the quarry's own formations plus data/geology.json).
##  * VOLUME is conserved. Every operation that removes ground returns exactly what it removed (m3 per material); every deposit adds exactly what it is given. total_volume() plus
##    everything carried stays constant. Slumping only moves material. The one exception is flatten() (construction), which reports what it created or removed.
##  * HARDNESS decides what a tool can do: a tool with max_hardness h can only take natural ground of hardness <= h. Anything harder reports `blocked_by` and takes nothing.
##    Loose material is always diggable. A "break" tool (pickaxe, hammer) turns hard natural ground into loose material in place (same volume), a "scoop" tool takes loose and soft ground.
##  * Meshes are 16 x 16-cell chunks (at most 3 rebuilt per frame); collision is one HeightMapShape3D per 32 x 32-cell block, refreshed at about 15 Hz for dirty blocks only.

const CELL := 0.5
const CHUNK := 16
const CCHUNK := 32
const AREA := CELL * CELL
const MAX_MATS := 8

var geo: QuarryGeology
var origin := Vector2.ZERO               ## world x, z of vertex (0, 0)
var cols := 0                            ## cells along x (a multiple of CCHUNK)
var rows := 0
var V := 0                               ## vertices per row (cols + 1)
var VR := 0                              ## vertex rows (rows + 1)
var ntop := PackedFloat32Array()         ## natural surface height of each vertex before any digging
var dug := PackedFloat32Array()          ## how much natural ground has been removed (m)
var lsum := PackedFloat32Array()         ## total loose thickness (m)
var loose: Array = []                    ## per material: PackedFloat32Array of loose thickness
var locked := PackedByteArray()
var body: StaticBody3D
var coll_shapes := {}                    ## Vector2i -> HeightMapShape3D
var chunk_nodes := {}
var dirty_chunks := {}
var dirty_coll := {}
var active := {}
var view_distance := 190.0               ## chunks beyond this distance from the camera are culled
var rebuilt_chunks := 0                  ## statistics for tests
var refreshed_shapes := 0
var material: ShaderMaterial
var _indices := PackedInt32Array()
var _coll_timer := 0.0
var _slope := PackedFloat32Array()       ## tan(repose) per material index

func setup(world_rect: Rect2, geology: QuarryGeology, natural_fn := Callable()) -> void:
	geo = geology
	origin = world_rect.position
	cols = int(ceil(world_rect.size.x / CELL / float(CCHUNK))) * CCHUNK
	rows = int(ceil(world_rect.size.y / CELL / float(CCHUNK))) * CCHUNK
	V = cols + 1
	VR = rows + 1
	var n := V * VR
	ntop.resize(n)
	dug.resize(n)
	lsum.resize(n)
	locked.resize(n)
	for m in range(MAX_MATS):
		var a := PackedFloat32Array()
		a.resize(n)
		loose.append(a)
	for j in range(VR):
		for i in range(V):
			var p := vertex_xz(i, j)
			ntop[j * V + i] = float(natural_fn.call(p.x, p.y)) if natural_fn.is_valid() else geo.natural_top
	_slope.resize(MAX_MATS)
	for m in range(MAX_MATS):
		var id: String = geo.order[mini(m, geo.order.size() - 1)]
		_slope[m] = tan(deg_to_rad(float(geo.props(id).get("repose", 36))))
	_build_indices()
	_build_material()
	body = StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.scale = Vector3(CELL, 1.0, CELL)
	body.set_meta("ground", true)
	add_child(body)
	for cz in range(rows / CCHUNK):
		for cx in range(cols / CCHUNK):
			var cs := CollisionShape3D.new()
			var sh := HeightMapShape3D.new()
			sh.map_width = CCHUNK + 1
			sh.map_depth = CCHUNK + 1
			cs.shape = sh
			cs.position = Vector3(origin.x / CELL + float(cx * CCHUNK) + CCHUNK * 0.5, 0.0, origin.y / CELL + float(cz * CCHUNK) + CCHUNK * 0.5)
			body.add_child(cs)
			coll_shapes[Vector2i(cx, cz)] = sh
			dirty_coll[Vector2i(cx, cz)] = true
	for cz in range(rows / CHUNK):
		for cx in range(cols / CHUNK):
			var mi := MeshInstance3D.new()
			mi.mesh = ArrayMesh.new()
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = view_distance                 # far chunks are not drawn: the 244 m plain costs what is in front of you
			mi.visibility_range_end_margin = 12.0
			add_child(mi)
			chunk_nodes[Vector2i(cx, cz)] = mi
			dirty_chunks[Vector2i(cx, cz)] = true

func _build_material() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/quarry_terrain.gdshader")
	for m in range(MAX_MATS):
		var id: String = geo.order[mini(m, geo.order.size() - 1)]
		var path := "res://assets/textures/%s.png" % str(geo.props(id).get("texture", "T_QD_ExcavatedDirt"))
		if ResourceLoader.exists(path):
			material.set_shader_parameter("tex%d" % m, load(path))

# ------------------------------------------------------------------ indexing and queries

func idx(i: int, j: int) -> int:
	return j * V + i

func vertex_xz(i: int, j: int) -> Vector2:
	return Vector2(origin.x + float(i) * CELL, origin.y + float(j) * CELL)

func vheight(k: int) -> float:
	return ntop[k] - dug[k] + lsum[k]

func vertex_pos(i: int, j: int) -> Vector3:
	var p := vertex_xz(i, j)
	return Vector3(p.x, vheight(j * V + i), p.y)

func in_bounds(x: float, z: float) -> bool:
	return x >= origin.x and z >= origin.y and x <= origin.x + float(cols) * CELL and z <= origin.y + float(rows) * CELL

## Natural surface height of the vertex now (above it lies the loose material).
func natural_y(k: int) -> float:
	return ntop[k] - dug[k]

func height_at(x: float, z: float) -> float:
	if not in_bounds(x, z):
		return geo.bed_y
	var gx := (x - origin.x) / CELL
	var gz := (z - origin.y) / CELL
	var i := mini(int(gx), cols - 1)
	var j := mini(int(gz), rows - 1)
	var fx := gx - float(i)
	var fz := gz - float(j)
	var h00 := vheight(idx(i, j))
	var h10 := vheight(idx(i + 1, j))
	var h01 := vheight(idx(i, j + 1))
	var h11 := vheight(idx(i + 1, j + 1))
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)

func vertex_at(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((p.x - origin.x) / CELL), 0, cols), clampi(roundi((p.z - origin.y) / CELL), 0, rows))

## The material id on top of vertex k: the dominant loose material, or the natural ground under it.
func top_material(k: int) -> String:
	if lsum[k] > 0.02:
		var best := 0
		var bv := -1.0
		for m in range(MAX_MATS):
			if loose[m][k] > bv:
				bv = loose[m][k]
				best = m
		return str(geo.order[mini(best, geo.order.size() - 1)])
	var i := k % V
	var j := k / V
	var p := vertex_xz(i, j)
	return geo.material_below(p.x, p.y, natural_y(k))

func material_at_point(p: Vector3) -> String:
	var v := vertex_at(p)
	return top_material(idx(v.x, v.y))

## Total of natural ground above bedrock plus all loose material (m3). Constant unless something digs, dumps, or flattens.
func total_volume() -> float:
	var s := 0.0
	for k in range(V * VR):
		s += ntop[k] - geo.bed_y - dug[k] + lsum[k]
	return s * AREA

func loose_volume(mat: String = "") -> float:
	var s := 0.0
	if mat == "":
		for k in range(V * VR):
			s += lsum[k]
	else:
		var a: PackedFloat32Array = loose[geo.index_of(mat)]
		for k in range(V * VR):
			s += a[k]
	return s * AREA

# ------------------------------------------------------------------ taking and putting material

func _take_loose(k: int, t: float, into: Dictionary) -> float:
	var have := lsum[k]
	if have <= 0.000001 or t <= 0.0:
		return 0.0
	var take := minf(t, have)
	var f := take / have
	for m in range(MAX_MATS):
		var a: PackedFloat32Array = loose[m]
		var part := a[k] * f
		if part > 0.0:
			a[k] = maxf(0.0, a[k] - part)
			var id: String = geo.order[mini(m, geo.order.size() - 1)]
			into[id] = float(into.get(id, 0.0)) + part
	lsum[k] = maxf(0.0, have - take)
	return take

## Takes natural ground off the top of vertex k, layer by layer, stopping at the first layer harder than max_hardness (reported in `blocked`).
func _take_natural(k: int, t: float, max_h: int, into: Dictionary, blocked: Array) -> float:
	var got := 0.0
	var i := k % V
	var j := k / V
	var p := vertex_xz(i, j)
	var left := t
	while left > 0.000001:
		var y := natural_y(k)
		if y <= geo.bed_y + 0.0001:
			break
		var layer: Array = geo.layer_below(p.x, p.y, y)
		var mid: String = str(layer[2])
		if geo.hardness(mid) > max_h:
			if blocked.is_empty():
				blocked.append(mid)
			break
		var step := minf(left, minf(y - maxf(float(layer[1]), geo.bed_y), y - geo.bed_y))
		if step <= 0.000001:
			break
		dug[k] += step
		into[mid] = float(into.get(mid, 0.0)) + step
		got += step
		left -= step
	return got

func _put_loose(k: int, mat: String, t: float) -> void:
	if t <= 0.0:
		return
	var m := geo.index_of(mat)
	var a: PackedFloat32Array = loose[m]
	a[k] += t
	lsum[k] += t

# ------------------------------------------------------------------ digging

func _result() -> Dictionary:
	return {"taken": {}, "volume": 0.0, "broken": 0.0, "blocked_by": "", "hit": ""}

func _add_taken(res: Dictionary, mats: Dictionary) -> void:
	for id in mats:
		var v: float = float(mats[id]) * AREA
		res["taken"][id] = float(res["taken"].get(id, 0.0)) + v
		res["volume"] = float(res["volume"]) + v

## A hand tool strike at p. Scoop: takes loose material and soft ground into the tool (returned in "taken", m3 per material). Break: turns natural ground the tool can
## break into loose material where it lies ("broken", m3), taking nothing. `blocked_by` names the material that stopped the tool (empty if none). `hit` is the material
## the strike landed on (for the sound).
func dig(p: Vector3, radius: float, depth: float, budget: float, max_hardness: int, mode := "scoop") -> Dictionary:
	var res := _result()
	var g := vertex_at(p)
	res["hit"] = top_material(idx(g.x, g.y))
	var reach := int(ceil(radius / CELL)) + 1
	var cand := []
	for j in range(maxi(0, g.y - reach), mini(VR - 1, g.y + reach) + 1):
		for i in range(maxi(0, g.x - reach), mini(V - 1, g.x + reach) + 1):
			var k := idx(i, j)
			if locked[k] != 0:
				continue
			var vp := vertex_xz(i, j)
			var d := Vector2(vp.x - p.x, vp.y - p.z).length()
			if d <= radius:
				cand.append([d, i, j])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var left := budget / AREA
	var blocked: Array = []
	for c in cand:
		if left <= 0.000001:
			break
		var i: int = c[1]
		var j: int = c[2]
		var k := idx(i, j)
		var mats := {}
		var took := 0.0
		if mode == "break":
			took = _take_natural(k, minf(depth, left), max_hardness, mats, blocked)
			for id in mats:
				_put_loose(k, str(id), float(mats[id]))
			res["broken"] = float(res["broken"]) + took * AREA
			left -= took
		else:
			took = _take_loose(k, minf(depth, left), mats)
			if took < minf(depth, left) - 0.000001:
				took += _take_natural(k, minf(depth, left) - took, max_hardness, mats, blocked)
			_add_taken(res, mats)
			left -= took
		if took > 0.0:
			_dirty_vertex(i, j)
	if not blocked.is_empty() and float(res["volume"]) + float(res["broken"]) <= 0.000001:
		res["blocked_by"] = blocked[0]
	elif not blocked.is_empty():
		res["blocked_by"] = blocked[0]                       # it dug something, then reached rock
	return res

## A loader bucket: cuts everything inside a rectangle in front of the lip down to the lip's height (never deeper), at most `budget` m3.
func cut_box(lip: Vector3, right: Vector3, fwd: Vector3, half_width: float, back: float, ahead: float, budget: float, max_hardness: int, loose_only := false) -> Dictionary:
	var res := _result()
	if budget <= 0.0:
		return res
	var g := vertex_at(lip)
	res["hit"] = top_material(idx(g.x, g.y))
	var reach := int(ceil((half_width + maxf(back, ahead)) / CELL)) + 1
	var left := budget / AREA
	var blocked: Array = []
	for j in range(maxi(0, g.y - reach), mini(VR - 1, g.y + reach) + 1):
		for i in range(maxi(0, g.x - reach), mini(V - 1, g.x + reach) + 1):
			var k := idx(i, j)
			if locked[k] != 0 or left <= 0.000001:
				continue
			var vp := vertex_pos(i, j)
			var rel := Vector3(vp.x - lip.x, 0.0, vp.z - lip.z)
			var u := rel.dot(right)
			var v := rel.dot(fwd)
			if absf(u) > half_width or v < -back or v > ahead:
				continue
			var h := vheight(k)
			var target := maxf(lip.y, geo.bed_y)
			if h <= target + 0.0005:
				continue
			var mats := {}
			var want := minf(h - target, left)
			var took := _take_loose(k, want, mats)
			if not loose_only and took < want - 0.000001:
				took += _take_natural(k, want - took, max_hardness, mats, blocked)
			_add_taken(res, mats)
			left -= took
			if took > 0.0:
				_dirty_vertex(i, j)
	if not blocked.is_empty():
		res["blocked_by"] = blocked[0]
	return res

## Adds exactly the given volumes (m3 per material) as a soft mound centred at p. Returns what could not be placed (all vertices locked).
func deposit(p: Vector3, radius: float, volumes: Dictionary) -> Dictionary:
	var total := 0.0
	for id in volumes:
		total += float(volumes[id])
	if total <= 0.0:
		return {}
	var g := vertex_at(p)
	var reach := int(ceil(radius / CELL)) + 1
	var cells := []
	var wsum := 0.0
	for j in range(maxi(0, g.y - reach), mini(VR - 1, g.y + reach) + 1):
		for i in range(maxi(0, g.x - reach), mini(V - 1, g.x + reach) + 1):
			var k := idx(i, j)
			if locked[k] != 0:
				continue
			var vp := vertex_xz(i, j)
			var d := Vector2(vp.x - p.x, vp.y - p.z).length()
			if d < radius:
				var w := 1.0 - (d * d) / (radius * radius)
				cells.append([i, j, w])
				wsum += w
	if cells.is_empty() or wsum <= 0.0:
		return volumes.duplicate()
	for id in volumes:
		var per := float(volumes[id]) / AREA / wsum
		for c in cells:
			_put_loose(idx(c[0], c[1]), str(id), per * float(c[2]))
	for c in cells:
		_dirty_vertex(c[0], c[1])
	return {}

## Adds a cone-shaped pile of one material (used for scenery and spoil heaps).
func add_pile(cx: float, cz: float, radius: float, height: float, mat: String, lumpy := 0.0) -> void:
	var g := vertex_at(Vector3(cx, 0.0, cz))
	var reach := int(ceil(radius / CELL)) + 1
	for j in range(maxi(0, g.y - reach), mini(VR - 1, g.y + reach) + 1):
		for i in range(maxi(0, g.x - reach), mini(V - 1, g.x + reach) + 1):
			var k := idx(i, j)
			if locked[k] != 0:
				continue
			var vp := vertex_xz(i, j)
			var d := Vector2(vp.x - cx, vp.y - cz).length()
			if d >= radius:
				continue
			var lump := 1.0 + lumpy * sin(vp.x * 1.7 + vp.y * 0.9) * cos(vp.y * 1.3 - vp.x * 0.4)
			_put_loose(k, mat, maxf(0.0, height * (1.0 - d / radius) * lump))
			_dirty_vertex(i, j)

# ------------------------------------------------------------------ structures and locks

func lock_rect(r: Rect2, margin := 0.0) -> void:
	_set_lock(r.grow(margin), 1)

func unlock_rect(r: Rect2, margin := 0.0) -> void:
	_set_lock(r.grow(margin), 0)

func lock_ring(n: int) -> void:
	for j in range(VR):
		for i in range(V):
			if mini(mini(i, V - 1 - i), mini(j, VR - 1 - j)) < n:
				locked[idx(i, j)] = 1

func _set_lock(r: Rect2, v: int) -> void:
	for j in range(VR):
		var z := origin.y + float(j) * CELL
		if z < r.position.y or z > r.end.y:
			continue
		for i in range(V):
			var x := origin.x + float(i) * CELL
			if x >= r.position.x and x <= r.end.x:
				locked[idx(i, j)] = v

func is_locked_at(x: float, z: float) -> bool:
	if not in_bounds(x, z):
		return true
	var g := vertex_at(Vector3(x, 0.0, z))
	return locked[idx(g.x, g.y)] != 0

## Levels a footprint to height y (the natural ground and any loose material under a structure are replaced by a flat pad) and locks it. Returns the volume change in m3
## (positive = ground was added): construction is the one thing that is allowed to create or remove ground.
func flatten(r: Rect2, y: float, lock := true) -> float:
	var before := 0.0
	var after := 0.0
	for j in range(VR):
		var z := origin.y + float(j) * CELL
		if z < r.position.y or z > r.end.y:
			continue
		for i in range(V):
			var x := origin.x + float(i) * CELL
			if x < r.position.x or x > r.end.x:
				continue
			var k := idx(i, j)
			before += vheight(k)
			for m in range(MAX_MATS):
				loose[m][k] = 0.0
			lsum[k] = 0.0
			dug[k] = maxf(0.0, ntop[k] - y)
			if ntop[k] < y:
				ntop[k] = y
				dug[k] = 0.0
			after += vheight(k)
			if lock:
				locked[k] = 1
			_dirty_vertex(i, j)
	return (after - before) * AREA

# ------------------------------------------------------------------ slumping (angle of repose)

func _dirty_vertex(i: int, j: int) -> void:
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var a := i + di
			var b := j + dj
			if a >= 0 and b >= 0 and a < V and b < VR:
				active[idx(a, b)] = true
	for dj in [-1, 0]:
		for di in [-1, 0]:
			var a: int = i + di
			var b: int = j + dj
			if a >= 0 and b >= 0:
				var ci: int = a / CHUNK
				var cj: int = b / CHUNK
				if ci < cols / CHUNK and cj < rows / CHUNK:
					dirty_chunks[Vector2i(ci, cj)] = true
					_nav_stale[Vector2i(ci, cj)] = true
				var ki: int = a / CCHUNK
				var kj: int = b / CCHUNK
				if ki < cols / CCHUNK and kj < rows / CCHUNK:
					dirty_coll[Vector2i(ki, kj)] = true

const NEIGH := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

func _dominant_loose(k: int) -> int:
	var best := 0
	var bv := -1.0
	for m in range(MAX_MATS):
		if loose[m][k] > bv:
			bv = loose[m][k]
			best = m
	return best

## Lets steep loose material and soft ground slump downhill. Only moves material (volume is conserved). Hard natural ground never slumps.
## Processes at most `budget` vertices; returns how many are still waiting.
func relax(budget := 700) -> int:
	var done := 0
	for k in active.keys():
		if done >= budget:
			break
		active.erase(k)
		done += 1
		if locked[k] != 0:
			continue
		var i: int = k % V
		var j: int = k / V
		var h := vheight(k)
		var moved := false
		for d in NEIGH:
			var a: int = i + d.x
			var b: int = j + d.y
			if a < 0 or b < 0 or a >= V or b >= VR:
				continue
			var nk := idx(a, b)
			if locked[nk] != 0:
				continue
			var m: int
			if lsum[k] > 0.0001:
				m = _dominant_loose(k)
			else:
				var vp := vertex_xz(i, j)
				var nid := geo.material_below(vp.x, vp.y, natural_y(k))
				if geo.hardness(nid) > 0:
					break
				m = geo.index_of(nid)
			var dist := CELL * (1.4142 if d.x != 0 and d.y != 0 else 1.0)
			var excess := (h - vheight(nk)) - float(_slope[m]) * dist
			if excess <= 0.002:
				continue
			var amount := minf(excess * 0.25, 0.5)
			var mats := {}
			var took := _take_loose(k, amount, mats)
			if took < amount - 0.000001:
				took += _take_natural(k, amount - took, 0, mats, [])
			for id in mats:
				_put_loose(nk, str(id), float(mats[id]))
			h = vheight(k)
			if took > 0.0:
				moved = true
				_dirty_vertex(a, b)
		if moved:
			_dirty_vertex(i, j)
	return active.size()

# ------------------------------------------------------------------ meshes and collision

func _build_indices() -> void:
	_indices.clear()
	var w := CHUNK + 1
	for z in range(CHUNK):
		for x in range(CHUNK):
			var a := z * w + x
			var b := a + 1
			var c := a + w
			var d := c + 1
			_indices.append_array([a, b, c, b, d, c])

func _build_chunk(cx: int, cz: int) -> void:
	var w := CHUNK + 1
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	pos.resize(w * w)
	nor.resize(w * w)
	col.resize(w * w)
	uv.resize(w * w)
	uv2.resize(w * w)
	for z in range(w):
		for x in range(w):
			var i := cx * CHUNK + x
			var j := cz * CHUNK + z
			var k := idx(i, j)
			var xz := vertex_xz(i, j)
			pos[z * w + x] = Vector3(xz.x, vheight(k), xz.y)
			var hl := vheight(idx(maxi(i - 1, 0), j))
			var hr := vheight(idx(mini(i + 1, cols), j))
			var hu := vheight(idx(i, maxi(j - 1, 0)))
			var hd := vheight(idx(i, mini(j + 1, rows)))
			nor[z * w + x] = Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
			var wts := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
			wts[geo.index_of(top_material(k))] = 1.0
			col[z * w + x] = Color(wts[0], wts[1], wts[2], wts[3])
			uv[z * w + x] = Vector2(wts[4], wts[5])
			uv2[z * w + x] = Vector2(wts[6], wts[7])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh: ArrayMesh = chunk_nodes[Vector2i(cx, cz)].mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(origin.x + float(cx * CHUNK) * CELL, geo.bed_y, origin.y + float(cz * CHUNK) * CELL), Vector3(CHUNK * CELL, 24.0, CHUNK * CELL))
	rebuilt_chunks += 1

func _update_shape(key: Vector2i) -> void:
	var data := PackedFloat32Array()
	var w := CCHUNK + 1
	data.resize(w * w)
	for z in range(w):
		for x in range(w):
			data[z * w + x] = vheight(idx(key.x * CCHUNK + x, key.y * CCHUNK + z))
	(coll_shapes[key] as HeightMapShape3D).map_data = data
	refreshed_shapes += 1

# ------------------------------------------------------------------ navigation

const NAV_STEP := 2                               ## the navigation surface samples every 2nd vertex (1 m): the agents are 1 m wide
var _nav_cache := {}                              ## chunk -> PackedVector3Array of its triangles (rebuilt only when the chunk changed)
var _nav_stale := {}

## Adds the terrain's walkable surface to a navigation bake: one cached triangle list per chunk, only the changed chunks are rebuilt, so collecting costs a few milliseconds.
## Returns how many chunks were added.
func collect_nav(src: NavigationMeshSourceGeometryData3D) -> int:
	var n := 0
	for key in chunk_nodes.keys():
		if _nav_stale.has(key) or not _nav_cache.has(key):
			_nav_cache[key] = _nav_faces(key.x, key.y)
			_nav_stale.erase(key)
		src.add_faces(_nav_cache[key], Transform3D.IDENTITY)
		n += 1
	return n

func _nav_faces(cx: int, cz: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for z in range(0, CHUNK, NAV_STEP):
		for x in range(0, CHUNK, NAV_STEP):
			var i := cx * CHUNK + x
			var j := cz * CHUNK + z
			var i2 := mini(i + NAV_STEP, cols)
			var j2 := mini(j + NAV_STEP, rows)
			var a := vertex_pos(i, j)
			var b := vertex_pos(i2, j)
			var c := vertex_pos(i2, j2)
			var d := vertex_pos(i, j2)
			out.append(a)
			out.append(b)
			out.append(c)
			out.append(a)
			out.append(c)
			out.append(d)
	return out

## Applies pending changes: slump a little, rebuild a few chunks, refresh dirty collision blocks at about 15 Hz. `force` does everything now (tests, start-up).
func flush(force := false) -> void:
	if force:
		while active.size() > 0:
			relax(100000)
		for key in dirty_chunks.keys():
			_build_chunk(key.x, key.y)
		dirty_chunks.clear()
		for key in dirty_coll.keys():
			_update_shape(key)
		dirty_coll.clear()
		return
	var left := 3
	for key in dirty_chunks.keys():
		if left <= 0:
			break
		_build_chunk(key.x, key.y)
		dirty_chunks.erase(key)
		left -= 1
	if not dirty_coll.is_empty() and _coll_timer <= 0.0:
		for key in dirty_coll.keys():
			_update_shape(key)
		dirty_coll.clear()
		_coll_timer = 0.066

func _physics_process(delta: float) -> void:
	_coll_timer -= delta
	if active.size() > 0:
		relax(700)
	flush()

# ------------------------------------------------------------------ saving

## Only what changed: vertex indices with their dug depth and loose material, compressed. Old saves have none and load as untouched ground.
func snapshot() -> Dictionary:
	var idxs := PackedInt32Array()
	for k in range(V * VR):
		if dug[k] > 0.00001 or lsum[k] > 0.00001:
			idxs.append(k)
	var dugs := PackedFloat32Array()
	var lo := PackedFloat32Array()
	for k in idxs:
		dugs.append(dug[k])
		for m in range(MAX_MATS):
			lo.append(loose[m][k])
	var raw := var_to_bytes({"i": idxs, "d": dugs, "l": lo})
	return {"v": 1, "size": raw.size(), "origin": [origin.x, origin.y], "cells": [cols, rows], "data": Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_ZSTD))}

func restore(snap: Dictionary) -> bool:
	if snap.is_empty() or int(snap.get("v", 0)) != 1:
		return false
	var cells: Array = snap.get("cells", [])
	if cells.size() != 2 or int(cells[0]) != cols or int(cells[1]) != rows:
		return false
	for k in range(V * VR):
		dug[k] = 0.0
		lsum[k] = 0.0
		for m in range(MAX_MATS):
			loose[m][k] = 0.0
	var raw := Marshalls.base64_to_raw(str(snap["data"])).decompress(int(snap["size"]), FileAccess.COMPRESSION_ZSTD)
	var d: Dictionary = bytes_to_var(raw)
	var idxs: PackedInt32Array = d["i"]
	var dugs: PackedFloat32Array = d["d"]
	var lo: PackedFloat32Array = d["l"]
	for n in range(idxs.size()):
		var k: int = idxs[n]
		dug[k] = dugs[n]
		var s := 0.0
		for m in range(MAX_MATS):
			var v: float = lo[n * MAX_MATS + m]
			loose[m][k] = v
			s += v
		lsum[k] = s
	for key in chunk_nodes.keys():
		dirty_chunks[key] = true
	for key in coll_shapes.keys():
		dirty_coll[key] = true
	active.clear()
	return true
