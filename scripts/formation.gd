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
var label: Label3D

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
	position = Vector3(float(c[0]), float(c[1]), float(c[2]))
	set_meta("kind", "deposit")
	set_meta("deposit", id)
	set_meta("resource", res)
	set_meta("formation", true)
	# Double-sided copy of the rock material: if a chunk is ever seen from inside or below (neighbours crumbling,
	# the ramp, the lower level) it still renders solid instead of letting the sky show through.
	var mat: Material = MeshKit.mat(QuarryArt.ROCK_MAT.get(res, "RockLimestone")).duplicate()
	(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	# Phase 6.1: style "cut" = quarry-wall blocks (flat faces, chamfered corners, bedded strata) instead of boulders.
	cut = str(f.get("style", "")) == "cut"
	if cut:
		# One continuous rock surface: world-space triplanar mapping, so the strata run unbroken across block seams.
		# The original surface is only slightly darker than freshly cut stone (swapped per column in refresh()).
		mat_old = QuarryFormation.rock_material(Color(0.88, 0.86, 0.82))
		mat_new = QuarryFormation.rock_material(Color(1.0, 1.0, 0.98))
		mat_old2 = mat_old
		mat_new2 = mat_new
		mat = mat_old
	var variants := []
	for k in range(5 if cut else 4):
		var s := MeshKit.Soup.new()
		if cut:
			MeshKit.cut_block_into(s, Vector3.ZERO, Vector3(cell * 1.02, tier_h * 1.01, cell * 1.02), 900 + k * 17 + id.length())
		else:
			MeshKit.rock_into(s, Vector3.ZERO, Vector3(cell * 1.14, tier_h * 1.3, cell * 1.14), 700 + k * 31 + id.length(), 4, 7, true, Vector2(-0.10, 0.18))
		variants.append(s.mesh())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in range(prog.column_count(id)):
		var local := prog.column_pos(id, i) - position
		local.y = 0.0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		cs.shape = box
		cs.set_meta("column", i)
		add_child(cs)
		shapes.append(cs)
		var stack := []
		for t in range(prog.column_tiers(id, i)):
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
		shown.append(stack.size())
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.font_size = 30
	label.pixel_size = 0.008
	label.outline_size = 8
	label.visibility_range_end = 26.0
	add_child(label)
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

## Re-reads the column counts. `instant` skips crumble animations (building, loading).
func refresh(instant := false) -> void:
	var nav_changed := false
	var top_y := 0.0
	for i in range(chunks.size()):
		var want := prog.chunks_left(fid, i)
		var stack: Array = chunks[i]
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
		var lp := prog.column_pos(fid, i) - position
		cs.position = Vector3(lp.x, maxf(0.2, h) * 0.5, lp.z)
		top_y = maxf(top_y, h)
		if cut and want > 0:
			var fresh := prog.column_cut_exposed(fid, i)
			for t in range(stack.size()):
				stack[t].material_override = (mat_new if t % 2 == 0 else mat_new2) if fresh else (mat_old if t % 2 == 0 else mat_old2)
		_update_cracks(i)
	label.position = Vector3(0, top_y + 0.7, 0)
	update_label()
	if nav_changed and not instant and game:
		game.nav_dirty = true

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
		label.modulate = Color(0.98, 0.9, 0.72)

func _update_cracks(i: int) -> void:
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
	if want > 0:
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
