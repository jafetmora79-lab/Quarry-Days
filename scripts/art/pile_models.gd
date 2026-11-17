extends RefCounted
class_name PileModels
## What a heap looks like depends on what it is made of (the same rule the terrain's angle of repose follows):
##   dirt   loose soil lies in a smooth, rounded CONE (about 35 degrees) with a flared foot, a lopsided outline and a few clods at the base - nothing angular
##   rock   broken rock lies as a ROCKY MOUND: dozens of angular chunks, big ones at the bottom and smaller ones on top, a ragged crest and loose pieces round the foot
##   ore    a rock mound with the mineral showing: coloured chunks sit among the grey stone
## All are single low-poly meshes (one material each) with their base on y = 0, centred on the origin.

## A smooth cone heap of radius `r` and height `h` (radius and height are the heap's full size).
static func dirt_mesh(r: float, h: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := MeshKit.Soup.new()
	var seg := 18
	var radii := [1.14, 1.0, 0.8, 0.6, 0.4, 0.2, 0.06]                 # a flared foot, then the slope, a rounded crown
	var rises := [0.0, 0.07, 0.34, 0.6, 0.82, 0.96, 1.0]
	var wob := []                                                      # a smooth lopsided outline (never a regular circle)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	for k in seg:
		var a := TAU * float(k) / seg
		wob.append(1.0 + 0.07 * sin(a * 2.0 + p1) + 0.04 * sin(a * 3.0 + p2))
	var lean := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12)) * r         # the crown sits a little off-centre
	var grid := []
	for i in radii.size():
		var row := []
		var t := float(i) / (radii.size() - 1)
		for k in seg:
			var a := TAU * float(k) / seg
			var rad: float = float(radii[i]) * r * float(wob[k]) * (1.0 + (rng.randf_range(-0.025, 0.025) if i > 0 and i < radii.size() - 1 else 0.0))
			var off := lean * t * t
			row.append(Vector3(cos(a) * rad + off.x, float(rises[i]) * h + (rng.randf_range(-0.02, 0.02) * h if i > 0 and i < radii.size() - 1 else 0.0), sin(a) * rad + off.y))
		grid.append(row)
	for i in range(radii.size() - 1):
		for k in seg:
			var k2 := (k + 1) % seg
			s.quad(grid[i][k], grid[i + 1][k], grid[i + 1][k2], grid[i][k2])
	var crown := Vector3(lean.x, h * 1.0, lean.y)
	for k in seg:
		s.tri(grid[radii.size() - 1][k], crown, grid[radii.size() - 1][(k + 1) % seg])
	for k in seg:
		s.tri(Vector3(0, 0.0, 0), grid[0][(k + 1) % seg], grid[0][k])
	for c in range(5):                                                   # clods at the foot, half-sunk, soft rounded lumps
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(1.05, 1.3)
		var sz := r * rng.randf_range(0.06, 0.1)
		MeshKit.rock_into(s, Vector3(cos(a) * d, -sz * 0.2, sin(a) * d), Vector3(sz * 1.6, sz, sz * 1.4), seed + 40 + c, 2, 7, false, Vector2(-0.08, 0.08))
	return s.mesh()

## The chunk positions of a rocky mound: [[centre, size], ...] - big chunks low and wide, small ones high, the crest broken, pieces strewn round the foot.
static func rock_chunks(r: float, h: float, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := []
	var unit := r * 0.42
	out.append([Vector3(0, 0, 0), Vector3(r * 1.5, h * 0.55, r * 1.35)])                     # the core that keeps the mound solid
	for i in range(30):
		var a := rng.randf() * TAU
		var d := r * 0.95 * sqrt(rng.randf())
		var surface := h * pow(maxf(0.0, 1.0 - d / (r * 1.05)), 0.75)
		var sz := unit * rng.randf_range(0.45, 1.0) * (1.15 - 0.7 * (d / r) * 0.0 - 0.45 * surface / h)
		out.append([Vector3(cos(a) * d, surface - sz * 0.28, sin(a) * d), Vector3(sz * rng.randf_range(0.9, 1.5), sz * rng.randf_range(0.6, 1.0), sz * rng.randf_range(0.9, 1.4))])
	for i in range(11):                                                                       # loose pieces that have rolled to the foot
		var a2 := rng.randf() * TAU
		var d2 := r * rng.randf_range(0.95, 1.35)
		var sz2 := unit * rng.randf_range(0.18, 0.4)
		out.append([Vector3(cos(a2) * d2, -sz2 * 0.1, sin(a2) * d2), Vector3(sz2 * 1.3, sz2, sz2 * 1.1)])
	return out

## One broken-off chunk: a blocky stone (a cuboid with tapered, tilted faces), never a cone or a ball.
static func chunk_into(s: MeshKit.Soup, c: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.45, 0.45)) * Basis(Vector3.FORWARD, rng.randf_range(-0.45, 0.45))
	MeshKit.box_into(s, Vector3.ZERO, size, Vector2(rng.randf_range(0.62, 1.0), rng.randf_range(0.62, 1.0)), Transform3D(b, c))

static func rock_mesh(r: float, h: float, seed: int) -> ArrayMesh:
	var s := MeshKit.Soup.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 11
	for ch in rock_chunks(r, h, seed):
		chunk_into(s, ch[0], ch[1], rng)
	return s.mesh()

## The mineral showing on a mound: small bright chunks on its surface (the colour is the ore's).
static func ore_mesh(r: float, h: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 7
	var s := MeshKit.Soup.new()
	for i in range(9):
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.05, 0.75)
		var surface := h * pow(maxf(0.0, 1.0 - d / (r * 1.05)), 0.75)
		var sz := r * rng.randf_range(0.1, 0.2)
		chunk_into(s, Vector3(cos(a) * d, surface * 0.95, sin(a) * d), Vector3(sz * 1.2, sz * 0.9, sz), rng)
	return s.mesh()

## A finished heap as one node. kind: "dirt", "rock" or "ore" (`ore` colours the mineral). Returns a Node3D holding one or two MeshInstance3D.
static func heap(kind: String, r: float, h: float, seed: int, material: String, ore := Color.WHITE) -> Node3D:
	var n := Node3D.new()
	n.name = "Heap_" + kind
	if kind == "dirt":
		MeshKit.inst(n, dirt_mesh(r, h, seed), MeshKit.mat(material))
		return n
	MeshKit.inst(n, rock_mesh(r, h, seed), MeshKit.mat(material))
	if kind == "ore":
		MeshKit.inst(n, ore_mesh(r, h, seed), MeshKit.flat(ore, 0.12))
	return n

## Which kind a resource lies as.
static func kind_of(res: String) -> String:
	if res in ["topsoil", "soil", "clay", "dirt"]:
		return "dirt"
	if res in ["iron_ore", "copper_ore", "gold_ore"]:
		return "ore"
	return "rock"
