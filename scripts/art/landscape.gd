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
	for i in range(MTN_RADII.size()):
		_mountains(i)
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
	env.fog_density = 0.0016
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

func _process(delta: float) -> void:
	if clouds_root:
		clouds_root.rotation.y += delta * 0.004

# ------------------------------------------------------------------ clouds

func _clouds() -> void:
	clouds_root = Node3D.new()
	clouds_root.name = "Clouds"
	add_child(clouds_root)
	cloud_mat = StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.albedo_color = Color(0.97, 0.97, 1.0)
	cloud_mat.disable_fog = true
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var meshes := []
	for k in range(3):
		var s := MeshKit.Soup.new()
		MeshKit.rock_into(s, Vector3.ZERO, Vector3(70.0 + 20.0 * k, 12.0 + 3.0 * k, 38.0 + 8.0 * k), 3100 + k, 3, 8, true, Vector2(-0.12, 0.2))
		MeshKit.rock_into(s, Vector3(26.0, -1.0, 6.0), Vector3(40.0, 9.0, 26.0), 3120 + k, 3, 7, true, Vector2(-0.1, 0.2))
		var m := s.mesh()
		m.surface_set_material(0, cloud_mat)
		meshes.append(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(14):
		var a := rng.randf() * TAU
		var r := rng.randf_range(160.0, 430.0)
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % 3]
		mi.position = Vector3(cos(a) * r, rng.randf_range(95.0, 140.0), sin(a) * r)
		mi.rotation.y = rng.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds_root.add_child(mi)

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

func _forest() -> void:
	var s := MeshKit.Soup.new()
	MeshKit.frustum_into(s, Vector3(0, 0.0, 0), 0.18, 0.14, 1.2, 5)                 # trunk
	MeshKit.frustum_into(s, Vector3(0, 0.9, 0), 1.3, 0.35, 2.0, 6)                  # lower cone
	MeshKit.frustum_into(s, Vector3(0, 2.4, 0), 0.95, 0.2, 1.8, 6)                  # upper cone
	var m := s.mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.36, 0.22)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var xfs := []
	var tries := 0
	while xfs.size() < 360 and tries < 4000:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(34.0, 49.0)
		# clumps: only keep spots where a slow noise is high, so the trees gather in groves
		if sin(a * 5.0 + 1.3) * 0.5 + cos(a * 9.0) * 0.5 < -0.15 and rng.randf() < 0.75:
			continue
		var p := Vector3(cos(a) * r, _embankment_height(r) - 0.25, sin(a) * r)
		if game.in_pit_corridor(p, 8.0) or (p.x > 24.0 and absf(p.z) < 18.0):
			continue
		var sc := rng.randf_range(1.2, 2.3)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.9, 1.4), sc)), p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
	forest = MultiMeshInstance3D.new()
	forest.name = "Forest"
	forest.multimesh = mm
	forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(forest)
	tree_count = xfs.size()
	for x in xfs:
		tree_positions.append((x as Transform3D).origin)
