extends Node3D
class_name QuarryPitZone
## Phase 6.3a: the new pit area. A gate in the north-east of the cliff ring (closed by a rockfall barrier until the
## cleanup tutorial is done) leads down a corridor to a 90 x 90 m plateau with a 36 x 36 m starting basin whose floor
## is 3.6 m lower, reached by a 20 m ramp. Nothing is mined here yet (the curved benches come in 6.3b-d).
##
## Local frame: the origin is the gate, local -Z points out of the quarry, x is across. The yard keeps its
## coordinates; this node only adds ground, walls and its own navigation region (baked in the background).
## Everything is built from boxes and procedural meshes, in the same low-poly pixel-textured style as the yard.

var game
var cfg: Dictionary
var is_open := false
var barrier: StaticBody3D
var nav_region: NavigationRegion3D
var nav_link: NavigationLink3D
var nav_ready := false
var formations: Array = []     # curved bench formations of this zone (their exposed columns are nav sources)
var last_source_boxes := 0
var bake_count := 0
var bake_ms := 0.0            # main-thread time spent collecting the last bake's source geometry
var _bake_dirty := false
var _baking := false
var _since_bake := 100.0       # game seconds since the last bake finished (rate limit)

var corr_len := 30.0
var corr_w := 8.0
var plat_w := 90.0
var plat_d := 90.0
var basin_w := 36.0
var basin_d := 36.0
var basin_y := -3.6
var ramp_w := 8.0
var ramp_run := 20.0
var wall_h := 8.0
var build_margin := 3.0

## Gate transform without needing the node (the world builder uses it before the zone exists).
static func gate_transform(c: Dictionary) -> Transform3D:
	var a := deg_to_rad(float(c.get("angle_deg", 306.0)))
	var r := float(c.get("gate_radius", 28.0))
	var d := Vector3(cos(a), 0, sin(a))
	return Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.z)), Vector3(d.x * r, 0, d.z * r))

func setup(main_node) -> bool:
	game = main_node
	cfg = game.prog.cfg.get("pit_zone", {})
	if cfg.is_empty():
		return false
	corr_len = float(cfg.get("corridor_length", corr_len))
	corr_w = float(cfg.get("corridor_width", corr_w))
	plat_w = float(cfg.get("plateau_width", plat_w))
	plat_d = float(cfg.get("plateau_depth", plat_d))
	basin_w = float(cfg.get("basin_width", basin_w))
	basin_d = float(cfg.get("basin_depth", basin_d))
	basin_y = float(cfg.get("basin_floor", basin_y))
	ramp_w = float(cfg.get("ramp_width", ramp_w))
	ramp_run = float(cfg.get("ramp_run", ramp_run))
	wall_h = float(cfg.get("wall_height", wall_h))
	build_margin = float(cfg.get("build_margin", build_margin))
	name = "PitZone"
	game.world.add_child(self)
	transform = gate_transform(cfg)
	_build_ground()
	_build_walls()
	_build_barrier()
	_build_art()
	_build_nav()
	set_open(false)
	return true

# ------------------------------------------------------------------ layout helpers (local coordinates)

func plateau_z0() -> float:
	return -corr_len

func plateau_z1() -> float:
	return -corr_len - plat_d

func basin_zc() -> float:
	return plateau_z0() - plat_d * 0.5

func basin_zn() -> float:
	return basin_zc() - basin_d * 0.5   # far (north) edge

func basin_zs() -> float:
	return basin_zc() + basin_d * 0.5   # near (south) edge, where the ramp starts

func to_loc(p: Vector3) -> Vector3:
	return global_transform.affine_inverse() * p

func to_world(l: Vector3) -> Vector3:
	return global_transform * l

func _body(label: String, pos: Vector3, size: Vector3, ground := true, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = label
	b.position = pos
	b.rotation = rot
	if ground:
		b.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	add_child(b)
	return b

func _build_ground() -> void:
	var z0 := plateau_z0()
	var z1 := plateau_z1()
	var hx := basin_w * 0.5
	var zn := basin_zn()
	var zs := basin_zs()
	_body("Corridor floor", Vector3(0, -0.25, 3.0 - (corr_len + 3.0) * 0.5), Vector3(corr_w, 0.5, corr_len + 3.0))
	# plateau: thick pieces around the basin hole, so the hole's sides are solid walls
	_body("Plateau south", Vector3(0, -2.75, (z0 + zs) * 0.5), Vector3(plat_w, 5.5, z0 - zs))
	_body("Plateau north", Vector3(0, -2.75, (z1 + zn) * 0.5), Vector3(plat_w, 5.5, zn - z1))
	_body("Plateau west", Vector3(-(plat_w * 0.5 + hx) * 0.5, -2.75, basin_zc()), Vector3(plat_w * 0.5 - hx, 5.5, basin_d))
	_body("Plateau east", Vector3((plat_w * 0.5 + hx) * 0.5, -2.75, basin_zc()), Vector3(plat_w * 0.5 - hx, 5.5, basin_d))
	_body("Basin floor", Vector3(0, basin_y - 0.25, basin_zc()), Vector3(basin_w, 0.5, basin_d))
	# access ramp from the south rim down into the basin
	var depth := -basin_y
	var ang := atan2(depth, ramp_run)
	var length := sqrt(ramp_run * ramp_run + depth * depth)
	var thick := 0.4
	var ramp := _body("Basin ramp", Vector3(0, -depth * 0.5 - thick * 0.5 / cos(ang) - 0.01, zs - ramp_run * 0.5), Vector3(ramp_w, thick, length), true, Vector3(-ang, 0, 0))
	ramp.set_meta("ramp", true)
	# solid fill under the ramp (stepped boxes just below the slab), so nobody can crawl or see under it
	for i in range(4):
		var seg := ramp_run / 4.0
		var top := -depth * float(i + 1) / 4.0 - 0.5
		var hgt := top + depth + 0.25
		if hgt > 0.05:
			var fill := _body("Ramp fill", Vector3(0, -depth - 0.25 + hgt * 0.5, zs - seg * (float(i) + 0.5)), Vector3(ramp_w, hgt, seg), false)
			fill.set_meta("nav_skip", true)
	for side in [-1.0, 1.0]:
		var curb := _body("Ramp curb", Vector3(side * (ramp_w * 0.5 + 0.15), -depth * 0.5 + 0.5, zs - ramp_run * 0.5), Vector3(0.25, 1.0, length - 0.6), false, Vector3(-ang, 0, 0))
		curb.set_meta("curb", true)

func _build_walls() -> void:
	var z0 := plateau_z0()
	var z1 := plateau_z1()
	var hx := basin_w * 0.5
	var zn := basin_zn()
	var zs := basin_zs()
	var h := wall_h
	# outer perimeter (solid, 3 m thick), with the corridor mouth left open on the south side
	_body("Wall west", Vector3(-plat_w * 0.5 - 1.5, h * 0.5, (z0 + z1) * 0.5), Vector3(3.0, h, plat_d + 6.0), false)
	_body("Wall east", Vector3(plat_w * 0.5 + 1.5, h * 0.5, (z0 + z1) * 0.5), Vector3(3.0, h, plat_d + 6.0), false)
	_body("Wall north", Vector3(0, h * 0.5, z1 - 1.5), Vector3(plat_w + 6.0, h, 3.0), false)
	var seg := plat_w * 0.5 - corr_w * 0.5
	for side in [-1.0, 1.0]:
		_body("Wall south", Vector3(side * (corr_w * 0.5 + seg * 0.5), h * 0.5, z0 + 1.5), Vector3(seg, h, 3.0), false)
		_body("Corridor wall", Vector3(side * (corr_w * 0.5 + 1.0), 3.0, 1.0 - (corr_len + 1.0) * 0.5 + 0.0), Vector3(2.0, 6.0, corr_len + 1.0), false)
	# low rim barriers along the basin edge (everywhere except the ramp mouth)
	var rim := 1.0
	_body("Rim west", Vector3(-hx - 0.15, rim * 0.5, basin_zc()), Vector3(0.3, rim, basin_d + 0.6), false)
	_body("Rim east", Vector3(hx + 0.15, rim * 0.5, basin_zc()), Vector3(0.3, rim, basin_d + 0.6), false)
	_body("Rim north", Vector3(0, rim * 0.5, zn - 0.15), Vector3(basin_w + 0.6, rim, 0.3), false)
	var rseg := hx - ramp_w * 0.5 - 0.6
	for side in [-1.0, 1.0]:
		_body("Rim south", Vector3(side * (ramp_w * 0.5 + 0.6 + rseg * 0.5), rim * 0.5, zs + 0.15), Vector3(rseg, rim, 0.3), false)

func _build_barrier() -> void:
	barrier = _body("North gate barrier", Vector3(0, 2.0, -0.6), Vector3(corr_w + 1.0, 4.0, 1.4), false)
	barrier.set_meta("kind", "gate")
	var r := MeshKit.Soup.new()
	for k in range(7):
		MeshKit.rock_into(r, Vector3(-3.6 + k * 1.2 + (k % 2) * 0.2, -2.0 + 2.0, 0.0), Vector3(2.4, 2.4 + float(k % 3) * 0.7, 2.2), 710 + k)
	var mi := MeshKit.inst(barrier, r.mesh(), MeshKit.mat("RockLimestone"))
	mi.position.y = -2.0

# ------------------------------------------------------------------ visuals

func _cell_quads(s: MeshKit.Soup, x0: float, x1: float, z0: float, z1: float, y: float, step: float, skip_hole := false) -> void:
	var hx := basin_w * 0.5
	var x := x0
	while x < x1 - 0.01:
		var z := z0
		while z < z1 - 0.01:
			var cx := x + step * 0.5
			var cz := z + step * 0.5
			var in_hole := skip_hole and absf(cx) < hx and cz > basin_zn() and cz < basin_zs()
			if not in_hole:
				var yy := y + 0.02 * sin(cx * 0.9 + cz * 0.4)
				s.quad(Vector3(x, yy, z), Vector3(x, yy, z + step), Vector3(x + step, yy, z + step), Vector3(x + step, yy, z))
			z += step
		x += step

func _wall(s: MeshKit.Soup, length: float, height: float, depth: float, seed: int, beds: int, yaw: float, at: Vector3) -> void:
	MeshKit.cliff_into(s, length, height, depth, seed, beds, Transform3D(Basis(Vector3.UP, yaw), at))

func _build_art() -> void:
	var z0 := plateau_z0()
	var z1 := plateau_z1()
	var hx := basin_w * 0.5
	var zn := basin_zn()
	var zs := basin_zs()
	var vis := Node3D.new()
	vis.name = "PitZoneVisuals"
	add_child(vis)
	# ground
	var road := MeshKit.Soup.new()
	_cell_quads(road, -corr_w * 0.5, corr_w * 0.5, -corr_len, 3.0, 0.015, 1.0)
	MeshKit.inst(vis, road.mesh(), MeshKit.mat("GroundRoad"))
	var plat := MeshKit.Soup.new()
	_cell_quads(plat, -plat_w * 0.5, plat_w * 0.5, z1, z0, 0.01, 3.0, true)
	MeshKit.inst(vis, plat.mesh(), MeshKit.mat("ExcavatedDirt"))
	var basin := MeshKit.Soup.new()
	_cell_quads(basin, -hx, hx, zn, zs, basin_y + 0.012, 3.0)
	MeshKit.inst(vis, basin.mesh(), MeshKit.mat("ExcavatedDirt"))
	# ramp surface
	var depth := -basin_y
	var ang := atan2(depth, ramp_run)
	var length := sqrt(ramp_run * ramp_run + depth * depth)
	var rs := MeshKit.Soup.new()
	var rxf := Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(0, -depth * 0.5 + 0.02, zs - ramp_run * 0.5))
	var hw := ramp_w * 0.5
	var hl := length * 0.5 + 0.1
	rs.quad(rxf * Vector3(-hw, 0, -hl), rxf * Vector3(-hw, 0, hl), rxf * Vector3(hw, 0, hl), rxf * Vector3(hw, 0, -hl))
	MeshKit.inst(vis, rs.mesh(), MeshKit.mat("GroundRoad"))
	var wedge := MeshKit.Soup.new()   # side faces of the ramp's solid fill (right triangles)
	for side in [-1.0, 1.0]:
		var xw: float = side * hw
		var a := Vector3(xw, 0.0, zs)
		var b := Vector3(xw, -depth, zs)
		var c := Vector3(xw, -depth, zs - ramp_run)
		if side > 0.0:
			wedge.tri(a, b, c)
		else:
			wedge.tri(a, c, b)
	MeshKit.inst(vis, wedge.mesh(), MeshKit.mat("CutLimestone"))
	for side in [-1.0, 1.0]:
		var curb := MeshKit.Soup.new()
		MeshKit.box_into(curb, Vector3.ZERO, Vector3(0.25, 0.35, length - 0.6), Vector2.ONE, Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(side * (hw + 0.15), -depth * 0.5 + 0.17, zs - ramp_run * 0.5)))
		MeshKit.inst(vis, curb.mesh(), MeshKit.mat("Hazard"))
	# basin walls (pale cut limestone), facing into the basin
	var bw := MeshKit.Soup.new()
	var hgt := -basin_y + 0.4
	_wall(bw, basin_w, hgt, 0.8, 801, 2, PI, Vector3(0, basin_y, zn - 0.4))
	_wall(bw, basin_d, hgt, 0.8, 802, 2, -PI * 0.5, Vector3(-hx - 0.4, basin_y, basin_zc()))
	_wall(bw, basin_d, hgt, 0.8, 803, 2, PI * 0.5, Vector3(hx + 0.4, basin_y, basin_zc()))
	var sl := hx - hw
	_wall(bw, sl, hgt, 0.8, 804, 2, 0.0, Vector3(-hw - sl * 0.5, basin_y, zs + 0.4))
	_wall(bw, sl, hgt, 0.8, 805, 2, 0.0, Vector3(hw + sl * 0.5, basin_y, zs + 0.4))
	MeshKit.inst(vis, bw.mesh(), MeshKit.mat("CutLimestone"))
	# outer perimeter and corridor walls (the same brown cliff strata as the yard ring), facing inward
	var ow := MeshKit.Soup.new()
	var oh := wall_h + 0.6
	_wall(ow, plat_w + 6.0, oh, 3.0, 811, 4, PI, Vector3(0, 0, z1 - 1.5))
	_wall(ow, plat_d, oh, 3.0, 812, 4, -PI * 0.5, Vector3(-plat_w * 0.5 - 1.5, 0, (z0 + z1) * 0.5))
	_wall(ow, plat_d, oh, 3.0, 813, 4, PI * 0.5, Vector3(plat_w * 0.5 + 1.5, 0, (z0 + z1) * 0.5))
	var seg := plat_w * 0.5 - corr_w * 0.5
	_wall(ow, seg, oh, 3.0, 814, 4, 0.0, Vector3(-corr_w * 0.5 - seg * 0.5, 0, z0 + 1.5))
	_wall(ow, seg, oh, 3.0, 815, 4, 0.0, Vector3(corr_w * 0.5 + seg * 0.5, 0, z0 + 1.5))
	_wall(ow, corr_len, 6.4, 2.0, 816, 3, -PI * 0.5, Vector3(-corr_w * 0.5 - 1.0, 0, -corr_len * 0.5))
	_wall(ow, corr_len, 6.4, 2.0, 817, 3, PI * 0.5, Vector3(corr_w * 0.5 + 1.0, 0, -corr_len * 0.5))
	MeshKit.inst(vis, ow.mesh(), MeshKit.mat("CliffStrata"))
	# railings along the basin rim, leaving the ramp mouth open
	var x := -hx + 1.25
	while x < hx - 1.0:
		if absf(x) > hw + 0.9:
			MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(x, 0, zn - 0.15), 0.0)
			MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(x, 0, zs + 0.15), 0.0)
		x += 2.5
	var z := zn + 1.25
	while z < zs - 1.0:
		MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(-hx - 0.15, 0, z), PI * 0.5)
		MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(hx + 0.15, 0, z), PI * 0.5)
		z += 2.5

# ------------------------------------------------------------------ gate

func set_open(open: bool) -> void:
	is_open = open
	barrier.visible = not open
	barrier.collision_layer = 0 if open else 1
	barrier.set_meta("nav_skip", open)
	if nav_link:
		nav_link.enabled = open
		NavigationServer3D.link_set_map(nav_link.get_rid(), game.nav_map)
	request_bake()

## True when a machine may be placed at world position p (plateau and basin floor, once the gate is open).
func build_ok(p: Vector3, margin := 0.0) -> bool:
	if not is_open:
		return false
	var l := to_loc(p)
	var m := margin + build_margin
	var z0 := plateau_z0()
	var z1 := plateau_z1()
	var hx := basin_w * 0.5
	if l.y > -0.8:
		if absf(l.x) > plat_w * 0.5 - m or l.z > z0 - m or l.z < z1 + m:
			return false
		# not on the basin hole or its rim
		if absf(l.x) < hx + 1.5 and l.z > basin_zn() - 1.5 and l.z < basin_zs() + 1.5:
			return false
		return true
	if l.y < -1.0 and l.y > basin_y - 1.0:
		if absf(l.x) > hx - 1.5 - margin or l.z < basin_zn() + 1.5 + margin or l.z > basin_zs() - 1.5 - margin:
			return false
		return not (absf(l.x) < ramp_w * 0.5 + 1.0 and l.z > basin_zs() - ramp_run - 2.0)
	return false

# ------------------------------------------------------------------ navigation (own region, baked in the background)

func _build_nav() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "PitNavigation"
	game.world.add_child(nav_region)
	nav_link = NavigationLink3D.new()
	nav_link.name = "PitGateLink"
	nav_link.bidirectional = true
	nav_link.start_position = to_world(Vector3(0, 0, 8.0))
	nav_link.end_position = to_world(Vector3(0, 0, -14.0)) # beyond the yard floor, so it lands on the pit region only
	nav_link.enabled = false
	game.world.add_child(nav_link)
	NavigationServer3D.link_set_map(nav_link.get_rid(), game.nav_map) # created during _ready: make sure it is on the game's map

func is_baking() -> bool:
	return _baking or _bake_dirty

func request_bake() -> void:
	_bake_dirty = true

func _process(delta: float) -> void:
	_since_bake += delta
	if _bake_dirty and not _baking and _since_bake >= 1.0 and is_inside_tree():
		_start_bake()

func _collect_sources() -> NavigationMeshSourceGeometryData3D:
	var src := NavigationMeshSourceGeometryData3D.new()
	for b in find_children("*", "StaticBody3D", true, false):
		if b.collision_layer == 0 or bool(b.get_meta("nav_skip", false)) or bool(b.get_meta("curb", false)):
			continue
		for c in b.get_children():
			if c is CollisionShape3D and c.shape is BoxShape3D:
				src.add_faces(game._box_faces((c.shape as BoxShape3D).size), b.global_transform * c.transform)
	var n := 0
	for f in formations:
		if not is_instance_valid(f):
			continue
		for c in f.get_children():
			if c is CollisionShape3D and c.has_meta("column") and not c.disabled and game.prog.column_exposed(f.fid, int(c.get_meta("column"))):
				src.add_faces(game._box_faces((c.shape as BoxShape3D).size), f.global_transform * c.transform)
				n += 1
	last_source_boxes = n
	return src

func _start_bake() -> void:
	var t0 := Time.get_ticks_usec()
	_bake_dirty = false
	_baking = true
	var src := _collect_sources()
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for cx in [-plat_w * 0.5 - 3.0, plat_w * 0.5 + 3.0]:
		for cz in [4.0, plateau_z1() - 3.0]:
			var w := to_world(Vector3(cx, 0, cz))
			lo = lo.min(w)
			hi = hi.max(w)
	mesh.filter_baking_aabb = AABB(Vector3(lo.x, basin_y - 2.0, lo.z), Vector3(hi.x - lo.x, -basin_y + 2.0 + 10.0, hi.z - lo.z))
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, src, _on_baked.bind(mesh))
	bake_ms = float(Time.get_ticks_usec() - t0) / 1000.0

func _on_baked(mesh: NavigationMesh) -> void:
	nav_region.navigation_mesh = mesh
	bake_count += 1
	nav_ready = true
	_baking = false
	_since_bake = 0.0
