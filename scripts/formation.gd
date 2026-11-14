extends StaticBody3D
class_name QuarryFormation
## One enormous rock formation built from stacked low-poly chunks on a column grid.
## Physics: one box collider per column, as tall as the chunks still standing (no rigid bodies).
## Visuals: shared rock meshes per formation (4 variants) and one MeshInstance3D per chunk; chunks
## crumble away (scale + sink + dust) when their units are mined, exposing the chunk below.
## All quantities live in QuarryProgression / state.deposits; this node only shows them.

const CRACKS := ["res://assets/textures/T_QD_Crack1.png", "res://assets/textures/T_QD_Crack2.png", "res://assets/textures/T_QD_Crack3.png"]
static var _crack_mats := []

## Shared cut-rock material: world-space triplanar texture (continuous across blocks), tinted per use.
static var _rock_mats := {}
static func rock_material(tint: Color) -> StandardMaterial3D:
	var key := tint.to_html()
	if _rock_mats.has(key):
		return _rock_mats[key]
	var m := (MeshKit.mat("CutLimestone") as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	m.uv1_triplanar_sharpness = 6.0
	m.albedo_color = tint
	_rock_mats[key] = m
	return m

var game
var prog: QuarryProgression
var fid := ""
var res := ""
var cell := 2.0
var tier_h := 1.2
var shapes: Array = []       # CollisionShape3D per column
var chunks: Array = []       # per column: Array of MeshInstance3D (bottom -> top)
var shown: Array = []        # chunks currently standing per column
var jiggle := {}             # MeshInstance3D -> remaining shake time
var crumbling: Array = []    # [MeshInstance3D, t]
var mat_old: StandardMaterial3D
var mat_new: StandardMaterial3D
var mat_old2: StandardMaterial3D
var mat_new2: StandardMaterial3D
var cut := false              # style "cut" (quarry-wall blocks)
var skin := false             # Phase 8.7: one continuous rock surface over all columns instead of a mesh per block
var skin_mi: MeshInstance3D
var _skin_sig := []
var label: Label3D
var decor: Array = []         # [MeshInstance3D, column index]: surface vegetation and loose rock standing on the top layer

func setup(main_node, p: QuarryProgression, id: String) -> void:
	game = main_node
	prog = p
	fid = id
	var f := prog.fdef(id)
	res = str(f["resource"])
	cell = float(f["cell"])
	tier_h = float(f["tier_h"])
	name = id
	var c: Array = f["center"]
	# Phase 8.7: a formation in the pit frame is rotated with it, so its axis-aligned column boxes tile the (rotated) grid exactly
	transform = prog.formation_frame(id) * Transform3D(Basis.IDENTITY, Vector3(float(c[0]), float(c[1]), float(c[2])))
	set_meta("kind", "deposit")
	set_meta("deposit", id)
	set_meta("resource", res)
	set_meta("formation", true)
	# Double-sided copy of the rock material: if a chunk is ever seen from inside or below (neighbours crumbling,
	# the ramp, the lower level) it still renders solid instead of letting the sky show through.
	var mat: Material = MeshKit.mat(QuarryArt.ROCK_MAT.get(res, "RockLimestone")).duplicate()
	(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	# world-space mapping: the boulders of a pile share one continuous set of strata instead of each restarting its texture
	(mat as BaseMaterial3D).uv1_triplanar = true
	(mat as BaseMaterial3D).uv1_world_triplanar = true
	(mat as BaseMaterial3D).uv1_scale = Vector3(0.5, 0.5, 0.5)
	(mat as BaseMaterial3D).uv1_triplanar_sharpness = 6.0
	# Phase 6.1: style "cut" = quarry-wall blocks (flat faces, chamfered corners, bedded strata) instead of boulders.
	cut = str(f.get("style", "")) == "cut"
	skin = bool(f.get("skin", false)) and cut and not prog.is_arc(id)
	if skin:
		mat = MeshKit.mat(QuarryArt.ROCK_MAT.get(res, "RockLimestone")).duplicate()
		(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		(mat as BaseMaterial3D).uv1_triplanar = true
		(mat as BaseMaterial3D).uv1_world_triplanar = true
		(mat as BaseMaterial3D).uv1_scale = Vector3(0.5, 0.5, 0.5)
		(mat as BaseMaterial3D).uv1_triplanar_sharpness = 6.0
		skin_mi = MeshInstance3D.new()
		skin_mi.name = "RockSkin"
		skin_mi.material_override = mat
		add_child(skin_mi)
	elif cut:
		# One continuous rock surface: world-space triplanar mapping, so the strata run unbroken across block seams.
		# The original surface is only slightly darker than freshly cut stone (swapped per column in refresh()).
		mat_old = QuarryFormation.rock_material(Color(0.88, 0.86, 0.82))
		mat_new = QuarryFormation.rock_material(Color(1.0, 1.0, 0.98))
		mat_old2 = mat_old
		mat_new2 = mat_new
		mat = mat_old
	var variants := []
	for k in range(0 if skin else (5 if cut else 4)):
		var s := MeshKit.Soup.new()
		if cut:
			MeshKit.cut_block_into(s, Vector3.ZERO, Vector3(cell * 1.02, tier_h * 1.01, cell * 1.02), 900 + k * 17 + id.length())
		else:
			MeshKit.rock_into(s, Vector3.ZERO, Vector3(cell * 1.14, tier_h * 1.3, cell * 1.14), 700 + k * 31 + id.length(), 4, 7, true, Vector2(-0.10, 0.18))
		variants.append(s.mesh())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in range(prog.column_count(id)):
		var local := _local(i)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		cs.shape = box
		cs.set_meta("column", i)
		add_child(cs)
		shapes.append(cs)
		var stack := []
		for t in range(0 if skin else prog.column_tiers(id, i)):
			var mi := MeshKit.inst(self, variants[rng.randi() % variants.size()], mat)
			if cut:
				# flush courses: blocks sit exactly on the one below with no wobble, so faces stay coplanar
				mi.position = local + Vector3(0, t * tier_h, 0)
				mi.rotation.y = float(rng.randi() % 4) * PI * 0.5
			else:
				mi.position = local + Vector3(rng.randf_range(-0.12, 0.12), t * tier_h - 0.08, rng.randf_range(-0.12, 0.12))
				mi.rotation.y = rng.randf_range(0, TAU)
				var sc := rng.randf_range(0.92, 1.08) * (1.06 if t == 0 else 1.0)
				mi.scale = Vector3(sc, rng.randf_range(0.95, 1.08), sc)
			mi.set_meta("base_pos", mi.position)
			mi.set_meta("base_scale", mi.scale)
			mi.visibility_range_end = 120.0
			stack.append(mi)
		chunks.append(stack)
		shown.append(prog.column_tiers(id, i) if skin else stack.size())
	label = PixelLabel.new()
	label.readout = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.font_size = 30
	label.pixel_size = 0.008
	label.outline_size = 8
	label.visibility_range_end = 26.0
	label.visible = not bool(f.get("no_label", false))
	add_child(label)
	if f.has("decor"):
		_build_decor(f["decor"])
	refresh(true)

static func crack_material(stage: int) -> Material:
	if _crack_mats.is_empty():
		for path in CRACKS:
			var m := StandardMaterial3D.new()
			m.albedo_texture = load(path)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.9, 0.9, 0.9)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.roughness = 1.0
			_crack_mats.append(m)
	return _crack_mats[clampi(stage, 0, 2)]

## Natural surface of the filled quarry: scrub, grass tufts, stones, pebbles and patches of darker and lighter soil standing on the top layer, so the surface is not one
## flat colour. Everything is drawn as five instanced batches (one draw call each, whatever the count), each instance tinted individually. They belong to the soil
## they stand on: cutting that column hides them (refresh() collapses their instance to nothing).
var _decor_groups: Array = []      ## [{"mm": MultiMesh, "base": Array[Transform3D], "col": Array[int], "on": Array[bool]}]

func _build_decor(dd: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(dd.get("seed", 1))
	var density := float(dd.get("density", 0.2))
	var scrub := MeshKit.Soup.new()
	MeshKit.rock_into(scrub, Vector3.ZERO, Vector3(1.5, 0.8, 1.5), 61, 3, 6)
	var tuft := MeshKit.Soup.new()
	for bl in range(7):
		var a := rng.randf() * TAU
		MeshKit.frustum_into(tuft, Vector3(cos(a) * rng.randf_range(0.05, 0.4), 0.0, sin(a) * rng.randf_range(0.05, 0.4)), 0.07, 0.008, rng.randf_range(0.35, 0.8), 4)
	var stone := MeshKit.Soup.new()
	MeshKit.rock_into(stone, Vector3.ZERO, Vector3(1.0, 0.65, 1.0), 77, 3, 6)
	var pebbles := MeshKit.Soup.new()
	for pk in range(5):
		MeshKit.rock_into(pebbles, Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5)), Vector3(0.22, 0.14, 0.2), 90 + pk, 2, 5)
	var patch := MeshKit.Soup.new()          # a low, irregular disc lying on the ground
	var pn := 9
	for k in range(pn):
		var a0 := float(k) / float(pn) * TAU
		var a1 := float(k + 1) / float(pn) * TAU
		var r0 := 1.0 + 0.25 * sin(a0 * 3.0 + 1.0)
		var r1 := 1.0 + 0.25 * sin(a1 * 3.0 + 1.0)
		patch.tri(Vector3.ZERO, Vector3(sin(a0) * r0, 0.0, cos(a0) * r0), Vector3(sin(a1) * r1, 0.0, cos(a1) * r1))
	# kind: [mesh, base colour, tint spread, share of the columns that get one, scale range, lift]
	var kinds := [
		[scrub.mesh(), Color(0.27, 0.37, 0.19), 0.2, 0.10, Vector2(0.8, 1.35), -0.05],
		[tuft.mesh(), Color(0.55, 0.58, 0.3), 0.22, 0.30, Vector2(0.8, 1.5), 0.0],
		[stone.mesh(), Color(0.62, 0.58, 0.5), 0.2, 0.07, Vector2(0.7, 1.4), -0.05],
		[pebbles.mesh(), Color(0.6, 0.55, 0.47), 0.2, 0.22, Vector2(0.9, 1.6), 0.0],
		[patch.mesh(), Color(0.55, 0.38, 0.25), 0.16, 0.30, Vector2(0.9, 2.0), 0.035],
	]
	var cols_list := []
	for i in range(prog.column_count(fid)):
		if prog.column_tiers(fid, i) > 0:
			cols_list.append(i)
	for ki in range(kinds.size()):
		var kd: Array = kinds[ki]
		var xfs: Array = []
		var cols: Array = []
		var tints: Array = []
		for i in cols_list:
			if rng.randf() > density * float(kd[3]) * 5.0:
				continue
			var lp := _local(i)
			var sc: float = rng.randf_range(float(kd[4].x), float(kd[4].y))
			var top := float(prog.column_tiers(fid, i)) * tier_h + float(kd[5])
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.8, 1.2) if ki != 4 else 1.0, sc))
			xfs.append(Transform3D(basis, Vector3(lp.x + rng.randf_range(-cell * 0.4, cell * 0.4), top, lp.z + rng.randf_range(-cell * 0.4, cell * 0.4))))
			cols.append(i)
			var base_c: Color = kd[1]
			var f := rng.randf_range(1.0 - float(kd[2]), 1.0 + float(kd[2]))          # one brightness factor: the hue stays natural (dry grass stays dry grass)
			tints.append(Color(clampf(base_c.r * f, 0.0, 1.0), clampf(base_c.g * f, 0.0, 1.0), clampf(base_c.b * f, 0.0, 1.0)))
		if xfs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = kd[0]
		mm.instance_count = xfs.size()
		for q in range(xfs.size()):
			mm.set_instance_transform(q, xfs[q])
			mm.set_instance_color(q, tints[q])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Decor%d" % ki
		mmi.material_override = _decor_material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 110.0
		add_child(mmi)
		var on: Array = []
		on.resize(xfs.size())
		on.fill(true)
		var clean: Array = []
		clean.resize(xfs.size())
		clean.fill(false)
		_decor_groups.append({"mm": mm, "base": xfs, "col": cols, "on": on, "clean": clean, "overgrowth": ki != 4})
	_apply_cleanup_state()

static var _decor_mat: StandardMaterial3D

static func _decor_material() -> StandardMaterial3D:
	if _decor_mat == null:
		_decor_mat = StandardMaterial3D.new()
		_decor_mat.vertex_color_use_as_albedo = true
		_decor_mat.vertex_color_is_srgb = true
		_decor_mat.albedo_color = Color(1, 1, 1)
		_decor_mat.roughness = 1.0
		_decor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _decor_mat

## The overgrowth (scrub, grass, loose stones and pebbles) is cleaned off the ground: everything within `radius` metres of a world point, or all of it.
## The patches of darker and lighter soil are just dirt and stay. Returns how many pieces were cleared.
func clean_decor(world_pos: Vector3, radius: float, everything := false) -> int:
	var lp := to_local(world_pos)
	var n := 0
	for g in _decor_groups:
		if not bool(g["overgrowth"]):
			continue
		var base: Array = g["base"]
		var clean: Array = g["clean"]
		for q in range(base.size()):
			if bool(clean[q]):
				continue
			var o: Vector3 = (base[q] as Transform3D).origin
			if everything or Vector2(o.x - lp.x, o.z - lp.z).length() <= radius:
				clean[q] = true
				n += 1
	if n > 0:
		_refresh_decor()
	return n

## Re-applies what the site cleanup has already done (a loaded save, or the world being rebuilt): around every cleared weed and heap, or everywhere
## once the whole site is clean.
func _apply_cleanup_state() -> void:
	if prog == null or not prog.cfg.has("cleanup_filled") or not prog.filled_world():
		return
	if bool(prog.cleanup.get("done", false)):
		clean_decor(Vector3.ZERO, 0.0, true)
		return
	for id in prog.cleanup_ids():
		if bool(prog.cleanup["cleared"].get(str(id), false)):
			var p2: Vector2 = prog.cleanup_pos(str(id))
			clean_decor(to_global(Vector3(0, 0, 0)) * 0.0 + Vector3(p2.x, 0.0, p2.y), 7.0)

## Shows or hides each decoration with the soil under it (an instance with zero scale draws nothing).
func _refresh_decor() -> void:
	for g in _decor_groups:
		var mm: MultiMesh = g["mm"]
		var on: Array = g["on"]
		var cols: Array = g["col"]
		var base: Array = g["base"]
		var clean: Array = g["clean"]
		for q in range(cols.size()):
			var want: bool = prog.chunks_left(fid, int(cols[q])) > 0 and not bool(clean[q])
			if want != bool(on[q]):
				on[q] = want
				mm.set_instance_transform(q, base[q] if want else Transform3D(Basis.from_scale(Vector3.ZERO), (base[q] as Transform3D).origin))

## Re-reads the column counts. `instant` skips crumble animations (building, loading).
func refresh(instant := false) -> void:
	var nav_changed := false
	var top_y := 0.0
	var sig := []
	for i in range(chunks.size()):
		var want := prog.chunks_left(fid, i)
		var stack: Array = chunks[i]
		if skin:
			sig.append(want)
			if not instant and want < int(shown[i]) and game and game.fx:
				game.fx.chunk_break(column_top(i) + Vector3(0, tier_h * 0.5, 0), res)
		for t in range(stack.size()):
			var mi: MeshInstance3D = stack[t]
			if t < want:
				if not mi.visible or mi.has_meta("crumbling"):
					mi.visible = true
					mi.remove_meta("crumbling")
					mi.position = mi.get_meta("base_pos")
					mi.scale = mi.get_meta("base_scale")
			elif mi.visible and not mi.has_meta("crumbling"):
				if instant:
					mi.visible = false
				else:
					_crumble(mi)
		if (shown[i] > 0) != (want > 0):
			nav_changed = true
		shown[i] = want
		var cs: CollisionShape3D = shapes[i]
		var h := float(want) * tier_h
		cs.disabled = want <= 0
		(cs.shape as BoxShape3D).size = Vector3(cell, maxf(0.2, h), cell)
		var lp := _local(i)
		cs.position = Vector3(lp.x, maxf(0.2, h) * 0.5, lp.z)
		top_y = maxf(top_y, h)
		if cut and want > 0:
			var fresh := prog.column_cut_exposed(fid, i)
			for t in range(stack.size()):
				stack[t].material_override = (mat_new if t % 2 == 0 else mat_new2) if fresh else (mat_old if t % 2 == 0 else mat_old2)
		_update_cracks(i)
	if skin and sig != _skin_sig:
		_skin_sig = sig
		_rebuild_skin(sig)
		_refresh_decor()                 # only when the surface really changed
		if fid == "q_top" and game and game.has_method("soil_follow_topsoil"):
			game.soil_follow_topsoil()   # loose soil never floats over a column that was just dug
	elif not skin:
		_refresh_decor()
	label.position = Vector3(0, top_y + 0.7, 0)
	update_label()
	if nav_changed and not instant and game:
		game.nav_dirty = true

## Deterministic per-corner noise in [0, 1): shared by every column that touches the corner, so the surface has no cracks.
func _corner_noise(gx: int, gy: int, salt: int) -> float:
	return float(abs(hash(Vector3i(gx, gy, salt + fid.length() * 31))) % 1000) / 1000.0

## Phase 8.7: the standing rock as ONE continuous surface. Every column that still has rock gets a slightly uneven top at its
## height; wherever a neighbour is lower (mined out, or the edge of the grid) the cliff face drops from the top down to the
## neighbour's height. All corners are shared, so the surface is watertight, and mining simply changes the heights.
func _rebuild_skin(heights: Array) -> void:
	var d := prog.dims(fid)
	var s := MeshKit.Soup.new()
	var half := cell * 0.5
	var jit := cell * 0.16
	var origin := Vector3.ZERO
	var c0 := _local(0)
	origin = Vector3(c0.x, 0, c0.z)
	# corner (gx, gy) is the lower-left corner of column (gx, gy) in grid space (gx in 0..d.x, gy in 0..d.y)
	var corner := func(gx: int, gy: int, h: float) -> Vector3:
		var base := origin + Vector3((float(gx) - 0.5) * cell, 0, (float(gy) - 0.5) * cell)
		var jx := (_corner_noise(gx, gy, 1) - 0.5) * 2.0 * jit
		var jz := (_corner_noise(gx, gy, 2) - 0.5) * 2.0 * jit
		# the outer boundary of the grid stays exactly on the grid line: a wobbling edge pulled the soil back from the ground around it and left a
		# strip of void (the background colour showing) all round the quarry
		if gx == 0 or gx == d.x:
			jx = 0.0
		if gy == 0 or gy == d.y:
			jz = 0.0
		var jy := -_corner_noise(gx, gy, 3) * (0.02 if str(prog.fdef(fid).get("frame", "")) == "pit" else 0.10)       # the walking surface and what you see agree to 2 cm (the collider top is flat)
		if h <= 0.0:
			return Vector3(base.x + jx, 0.0, base.z + jz)
		return Vector3(base.x + jx, h + jy, base.z + jz)
	for gy in range(d.y):
		for gx in range(d.x):
			var h := float(int(heights[gy * d.x + gx])) * tier_h
			if h <= 0.0:
				continue
			var a: Vector3 = corner.call(gx, gy, h)
			var b: Vector3 = corner.call(gx + 1, gy, h)
			var c: Vector3 = corner.call(gx + 1, gy + 1, h)
			var e: Vector3 = corner.call(gx, gy + 1, h)
			var mid := (a + b + c + e) * 0.25
			mid.y += (_corner_noise(gx, gy, 4) - 0.6) * 0.14
			_tri_out(s, a, e, mid, Vector3.UP)
			_tri_out(s, e, c, mid, Vector3.UP)
			_tri_out(s, c, b, mid, Vector3.UP)
			_tri_out(s, b, a, mid, Vector3.UP)
			# cliff faces: toward -x, +x, -z, +z
			var dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
			for o in dirs:
				var nx: int = gx + o.x
				var ny: int = gy + o.y
				var nh := 0.0
				if nx >= 0 and ny >= 0 and nx < d.x and ny < d.y:
					nh = float(int(heights[ny * d.x + nx])) * tier_h
				if nh >= h - 0.001:
					continue
				var k0: Vector2i
				var k1: Vector2i
				var out_dir := Vector3(o.x, 0, o.y)
				if o == Vector2i(-1, 0):
					k0 = Vector2i(gx, gy + 1); k1 = Vector2i(gx, gy)
				elif o == Vector2i(1, 0):
					k0 = Vector2i(gx + 1, gy); k1 = Vector2i(gx + 1, gy + 1)
				elif o == Vector2i(0, -1):
					k0 = Vector2i(gx, gy); k1 = Vector2i(gx + 1, gy)
				else:
					k0 = Vector2i(gx + 1, gy + 1); k1 = Vector2i(gx, gy + 1)
				var p0: Vector3 = corner.call(k0.x, k0.y, h)
				var p1: Vector3 = corner.call(k1.x, k1.y, h)
				# bottom edge of the face: the neighbour's top (same corners), or the floor where nothing stands
				var q0: Vector3 = corner.call(k0.x, k0.y, nh)
				var q1: Vector3 = corner.call(k1.x, k1.y, nh)
				_quad_out(s, q0, q1, p1, p0, out_dir)
	skin_mi.mesh = s.mesh()

func _tri_out(s: MeshKit.Soup, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	if (b - a).cross(c - a).dot(hint) < 0.0:
		s.tri(a, c, b)
	else:
		s.tri(a, b, c)

func _quad_out(s: MeshKit.Soup, a: Vector3, b: Vector3, c: Vector3, e: Vector3, hint: Vector3) -> void:
	_tri_out(s, a, b, c, hint)
	_tri_out(s, a, c, e, hint)

## A column's centre in this node's own frame, at floor level.
func _local(i: int) -> Vector3:
	var l := transform.affine_inverse() * prog.column_pos(fid, i)
	l.y = 0.0
	return l

func update_label() -> void:
	var left := prog.units_left(fid)
	var total := prog.max_units(fid)
	if prog.formation_locked(fid) != "":
		label.text = "%s\nCLEAR THE SITE FIRST" % str(prog.fdef(fid)["title"]).to_upper()
		label.modulate = Color(1.0, 0.7, 0.5)
		return
	if left <= 0:
		label.text = "%s\nCLEARED" % str(prog.fdef(fid)["title"]).to_upper()
		label.modulate = Color(0.75, 0.95, 0.7)
	else:
		label.text = "%s\n%d / %d %s" % [str(prog.fdef(fid)["title"]).to_upper(), left, total, prog.display(res).to_upper()]
		if prog.benched(fid):
			label.text += "\nBENCH %d OF %d  -  %d%% CUT" % [prog.bench_number(fid), prog.bench_levels(fid), int(prog.bench_progress(fid) * 100.0)]
		label.modulate = Color(0.98, 0.9, 0.72)

func _update_cracks(i: int) -> void:
	if skin:
		return
	var want := prog.chunks_left(fid, i)
	var stack: Array = chunks[i]
	for t in range(stack.size()):
		stack[t].material_overlay = null
	if want <= 0:
		return
	var dmg := prog.top_chunk_damage(fid, i)
	if dmg > 0.12:
		stack[want - 1].material_overlay = crack_material(0 if dmg < 0.45 else (1 if dmg < 0.75 else 2))

func _crumble(mi: MeshInstance3D) -> void:
	mi.set_meta("crumbling", true)
	crumbling.append([mi, 0.0])
	if game and game.fx:
		game.fx.chunk_break(global_transform * mi.position + Vector3(0, tier_h * 0.5, 0), res)

## Visual hit on a column's top chunk (shake). Damage itself is applied by the caller.
func hit(i: int) -> void:
	if i < 0 or i >= chunks.size():
		return
	var want := prog.chunks_left(fid, i)
	if want > 0 and not skin:
		jiggle[chunks[i][want - 1]] = 0.16
	_update_cracks(i)

## World-space point on the exposed side of a column's top chunk (effects, pieces, rig drill head).
func column_top(i: int) -> Vector3:
	var p := prog.column_pos(fid, i)
	p.y = position.y + maxf(0.4, float(prog.chunks_left(fid, i)) * tier_h - tier_h * 0.5)
	return p

func column_from_shape(shape_idx: int) -> int:
	var owner_id := shape_find_owner(shape_idx)
	var node = shape_owner_get_owner(owner_id)
	return int(node.get_meta("column", -1)) if node else -1

func _process(delta: float) -> void:
	if not jiggle.is_empty():
		for mi in jiggle.keys():
			var t: float = jiggle[mi] - delta
			if t <= 0.0 or not is_instance_valid(mi):
				jiggle.erase(mi)
				if is_instance_valid(mi) and not mi.has_meta("crumbling"):
					mi.position = mi.get_meta("base_pos")
				continue
			jiggle[mi] = t
			var a := t / 0.16
			mi.position = mi.get_meta("base_pos") + Vector3(sin(t * 140.0), 0, cos(t * 120.0)) * 0.035 * a
	for k in range(crumbling.size() - 1, -1, -1):
		var entry: Array = crumbling[k]
		var mi: MeshInstance3D = entry[0]
		entry[1] = float(entry[1]) + delta
		var a := clampf(float(entry[1]) / 0.45, 0.0, 1.0)
		if not mi.has_meta("crumbling"):
			crumbling.remove_at(k)
			continue
		var e := a * a
		mi.scale = (mi.get_meta("base_scale") as Vector3) * lerpf(1.0, 0.15, e)
		mi.position = (mi.get_meta("base_pos") as Vector3) + Vector3(0, -tier_h * 0.6 * e, 0)
		if a >= 1.0:
			mi.visible = false
			mi.remove_meta("crumbling")
			mi.position = mi.get_meta("base_pos")
			mi.scale = mi.get_meta("base_scale")
			crumbling.remove_at(k)
