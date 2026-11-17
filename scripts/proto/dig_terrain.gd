extends Node3D
class_name DigTerrain
## PROTOTYPE: deformable quarry ground for MudRunner-style digging.
##
## The ground is a heightfield of vertices 0.5 m apart. Each vertex stores two layer thicknesses (dirt, rock)
## above a fixed bedrock. Digging removes thickness (volume) from vertices and hands it to whoever digs;
## dumping adds exactly that volume back. Nothing is created or destroyed, so total_volume() of the terrain
## plus everything being carried is constant. Piles slump toward an angle of repose, again moving material
## (never making it). Visuals are a chunked mesh; collision is a HeightMapShape3D that follows the ground.

const CELL := 0.5
const CHUNK := 16                      # cells per chunk side
const BEDROCK := -2.0                  # undiggable floor (metres)
const AREA := CELL * CELL              # m2 of ground each vertex stands for
const DIRT_SLOPE := 0.72               # tan(angle of repose): dirt ~36 deg
const ROCK_SLOPE := 1.15               # broken rock ~49 deg

var N := 80                            # cells per side (40 m x 40 m)
var V := 81                            # vertices per side
var base := PackedFloat32Array()       # undisturbed natural ground (dirt); dug only after loose material
var dirt := PackedFloat32Array()       # loose dirt on top (piles, dumped loads)
var rock := PackedFloat32Array()       # loose rock on top
var locked := PackedByteArray()        # perimeter berm: neither dug nor slumped
var body: StaticBody3D
var shape: HeightMapShape3D
var chunk_nodes := {}
var dirty_chunks := {}
var collision_dirty := false
var active := {}                       # vertices that may still slump
var _collision_timer := 0.0
var _indices := PackedInt32Array()
var material: ShaderMaterial
var rebuilt_chunks := 0                # statistics for tests

func setup(n := 80) -> void:
	N = n
	V = n + 1
	base.resize(V * V)
	dirt.resize(V * V)
	rock.resize(V * V)
	locked.resize(V * V)
	for k in range(V * V):
		base[k] = -BEDROCK                  # flat ground at y = 0
		dirt[k] = 0.0
		rock[k] = 0.0
	_build_berm()
	_build_indices()
	material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/dig_terrain.gdshader")
	material.set_shader_parameter("dirt_tex", load("res://assets/textures/T_QD_ExcavatedDirt.png"))
	material.set_shader_parameter("rock_tex", load("res://assets/textures/T_QD_RockLimestone.png"))
	body = StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.scale = Vector3(CELL, 1.0, CELL)       # one heightmap sample = one vertex = CELL metres
	add_child(body)
	var cs := CollisionShape3D.new()
	shape = HeightMapShape3D.new()
	shape.map_width = V
	shape.map_depth = V
	cs.shape = shape
	body.add_child(cs)
	for cz in range(N / CHUNK):
		for cx in range(N / CHUNK):
			var mi := MeshInstance3D.new()
			mi.mesh = ArrayMesh.new()
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			chunk_nodes[Vector2i(cx, cz)] = mi
			dirty_chunks[Vector2i(cx, cz)] = true
	collision_dirty = true
	flush(true)

# ------------------------------------------------------------------ indexing and queries

func idx(i: int, j: int) -> int:
	return j * V + i

func vheight(k: int) -> float:
	return BEDROCK + base[k] + dirt[k] + rock[k]

func _loose_rock_ratio(k: int) -> float:
	var loose := dirt[k] + rock[k]
	return rock[k] / loose if loose > 0.02 else 0.0

## Removes `t` m of material from vertex k: loose material first (mixed as it lies), then natural ground.
## Returns Vector2(dirt_thickness, rock_thickness) actually taken.
func _take(k: int, t: float) -> Vector2:
	var loose := dirt[k] + rock[k]
	var from_loose := minf(t, loose)
	var r := 0.0
	var d := 0.0
	if loose > 0.00001:
		r = from_loose * rock[k] / loose
		d = from_loose - r
	rock[k] = maxf(0.0, rock[k] - r)
	dirt[k] = maxf(0.0, dirt[k] - d)
	var from_base := minf(maxf(0.0, t - from_loose), base[k])
	base[k] -= from_base
	return Vector2(d + from_base, r)

func vertex_pos(i: int, j: int) -> Vector3:
	return Vector3((i - N * 0.5) * CELL, vheight(idx(i, j)), (j - N * 0.5) * CELL)

func to_grid(p: Vector3) -> Vector2:
	var l := to_local(p)
	return Vector2(l.x / CELL + N * 0.5, l.z / CELL + N * 0.5)

## Ground height under world x,z (bilinear between vertices). Outside the field: BEDROCK.
func height_at(x: float, z: float) -> float:
	var g := to_grid(Vector3(x, 0, z))
	if g.x < 0 or g.y < 0 or g.x > N or g.y > N:
		return BEDROCK
	var i := mini(int(g.x), N - 1)
	var j := mini(int(g.y), N - 1)
	var fx := g.x - i
	var fz := g.y - j
	var h00 := vheight(idx(i, j))
	var h10 := vheight(idx(i + 1, j))
	var h01 := vheight(idx(i, j + 1))
	var h11 := vheight(idx(i + 1, j + 1))
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)

func rock_ratio_at(x: float, z: float) -> float:
	var g := to_grid(Vector3(x, 0, z))
	var i := clampi(roundi(g.x), 0, N)
	var j := clampi(roundi(g.y), 0, N)
	return _loose_rock_ratio(idx(i, j))

## Total loose material in the field (m3). Constant unless something digs or dumps.
func total_volume() -> float:
	var s := 0.0
	for k in range(V * V):
		s += base[k] + dirt[k] + rock[k]
	return s * AREA

func total_split() -> Vector2:
	var d := 0.0
	var r := 0.0
	for k in range(V * V):
		d += base[k] + dirt[k]
		r += rock[k]
	return Vector2(d, r) * AREA

# ------------------------------------------------------------------ initial layout

func _build_berm() -> void:
	# A two-vertex locked wall around the arena (rock berm), with a ramp on the inside.
	for j in range(V):
		for i in range(V):
			var edge := mini(mini(i, V - 1 - i), mini(j, V - 1 - j))
			var k := idx(i, j)
			if edge <= 1:
				locked[k] = 1
				rock[k] = 3.2
			elif edge == 2:
				rock[k] = 1.5
			elif edge == 3:
				rock[k] = 0.6

## Adds a cone-shaped pile of `kind` ("dirt"/"rock") at world x,z with the given radius and height.
func add_pile(cx: float, cz: float, radius: float, height: float, kind: String, lumpy := 0.0) -> void:
	for j in range(V):
		for i in range(V):
			var p := Vector3((i - N * 0.5) * CELL, 0, (j - N * 0.5) * CELL)
			var d := Vector2(p.x - cx, p.z - cz).length()
			if d >= radius:
				continue
			var t := 1.0 - d / radius
			var lump := 1.0 + lumpy * sin(p.x * 1.7 + p.z * 0.9) * cos(p.z * 1.3 - p.x * 0.4)
			var add := height * t * lump
			var k := idx(i, j)
			if locked[k]:
				continue
			if kind == "rock":
				rock[k] += maxf(0.0, add)
			else:
				dirt[k] += maxf(0.0, add)
			_dirty_vertex(i, j)

# ------------------------------------------------------------------ digging and dumping

## Cuts the ground inside a rectangle in front of a tool lip down to the lip's height.
## `lip`: world position of the cutting edge (centre); `right`/`fwd`: horizontal unit directions;
## `half_width`: tool half width; `back`/`ahead`: how far behind / in front of the lip counts.
## `budget`: max volume (m3) to remove this call. Returns {"dirt": m3, "rock": m3} actually removed.
func cut_box(lip: Vector3, right: Vector3, fwd: Vector3, half_width: float, back: float, ahead: float, budget: float) -> Dictionary:
	var out := {"dirt": 0.0, "rock": 0.0}
	if budget <= 0.0:
		return out
	var g := to_grid(lip)
	var reach := int(ceil((half_width + maxf(back, ahead)) / CELL)) + 1
	var ci := roundi(g.x)
	var cj := roundi(g.y)
	var left := budget / AREA                      # thickness budget (m summed over vertices)
	for j in range(maxi(0, cj - reach), mini(V - 1, cj + reach) + 1):
		for i in range(maxi(0, ci - reach), mini(V - 1, ci + reach) + 1):
			var k := idx(i, j)
			if locked[k] or left <= 0.0:
				continue
			var p := vertex_pos(i, j)
			var rel := Vector3(p.x - lip.x, 0, p.z - lip.z)
			var u := rel.dot(right)
			var v := rel.dot(fwd)
			if absf(u) > half_width or v < -back or v > ahead:
				continue
			var target := maxf(lip.y, BEDROCK)
			var h := vheight(k)
			if h <= target + 0.0005:
				continue
			var took := _take(k, minf(h - target, left))
			left -= took.x + took.y
			out["dirt"] += took.x * AREA
			out["rock"] += took.y * AREA
			_dirty_vertex(i, j)
	return out

## Round scoop for a hand shovel: removes up to `budget` m3 from vertices within `radius` of p,
## taking at most `depth` m off the top of each. Returns {"dirt", "rock"}.
func cut_disc(p: Vector3, radius: float, depth: float, budget: float) -> Dictionary:
	var out := {"dirt": 0.0, "rock": 0.0}
	var g := to_grid(p)
	var reach := int(ceil(radius / CELL)) + 1
	var ci := roundi(g.x)
	var cj := roundi(g.y)
	var left := budget / AREA
	# nearest vertices first so the hole is round and the budget is used where the player aims
	var cand := []
	for j in range(maxi(0, cj - reach), mini(V - 1, cj + reach) + 1):
		for i in range(maxi(0, ci - reach), mini(V - 1, ci + reach) + 1):
			var k := idx(i, j)
			if locked[k]:
				continue
			var vp := vertex_pos(i, j)
			var d := Vector2(vp.x - p.x, vp.z - p.z).length()
			if d <= radius:
				cand.append([d, i, j])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for c in cand:
		if left <= 0.0:
			break
		var i: int = c[1]
		var j: int = c[2]
		var k := idx(i, j)
		var t := minf(minf(depth, left), base[k] + dirt[k] + rock[k])
		if t <= 0.0:
			continue
		var took := _take(k, t)
		left -= took.x + took.y
		out["dirt"] += took.x * AREA
		out["rock"] += took.y * AREA
		_dirty_vertex(i, j)
	return out

## Adds exactly `volume` m3 (split dirt/rock by `rock_frac`) as a soft mound centred at p.
## Returns the volume that could not be placed (all vertices locked) so callers can keep it.
func deposit(p: Vector3, radius: float, volume: float, rock_frac: float) -> float:
	if volume <= 0.0:
		return 0.0
	var g := to_grid(p)
	var reach := int(ceil(radius / CELL)) + 1
	var ci := roundi(g.x)
	var cj := roundi(g.y)
	var cells := []
	var wsum := 0.0
	for j in range(maxi(0, cj - reach), mini(V - 1, cj + reach) + 1):
		for i in range(maxi(0, ci - reach), mini(V - 1, ci + reach) + 1):
			var k := idx(i, j)
			if locked[k]:
				continue
			var vp := vertex_pos(i, j)
			var d := Vector2(vp.x - p.x, vp.z - p.z).length()
			if d < radius:
				var w := 1.0 - (d * d) / (radius * radius)
				cells.append([i, j, w])
				wsum += w
	if cells.is_empty() or wsum <= 0.0:
		return volume
	var per := volume / AREA / wsum
	for c in cells:
		var k := idx(c[0], c[1])
		var t: float = per * c[2]
		rock[k] += t * rock_frac
		dirt[k] += t * (1.0 - rock_frac)
		_dirty_vertex(c[0], c[1])
	return 0.0

# ------------------------------------------------------------------ slumping (angle of repose)

func _dirty_vertex(i: int, j: int) -> void:
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var a := i + di
			var b := j + dj
			if a >= 0 and b >= 0 and a <= N and b <= N:
				active[idx(a, b)] = true
	# every chunk touching this vertex must be rebuilt (chunk edges share vertices)
	for dj in [-1, 0]:
		for di in [-1, 0]:
			var ci: int = (i + di) / CHUNK if i + di >= 0 else -1
			var cj: int = (j + dj) / CHUNK if j + dj >= 0 else -1
			if ci >= 0 and cj >= 0 and ci < N / CHUNK and cj < N / CHUNK:
				dirty_chunks[Vector2i(ci, cj)] = true
	collision_dirty = true

const NEIGH := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

## Lets steep ground slump downhill. Moves material between neighbours only (volume is conserved).
## Processes at most `budget` vertices; returns how many are still unstable.
func relax(budget := 700) -> int:
	var done := 0
	var keys := active.keys()
	for k in keys:
		if done >= budget:
			break
		active.erase(k)
		done += 1
		var i: int = k % V
		var j: int = k / V
		if locked[k]:
			continue
		var h := vheight(k)
		var moved := false
		for d in NEIGH:
			var a: int = i + d.x
			var b: int = j + d.y
			if a < 0 or b < 0 or a > N or b > N:
				continue
			var nk := idx(a, b)
			if locked[nk]:
				continue
			var top := base[k] + dirt[k] + rock[k]
			if top <= 0.0001:
				break
			var slope := lerpf(DIRT_SLOPE, ROCK_SLOPE, _loose_rock_ratio(k))
			var dist := CELL * (1.4142 if d.x != 0 and d.y != 0 else 1.0)
			var excess := (h - vheight(nk)) - slope * dist
			if excess <= 0.002:
				continue
			var took := _take(k, minf(excess * 0.25, top * 0.5))
			dirt[nk] += took.x
			rock[nk] += took.y
			h = vheight(k)
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
			# clockwise as seen from above for Godot's front faces
			_indices.append_array([a, b, c, b, d, c])

func _build_chunk(cx: int, cz: int) -> void:
	var w := CHUNK + 1
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	pos.resize(w * w)
	nor.resize(w * w)
	col.resize(w * w)
	for z in range(w):
		for x in range(w):
			var i := cx * CHUNK + x
			var j := cz * CHUNK + z
			var k := idx(i, j)
			pos[z * w + x] = Vector3((i - N * 0.5) * CELL, vheight(k), (j - N * 0.5) * CELL)
			var hl := vheight(idx(maxi(i - 1, 0), j))
			var hr := vheight(idx(mini(i + 1, N), j))
			var hu := vheight(idx(i, maxi(j - 1, 0)))
			var hd := vheight(idx(i, mini(j + 1, N)))
			nor[z * w + x] = Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
			col[z * w + x] = Color(_loose_rock_ratio(k), 0, 0, 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh: ArrayMesh = chunk_nodes[Vector2i(cx, cz)].mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(cx * CHUNK - N * 0.5, BEDROCK, cz * CHUNK - N * 0.5) * Vector3(CELL, 1, CELL), Vector3(CHUNK * CELL, 8.0, CHUNK * CELL))
	rebuilt_chunks += 1

func _update_collision() -> void:
	var data := PackedFloat32Array()
	data.resize(V * V)
	for k in range(V * V):
		data[k] = vheight(k)
	shape.map_data = data
	collision_dirty = false

## Applies pending changes: slump a little, rebuild a few chunks, refresh collision at ~15 Hz.
## `force` rebuilds everything immediately (tests, startup).
func flush(force := false) -> void:
	if force:
		while active.size() > 0:
			relax(100000)
		for key in dirty_chunks.keys():
			_build_chunk(key.x, key.y)
		dirty_chunks.clear()
		_update_collision()
		return
	var left := 3
	for key in dirty_chunks.keys():
		if left <= 0:
			break
		_build_chunk(key.x, key.y)
		dirty_chunks.erase(key)
		left -= 1
	if collision_dirty and _collision_timer <= 0.0:
		_update_collision()
		_collision_timer = 0.066

func _physics_process(delta: float) -> void:
	_collision_timer -= delta
	if active.size() > 0:
		relax(700)
	flush()
