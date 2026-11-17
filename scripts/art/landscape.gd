extends Node3D
class_name QuarryLandscape
## Phase 6 natural environment: everything that makes the quarry feel like it sits in a larger valley, with no
## collision, no navigation and no gameplay. Lightweight and shared: one gradient sky, a handful of low-poly clouds,
## three layers of distant mountain ridges (one mesh each), and one MultiMesh of low-poly conifers on the
## embankment around the yard.
##
##  * Sky: ProceduralSkyMaterial gradient and sun disc (cheap in GL Compatibility), recoloured with the time of day.
##  * Haze: distance fog tinted like the horizon, light enough to keep the mountains readable.
##  * Clouds: 14 flattened unshaded blobs on a slowly turning ring; no transparency.
##  * Mountains: three jagged rings far beyond the playable area, hidden at their feet by the embankment.
##  * Forest: ~360 conifer instances between r 34 and 49 (skipping the access corridor and the east expansion).

const MTN_RADII := [300.0, 400.0, 520.0]
const MTN_HEIGHTS := [62.0, 96.0, 128.0]
const MTN_SEGMENTS := 112

var game
var env: Environment
var sky_mat: ProceduralSkyMaterial
var clouds_root: Node3D
var cloud_mat: StandardMaterial3D
var mountain_nodes: Array = []
var forest: MultiMeshInstance3D
var tree_count := 0
var tree_positions: Array = []   # for tests (the headless renderer does not keep MultiMesh data)
var day := 1.0
var sun: MeshInstance3D
var moon: MeshInstance3D

const SKY_TOP := [Color(0.02, 0.04, 0.10), Color(0.27, 0.50, 0.82)]
const SKY_HORIZON := [Color(0.05, 0.07, 0.13), Color(0.80, 0.88, 0.94)]
const GROUND := [Color(0.03, 0.04, 0.06), Color(0.52, 0.55, 0.50)]
const MTN_BASE := [Color(0.35, 0.36, 0.30), Color(0.40, 0.42, 0.42), Color(0.44, 0.47, 0.52)]
const MTN_TOP := [Color(0.56, 0.52, 0.45), Color(0.55, 0.55, 0.57), Color(0.60, 0.63, 0.68)]

func build(main_node) -> void:
	game = main_node
	name = "Landscape"
	game.add_child(self)
	env = game.sky_light.environment
	_sky()
	_clouds()
	_sun_moon()
	for i in range(MTN_RADII.size()):
		_mountains(i)
	if game.blueprint:
		_forest_blueprint()
	else:
		_forest()
	set_day(1.0)

# ------------------------------------------------------------------ sky and haze

func _sky() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.18
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.12
	sky_mat.use_debanding = false
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_density = 0.0021
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0

## 0 = night, 1 = full day. Called by the world's light update.
func set_day(d: float) -> void:
	day = d
	var top := (SKY_TOP[0] as Color).lerp(SKY_TOP[1], d)
	var hor := (SKY_HORIZON[0] as Color).lerp(SKY_HORIZON[1], d)
	var gnd := (GROUND[0] as Color).lerp(GROUND[1], d)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = gnd
	env.fog_light_color = hor.lerp(Color(0.86, 0.84, 0.76), 0.25 * d)
	if cloud_mat:
		cloud_mat.albedo_color = Color(0.2, 0.22, 0.3).lerp(Color(0.97, 0.97, 1.0), d)
		cloud_mat.emission_energy_multiplier = lerpf(0.25, 0.45, d)

## Golden hour: `g` 0..1 tints the horizon band, the lower sky, the haze, the clouds and the sun disc (sunrise rosier, sunset orange).
func set_glow(g: float, rising: bool) -> void:
	var warm := Color(1.0, 0.50, 0.24) if not rising else Color(1.0, 0.62, 0.52)
	var hor := (SKY_HORIZON[0] as Color).lerp(SKY_HORIZON[1], day).lerp(warm, g * 0.85)
	var top := (SKY_TOP[0] as Color).lerp(SKY_TOP[1], day).lerp(Color(0.30, 0.26, 0.48) if not rising else Color(0.40, 0.40, 0.62), g * 0.5)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	env.fog_light_color = hor.lerp(Color(0.86, 0.84, 0.76), 0.25 * day * (1.0 - g))
	if cloud_mat:
		cloud_mat.albedo_color = cloud_mat.albedo_color.lerp(warm.lerp(Color(1, 1, 1), 0.35), g * 0.7)
	if sun and sun.material_override is StandardMaterial3D:
		(sun.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.93, 0.62).lerp(Color(1.0, 0.45, 0.18), g)

func _process(delta: float) -> void:
	if clouds_root:
		clouds_root.rotation.y += delta * 0.004

# ------------------------------------------------------------------ clouds

func _clouds() -> void:
	clouds_root = Node3D.new()
	clouds_root.name = "Clouds"
	add_child(clouds_root)
	cloud_mat = StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.97, 0.97, 1.0)
	cloud_mat.roughness = 1.0
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_mat.disable_fog = true
	cloud_mat.emission_enabled = true                  # keeps the shapes readable in the dark
	cloud_mat.emission = Color(0.50, 0.54, 0.64)
	cloud_mat.emission_energy_multiplier = 0.45
	# three cumulus shapes: flat-bottomed puffs grouped into banks, lit by the sun so the tops are bright and the
	# undersides grey (the old single flat blobs read as white polygons)
	var meshes := []
	for k in range(3):
		var s := MeshKit.Soup.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 3100 + k * 17
		for i in range(5 + k):
			var off := Vector3(rng.randf_range(-1.0, 1.0) * (20.0 + 7.0 * k), rng.randf_range(-0.1, 0.9) * 5.0, rng.randf_range(-1.0, 1.0) * 8.0)
			var r := rng.randf_range(9.0, 15.0)
			MeshKit.rock_into(s, off, Vector3(r * 2.3, r * 1.15, r * 1.7), 3200 + k * 31 + i, 3, 8, true, Vector2(-0.1, 0.12))
		var m := s.mesh()
		m.surface_set_material(0, cloud_mat)
		meshes.append(m)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 4242
	for i in range(16):
		var a := rng2.randf() * TAU
		var r := rng2.randf_range(140.0, 440.0)
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % 3]
		mi.position = Vector3(cos(a) * r, rng2.randf_range(105.0, 150.0), sin(a) * r)
		mi.rotation.y = rng2.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds_root.add_child(mi)

# ------------------------------------------------------------------ sun and moon

func _sun_moon() -> void:
	sun = _disc("Sun", 24.0, Color(1.0, 0.93, 0.62))
	moon = _disc("Moon", 16.0, Color(0.86, 0.90, 1.0))

func _disc(nm: String, radius: float, color: Color) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = sm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Sun and moon cross the sky with the clock: the sun rises in the east at 06:00, is highest at noon and sets in the
## west at 18:00; the moon is on the opposite side. Each hides below the horizon.
func set_time(minutes: float) -> void:
	var phase := fposmod(minutes, 1440.0) / 1440.0
	var al := (phase - 0.25) * TAU
	if sun:
		var d := Vector3(cos(al), sin(al), -0.30).normalized()
		sun.position = d * 430.0
		sun.visible = d.y > -0.06
	if moon:
		var d2 := Vector3(-cos(al), -sin(al), 0.25).normalized()
		moon.position = d2 * 430.0
		moon.visible = d2.y > -0.06
		moon.rotation.y = al

# ------------------------------------------------------------------ mountains

## Ridge height factor around the ring (0..1): a few overlapping sine waves with sharpened peaks.
static func ridge(theta: float, seed: float) -> float:
	var n := 0.5 * sin(2.0 * theta + seed) + 0.3 * sin(5.0 * theta + seed * 2.3) + 0.2 * sin(11.0 * theta + seed * 4.1)
	n = n * 0.5 + 0.5
	return 0.3 + 0.7 * pow(clampf(n, 0.0, 1.0), 1.4)

func _mountains(layer: int) -> void:
	var s := MeshKit.Soup.new()
	var R: float = MTN_RADII[layer]
	var H: float = MTN_HEIGHTS[layer]
	var seed := 1.7 + 2.9 * layer
	var n := MTN_SEGMENTS
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + layer
	# three rows per segment: foot, shoulder, crest; per-vertex radial and height jitter makes angular facets
	var foot := []
	var shoulder := []
	var crest := []
	for i in range(n):
		var th := TAU * float(i) / float(n)
		var h := H * ridge(th, seed) * rng.randf_range(0.86, 1.1)
		var rj := rng.randf_range(-0.04, 0.04) * R
		foot.append(Vector3(cos(th) * R, -40.0, sin(th) * R))
		var rs := R + 0.20 * H + rj
		shoulder.append(Vector3(cos(th) * rs, h * 0.5 * rng.randf_range(0.8, 1.15), sin(th) * rs))
		var rc := R + 0.48 * H + rj * 0.5
		crest.append(Vector3(cos(th) * rc, h, sin(th) * rc))
	for i in range(n):
		var k := (i + 1) % n
		s.quad(foot[i], shoulder[i], shoulder[k], foot[k])
		s.quad(shoulder[i], crest[i], crest[k], shoulder[k])
		# a roof behind the crest closes the ring so no sky shows through
		s.tri(crest[i], Vector3(crest[i].x * 1.18, -40.0, crest[i].z * 1.18), crest[k])
	var m := s.mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = (MTN_BASE[layer] as Color).lerp(MTN_TOP[layer], 0.5)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Mountains%d" % layer
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mountain_nodes.append(mi)

# ------------------------------------------------------------------ forest on the embankment

func _embankment_height(r: float) -> float:
	var rings := [[29.0, 0.0], [33.0, 4.5], [40.0, 7.5], [52.0, 9.0]]
	for k in range(rings.size() - 1):
		if r <= rings[k + 1][0]:
			return lerpf(float(rings[k][1]), float(rings[k + 1][1]), (r - float(rings[k][0])) / (float(rings[k + 1][0]) - float(rings[k][0])))
	return 9.0

## ------------------------------------------------------------------ the forest (Blender models, MultiMesh)
## Species: tall and young pines, birches (trees: `forest` holds the pines, `tree_positions` their spots); under and between them bushes, ferns, grass, wildflowers, logs,
## stumps and mossy stones. Handcrafted-looking rather than an even carpet: the density grows with the distance from the working yard, trees gather in groves with
## clearings between them, species mix by distance (young pines, birches and bushes near the edge, tall pines far away), every instance has its own scale, turn, a slight
## lean and a tint. Ground cover is split into 64 m chunks with their own draw distance. Nothing grows on the yard, the roads, the tunnel approach, the quarry or the
## east extension.

var _mm_nodes := {}
var young_positions: Array = []

## True where nothing may grow (xz in world metres).
func forest_blocked(p: Vector2) -> bool:
	var hub: Rect2 = game.hub_rect()
	if hub.grow(7.0).has_point(p):
		return true
	if p.x > -134.0 and p.x < 134.0 and p.y > -115.0 and p.y < -2.0:
		return true                                              # the quarry and its fence
	if p.x > -78.0 and p.x < -18.0 and p.y > 12.0 and p.y < 40.0:
		return true                                              # the service lane and the tunnel approach
	if p.x > -126.0 and p.x < -26.0 and p.y > -16.0 and p.y < 68.0:
		return true                                              # the tunnel mountain
	if QuarryOpening.near_road(p, 7.5):
		return true                                              # the winding forest road out of the tunnel
	if p.x > 22.0 and p.x < 58.0 and p.y > -6.0 and p.y < 32.0:
		return true                                              # the east extension
	if absf(p.x) < 9.0 and p.y > -140.0 and p.y < 30.0:
		return true                                              # the central road, the gate and the haul road
	return false

## Slow value noise: groves where it is high, clearings where it is low.
static func grove(p: Vector2) -> float:
	return 0.5 * sin(p.x * 0.071 + 1.3) * cos(p.y * 0.053) + 0.3 * sin(p.x * 0.19 + p.y * 0.13) + 0.2 * cos(p.y * 0.23 - p.x * 0.11)

const TREE_CHUNK := 64.0          ## trees are drawn in 64 m squares, each its own batch, so the ones outside the view are culled (one batch of 5,000 trees was drawn whole every frame)
const TREE_NEAR := 95.0           ## the full pine inside this distance, the cheap far pine beyond it
const TREE_END := 300.0

## Plants trees as culled, distance-LOD'd chunks. Returns an invisible MultiMeshInstance3D holding every instance (the data: positions and counts for the game and its tests);
## what is drawn are the chunk batches: `key` (full model, up to TREE_NEAR) and `far_key` (the cheap model, from TREE_NEAR - 15 m on) when given, else `key` out to `end`.
func _add_trees(key: String, nm: String, xfs: Array, tints: Array, far_key := "", end := TREE_END) -> MultiMeshInstance3D:
	var data := _add_mm(key, nm, xfs, tints)
	if data == null:
		return null
	data.visible = false
	var cells := {}
	for i in range(xfs.size()):
		var o: Vector3 = (xfs[i] as Transform3D).origin
		var ck := "%d_%d" % [int(floor(o.x / TREE_CHUNK)), int(floor(o.z / TREE_CHUNK))]
		if not cells.has(ck):
			cells[ck] = [[], []]
		cells[ck][0].append(xfs[i])
		cells[ck][1].append(tints[i])
	for ck in cells:
		var near := _add_mm(key, "%s_%s" % [nm, ck], cells[ck][0], cells[ck][1], TREE_NEAR if far_key != "" else end)
		if far_key != "" and WorldModels.has(far_key):
			var far := _add_mm(far_key, "%s_far_%s" % [nm, ck], cells[ck][0], cells[ck][1], end)
			if far != null:
				far.visibility_range_begin = TREE_NEAR - 15.0
				far.visibility_range_begin_margin = 10.0
		elif far_key != "" and near != null:
			near.visibility_range_end = end
	return data

func _add_mm(key: String, nm: String, xfs: Array, tints: Array, draw_end := 0.0) -> MultiMeshInstance3D:
	var m: ArrayMesh = WorldModels.mesh(key)
	if m == null or xfs.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = m
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, tints[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if draw_end > 0.0:
		mi.visibility_range_end = draw_end
		mi.visibility_range_end_margin = 10.0
	add_child(mi)
	_mm_nodes[nm] = mi
	return mi

func _xf(r: RandomNumberGenerator, p: Vector3, smin: float, smax: float, lean := 0.04) -> Transform3D:
	var sc := r.randf_range(smin, smax)
	var b := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-lean, lean)) * Basis(Vector3.FORWARD, r.randf_range(-lean, lean))
	return Transform3D(b.scaled(Vector3(sc, sc * r.randf_range(0.92, 1.12), sc)), p)

static func _tint(r: RandomNumberGenerator, v := 0.1) -> Color:
	var f := r.randf_range(1.0 - v, 1.0 + v)
	return Color(f, f * r.randf_range(0.97, 1.03), f * r.randf_range(0.94, 1.0))

func _cover_add(chunks: Dictionary, kind: String, xf: Transform3D, tint: Color) -> void:
	var o := xf.origin
	var key := "%s|%d_%d" % [kind, int(floor(o.x / 64.0)), int(floor(o.z / 64.0))]
	if not chunks.has(key):
		chunks[key] = [[], []]
	chunks[key][0].append(xf)
	chunks[key][1].append(tint)

## Plants the forest. `rects`: [x0, z0, x1, z1, attempts] areas to grow in; `centre`: the working yard the density is measured from.
func _plant(rects: Array, seed: int, ground_y: Callable, centre := Vector2(0.0, 12.0)) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pine_x: Array = []
	var pine_t: Array = []
	var young_x: Array = []
	var young_t: Array = []
	var birch_x: Array = []
	var birch_t: Array = []
	var chunks := {}
	for z in rects:
		var tries := 0
		while tries < int(z[4]):
			tries += 1
			var p2 := Vector2(r.randf_range(float(z[0]), float(z[2])), r.randf_range(float(z[1]), float(z[3])))
			if forest_blocked(p2):
				continue
			var d := p2.distance_to(centre)
			var far := smoothstep(45.0, 170.0, d)
			var gv := grove(p2)
			var keep := lerpf(0.10, 0.92, far)
			if gv < -0.05:
				keep *= 0.18                                 # a clearing
			elif gv > 0.35:
				keep = minf(1.0, keep * 1.5)                 # the heart of a grove
			if r.randf() > keep:
				if r.randf() < 0.07 and d > 50.0:            # a clearing is not bare: meadow flowers and grass
					var q := Vector3(p2.x, ground_y.call(p2), p2.y)
					_cover_add(chunks, "flowers", _xf(r, q, 0.9, 1.6, 0.0), _tint(r, 0.12))
					_cover_add(chunks, "grass", _xf(r, q + Vector3(r.randf_range(-0.8, 0.8), 0, r.randf_range(-0.8, 0.8)), 0.9, 1.8, 0.0), _tint(r, 0.15))
				continue
			var p := Vector3(p2.x, ground_y.call(p2), p2.y)
			var roll := r.randf()
			var young_share := lerpf(0.5, 0.12, far)
			var birch_share := 0.12 * (1.0 - far * 0.5)
			if roll < young_share:
				young_x.append(_xf(r, p, 0.8, 1.5))
				young_t.append(_tint(r))
			elif roll < young_share + birch_share and gv < 0.3:
				birch_x.append(_xf(r, p, 0.85, 1.35))
				birch_t.append(_tint(r))
			else:
				pine_x.append(_xf(r, p, 0.75 + 0.2 * far, 1.35 + 0.25 * far))
				pine_t.append(_tint(r))
			var u := r.randf()                               # the forest floor around it
			var around := p + Vector3(r.randf_range(-2.6, 2.6), 0, r.randf_range(-2.6, 2.6))
			around.y = ground_y.call(Vector2(around.x, around.z))
			if u < 0.30:
				_cover_add(chunks, "fern", _xf(r, around, 0.8, 1.5, 0.0), _tint(r, 0.12))
			elif u < 0.52:
				_cover_add(chunks, "bush", _xf(r, around, 0.8, 1.5, 0.0), _tint(r, 0.1))
			elif u < 0.68:
				_cover_add(chunks, "grass", _xf(r, around, 1.0, 1.8, 0.0), _tint(r, 0.15))
			elif u < 0.74:
				_cover_add(chunks, "flowers", _xf(r, around, 0.9, 1.4, 0.0), _tint(r, 0.1))
			elif u < 0.77:
				_cover_add(chunks, "mossy_stone", _xf(r, around, 0.8, 1.7, 0.0), Color(1, 1, 1))
			elif u < 0.785:
				_cover_add(chunks, "log", _xf(r, around, 0.8, 1.3, 0.0), Color(1, 1, 1))
			elif u < 0.80:
				_cover_add(chunks, "stump", _xf(r, around, 0.8, 1.3, 0.0), Color(1, 1, 1))
	forest = _add_trees("pine_tall", "Forest", pine_x, pine_t, "pine_far")
	_add_trees("pine_young", "ForestYoung", young_x, young_t, "", 260.0)
	_add_trees("birch", "ForestBirch", birch_x, birch_t, "", 220.0)
	tree_count = pine_x.size()
	for x in pine_x:
		tree_positions.append((x as Transform3D).origin)
	for x in young_x:
		young_positions.append((x as Transform3D).origin)
	for x in birch_x:
		young_positions.append((x as Transform3D).origin)
	for key in chunks:
		var kind: String = str(key).get_slice("|", 0)
		var data: Array = chunks[key]
		_add_mm(kind, "Cover_%s" % str(key).replace("|", "_"), data[0], data[1], 110.0 if kind in ["fern", "grass", "flowers"] else 150.0)

## The blueprint world's forests: the strips east and west of the quarry, the land east of the yard and south of the quarry fence, thinning toward the yard.
func _forest_blueprint() -> void:
	var flat := func(_p: Vector2) -> float: return 0.0
	_plant([[-200.0, -125.0, -132.0, 76.0, 5200], [132.0, -125.0, 200.0, 76.0, 5200], [-132.0, 40.0, 132.0, 76.0, 3200], [-200.0, 76.0, 200.0, 80.0, 400]], 78, flat)

## The old (non-blueprint) layout: trees only on the embankment ring (radius 34-49 m), outside the pit corridor and the east side.
func _forest() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var xfs: Array = []
	var tints: Array = []
	var tries := 0
	while xfs.size() < 360 and tries < 6000:
		tries += 1
		var a := r.randf() * TAU
		var rad := r.randf_range(34.0, 49.0)
		if sin(a * 5.0 + 1.3) * 0.5 + cos(a * 9.0) * 0.5 < -0.15 and r.randf() < 0.75:
			continue
		var p := Vector3(cos(a) * rad, _embankment_height(rad) - 0.25, sin(a) * rad)
		if game.in_pit_corridor(p, 8.0) or (p.x > 24.0 and absf(p.z) < 18.0):
			continue
		xfs.append(_xf(r, p, 0.9, 1.5))
		tints.append(_tint(r))
	forest = _add_mm("pine_tall", "Forest", xfs, tints)                  # the old layout's embankment ring: a few hundred trees, one batch
	tree_count = xfs.size()
	for x in xfs:
		tree_positions.append((x as Transform3D).origin)
