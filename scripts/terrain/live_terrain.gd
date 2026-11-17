extends Node3D
class_name LiveTerrain
## The quarry's real ground (step 1 of the digging integration): the heightfield terrain (QuarryTerrain) laid over the whole filled quarry, 244 x 92 m, standing in for the
## formation columns' skins and colliders. People, vehicles and workers now walk on it; the surface you see is the geology (topsoil, clay, gravel, limestone, coal, iron ...)
## textured by material, with dug faces that slump to their angle of repose.
##
## The formations (data/progression.json) stay the BOOKKEEPING for now: every column a tool, machine, crew or the dinosaur cuts lowers the terrain under that column to the
## column's new top (refresh_column), and a saved game's cut columns lower it at load. Their colliders move to layer 32 (mining rays and look-at see them, nobody walks on them)
## and their skins are hidden. Only the marked excavation (progression dig rects) is unlocked; everything else is locked so it never slumps or digs.
## Later steps move the source of truth from the columns to the terrain (player digging, machines, crews, saves).

const ORIGIN := Vector2(-122.0, -108.0)
const SIZE := Vector2(256.0, 96.0)

var game
var prog
var geo: QuarryGeology
var terrain: QuarryTerrain
var attach_ms := 0.0
var synced_columns := 0

func attach(g) -> void:
	var t0 := Time.get_ticks_usec()
	game = g
	prog = g.prog
	name = "LiveTerrain"
	geo = QuarryGeology.new(prog)
	terrain = QuarryTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(Rect2(ORIGIN, SIZE), geo, Callable(self, "_natural"))
	terrain.lock_rect(Rect2(ORIGIN, SIZE))                          # everything locked ...
	var dr: Array = prog.dig_rect("q_top")
	if dr.is_empty():
		dr = [ORIGIN.x + 2.0, ORIGIN.y + 4.0, ORIGIN.x + SIZE.x - 2.0, ORIGIN.y + SIZE.y - 2.0]
	terrain.unlock_rect(Rect2(float(dr[0]), float(dr[1]), float(dr[2]) - float(dr[0]), float(dr[3]) - float(dr[1])))   # ... except the marked excavation
	for id in geo._formations:
		for i in range(prog.column_count(id)):
			if prog.chunks_left(id, i) < prog.column_tiers(id, i):
				refresh_column(id, i)
	terrain.flush(true)
	for id in geo._formations:
		if game.formation_nodes.has(id):
			var node: QuarryFormation = game.formation_nodes[id]
			node.collision_layer = 32                                  # rays and look-at only
			if node.skin_mi != null:
				node.skin_mi.visible = false
	attach_ms = float(Time.get_ticks_usec() - t0) / 1000.0

## Natural ground height before any digging: the plain at 0; the margin beyond the formations' footprint sits 4 cm below the old yard ground so the two never z-fight.
func _natural(x: float, z: float) -> float:
	if x < -122.0 or x > 122.0 or z < -104.0:
		return -0.04
	return 0.0

## The height the quarry's columns currently leave at (x, z): the top of the highest formation with rock or soil left there; where all of them are cut, the floor
## under the lowest. NAN where no formation lies at all.
func surface_at(x: float, z: float) -> float:
	# a vertex on the border between two columns takes the LOWER one, so a cut keeps its full width and its wall starts exactly on the column edge (a truck lane is not narrowed)
	var lo := NAN
	for o in [Vector2(-0.02, -0.02), Vector2(0.02, -0.02), Vector2(-0.02, 0.02), Vector2(0.02, 0.02)]:
		var v := _surface_point(x + o.x, z + o.y)
		if not is_nan(v) and (is_nan(lo) or v < lo):
			lo = v
	return lo

func _surface_point(x: float, z: float) -> float:
	var p := Vector3(x, 0.0, z)
	var best := -INF
	var floor_y := INF
	var any := false
	for id in geo._formations:
		var col: int = prog.cell_index_at(id, p)
		if col < 0 or prog.column_tiers(id, col) <= 0:
			continue
		any = true
		var bottom: float = prog.column_pos(id, col).y
		floor_y = minf(floor_y, bottom)
		var want: int = prog.chunks_left(id, col)
		if want > 0:
			best = maxf(best, bottom + float(want) * float(prog.fdef(id)["tier_h"]))
	if best > -INF:
		return best
	var lf := _level_floor(p)
	if not is_nan(lf):
		return lf
	return floor_y if any else NAN

## Where every column is cut away the ground is the floor of the pit level that point belongs to (the pit shells of levels 2 to 5, whose floors lie below the formations of the
## level above: level 5's floor at -14.4 m under the bottoms of level 4's rock at -12 m). NAN outside every level.
func _level_floor(w: Vector3) -> float:
	if game.pit_zone == null:
		return NAN
	var l: Vector3 = game.pit_zone.to_loc(w)
	var low := NAN
	for lp in game.pit_zone.level_pits:
		var r: Rect2 = lp["cols"]
		var yb := float(lp["y_bot"])
		var inside: bool = r.has_point(Vector2(l.x, l.z))
		if not inside:                                      # the level's haul ramp and floor road: the ground is under the ramp body (a separate solid), never above it
			var sp: Dictionary = game.pit_zone.ramp_span(lp)
			var strip: Rect2 = lp["strip"]
			var z0 := minf(float(sp["rn"]), float(sp["fn"]))
			var z1 := maxf(float(sp["rs"]), float(sp["fs"]))
			inside = l.x >= strip.position.x and l.x <= strip.end.x and l.z >= z0 and l.z <= z1
		if inside and (is_nan(low) or yb < low):
			low = yb
	return low

## Lowers (or raises) the terrain under one formation column to what the columns now leave there.
func refresh_column(fid: String, col: int) -> void:
	if terrain == null:
		return
	var c: Vector3 = prog.column_pos(fid, col)
	var half := float(prog.fdef(fid)["cell"]) * 0.5
	var i0 := int(ceil((c.x - half - terrain.origin.x) / QuarryTerrain.CELL - 0.0001))
	var i1 := int(floor((c.x + half - terrain.origin.x) / QuarryTerrain.CELL + 0.0001))      # both border rows: a border vertex follows whichever side is lower
	var j0 := int(ceil((c.z - half - terrain.origin.y) / QuarryTerrain.CELL - 0.0001))
	var j1 := int(floor((c.z + half - terrain.origin.y) / QuarryTerrain.CELL + 0.0001))
	for j in range(maxi(0, j0), mini(terrain.VR - 1, j1) + 1):
		for i in range(maxi(0, i0), mini(terrain.V - 1, i1) + 1):
			var xz := terrain.vertex_xz(i, j)
			var s := surface_at(xz.x, xz.y)
			if is_nan(s):
				continue
			var k := terrain.idx(i, j)
			var d := maxf(0.0, terrain.ntop[k] - s)
			if absf(d - terrain.dug[k]) > 0.0001:
				terrain.dug[k] = d
				terrain._dirty_vertex(i, j)
	synced_columns += 1

## Footprint of a structure: flatten and lock it so nothing digs or slumps under it (and unlock when it is sold or moved).
func lock_footprint(center: Vector3, half: Vector2) -> void:
	if terrain == null:
		return
	var r := Rect2(center.x - half.x, center.z - half.y, half.x * 2.0, half.y * 2.0)
	if terrain.in_bounds(center.x, center.z):
		terrain.lock_rect(r, 0.5)

func unlock_footprint(center: Vector3, half: Vector2) -> void:
	if terrain == null:
		return
	var dr: Array = prog.dig_rect("q_top")
	terrain.unlock_rect(Rect2(center.x - half.x, center.z - half.y, half.x * 2.0, half.y * 2.0), 0.5)
	if not dr.is_empty():                                              # whatever lies outside the marked excavation stays locked
		var full := Rect2(ORIGIN, SIZE)
		var dig := Rect2(float(dr[0]), float(dr[1]), float(dr[2]) - float(dr[0]), float(dr[3]) - float(dr[1]))
		for j in range(terrain.VR):
			var z := terrain.origin.y + float(j) * QuarryTerrain.CELL
			for i in range(terrain.V):
				var x := terrain.origin.x + float(i) * QuarryTerrain.CELL
				if full.has_point(Vector2(x, z)) and not dig.has_point(Vector2(x, z)):
					terrain.locked[terrain.idx(i, j)] = 1
