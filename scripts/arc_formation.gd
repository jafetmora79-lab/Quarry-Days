extends "res://scripts/formation.gd"
class_name QuarryArcFormation
## Phase 6.3b: a curved bench (arc layout) drawn with MultiMeshes instead of one node per chunk.
##
## Same data and rules as QuarryFormation (columns, tiers, exposure, units, saves) but laid out as angular slices of
## concentric rings, with these differences:
##  * Chunks are instances of at most five shared meshes (one MultiMeshInstance3D each), so a band of a thousand chunks
##    costs a handful of draw calls. Hidden chunks are zero-scale instances; hit, crumble and shake only rewrite the
##    transform of the chunks involved.
##  * Tints (weathered surface vs. freshly cut stone, alternating courses) are per-instance colours.
##  * Crack decals come from a small pool of overlay meshes shared by the most recently damaged columns.
##  * Physics: one tangentially rotated box per column (as before).
##  * Navigation: the pit zone bakes from the boxes of exposed columns only (see QuarryPitZone).
## `chunks` holds, per column, the instance references [variant, index] bottom to top.

var variants: Array = []          # shared ArrayMesh per variant
var mms: Array = []               # MultiMesh per variant
var base_xf: Dictionary = {}      # "v:i" -> Transform3D (standing pose)
var inst_state: Dictionary = {}   # "v:i" -> 0 hidden, 1 standing, 2 crumbling
var fresh_col: Array = []         # per column: tinted as freshly cut
var crack_pool: Array = []        # MeshInstance3D overlays
var crack_col: Array = []         # column each overlay currently marks (-1 free)
var _crack_next := 0
const ZERO_XF := Transform3D(Basis(Vector3.RIGHT * 0.0001, Vector3.UP * 0.0001, Vector3.BACK * 0.0001), Vector3(0, -50, 0))
const TONE_OLD := [Color(0.88, 0.86, 0.82), Color(0.88, 0.86, 0.82)]   # same tone every course: no stripes between blocks
const TONE_NEW := [Color(1.0, 1.0, 0.98), Color(1.0, 1.0, 0.98)]

func _key(ref: Vector2i) -> String:
	return "%d:%d" % [ref.x, ref.y]

func setup(main_node, p: QuarryProgression, id: String) -> void:
	game = main_node
	prog = p
	fid = id
	var f := prog.fdef(id)
	res = str(f["resource"])
	cell = float(f["cell"])
	tier_h = float(f["tier_h"])
	cut = true
	name = id
	position = prog.formation_origin_world(id)
	set_meta("kind", "deposit")
	set_meta("deposit", id)
	set_meta("resource", res)
	set_meta("formation", true)
	var base_mat := QuarryFormation.rock_material(Color.WHITE).duplicate() as StandardMaterial3D   # world-space triplanar rock
	base_mat.vertex_color_use_as_albedo = true
	for k in range(5):
		var s := MeshKit.Soup.new()
		MeshKit.cut_block_into(s, Vector3.ZERO, Vector3(cell * 1.02, tier_h * 1.01, cell * 1.02), 900 + k * 17 + id.length())
		variants.append(s.mesh())
	# assign every chunk to a variant, then size the MultiMeshes
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var counts := [0, 0, 0, 0, 0]
	var refs: Array = []
	var n_cols := prog.column_count(id)
	for i in range(n_cols):
		var stack := []
		for t in range(prog.column_tiers(id, i)):
			var v := rng.randi() % variants.size()
			stack.append(Vector2i(v, counts[v]))
			counts[v] += 1
		refs.append(stack)
	for v in range(variants.size()):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = variants[v]
		mm.instance_count = counts[v]
		for k in range(counts[v]):
			mm.set_instance_transform(k, ZERO_XF)
			mm.set_instance_color(k, TONE_OLD[0])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Chunks%d" % v
		mmi.multimesh = mm
		mmi.material_override = base_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 160.0
		add_child(mmi)
		mms.append(mm)
	chunks = refs
	for i in range(n_cols):
		var lp := prog.column_pos(id, i) - position
		lp.y = 0.0
		var yaw := prog.column_yaw(id, i)
		var sz := prog.column_size(id, i)
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		cs.set_meta("column", i)
		cs.set_meta("yaw", yaw)
		cs.rotation.y = yaw
		add_child(cs)
		shapes.append(cs)
		var stack2: Array = chunks[i]
		for t in range(stack2.size()):
			var flip := PI if rng.randf() < 0.5 else 0.0
			var basis := Basis(Vector3.UP, yaw + flip) * Basis.from_scale(Vector3(1.0, 1.0, sz.y / cell))
			base_xf[_key(stack2[t])] = Transform3D(basis, lp + Vector3(0, float(t) * tier_h, 0))
			inst_state[_key(stack2[t])] = 0
		shown.append(stack2.size())
		fresh_col.append(false)
	for k in range(3):
		var mi := MeshInstance3D.new()
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		crack_pool.append(mi)
		crack_col.append(-1)
	label = PixelLabel.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.font_size = 30
	label.pixel_size = 0.008
	label.outline_size = 8
	label.visibility_range_end = 40.0
	add_child(label)
	refresh(true)

func _put(ref: Vector2i, xf: Transform3D) -> void:
	mms[ref.x].set_instance_transform(ref.y, xf)

func _color(ref: Vector2i, c: Color) -> void:
	mms[ref.x].set_instance_color(ref.y, c)

func chunk_standing(col: int, t: int) -> bool:
	return int(inst_state.get(_key(chunks[col][t]), 0)) == 1

func standing_count(col: int) -> int:
	var n := 0
	for t in range(chunks[col].size()):
		if chunk_standing(col, t):
			n += 1
	return n

func refresh(instant := false) -> void:
	var nav_changed := false
	var top_y := 0.0
	for i in range(chunks.size()):
		var want := prog.chunks_left(fid, i)
		var stack: Array = chunks[i]
		var fresh := prog.column_cut_exposed(fid, i)
		var tint_changed: bool = fresh != bool(fresh_col[i])
		fresh_col[i] = fresh
		for t in range(stack.size()):
			var ref: Vector2i = stack[t]
			var key := _key(ref)
			var st := int(inst_state[key])
			if t < want:
				if st != 1:
					_put(ref, base_xf[key])
					inst_state[key] = 1
					tint_changed = true
			elif st == 1:
				if instant:
					_put(ref, ZERO_XF)
					inst_state[key] = 0
				else:
					_crumble_ref(ref)
			if tint_changed and t < want:
				_color(ref, (TONE_NEW if fresh else TONE_OLD)[t % 2])
		if (shown[i] > 0) != (want > 0):
			nav_changed = true
		shown[i] = want
		var cs: CollisionShape3D = shapes[i]
		var h := float(want) * tier_h
		var sz := prog.column_size(fid, i)
		cs.disabled = want <= 0
		(cs.shape as BoxShape3D).size = Vector3(sz.x, maxf(0.2, h), sz.y)
		var lp := prog.column_pos(fid, i) - position
		cs.position = Vector3(lp.x, maxf(0.2, h) * 0.5, lp.z)
		top_y = maxf(top_y, h)
		_update_cracks(i)
	var mid := prog.column_pos(fid, prog.column_count(fid) / 2) - position
	label.position = Vector3(mid.x, top_y + 1.2, mid.z)
	update_label()
	if nav_changed and not instant and game:
		if game.pit_zone and str(prog.fdef(fid).get("frame", "")) == "pit":
			game.pit_zone.request_bake()
		else:
			game.nav_dirty = true

func _update_cracks(i: int) -> void:
	var slot := crack_col.find(i)
	var want := prog.chunks_left(fid, i)
	var dmg := prog.top_chunk_damage(fid, i) if want > 0 else 0.0
	if want <= 0 or dmg <= 0.12:
		if slot >= 0:
			crack_pool[slot].visible = false
			crack_col[slot] = -1
		return
	if slot < 0:
		slot = _crack_next
		_crack_next = (_crack_next + 1) % crack_pool.size()
		if crack_col[slot] >= 0 and crack_col[slot] != i:
			crack_pool[slot].visible = false
	var ref: Vector2i = chunks[i][want - 1]
	var mi: MeshInstance3D = crack_pool[slot]
	mi.mesh = variants[ref.x]
	mi.transform = Transform3D((base_xf[_key(ref)] as Transform3D).basis.scaled(Vector3.ONE * 1.01), (base_xf[_key(ref)] as Transform3D).origin)
	mi.material_override = crack_material(0 if dmg < 0.45 else (1 if dmg < 0.75 else 2))
	mi.visible = true
	crack_col[slot] = i

func _crumble_ref(ref: Vector2i) -> void:
	inst_state[_key(ref)] = 2
	crumbling.append([ref, 0.0])
	if game and game.fx:
		var xf: Transform3D = base_xf[_key(ref)]
		game.fx.chunk_break(global_transform * xf.origin + Vector3(0, tier_h * 0.5, 0), res)

func hit(i: int) -> void:
	if i < 0 or i >= chunks.size():
		return
	var want := prog.chunks_left(fid, i)
	if want > 0:
		jiggle[chunks[i][want - 1]] = 0.16
	_update_cracks(i)

func _process(delta: float) -> void:
	for ref in jiggle.keys():
		var key := _key(ref)
		var t: float = jiggle[ref] - delta
		if t <= 0.0 or int(inst_state[key]) != 1:
			jiggle.erase(ref)
			if int(inst_state[key]) == 1:
				_put(ref, base_xf[key])
			continue
		jiggle[ref] = t
		var xf: Transform3D = base_xf[key]
		var a := t / 0.16
		xf.origin += Vector3(sin(t * 140.0), 0, cos(t * 120.0)) * 0.035 * a
		_put(ref, xf)
	for k in range(crumbling.size() - 1, -1, -1):
		var entry: Array = crumbling[k]
		var ref: Vector2i = entry[0]
		var key := _key(ref)
		entry[1] = float(entry[1]) + delta
		if int(inst_state[key]) != 2:
			crumbling.remove_at(k) # re-raised before it finished
			continue
		var a := clampf(float(entry[1]) / 0.45, 0.0, 1.0)
		var e := a * a
		var xf: Transform3D = base_xf[key]
		xf.basis = xf.basis.scaled(Vector3.ONE * lerpf(1.0, 0.15, e))
		xf.origin += Vector3(0, -tier_h * 0.6 * e, 0)
		_put(ref, xf)
		if a >= 1.0:
			_put(ref, ZERO_XF)
			inst_state[key] = 0
			crumbling.remove_at(k)
