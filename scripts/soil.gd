extends Node3D
class_name QuarrySoil
## Phase 10.2: the loose soil that covers the working ground. A fixed grid of cells (data "soil"), each holding a number of soil units
## (units_per_cell = layers x units_per_layer); the surface height of a cell is its fraction of full depth times the full depth.
## Digging only ever takes units out of a cell: the units become cargo, are dumped on the spoil heap, and are counted - nothing appears
## from nowhere. Collision is one box per cell inside ONE static body (a box is switched off when its cell is empty); the visible surface
## is ONE mesh rebuilt when cells change; where a cell is empty nothing is drawn and the topsoil layer under it (the formation q_top) shows.

var cols := 0
var rows := 0
var cell := 2.0
var origin := Vector2.ZERO
var layers := 3
var units_per_layer := 4
var layer_h := 0.3
var units := PackedInt32Array()
var active := PackedByteArray()          ## 1 = the cell is part of the soil field (clear of rocks, paths and the spoil heap)
var body: StaticBody3D
var shapes: Array = []
var surface: MeshInstance3D
var _dirty := true
var _dirty_cells := {}
var removed_total := 0

func max_units() -> int:
	return layers * units_per_layer

func full_depth() -> float:
	return float(layers) * layer_h

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
	for i in range(cols * rows):
		var u := max_units() if int(active[i]) == 1 else 0
		if saved.size() == cols * rows and int(active[i]) == 1:
			u = clampi(int(saved[i]), 0, max_units())
		units[i] = u
	body = StaticBody3D.new()
	body.name = "SoilBody"
	body.set_meta("climbable", true)         # a low heap can be climbed like a ledge
	add_child(body)
	for i in range(cols * rows):
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		cs.shape = box
		body.add_child(cs)
		shapes.append(cs)
	surface = MeshInstance3D.new()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.material_override = MeshKit.mat("ExcavatedDirt")
	add_child(surface)
	refresh(true)

## Sets every cell from a saved list (an empty or mismatched list means untouched ground: full depth).
func apply(saved: Array) -> void:
	for i in range(units.size()):
		var u := max_units() if int(active[i]) == 1 else 0
		if saved.size() == units.size() and int(active[i]) == 1:
			u = clampi(int(saved[i]), 0, max_units())
		units[i] = u
	refresh(true)

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

func height(i: int) -> float:
	return float(units[i]) / float(max_units()) * full_depth()

## Highest ground of the cell under a point (0 where there is no soil).
func surface_y(p: Vector3) -> float:
	var i := cell_at(p)
	return height(i) if i >= 0 else 0.0

## The cell with soil nearest to `p` within `reach` (measured on the ground), or -1.
func nearest_cell(p: Vector3, reach: float) -> int:
	var best := -1
	var best_d := reach
	var c0 := cell_at(p)
	var span := int(ceil(reach / cell)) + 1
	var cx0 := (c0 % cols) if c0 >= 0 else clampi(int(floor((p.x - origin.x) / cell)), 0, cols - 1)
	var cz0 := (c0 / cols) if c0 >= 0 else clampi(int(floor((p.z - origin.y) / cell)), 0, rows - 1)
	for cz in range(maxi(0, cz0 - span), mini(rows, cz0 + span + 1)):
		for cx in range(maxi(0, cx0 - span), mini(cols, cx0 + span + 1)):
			var i := cz * cols + cx
			if int(units[i]) <= 0:
				continue
			var c := cell_center(i)
			var d := Vector2(c.x - p.x, c.z - p.z).length()
			if d < best_d:
				best_d = d
				best = i
	return best

## Takes up to n units out of a cell; returns what was taken.
func remove(i: int, n: int) -> int:
	if i < 0 or i >= units.size() or n <= 0:
		return 0
	var take := mini(n, int(units[i]))
	if take <= 0:
		return 0
	units[i] = int(units[i]) - take
	removed_total += take
	_dirty_cells[i] = true
	_dirty = true
	return take

func refresh(force := false) -> void:
	if not _dirty and not force:
		return
	for i in range(units.size()):
		if force or _dirty_cells.has(i):
			var cs: CollisionShape3D = shapes[i]
			var h := height(i)
			cs.disabled = h < 0.05
			(cs.shape as BoxShape3D).size = Vector3(cell, maxf(0.1, h), cell)
			var c := cell_center(i)
			cs.position = Vector3(c.x, maxf(0.1, h) * 0.5, c.z)
	_dirty_cells.clear()
	_dirty = false
	_rebuild_meshes()

func _noise(gx: int, gz: int, salt: int) -> float:
	return float(abs(hash(Vector3i(gx, gz, salt))) % 1000) / 1000.0

func _corner(gx: int, gz: int, y: float) -> Vector3:
	var inner := gx > 0 and gx < cols and gz > 0 and gz < rows
	var j := cell * 0.12 if inner else 0.0
	return Vector3(origin.x + float(gx) * cell + (_noise(gx, gz, 1) - 0.5) * 2.0 * j, y, origin.y + float(gz) * cell + (_noise(gx, gz, 2) - 0.5) * 2.0 * j)

func _out(s: MeshKit.Soup, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	if (b - a).cross(c - a).dot(hint) < 0.0:
		s.tri(a, c, b)
	else:
		s.tri(a, b, c)

func _rebuild_meshes() -> void:
	var s := MeshKit.Soup.new()
	for cz in range(rows):
		for cx in range(cols):
			var i := cz * cols + cx
			if int(active[i]) != 1:
				continue
			var h := height(i)
			if h < 0.05:
				continue           # an emptied cell draws NOTHING: the ground beneath it (the topsoil layer, drawn by its own formation) is what shows, not a made-up patch
			var a := _corner(cx, cz, h)
			var b := _corner(cx + 1, cz, h)
			var c := _corner(cx + 1, cz + 1, h)
			var d := _corner(cx, cz + 1, h)
			var mid := (a + b + c + d) * 0.25
			mid.y += (_noise(cx, cz, 3) - 0.5) * 0.06
			for e in [[a, d], [d, c], [c, b], [b, a]]:
				_out(s, e[0], e[1], mid, Vector3.UP)
			var sides := [[Vector2i(-1, 0), d, a], [Vector2i(1, 0), b, c], [Vector2i(0, -1), a, b], [Vector2i(0, 1), c, d]]
			for sd in sides:
				var o: Vector2i = sd[0]
				var nx := cx + o.x
				var nz := cz + o.y
				var nh := 0.0
				if nx >= 0 and nz >= 0 and nx < cols and nz < rows and int(active[nz * cols + nx]) == 1:
					nh = height(nz * cols + nx)
				if nh >= h - 0.001:
					continue
				var p0: Vector3 = sd[1]
				var p1: Vector3 = sd[2]
				var q0 := Vector3(p0.x, nh, p0.z)
				var q1 := Vector3(p1.x, nh, p1.z)
				_out(s, q0, q1, p1, Vector3(o.x, 0, o.y))
				_out(s, q0, p1, p0, Vector3(o.x, 0, o.y))
	surface.mesh = s.mesh()
