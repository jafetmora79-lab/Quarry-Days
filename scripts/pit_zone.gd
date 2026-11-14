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
const GRASS_DRY := "res://THE_VEIL_ASSETS_V2/Materials_Godot/Ground/M_Grnd_GrassDry.tres"
var flat := false              ## the blueprint quarry (new world): attached to the yard, fenced, flat start; no corridor, rim or rock walls
var level_pits: Array = []     ## Phase 7.2: [{"n", "rect": Rect2 (x, z, w, d) incl. ramp strip, "rw", "y_top", "y_bot", "cols": Rect2}] for quarry levels 2+
var basin_holes: Array = []    ## Rect2s (local x, z) cut out of the basin floor (the level-2 pit)
var deepest_y := -3.6

## Gate transform without needing the node (the world builder uses it before the zone exists).
static func gate_transform(c: Dictionary) -> Transform3D:
	var a := deg_to_rad(float(c.get("angle_deg", 306.0)))
	var r := float(c.get("gate_radius", 28.0))
	var d := Vector3(cos(a), 0, sin(a))
	return Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.z)), Vector3(d.x * r, 0, d.z * r))

func setup(main_node) -> bool:
	game = main_node
	cfg = game.prog.pit_cfg()
	flat = game.prog.filled_world()
	if cfg.is_empty():
		return false
	corr_len = float(cfg.get("corridor_length", corr_len))
	corr_w = float(cfg.get("corridor_width", corr_w))
	plat_w = float(cfg.get("plateau_width", plat_w))
	plat_d = float(cfg.get("plateau_depth", plat_d))
	basin_w = float(cfg.get("basin_width", basin_w))
	basin_d = float(cfg.get("basin_depth", basin_d))
	basin_y = float(cfg.get("basin_floor", basin_y))
	deepest_y = basin_y
	ramp_w = float(cfg.get("ramp_width", ramp_w))
	ramp_run = float(cfg.get("ramp_run", ramp_run))
	wall_h = float(cfg.get("wall_height", wall_h))
	build_margin = float(cfg.get("build_margin", build_margin))
	name = "PitZone"
	game.world.add_child(self)
	transform = gate_transform(cfg)
	_read_levels()
	_build_ground()
	_build_levels()
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
	if corr_len > 0.5:
		_body("Corridor floor", Vector3(0, -0.25, 3.0 - (corr_len + 3.0) * 0.5), Vector3(corr_w, 0.5, corr_len + 3.0))
	# plateau: thick pieces around the basin hole, so the hole's sides are solid walls
	if z0 - zs > 0.05:
		_body("Plateau south", Vector3(0, -2.75, (z0 + zs) * 0.5), Vector3(plat_w, 5.5, z0 - zs))
	if zn - z1 > 0.05:
		_body("Plateau north", Vector3(0, -2.75, (z1 + zn) * 0.5), Vector3(plat_w, 5.5, zn - z1))
	_body("Plateau west", Vector3(-(plat_w * 0.5 + hx) * 0.5, -2.75, basin_zc()), Vector3(plat_w * 0.5 - hx, 5.5, basin_d))
	_body("Plateau east", Vector3((plat_w * 0.5 + hx) * 0.5, -2.75, basin_zc()), Vector3(plat_w * 0.5 - hx, 5.5, basin_d))
	_slab_with_hole("Basin floor", Rect2(-hx, zn, basin_w, basin_d), basin_y, basin_holes[0] if not basin_holes.is_empty() else Rect2())
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
	if flat:
		return                  # the blueprint quarry is flush with the plateau: there is no basin ramp, so no curb to bump into (the art has none either)
	for side in [-1.0, 1.0]:
		var curb := _body("Ramp curb", Vector3(side * (ramp_w * 0.5 + 0.15), -depth * 0.5 + 0.5, zs - ramp_run * 0.5), Vector3(0.25, 1.0, length - 0.6), false, Vector3(-ang, 0, 0))
		curb.set_meta("curb", true)

## Floor slab (ground) over `rect` with its top at y_top, leaving `hole` open (an empty Rect2 = no hole): up to four boxes.
func _slab_with_hole(label: String, rect: Rect2, y_top: float, hole: Rect2) -> void:
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		_body(label, Vector3(rect.position.x + rect.size.x * 0.5, y_top - 0.25, rect.position.y + rect.size.y * 0.5), Vector3(rect.size.x, 0.5, rect.size.y))
		return
	var pieces := [
		Rect2(rect.position.x, rect.position.y, hole.position.x - rect.position.x, rect.size.y),                         # west
		Rect2(hole.end.x, rect.position.y, rect.end.x - hole.end.x, rect.size.y),                                        # east
		Rect2(hole.position.x, rect.position.y, hole.size.x, hole.position.y - rect.position.y),                         # north
		Rect2(hole.position.x, hole.end.y, hole.size.x, rect.end.y - hole.end.y)]                                        # south
	for r in pieces:
		if r.size.x > 0.01 and r.size.y > 0.01:
			_body(label, Vector3(r.position.x + r.size.x * 0.5, y_top - 0.25, r.position.y + r.size.y * 0.5), Vector3(r.size.x, 0.5, r.size.y))

## Reads quarry_levels[n].pit (levels 2-4) into level_pits and the holes cut in the floor above each pit.
## Phase 8.7: a pit is a big rectangle with a haul-road strip along one side. The ramp falls from the strip's `ramp_top`
## end over `ramp_run` metres to the level floor; the rest of the strip is flat road. The columns (the level's rock)
## fill the rest of the rectangle.
func _read_levels() -> void:
	level_pits.clear()
	basin_holes.clear()
	var levels: Array = game.prog.levels()
	for n in range(2, levels.size() + 1):
		var d: Dictionary = levels[n - 1]
		var pit: Dictionary = d.get("pit", {})
		if pit.is_empty() or not bool(d.get("built", false)):
			continue
		var r: Array = pit["rect"]
		var rw := float(pit.get("ramp_w", 9.0))
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
		var west := str(pit.get("side", "W")) == "W"
		var strip := Rect2(rect.position.x, rect.position.y, rw, rect.size.y) if west else Rect2(rect.end.x - rw, rect.position.y, rw, rect.size.y)
		var cols := Rect2(rect.position.x + rw, rect.position.y, rect.size.x - rw, rect.size.y) if west else Rect2(rect.position.x, rect.position.y, rect.size.x - rw, rect.size.y)
		level_pits.append({"n": n, "rect": rect, "rw": rw, "run": float(pit.get("ramp_run", 21.0)), "west": west, "y_top": float(pit["y_top"]), "y_bot": float(d["floor_y"]),
			"top_north": str(pit.get("ramp_top", "south")) == "north", "strip": strip, "cols": cols})
		deepest_y = minf(deepest_y, float(d["floor_y"]))
	if not level_pits.is_empty():
		basin_holes.append(level_pits[0]["rect"])

## One ramp (slab, solid fill under it, a curb on the open side) running along -z from (y_top at z_south) down to
## (y_bot at z_north), between x_a and x_b. Same construction as the basin ramp.
const CURB_OPEN := 0.45     ## where the ramp is lower than this above the floor beside it, the side rail ends: you can step off

## The side rail of a pit ramp covers only the steep upper part. Returns {"z": centre, "y": surface height at the centre, "len": length along the slope}.
func _curb_span(z_south: float, z_north: float, y_top: float, y_bot: float, top_north: bool) -> Dictionary:
	var run := z_south - z_north
	var rise := y_top - y_bot
	var frac := clampf(1.0 - CURB_OPEN / maxf(rise, 0.01), 0.1, 1.0)
	var rc := run * frac
	var z_top := z_north if top_north else z_south
	var sgn := 1.0 if top_north else -1.0
	var zc := z_top + sgn * rc * 0.5
	var yc := y_top - rise * frac * 0.5
	var ang := atan2(rise, run)
	return {"z": zc, "y": yc, "len": maxf(0.5, rc / cos(ang) - 0.3)}

## z range [south, north] of a pit's sloped part and of its flat run-out.
func ramp_span(lp: Dictionary) -> Dictionary:
	var rect: Rect2 = lp["rect"]
	var run: float = lp["run"]
	if bool(lp["top_north"]):
		return {"rs": rect.position.y + run, "rn": rect.position.y, "fs": rect.end.y, "fn": rect.position.y + run}
	return {"rs": rect.end.y, "rn": rect.end.y - run, "fs": rect.end.y - run, "fn": rect.position.y}

## Ramp profile with eased ends: [[d, y], ...] with d = distance down the ramp from its top end. The first and last
## metres run at half the slope, so a long machine rolls over the crest and into the foot instead of high-centring.
func ramp_profile(y_top: float, y_bot: float, run: float) -> Array:
	var rise := y_top - y_bot
	var e := minf(3.0, run * 0.2)
	var s := rise / run
	var s2 := (rise - e * s) / (run - 2.0 * e)
	return [[0.0, y_top], [e, y_top - s * 0.5 * e], [run - e, y_top - s * 0.5 * e - s2 * (run - 2.0 * e)], [run, y_bot]]

func _profile_y(prof: Array, d: float) -> float:
	for k in range(prof.size() - 1):
		var a: Array = prof[k]
		var b: Array = prof[k + 1]
		if d <= float(b[0]) + 0.0001:
			var t := clampf((d - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
			return lerpf(float(a[1]), float(b[1]), t)
	return float((prof[prof.size() - 1] as Array)[1])

func _make_ramp(label: String, x_a: float, x_b: float, z_south: float, z_north: float, y_top: float, y_bot: float, top_north := false, curb_east := true) -> void:
	var run := z_south - z_north
	var rise := y_top - y_bot
	var thick := 0.4
	var w := x_b - x_a
	var cx := (x_a + x_b) * 0.5
	var prof := ramp_profile(y_top, y_bot, run)
	for k in range(prof.size() - 1):
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
		var dd := float(p1[0]) - float(p0[0])
		var dy := float(p0[1]) - float(p1[1])
		var ang := atan2(dy, dd)
		var tilt := ang if top_north else -ang
		var dmid := (float(p0[0]) + float(p1[0])) * 0.5
		var zmid := z_north + dmid if top_north else z_south - dmid
		var ymid := (float(p0[1]) + float(p1[1])) * 0.5
		var slab := _body(label + " ramp", Vector3(cx, ymid - thick * 0.5 / cos(ang), zmid), Vector3(w, thick, sqrt(dd * dd + dy * dy)), true, Vector3(tilt, 0, 0))
		slab.set_meta("ramp", true)
	# solid fill under the slabs, stepped, so nobody crawls or looks under the ramp
	var n := 8
	for i in range(n):
		var seg := run / float(n)
		var surf_far := _profile_y(prof, seg * float(i + 1))
		var hgt := surf_far - y_bot - 0.3
		if hgt > 0.05:
			var d_mid := seg * (float(i) + 0.5)
			var zc := z_north + d_mid if top_north else z_south - d_mid
			var fill := _body(label + " ramp fill", Vector3(cx, y_bot - 0.25 + hgt * 0.5, zc), Vector3(w, hgt, seg), false)
			fill.set_meta("nav_skip", true)
			fill.set_meta("climbable", true)
	var cs := _curb_span(z_south, z_north, y_top, y_bot, top_north)
	var ang_l := atan2(rise, run)
	var tilt_l := ang_l if top_north else -ang_l
	var curb_x := x_b + 0.15 if curb_east else x_a - 0.15
	var curb := _body(label + " ramp curb", Vector3(curb_x, float(cs["y"]) + 0.5, float(cs["z"])), Vector3(0.25, 1.0, float(cs["len"])), false, Vector3(tilt_l, 0, 0))
	curb.set_meta("curb", true)

## The retaining walls of one pit as segments [side, x0, x1, z0, z1] (xz rectangle of the wall line): all four sides,
## except that the end where the ramp starts is open across the haul-road strip.
func wall_segments(lp: Dictionary) -> Array:
	var rect: Rect2 = lp["rect"]
	var strip: Rect2 = lp["strip"]
	var tn: bool = lp["top_north"]
	var out := []
	out.append(["west", rect.position.x, rect.position.x, rect.position.y, rect.end.y])
	out.append(["east", rect.end.x, rect.end.x, rect.position.y, rect.end.y])
	for end in ["north", "south"]:
		var z := rect.position.y if end == "north" else rect.end.y
		var open_here: bool = ((end == "north") == tn)
		if not open_here:
			out.append([end, rect.position.x, rect.end.x, z, z])
		elif lp["west"]:
			out.append([end, strip.end.x, rect.end.x, z, z])
		else:
			out.append([end, rect.position.x, strip.position.x, z, z])
	return out

## Collision shell of quarry levels 2-4: ramp, flat road, retaining walls and floor slabs (with a hole for the next level's pit).
## Everything is there from the start, under the flush columns of the level's rock; digging is what opens it up.
func _build_levels() -> void:
	for k in range(level_pits.size()):
		var lp: Dictionary = level_pits[k]
		var rect: Rect2 = lp["rect"]
		var cols: Rect2 = lp["cols"]
		var strip: Rect2 = lp["strip"]
		var y_top: float = lp["y_top"]
		var y_bot: float = lp["y_bot"]
		var n: int = lp["n"]
		var sp := ramp_span(lp)
		_make_ramp("L%d" % n, strip.position.x, strip.end.x, float(sp["rs"]), float(sp["rn"]), y_top, y_bot, bool(lp["top_north"]), bool(lp["west"]))
		# the flat road beyond the end of the ramp
		var fz0 := float(sp["fn"])
		var fz1 := float(sp["fs"])
		if fz1 - fz0 > 0.05:
			_body("L%d road" % n, Vector3(strip.position.x + strip.size.x * 0.5, y_bot - 0.25, (fz0 + fz1) * 0.5), Vector3(strip.size.x, 0.5, fz1 - fz0))
		var h := (y_top - y_bot) + 0.5
		var cy := y_bot - 0.5 + h * 0.5
		for sg in wall_segments(lp):
			var wl: Array = sg
			var wb: StaticBody3D
			match str(wl[0]):
				"west", "east":
					var xo: float = float(wl[1]) + (-0.5 if wl[0] == "west" else 0.5)
					wb = _body("L%d wall %s" % [n, wl[0]], Vector3(xo, cy, (float(wl[3]) + float(wl[4])) * 0.5), Vector3(1.0, h, rect.size.y + 2.0), false)
				_:
					var zo: float = float(wl[3]) + (-0.5 if wl[0] == "north" else 0.5)
					wb = _body("L%d wall %s" % [n, wl[0]], Vector3((float(wl[1]) + float(wl[2])) * 0.5, cy, zo), Vector3(float(wl[2]) - float(wl[1]) + 1.0, h, 1.0), false)
			wb.set_meta("nav_skip", true)
		var hole := Rect2()
		if k + 1 < level_pits.size():
			hole = level_pits[k + 1]["rect"]
		_slab_with_hole("L%d floor" % n, cols, y_bot, hole)

## The quarry's perimeter in the blueprint world: an industrial fence (collision boxes; rails and posts are drawn in _build_art) with the central
## vehicle gate on the yard side, and invisible boundary walls at the edge of the plateau so nothing leaves the property.
func _build_fence() -> void:
	var f: Array = cfg.get("fence", [-126.0, -100.0, 126.0, 0.0])
	var x0 := float(f[0])
	var z0f := float(f[1])
	var x1 := float(f[2])
	var z1f := float(f[3])
	var gate := 4.8
	var t := 0.3
	var h := 2.2
	var fb := []
	fb.append(_body("Quarry fence west", Vector3(x0, h * 0.5, (z0f + z1f) * 0.5), Vector3(t, h, z1f - z0f), false))
	fb.append(_body("Quarry fence east", Vector3(x1, h * 0.5, (z0f + z1f) * 0.5), Vector3(t, h, z1f - z0f), false))
	fb.append(_body("Quarry fence north", Vector3(0, h * 0.5, z0f), Vector3(x1 - x0, h, t), false))
	var seg := (x1 - x0) * 0.5 - gate
	fb.append(_body("Quarry fence south west", Vector3(x0 + seg * 0.5, h * 0.5, z1f), Vector3(seg, h, t), false))
	fb.append(_body("Quarry fence south east", Vector3(x1 - seg * 0.5, h * 0.5, z1f), Vector3(seg, h, t), false))
	for b in fb:
		b.set_meta("fence", true)          # drawn as ONE merged fence mesh (_build_fence_art); the old rim dressing must leave it alone
	var hb := 9.0
	_body("Boundary west", Vector3(-plat_w * 0.5 - 1.0, hb * 0.5, (plateau_z0() + plateau_z1()) * 0.5), Vector3(2.0, hb, plat_d + 6.0), false)
	_body("Boundary east", Vector3(plat_w * 0.5 + 1.0, hb * 0.5, (plateau_z0() + plateau_z1()) * 0.5), Vector3(2.0, hb, plat_d + 6.0), false)
	_body("Boundary north", Vector3(0, hb * 0.5, plateau_z1() - 1.0), Vector3(plat_w + 6.0, hb, 2.0), false)

func _build_walls() -> void:
	if flat:
		_build_fence()
		return
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
	if game.prog.filled_world():
		return                  # the filled quarry is flush with the plateau: nothing to fence off at the rim, you walk straight onto it
	var rim := 1.0
	_body("Rim west", Vector3(-hx - 0.15, rim * 0.5, basin_zc()), Vector3(0.3, rim, basin_d + 0.6), false)
	_body("Rim east", Vector3(hx + 0.15, rim * 0.5, basin_zc()), Vector3(0.3, rim, basin_d + 0.6), false)
	_body("Rim north", Vector3(0, rim * 0.5, zn - 0.15), Vector3(basin_w + 0.6, rim, 0.3), false)
	var rseg := hx - ramp_w * 0.5 - 0.6
	for side in [-1.0, 1.0]:
		_body("Rim south", Vector3(side * (ramp_w * 0.5 + 0.6 + rseg * 0.5), rim * 0.5, zs + 0.15), Vector3(rseg, rim, 0.3), false)

func _build_barrier() -> void:
	if flat:
		return                # the blueprint quarry has no rockfall barrier: the fence gate is the way in, open from the start
	barrier = _body("North gate barrier", Vector3(0, 2.0, -0.6), Vector3(corr_w + 1.0, 4.0, 1.4), false)
	barrier.set_meta("kind", "gate")
	var r := MeshKit.Soup.new()
	for k in range(7):
		MeshKit.rock_into(r, Vector3(-3.6 + k * 1.2 + (k % 2) * 0.2, -2.0 + 2.0, 0.0), Vector3(2.4, 2.4 + float(k % 3) * 0.7, 2.2), 710 + k)
	var mi := MeshKit.inst(barrier, r.mesh(), MeshKit.mat("RockLimestone"))
	mi.position.y = -2.0

# ------------------------------------------------------------------ visuals

## The blueprint quarry's industrial fence as ONE merged mesh (posts, rails, a wire-mesh band) plus a few hazard plates: the whole 700 m of fence is
## two draw calls. The central gate stays open (posts and a lintel on the yard side are drawn by the art layer).
func _build_fence_art(vis: Node3D) -> void:
	var f: Array = cfg.get("fence", [-126.0, -100.0, 126.0, 0.0])
	var x0 := float(f[0])
	var z0f := float(f[1])
	var x1 := float(f[2])
	var z1f := float(f[3])
	var gate := 4.8
	var steel := MeshKit.Soup.new()
	var wire := MeshKit.Soup.new()
	var runs := [[Vector2(x0, z0f), Vector2(x1, z0f)], [Vector2(x1, z0f), Vector2(x1, z1f)], [Vector2(x0, z1f), Vector2(x0, z0f)],
		[Vector2(x0, z1f), Vector2(-gate, z1f)], [Vector2(gate, z1f), Vector2(x1, z1f)]]
	# the property boundary: a proper fence all the way round (the invisible walls stand just behind it), so the edge of the site is something you can see
	var px := plat_w * 0.5
	var pz_south := 88.0                    # local z of the land's south edge (world z 80)
	var perimeter := [[Vector2(-px, z0f), Vector2(-px, pz_south)], [Vector2(px, z0f), Vector2(px, pz_south)], [Vector2(-px, pz_south), Vector2(px, pz_south)], [Vector2(-px, z0f), Vector2(x0, z0f)], [Vector2(x1, z0f), Vector2(px, z0f)]]
	var h := 2.2
	for r in runs + perimeter:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var d := b - a
		var len := d.length()
		var yaw := -atan2(d.y, d.x)
		var n := maxi(1, int(ceil(len / 3.0)))
		for i in range(n + 1):
			var p := a + d * (float(i) / float(n))
			MeshKit.box_into(steel, Vector3(p.x, h * 0.5, p.y), Vector3(0.14, h, 0.14))
		var c := (a + b) * 0.5
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, 0.0, c.y))
		MeshKit.box_into(steel, Vector3.ZERO, Vector3(len, 0.07, 0.07), Vector2.ONE, Transform3D(xf.basis, xf * Vector3(0, h - 0.05, 0)))
		MeshKit.box_into(steel, Vector3.ZERO, Vector3(len, 0.07, 0.07), Vector2.ONE, Transform3D(xf.basis, xf * Vector3(0, 0.12, 0)))
		MeshKit.box_into(wire, Vector3.ZERO, Vector3(len, h - 0.4, 0.02), Vector2.ONE, Transform3D(xf.basis, xf * Vector3(0, h * 0.5 + 0.02, 0)))
	MeshKit.inst(vis, steel.mesh(), MeshKit.mat("SteelPlate")).name = "FenceFrame"
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.42, 0.45, 0.47, 0.34)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 1.0
	MeshKit.inst(vis, wire.mesh(), wm).name = "FenceWire"


func _wob(y: float, x: float, z: float) -> float:
	return y + 0.02 * sin(x * 0.9 + z * 0.4)

## The ground rectangle (world x, z) the blueprint quarry's topsoil field stands on: the outer edges of the first formation's columns.
func _soil_footprint() -> Rect2:
	var id := "q_top"
	if game == null or game.prog == null or not game.prog.is_formation(id):
		return Rect2()
	var n: int = game.prog.column_count(id)
	var cell := float(game.prog.fdef(id)["cell"])
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in range(n):
		var p: Vector3 = game.prog.column_pos(id, i)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	if n == 0:
		return Rect2()
	return Rect2(lo.x - cell * 0.5, lo.y - cell * 0.5, hi.x - lo.x + cell, hi.y - lo.y + cell)

## The same rectangle in this node's own coordinates (the ground meshes are built there; the node itself stands a few metres off the world origin).
func _soil_footprint_local() -> Rect2:
	var w := _soil_footprint()
	if w.size.x <= 0.0:
		return w
	var a := to_loc(Vector3(w.position.x, 0.0, w.position.y))
	var b := to_loc(Vector3(w.end.x, 0.0, w.end.y))
	return Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(b.x - a.x), absf(b.z - a.z))

func _cell_quads(s: MeshKit.Soup, x0: float, x1: float, z0: float, z1: float, y: float, step: float, skip_hole := false, holes: Array = []) -> void:
	var hx := basin_w * 0.5
	var x := x0
	while x < x1 - 0.01:
		var z := z0
		while z < z1 - 0.01:
			var cx := x + step * 0.5
			var cz := z + step * 0.5
			var in_hole := skip_hole and absf(cx) < hx and cz > basin_zn() and cz < basin_zs()
			for hr in holes:
				if (hr as Rect2).has_point(Vector2(cx, cz)):
					in_hole = true
			if not in_hole:
				# heights are a function of the corner position, so neighbouring cells share their edges: no hairline cracks
				# for the sky to show through (the old cells each had their own height)
				var x2 := x + step
				var z2 := z + step
				s.quad(Vector3(x, _wob(y, x, z), z), Vector3(x, _wob(y, x, z2), z2), Vector3(x2, _wob(y, x2, z2), z2), Vector3(x2, _wob(y, x2, z), z))
			z += step
		x += step

## Rock colour of a level's cut faces: paler near the surface, then greyer (coal), rusty (iron/copper) and cold (the deepest bench).
func level_rock(n: int) -> Material:
	var tints := {1: Color(1.0, 1.0, 0.98), 2: Color(0.74, 0.72, 0.70), 3: Color(0.80, 0.62, 0.52), 4: Color(0.62, 0.58, 0.68)}
	return QuarryFormation.rock_material(tints.get(n, Color(1, 1, 1)))

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
	var foot := _soil_footprint_local()
	if flat and foot.size.x > 0.0:
		# the blueprint quarry: grass everywhere except exactly under the topsoil field (whose own surface and the basin floor below it cover that rectangle).
		# The cells are 2 m so the footprint's edges fall on cell edges: nothing overlaps it and no strip is left bare (the old rectangle did not match the soil)
		_cell_quads(plat, -plat_w * 0.5, plat_w * 0.5, minf(z1 - 8.0, foot.position.y - 4.0), z0, 0.01, 2.0, false, [foot])
	else:
		_cell_quads(plat, -plat_w * 0.5, plat_w * 0.5, z1, z0, 0.01, 3.0, true)
	MeshKit.inst(vis, plat.mesh(), MeshKit.mat(GRASS_DRY if flat else "ExcavatedDirt"))        # the land around the fenced quarry is dry grass; the quarry itself is bare soil
	var basin := MeshKit.Soup.new()
	_cell_quads(basin, -hx, hx, zn, zs, basin_y + 0.012, 2.0, false, basin_holes)
	MeshKit.inst(vis, basin.mesh(), MeshKit.mat("ExcavatedDirt"))
	var hw := ramp_w * 0.5
	if not flat:                  # (the blueprint quarry is flush with the plateau: no basin ramp, no curbs)
		# ramp surface
		var depth := -basin_y
		var ang := atan2(depth, ramp_run)
		var length := sqrt(ramp_run * ramp_run + depth * depth)
		var rs := MeshKit.Soup.new()
		var rxf := Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(0, -depth * 0.5 + 0.02, zs - ramp_run * 0.5))
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
	# quarry levels 2-4: floors, haul roads and retaining walls of each pit (see _build_levels)
	for k in range(level_pits.size()):
		var lp: Dictionary = level_pits[k]
		var rect: Rect2 = lp["rect"]
		var cols: Rect2 = lp["cols"]
		var strip: Rect2 = lp["strip"]
		var yt: float = lp["y_top"]
		var yb: float = lp["y_bot"]
		var tn: bool = lp["top_north"]
		var sp := ramp_span(lp)
		var hole: Array = []
		if k + 1 < level_pits.size():
			hole.append(level_pits[k + 1]["rect"])
		var lf := MeshKit.Soup.new()
		_cell_quads(lf, cols.position.x, cols.end.x, cols.position.y, cols.end.y, yb + 0.012, 3.0, false, hole)
		MeshKit.inst(vis, lf.mesh(), MeshKit.mat("ExcavatedDirt"))
		var lroad := MeshKit.Soup.new()
		var fz0 := float(sp["fn"])
		var fz1 := float(sp["fs"])
		if fz1 - fz0 > 0.05:
			_cell_quads(lroad, strip.position.x, strip.end.x, fz0, fz1, yb + 0.015, 3.0)
		# the ramp surface and the side of its solid body (towards the rock), following the eased profile
		var run: float = float(sp["rs"]) - float(sp["rn"])
		var rise := yt - yb
		var prof := ramp_profile(yt, yb, run)
		var sx0 := strip.position.x
		var sx1 := strip.end.x
		var lw := MeshKit.Soup.new()
		var xe: float = cols.position.x if lp["west"] else cols.end.x
		for q in range(prof.size() - 1):
			var p0: Array = prof[q]
			var p1: Array = prof[q + 1]
			var z0r: float = float(sp["rn"]) + float(p0[0]) if tn else float(sp["rs"]) - float(p0[0])
			var z1r: float = float(sp["rn"]) + float(p1[0]) if tn else float(sp["rs"]) - float(p1[0])
			var y0r := float(p0[1]) + 0.02
			var y1r := float(p1[1]) + 0.02
			if tn:
				lroad.quad(Vector3(sx0, y0r, z0r), Vector3(sx0, y1r, z1r), Vector3(sx1, y1r, z1r), Vector3(sx1, y0r, z0r))
			else:
				lroad.quad(Vector3(sx0, y0r, z0r), Vector3(sx1, y0r, z0r), Vector3(sx1, y1r, z1r), Vector3(sx0, y1r, z1r))      # the ramp runs the other way: wind it to face up
			lw.quad(Vector3(xe, y0r, z0r), Vector3(xe, yb, z0r), Vector3(xe, yb, z1r), Vector3(xe, y1r, z1r))
			lw.quad(Vector3(xe, y0r, z0r), Vector3(xe, y1r, z1r), Vector3(xe, yb, z1r), Vector3(xe, yb, z0r))
		MeshKit.inst(vis, lroad.mesh(), MeshKit.mat("GroundRoad"))
		MeshKit.inst(vis, lw.mesh(), level_rock(int(lp["n"])))
		var lang := atan2(rise, run)
		var ltilt := lang if tn else -lang
		var lc := MeshKit.Soup.new()
		var lcs := _curb_span(float(sp["rs"]), float(sp["rn"]), yt, yb, tn)
		var cxo: float = (cols.position.x + 0.15) if lp["west"] else (cols.end.x - 0.15)
		MeshKit.box_into(lc, Vector3.ZERO, Vector3(0.25, 0.35, float(lcs["len"])), Vector2.ONE, Transform3D(Basis(Vector3.RIGHT, ltilt), Vector3(cxo, float(lcs["y"]) + 0.17, float(lcs["z"]))))
		MeshKit.inst(vis, lc.mesh(), MeshKit.mat("Hazard"))
		# cliff faces of the pit walls, in the level's own rock colour
		var lh := rise + 0.3
		var wsoup := MeshKit.Soup.new()
		var sd := 900 + k * 11
		for sg in wall_segments(lp):
			var wl: Array = sg
			sd += 1
			match str(wl[0]):
				"north": _wall(wsoup, float(wl[2]) - float(wl[1]) + 0.9, lh, 0.8, sd, 2, PI, Vector3((float(wl[1]) + float(wl[2])) * 0.5, yb, float(wl[3]) - 0.4))
				"south": _wall(wsoup, float(wl[2]) - float(wl[1]) + 0.9, lh, 0.8, sd, 2, 0.0, Vector3((float(wl[1]) + float(wl[2])) * 0.5, yb, float(wl[3]) + 0.4))
				"west": _wall(wsoup, rect.size.y + 1.8, lh, 0.8, sd, 2, -PI * 0.5, Vector3(float(wl[1]) - 0.4, yb, (float(wl[3]) + float(wl[4])) * 0.5))
				"east": _wall(wsoup, rect.size.y + 1.8, lh, 0.8, sd, 2, PI * 0.5, Vector3(float(wl[1]) + 0.4, yb, (float(wl[3]) + float(wl[4])) * 0.5))
		MeshKit.inst(vis, wsoup.mesh(), level_rock(int(lp["n"])))
	if flat:
		_build_fence_art(vis)       # industrial fencing instead of any rock enclosure
		return
	# basin walls (pale cut limestone), facing into the basin
	var bw := MeshKit.Soup.new()
	var hgt := -basin_y + 0.4
	_wall(bw, basin_w + 1.8, hgt, 0.8, 801, 2, PI, Vector3(0, basin_y, zn - 0.4))
	_wall(bw, basin_d + 1.8, hgt, 0.8, 802, 2, -PI * 0.5, Vector3(-hx - 0.4, basin_y, basin_zc()))
	_wall(bw, basin_d + 1.8, hgt, 0.8, 803, 2, PI * 0.5, Vector3(hx + 0.4, basin_y, basin_zc()))
	var sl := hx - hw
	_wall(bw, sl, hgt, 0.8, 804, 2, 0.0, Vector3(-hw - sl * 0.5, basin_y, zs + 0.4))
	_wall(bw, sl, hgt, 0.8, 805, 2, 0.0, Vector3(hw + sl * 0.5, basin_y, zs + 0.4))
	MeshKit.inst(vis, bw.mesh(), MeshKit.mat("CutLimestone"))
	# outer perimeter and corridor walls (the same brown cliff strata as the yard ring), facing inward
	var ow := MeshKit.Soup.new()
	var oh := wall_h + 0.6
	_wall(ow, plat_w + 6.0, oh, 3.0, 811, 4, PI, Vector3(0, 0, z1 - 1.5))
	_wall(ow, plat_d + 3.0, oh, 3.0, 812, 4, -PI * 0.5, Vector3(-plat_w * 0.5 - 1.5, 0, (z0 + z1) * 0.5))
	_wall(ow, plat_d + 3.0, oh, 3.0, 813, 4, PI * 0.5, Vector3(plat_w * 0.5 + 1.5, 0, (z0 + z1) * 0.5))
	var seg := plat_w * 0.5 - corr_w * 0.5
	_wall(ow, seg, oh, 3.0, 814, 4, 0.0, Vector3(-corr_w * 0.5 - seg * 0.5, 0, z0 + 1.5))
	_wall(ow, seg, oh, 3.0, 815, 4, 0.0, Vector3(corr_w * 0.5 + seg * 0.5, 0, z0 + 1.5))
	_wall(ow, corr_len + 2.0, 6.4, 2.0, 816, 3, -PI * 0.5, Vector3(-corr_w * 0.5 - 1.0, 0, -corr_len * 0.5))
	_wall(ow, corr_len + 2.0, 6.4, 2.0, 817, 3, PI * 0.5, Vector3(corr_w * 0.5 + 1.0, 0, -corr_len * 0.5))
	MeshKit.inst(vis, ow.mesh(), MeshKit.mat("CliffStrata"))
	# railings along the basin rim, leaving the ramp mouth open
	var x := -hx + 1.25
	while x < hx - 1.0:
		if absf(x) > hw + 0.9:
			MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(x, 0, zn - 0.15), 0.0)
			MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(x, 0, zs + 0.15), 0.0)
		x += 5.0
	var z := zn + 1.25
	while z < zs - 1.0:
		MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(-hx - 0.15, 0, z), PI * 0.5)
		MeshKit.prop(vis, QuarryArt.P_RAILING, Vector3(hx + 0.15, 0, z), PI * 0.5)
		z += 5.0

# ------------------------------------------------------------------ gate

func set_open(open: bool) -> void:
	is_open = open or flat
	if barrier != null:
		barrier.visible = not is_open
		barrier.collision_layer = 0 if is_open else 1
		barrier.set_meta("nav_skip", is_open)
	if nav_link:
		nav_link.enabled = is_open
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
	# the floors of the lower levels: machines may stand on a cleared floor (belts, outputs, crushers), away from the walls,
	# the ramps and the pit of the next level. (The floor must really be there: placement also checks the ground.)
	for k in range(level_pits.size()):
		var lp: Dictionary = level_pits[k]
		if absf(l.y - float(lp["y_bot"])) < 1.0:
			var inset: Rect2 = (lp["cols"] as Rect2).grow(-(1.0 + margin))
			if not inset.has_point(Vector2(l.x, l.z)):
				continue
			if k + 1 < level_pits.size() and (level_pits[k + 1]["rect"] as Rect2).grow(1.0).has_point(Vector2(l.x, l.z)):
				continue
			return true
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
			if c is CollisionShape3D and c.has_meta("column") and not c.disabled and game.prog.column_walkable(f.fid, int(c.get_meta("column"))):
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
	mesh.filter_baking_aabb = AABB(Vector3(lo.x, deepest_y - 2.0, lo.z), Vector3(hi.x - lo.x, -deepest_y + 2.0 + 10.0, hi.z - lo.z))
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, src, _on_baked.bind(mesh))
	bake_ms = float(Time.get_ticks_usec() - t0) / 1000.0

func _on_baked(mesh: NavigationMesh) -> void:
	nav_region.navigation_mesh = mesh
	bake_count += 1
	nav_ready = true
	_baking = false
	_since_bake = 0.0
