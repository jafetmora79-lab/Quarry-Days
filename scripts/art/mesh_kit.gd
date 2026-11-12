extends RefCounted
class_name MeshKit
## Low-poly mesh helpers for Quarry Days, following THE VEIL's modelling conventions:
## metres, flat-shaded chunky geometry, meter-UVs (1 UV unit = 1 m, so every pixel texture keeps 64 px/m),
## light geometry for integrated GPUs. Each builder returns an ArrayMesh with one surface.

const MAT_DIR := "res://assets/materials/"
static var _mats := {}

## Shared materials: Quarry Days ones by short name ("PaintYellow" -> M_QD_PaintYellow) or any res:// path.
static func mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var path := name if name.begins_with("res://") else MAT_DIR + "M_QD_" + name + ".tres"
	var m: Material = load(path)
	_mats[name] = m
	return m

## Plain untextured colour material for tiny details (lights, glass tints) - still nearest/rough like the rest.
static func flat(color: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := "flat_" + color.to_html() + str(emissive)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m

# ------------------------------------------------------------------ triangle soup builder

class Soup:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv_scale := 1.0

	## Flat-shaded triangle with planar meter-UVs chosen by the face's dominant axis.
	func tri(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			return
		n = n.normalized()
		# Godot front faces are clockwise; our builders emit counter-clockwise, so flip the order.
		for p in [a, c, b]:
			verts.append(p)
			norms.append(n)
			uvs.append(_uv(p, n) * uv_scale)

	func _uv(p: Vector3, n: Vector3) -> Vector2:
		var ax := absf(n.x)
		var ay := absf(n.y)
		var az := absf(n.z)
		if ay >= ax and ay >= az:
			return Vector2(p.x, p.z)
		if ax >= az:
			return Vector2(p.z * signf(n.x), -p.y)
		return Vector2(-p.x * signf(n.z), -p.y)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var m := ArrayMesh.new()
		if verts.size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m

# ------------------------------------------------------------------ primitives

## Box centred at `c`; optional `taper` shrinks the top face (x, z) for chunky PSX silhouettes.
static func box_into(s: Soup, c: Vector3, size: Vector3, taper := Vector2.ONE, xf := Transform3D.IDENTITY) -> void:
	var h := size * 0.5
	var b := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]
	var t := [Vector3(-h.x * taper.x, h.y, -h.z * taper.y), Vector3(h.x * taper.x, h.y, -h.z * taper.y), Vector3(h.x * taper.x, h.y, h.z * taper.y), Vector3(-h.x * taper.x, h.y, h.z * taper.y)]
	for i in 4:
		b[i] = xf * (c + b[i])
		t[i] = xf * (c + t[i])
	s.quad(t[0], t[3], t[2], t[1])          # top
	s.quad(b[0], b[1], b[2], b[3])          # bottom
	for i in 4:
		var j := (i + 1) % 4
		s.quad(b[i], t[i], t[j], b[j])

static func box(size: Vector3, taper := Vector2.ONE) -> ArrayMesh:
	var s := Soup.new()
	box_into(s, Vector3.ZERO, size, taper)
	return s.mesh()

## Extrudes a closed profile drawn in the (z, y) plane along x from -w/2 to +w/2 (side profile of a vehicle,
## a roof section, a bucket). Concave profiles are fine.
static func extrude_into(s: Soup, profile: PackedVector2Array, width: float, xf := Transform3D.IDENTITY, caps := true) -> void:
	_orient_ccw(profile)
	var n := profile.size()
	var hw := width * 0.5
	for i in n:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % n]
		s.quad(xf * Vector3(-hw, a.y, a.x), xf * Vector3(hw, a.y, a.x), xf * Vector3(hw, b.y, b.x), xf * Vector3(-hw, b.y, b.x))
	if caps:
		var idx := Geometry2D.triangulate_polygon(profile)
		for k in range(0, idx.size(), 3):
			var p0: Vector2 = profile[idx[k]]
			var p1: Vector2 = profile[idx[k + 1]]
			var p2: Vector2 = profile[idx[k + 2]]
			s.tri(xf * Vector3(hw, p0.y, p0.x), xf * Vector3(hw, p2.y, p2.x), xf * Vector3(hw, p1.y, p1.x))
			s.tri(xf * Vector3(-hw, p0.y, p0.x), xf * Vector3(-hw, p1.y, p1.x), xf * Vector3(-hw, p2.y, p2.x))

static func extrude(profile: PackedVector2Array, width: float) -> ArrayMesh:
	var s := Soup.new()
	_orient_ccw(profile)
	extrude_into(s, profile, width)
	return s.mesh()

static func _orient_ccw(p: PackedVector2Array) -> void:
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()

## Frustum / cylinder along +Y from y0 to y1 (radii r0 -> r1). `seg` low (6-10) keeps the PSX facets.
static func frustum_into(s: Soup, c: Vector3, r0: float, r1: float, height: float, seg := 8, xf := Transform3D.IDENTITY, caps := true) -> void:
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := c + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := c + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := c + Vector3(cos(a0) * r1, height, sin(a0) * r1)
		var q1 := c + Vector3(cos(a1) * r1, height, sin(a1) * r1)
		s.quad(xf * p0, xf * q0, xf * q1, xf * p1)
		if caps:
			s.tri(xf * (c + Vector3(0, height, 0)), xf * q1, xf * q0)
			s.tri(xf * c, xf * p0, xf * p1)

## Wheel/drum: cylinder lying along X (axle), centred at c.
static func drum_into(s: Soup, c: Vector3, radius: float, width: float, seg := 10) -> void:
	frustum_into(s, Vector3.ZERO, radius, radius, width, seg, Transform3D(Basis(Vector3(0, 0, 1), -PI / 2), c + Vector3(-width * 0.5, 0, 0)))

## Faceted rock: a squashed low-res sphere with seeded jitter, flat shaded. Meter-UVs suit the strata textures.
## The flat base is capped (normal facing down) so the solid is closed: nothing can be seen through its underside.
## `jitter` is the (min, max) radial wobble; formations pass a tighter minimum so neighbouring chunks overlap with no gaps.
static func rock_into(s: Soup, c: Vector3, size: Vector3, seed: int, rings := 4, seg := 7, flat_base := true, jitter := Vector2(-0.22, 0.18)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var grid := []
	for r in range(rings + 1):
		var v := float(r) / rings
		var phi := lerpf(-PI / 2 if not flat_base else -0.15, PI / 2, v)
		var row := []
		for k in seg:
			var th := TAU * k / seg + (0.3 if r % 2 else 0.0)
			var j := 1.0 + rng.randf_range(jitter.x, jitter.y) if r > 0 and r < rings else 1.0
			var p := Vector3(cos(phi) * cos(th), sin(phi), cos(phi) * sin(th)) * j
			if flat_base and r == 0:
				p.y = 0.0
			row.append(c + Vector3(p.x * size.x * 0.5, (p.y if not flat_base else maxf(0.0, p.y)) * size.y, p.z * size.z * 0.5))
		grid.append(row)
	for r in range(rings):
		for k in seg:
			var k2 := (k + 1) % seg
			s.quad(grid[r][k], grid[r + 1][k], grid[r + 1][k2], grid[r][k2])
	if flat_base:
		for k in seg:
			s.tri(c, grid[0][k], grid[0][(k + 1) % seg])
	var top: Vector3 = c + Vector3(rng.randf_range(-0.1, 0.1) * size.x, size.y * (1.0 if flat_base else 0.5), rng.randf_range(-0.1, 0.1) * size.z)
	for k in seg:
		s.tri(grid[rings][k], top, grid[rings][(k + 1) % seg])

## Cut-stone block for quarry faces: a mostly flat-sided slab (origin at the bottom centre) with chamfered vertical
## edges (fractured corners), a slightly tilted, slightly inset top and a little vertex jitter. Closed solid,
## 8 sides + 2 caps = 32 triangles. Stacked and tiled by QuarryFormation with style "cut".
static func cut_block_into(s: Soup, c: Vector3, size: Vector3, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hw := size.x * 0.5
	var hd := size.z * 0.5
	var cut := [rng.randf_range(0.03, 0.09) * size.x, rng.randf_range(0.03, 0.09) * size.x, rng.randf_range(0.03, 0.09) * size.z, rng.randf_range(0.03, 0.09) * size.z]
	var ring := [Vector2(-hw + cut[0], -hd), Vector2(hw - cut[1], -hd), Vector2(hw, -hd + cut[1]), Vector2(hw, hd - cut[2]),
		Vector2(hw - cut[2], hd), Vector2(-hw + cut[3], hd), Vector2(-hw, hd - cut[3]), Vector2(-hw, -hd + cut[0])]
	var tilt_x := rng.randf_range(-0.008, 0.008)  # nearly flat: neighbouring blocks must read as one continuous face
	var tilt_z := rng.randf_range(-0.008, 0.008)
	var bottom := []
	var top := []
	for p in ring:
		var j: Vector2 = Vector2(rng.randf_range(-0.008, 0.008) * size.x, rng.randf_range(-0.008, 0.008) * size.z)
		bottom.append(c + Vector3(p.x + j.x, 0.0, p.y + j.y))
		var ti: Vector2 = Vector2(p.x * 0.995 + j.x * 0.5, p.y * 0.995 + j.y * 0.5)
		var ty: float = size.y * (1.0 + tilt_x * p.x / hw + tilt_z * p.y / hd + rng.randf_range(-0.006, 0.006))
		top.append(c + Vector3(ti.x, ty, ti.y))
	var cb := c
	var ct := c + Vector3(0, size.y * (1.0 + rng.randf_range(-0.02, 0.02)), 0)
	var n := ring.size()
	for i in n:
		var k := (i + 1) % n
		s.quad(bottom[i], top[i], top[k], bottom[k])
		s.tri(ct, top[k], top[i])
		s.tri(cb, bottom[i], bottom[k])

static func rock(size: Vector3, seed: int, rings := 4, seg := 7) -> ArrayMesh:
	var s := Soup.new()
	rock_into(s, Vector3.ZERO, size, seed, rings, seg)
	return s.mesh()

## Stratified quarry wall along X (length) rising to `height`, front face toward -Z. Beds step back as
## they rise (benches), with jittered lips; the back is closed so it reads solid from behind too.
static func cliff_into(s: Soup, length: float, height: float, depth: float, seed: int, beds := 4, xf := Transform3D.IDENTITY) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cols := int(maxf(3.0, length / 1.6))
	var rows := beds * 2
	var pts := []
	for r in range(rows + 1):
		var row := []
		var y := height * float(r) / rows
		var bench := float(r / 2) * depth * 0.18 + (0.12 * depth if r % 2 == 1 else 0.0)
		for k in range(cols + 1):
			var x := -length * 0.5 + length * float(k) / cols
			var z := -depth * 0.5 + bench + rng.randf_range(-0.18, 0.18) * (0.0 if r == 0 else 1.0)
			var yy := y + (rng.randf_range(-0.15, 0.15) if r > 0 and r < rows else 0.0)
			row.append(xf * Vector3(x + (rng.randf_range(-0.2, 0.2) if k > 0 and k < cols else 0.0), yy, z))
		pts.append(row)
	for r in range(rows):
		for k in range(cols):
			s.quad(pts[r][k], pts[r + 1][k], pts[r + 1][k + 1], pts[r][k + 1])
	var back := depth * 0.5
	var bl := xf * Vector3(-length * 0.5, 0, back)
	var br := xf * Vector3(length * 0.5, 0, back)
	var tl := xf * Vector3(-length * 0.5, height, back)
	var tr := xf * Vector3(length * 0.5, height, back)
	s.quad(br, tr, tl, bl)
	for k in range(cols):                      # top cap
		s.quad(pts[rows][k], tl.lerp(tr, float(k) / cols), tl.lerp(tr, float(k + 1) / cols), pts[rows][k + 1])
	for side in [0, cols]:                      # end caps
		var b := bl if side == 0 else br
		var t := tl if side == 0 else tr
		for r in range(rows):
			if side == 0:
				s.quad(pts[r][0], b.lerp(t, float(r) / rows), b.lerp(t, float(r + 1) / rows), pts[r + 1][0])
			else:
				s.quad(pts[r + 1][cols], b.lerp(t, float(r + 1) / rows), b.lerp(t, float(r) / rows), pts[r][cols])

static func cliff(length: float, height: float, depth: float, seed: int, beds := 4) -> ArrayMesh:
	var s := Soup.new()
	cliff_into(s, length, height, depth, seed, beds)
	return s.mesh()

# ------------------------------------------------------------------ node helpers

static func inst(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, shadows := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Instance a THE VEIL GLB prop (cached PackedScene). Returns the instance root.
static var _scenes := {}
static func prop(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var packed: PackedScene = _scenes[path]
	if packed == null:
		return null
	var n: Node3D = packed.instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Reused props are decorative: their own colliders are off so that every blocking volume is an explicit
	# box in the world (which the worker navigation bake sees). See QuarryArt.solid().
	for co in n.find_children("*", "CollisionObject3D", true, false):
		co.collision_layer = 0
		co.collision_mask = 0
	return n
