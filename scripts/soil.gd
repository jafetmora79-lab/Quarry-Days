extends Node3D
class_name QuarrySoil
## The soil field of the working ground (data "soil": 22 x 10 cells of 2 m, 3 layers of 0.3 m, 4 units a layer), now REAL GROUND: the soil is a layer of loose topsoil lying on the
## quarry terrain (QuarryTerrain), not a grid of boxes drawn over it. Walking on it, digging it with a shovel, scooping it with a loader, pushing it with a dozer, its edges slumping to
## the angle of repose - all of that is the terrain's. This class is the bookkeeping VIEW of that ground that contracts, machines, crew and saves already speak: cells, units per cell,
## a cell's height, "take n units", "put n units", the cells a machine stands on. One soil unit = cell x cell x full depth / max units = 0.3 m3 of loose topsoil, exactly the volume the
## old field gave per unit, so every contract number (soil removed, soil hauled) means what it always meant.
##
## units[i] is DERIVED from the terrain (sync()): the loose topsoil over the cell's 16 vertices. A saved game keeps the terrain snapshot; an older save (cells only) is applied to the
## terrain at load (apply()). Without a terrain (legacy layouts) the field is units-only bookkeeping.

signal cells_changed(cells: Array)

var cols := 0
var rows := 0
var cell := 2.0
var origin := Vector2.ZERO
var layers := 3
var units_per_layer := 4
var layer_h := 0.3
var units := PackedInt32Array()
var active := PackedByteArray()          ## 1 = the cell is part of the soil field (clear of rocks, paths and the spoil heap)
var terrain: QuarryTerrain               ## the ground the soil lies on (set before setup())
var removed_total := 0
var _dirty_cells := {}
var _dirty := true
var _since_sync := 0.0

func max_units() -> int:
	return layers * units_per_layer

func full_depth() -> float:
	return float(layers) * layer_h

## m3 of loose topsoil in one soil unit.
func unit_volume() -> float:
	return cell * cell * full_depth() / float(max_units())

func setup(cfg: Dictionary, mask: PackedByteArray, saved: Array) -> void:
	name = "SoilField"
	cols = int(cfg["cols"])
	rows = int(cfg["rows"])
	cell = float(cfg.get("cell", 2.0))
	origin = Vector2(float(cfg["origin"][0]), float(cfg["origin"][1]))
	layers = int(cfg.get("layers", 3))
	units_per_layer = int(cfg.get("units_per_layer", 4))
	layer_h = float(cfg.get("layer_h", 0.3))
	active = mask
	units = PackedInt32Array()
	units.resize(cols * rows)
	apply(saved)

func _cell_rect(i: int) -> Rect2:
	return Rect2(origin.x + float(i % cols) * cell, origin.y + float(i / cols) * cell, cell, cell)

## Sets every cell from a saved list (an empty or mismatched list means untouched ground: full depth). The terrain's loose topsoil over each cell is raised or lowered to match, then the
## whole field settles to its angle of repose (the hard square edges slump into real slopes). A newer save restores the terrain itself afterwards and sync() reads it back.
func apply(saved: Array) -> void:
	for i in range(units.size()):
		var u := max_units() if int(active[i]) == 1 else 0
		if saved.size() == units.size() and int(active[i]) == 1:
			u = clampi(int(saved[i]), 0, max_units())
		units[i] = u
		if terrain != null and int(active[i]) == 1:
			_match_terrain(i, u)
	if terrain != null:
		terrain.flush(true)
		sync()
	_dirty = true
	_dirty_cells.clear()

func _match_terrain(i: int, u: int) -> void:
	if _read_cell(i) == u:
		return                                   # the ground already holds exactly this many units (a saved terrain restores itself: do not round it)
	var want := float(u) * unit_volume()
	var r := _cell_rect(i)
	var have := terrain.loose_rect_volume(r, "topsoil")
	if want > have + 0.000001:
		terrain.loose_rect_add(r, "topsoil", want - have)
	elif have > want + 0.000001:
		terrain.loose_rect_take(r, "topsoil", have - want)

func _read_cell(i: int) -> int:
	return clampi(int(round(terrain.loose_rect_volume(_cell_rect(i), "topsoil") / unit_volume())), 0, max_units())

## Reads every cell's units back from the ground.
func sync() -> void:
	if terrain == null:
		return
	for i in range(units.size()):
		if int(active[i]) == 1:
			units[i] = _read_cell(i)

## Reads the cells within `radius` of `p` back from the ground.
func sync_near(p: Vector3, radius: float) -> void:
	if terrain == null:
		return
	var c0 := cell_at(p)
	var span := int(ceil(radius / cell)) + 1
	var cx0 := (c0 % cols) if c0 >= 0 else clampi(int(floor((p.x - origin.x) / cell)), 0, cols - 1)
	var cz0 := (c0 / cols) if c0 >= 0 else clampi(int(floor((p.z - origin.y) / cell)), 0, rows - 1)
	for cz in range(maxi(0, cz0 - span), mini(rows, cz0 + span + 1)):
		for cx in range(maxi(0, cx0 - span), mini(cols, cx0 + span + 1)):
			var i := cz * cols + cx
			if int(active[i]) == 1:
				units[i] = _read_cell(i)

func total() -> int:
	var n := 0
	for u in units:
		n += int(u)
	return n

func cell_center(i: int) -> Vector3:
	return Vector3(origin.x + (float(i % cols) + 0.5) * cell, 0.0, origin.y + (float(i / cols) + 0.5) * cell)

func cell_at(p: Vector3) -> int:
	var cx := int(floor((p.x - origin.x) / cell))
	var cz := int(floor((p.z - origin.y) / cell))
	if cx < 0 or cz < 0 or cx >= cols or cz >= rows:
		return -1
	return cz * cols + cx

## Depth of the loose soil in a cell (what its units stand for), m.
func height(i: int) -> float:
	return float(units[i]) / float(max_units()) * full_depth()

## The ground height under a point (the real surface).
func surface_y(p: Vector3) -> float:
	if terrain != null and terrain.in_bounds(p.x, p.z):
		return terrain.height_at(p.x, p.z)
	var i := cell_at(p)
	return height(i) if i >= 0 else 0.0

## The cell with soil nearest to `p` within `reach` (measured on the ground), or -1.
func nearest_cell(p: Vector3, reach: float, exclude := {}) -> int:
	var best := -1
	var best_d := reach
	sync_near(p, reach)
	var c0 := cell_at(p)
	var span := int(ceil(reach / cell)) + 1
	var cx0 := (c0 % cols) if c0 >= 0 else clampi(int(floor((p.x - origin.x) / cell)), 0, cols - 1)
	var cz0 := (c0 / cols) if c0 >= 0 else clampi(int(floor((p.z - origin.y) / cell)), 0, rows - 1)
	for cz in range(maxi(0, cz0 - span), mini(rows, cz0 + span + 1)):
		for cx in range(maxi(0, cx0 - span), mini(cols, cx0 + span + 1)):
			var i := cz * cols + cx
			if int(units[i]) <= 0 or exclude.has(i):
				continue
			var c := cell_center(i)
			var d := Vector2(c.x - p.x, c.z - p.z).length()
			if d < best_d:
				best_d = d
				best = i
	return best

## The cells a rectangle lies on (`xf` places it, `half` = half its width and depth): what a machine stands on.
func cells_under(xf: Transform3D, half: Vector2) -> Dictionary:
	var out := {}
	var nx := int(ceil(half.x * 2.0 / (cell * 0.5))) + 1
	var nz := int(ceil(half.y * 2.0 / (cell * 0.5))) + 1
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			var lp := Vector3(lerpf(-half.x, half.x, float(ix) / float(nx)), 0.0, lerpf(-half.y, half.y, float(iz) / float(nz)))
			var i := cell_at(xf * lp)
			if i >= 0:
				out[i] = true
	return out

## Puts up to n units into an active cell (spreading what a bulldozer carries); returns what fitted. Never beyond the full depth.
func add(i: int, n: int) -> int:
	if i < 0 or i >= units.size() or n <= 0 or int(active[i]) != 1:
		return 0
	if terrain != null:
		units[i] = _read_cell(i)
	var put := mini(n, max_units() - int(units[i]))
	if put <= 0:
		return 0
	if terrain != null:
		terrain.loose_rect_add(_cell_rect(i), "topsoil", float(put) * unit_volume())
	units[i] = int(units[i]) + put
	removed_total = maxi(0, removed_total - put)
	_dirty_cells[i] = true
	_dirty = true
	return put

## Takes up to n units out of a cell; returns what was taken.
func remove(i: int, n: int) -> int:
	if i < 0 or i >= units.size() or n <= 0:
		return 0
	if terrain != null:
		units[i] = _read_cell(i)
	var take := mini(n, int(units[i]))
	if take <= 0:
		return 0
	if terrain != null:
		terrain.loose_rect_take(_cell_rect(i), "topsoil", float(take) * unit_volume())
	units[i] = int(units[i]) - take
	removed_total += take
	_dirty_cells[i] = true
	_dirty = true
	return take

## Tells whoever cares which cells changed (vehicles standing on them wake up). The ground itself is drawn and collided by the terrain.
func refresh(force := false) -> void:
	if not _dirty and not force:
		return
	var changed := _dirty_cells.keys()
	_dirty_cells.clear()
	_dirty = false
	if not changed.is_empty():
		cells_changed.emit(changed)

## The ground keeps settling after a cut (the loose soil slumps into a hole, a heap spreads): every half second the cells are read back so machines and the crew see it.
func _process(delta: float) -> void:
	if terrain == null:
		return
	_since_sync += delta
	if _since_sync >= 0.5:
		_since_sync = 0.0
		sync()
