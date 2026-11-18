extends Node3D
class_name CashHopperView
## The look and the feedback of a Cash Hopper. It owns NO gameplay: every number it shows is read from Business (outputs[index]), and it only reacts to
## Business.cash_sold. The visuals are a temporary placeholder built from primitives; a Blender model can replace them without touching any gameplay code:
##
##   * Drop  res://assets/world/WLD_QD_cash_hopper.glb  next to the other world models. If it exists it is shown INSTEAD of the placeholder, and any node in it
##     whose name matches an attachment below (e.g. "Attach_RockSpawn") moves the matching marker to that node's place.
##   * Scale / orientation contract: 1 unit = 1 m, +Y up, the machine's FRONT (the display) faces -Z, its origin is the point on the ground under its centre, and the
##     footprint is about 1.9 m x 1.9 m (the collision box the game builds). Belts reach it from any side within 1.7 m of the origin.
##
## Attachment points (Node3D children of this node; all names are part of the contract):
##   Attach_Body          the hopper body / frame
##   Attach_InputFunnel   the wide funnel mouth the rocks fall into
##   Attach_Processor     the processing section (crusher / mill box)
##   Attach_ConveyorIn    where a belt meets the machine (informational: the game links belts by distance)
##   Attach_RockSpawn     where a falling rock starts its animation (above the funnel)
##   Attach_Audio         the AudioStreamPlayer3D for clunk and coin
##   Attach_FloatText     where the floating "+$5" starts
##   Attach_Display       the little status screen (a Label3D)
##   Pivot_Flywheel       spins about its local X while the machine works
##   Pivot_Flap           hinge about its local X that kicks on every sale (impact)

const MODEL_PATH := "res://assets/world/WLD_QD_cash_hopper.glb"
const MARKERS := {
	"Attach_Body": Vector3(0, 0.0, 0), "Attach_InputFunnel": Vector3(0, 1.45, 0), "Attach_Processor": Vector3(0, 0.55, 0.0),
	"Attach_ConveyorIn": Vector3(0, 0.55, 1.1), "Attach_RockSpawn": Vector3(0, 2.35, 0), "Attach_Audio": Vector3(0, 1.2, 0),
	"Attach_FloatText": Vector3(0, 2.6, 0), "Attach_Display": Vector3(0.6, 1.02, -0.9), "Attach_SaleDisplay": Vector3(0, 1.655, -0.81), "Attach_Sign": Vector3(0, 0.86, -0.9),
	"Pivot_Flywheel": Vector3(0.97, 0.85, 0.0), "Pivot_Flap": Vector3(0, 1.2, 0.0)}

var game
var index := -1
var points := {}                         ## attachment name -> Node3D
var placeholder: Node3D
var model: Node3D
var display: Label3D
var fill: MeshInstance3D
var audio: AudioStreamPlayer3D
var clunk_streams: Array = []
var coin_stream: AudioStream
var _pending := {}                       ## material -> [units, money] waiting for the next feedback burst (grouped at high speed)
var _burst_t := 0.0
var _disp_t := 0.0
var _flap_kick := 0.0
var _live_floats := 0
var _rock_mats := {}
var _rng := RandomNumberGenerator.new()
var _last_current := ""
var piston: Node3D                       ## the ram on the front corner: pumps while it works (the Blender model)
var funnel_node: Node3D                  ## the funnel: it shivers while rock goes through
var drawer: Node3D                       ## the payout drawer: it slides out on every payout
var gear_a: Node3D
var gear_b: Node3D
var lamp2: MeshInstance3D
var sale_display: Label3D                ## the slanted LED window on top: shows +$ of the sale in progress
var glow: OmniLight3D                    ## amber light round the lamps, brighter while it works
var anim: AnimationPlayer                ## the Blender clips: Idle, SaleRegistered, Processing, Counting, DrawerOpen, DrawerClose, ReturnToIdle
var phase := "idle"                      ## the six phases of a payout: idle, registered, processing, counting, payout, complete
var _seq_running := false
var _queued_money := 0                   ## sales that arrive while a payout is playing are added up and paid out in the same open drawer
var _queued_units := 0
var _queued_res := ""
var _chain_until_ms := 0                 ## a sale within a few seconds of the last payout plays the short version
var _vibe := 0.0
var _lamp_level := 0.5
var _lamp_mat: StandardMaterial3D
var _note: Node3D                        ## the compact payout notification (one at a time: it is updated, never stacked)
var _note_label: Label3D
var _note_mats: Array = []
var _note_total := 0
var _note_tween: Tween
var _note_base := Vector3.ZERO
var sparks: CPUParticles3D
var _tier_shown := -1                   ## which upgrade tier the model is dressed for
var _cash_nodes: Array = []
var _funnel_y0 := 0.0                    ## the heights the funnel and the ram stand at (their shiver and pumping are offsets from these, not absolute heights)
var _piston_y0 := 0.0
var lamp: MeshInstance3D                 ## the status lamp: green while selling, amber when idle
var _t := 0.0
var _work := 0.0                         ## 0..1 how hard the machine is working (eased: it winds up and down)
var _fw_speed := 0.0
var _display_live := false
var _lamp_on := -1
var _thump := 0.0                        ## the housing's jolt on each crush, easing out
var _last_items := {}                    ## what the hopper held at the last look: a rise means material has just gone in
var _intake_cd := 0.0
var _items_seen := false
var _fill_target := Vector3.ONE

func setup(g, i: int) -> void:
	game = g
	index = i
	name = "CashHopperView"
	_rng.seed = 1000 + i
	for k in MARKERS:
		var m := Node3D.new()
		m.name = k
		m.position = MARKERS[k]
		add_child(m)
		points[k] = m
	audio = AudioStreamPlayer3D.new()
	audio.name = "Audio"
	audio.unit_size = 9.0
	audio.max_distance = 60.0
	audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	points["Attach_Audio"].add_child(audio)
	clunk_streams = [load("res://audio/breaker_hit.wav"), load("res://audio/hit_hammer.wav"), load("res://audio/rock_break.wav")]
	coin_stream = load("res://audio/coin.wav")
	if WorldModels.has("cash_hopper"):
		var hm: Dictionary = WorldModels.animal("cash_hopper")            # the Blender hopper (tools/world_models/build_world.py), the game's own materials swapped in
		if not hm.is_empty():
			model = hm["root"]
			points["Attach_Body"].add_child(model)
			for k in MARKERS:
				var n := model.find_child(k, true, false) as Node3D
				if n != null:
					points[k].transform = _rel(n)
					if k.begins_with("Pivot_"):
						points[k] = n
			piston = model.find_child("Pivot_Piston", true, false) as Node3D
			funnel_node = model.find_child("Pivot_Funnel", true, false) as Node3D
			lamp = model.find_child("Lamp_Status", true, false).get_node_or_null("Mesh") as MeshInstance3D
			var l2 := model.find_child("Lamp_Status2", true, false)
			lamp2 = l2.get_node_or_null("Mesh") as MeshInstance3D if l2 != null else null
			drawer = model.find_child("Pivot_Drawer", true, false) as Node3D
			gear_a = model.find_child("Pivot_GearA", true, false) as Node3D
			gear_b = model.find_child("Pivot_GearB", true, false) as Node3D
			fill = model.find_child("Fill", true, false).get_node_or_null("Mesh") as MeshInstance3D
			if fill != null:
				fill.visible = false
	elif ResourceLoader.exists(MODEL_PATH):
		var ps = load(MODEL_PATH)
		if ps is PackedScene:
			model = ps.instantiate() as Node3D
			points["Attach_Body"].add_child(model)
			for k in MARKERS:
				var n := model.find_child(k, true, false) as Node3D
				if n != null:
					points[k].transform = _rel(n)      # the model decides where its own parts are
					if k.begins_with("Pivot_"):
						points[k] = n                                   # the pivots hold the model's own meshes: those are the nodes that turn
			piston = model.find_child("Pivot_Piston", true, false) as Node3D
			funnel_node = model.find_child("Pivot_Funnel", true, false) as Node3D
			lamp = model.find_child("Lamp_Status", true, false) as MeshInstance3D
			fill = model.find_child("Fill", true, false) as MeshInstance3D
			if fill != null:
				fill.visible = false
	if model != null:
		anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if funnel_node != null:
		_funnel_y0 = funnel_node.position.y
	if piston != null:
		_piston_y0 = piston.position.y
	if model == null:
		_build_placeholder()
	display = Label3D.new()
	display.name = "Display"
	display.pixel_size = 0.00085 if drawer != null else 0.0027
	display.font_size = 36
	display.outline_size = 6
	display.modulate = Color(0.75, 1.0, 0.7)
	display.outline_modulate = Color(0.04, 0.08, 0.04)
	display.double_sided = false
	display.no_depth_test = false
	display.rotation = Vector3(0, PI, 0)                                  # reads from the front (-Z)
	points["Attach_Display"].add_child(display)
	_refresh_display()
	if drawer != null:
		_build_extras()
		_play("Idle")
		for k in range(4):
			var cn := model.find_child("Cash_%d" % (k + 1), true, false)
			if cn != null:
				_cash_nodes.append(cn)
		_apply_tier(game.business.cash_tier_index(index), false)

## A marker's place in the model's own space (the view is not in the tree yet while it is being built, so global transforms are not available).
func _rel(n: Node3D) -> Transform3D:
	var t := Transform3D()
	var cur: Node = n
	while cur != null and cur != model and cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

## The letters and lights the model has frames for: the sale display on top, the CASH HOPPER name, the lamps' glow, the payout sparks.
func _build_extras() -> void:
	sale_display = Label3D.new()
	sale_display.name = "SaleDisplay"
	sale_display.font = QuarryTheme.hud()
	sale_display.font_size = 36
	sale_display.pixel_size = 0.0034
	sale_display.outline_size = 0
	sale_display.shaded = false
	sale_display.outline_modulate = Color(0.0, 0.1, 0.03)
	sale_display.rotation = Vector3(-0.336, PI, 0)
	sale_display.position = Vector3(0, 0.012, -0.035)                          # (a hair in front of the glass)
	points["Attach_SaleDisplay"].add_child(sale_display)
	_sale_text("READY", 0.5)
	var sign_l := Label3D.new()
	sign_l.name = "Plaque"
	sign_l.font = QuarryTheme.hud()
	sign_l.text = "CASH HOPPER"
	sign_l.font_size = 22
	sign_l.pixel_size = 0.0034
	sign_l.outline_size = 0
	sign_l.shaded = false
	sign_l.modulate = Color(1.0, 0.82, 0.3)
	sign_l.rotation = Vector3(0, PI, 0)
	points["Attach_Sign"].add_child(sign_l)
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.62, 0.2)
	glow.omni_range = 3.0
	glow.shadow_enabled = false
	glow.position = Vector3(0, 1.8, -0.9)
	add_child(glow)
	_lamp_mat = StandardMaterial3D.new()                                  # both lamps share one material: one value to change
	_lamp_mat.albedo_color = Color(1.0, 0.62, 0.16)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.58, 0.12)
	if lamp != null:
		lamp.material_override = _lamp_mat
	if lamp2 != null:
		lamp2.material_override = _lamp_mat
	_set_lamp(0.5)
	sparks = CPUParticles3D.new()                                         # a few tiny golden sparks at the drawer
	sparks.name = "Sparks"
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 10
	sparks.lifetime = 0.5
	sparks.explosiveness = 0.9
	sparks.direction = Vector3(0, 1, -0.6)
	sparks.spread = 55.0
	sparks.initial_velocity_min = 0.5
	sparks.initial_velocity_max = 1.1
	sparks.gravity = Vector3(0, -2.5, 0)
	sparks.position = Vector3(0, 0.6, -1.15)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.03)
	sparks.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(1.0, 0.82, 0.3, 1.0)
	sparks.material_override = sm
	sparks.color = Color(1.0, 0.85, 0.35)
	add_child(sparks)

## The three upgrade tiers look different, so an upgrade is something you can see: the small old hopper (worn grey cabinet, one lamp, two cash bundles, a little smaller), the Motorized Hopper
## (the green and yellow machine, both lamps, three bundles) and the Industrial Hopper (rust-red, full size, four bundles, brighter lamps).
const TIER_LOOK := [
	{"scale": 0.8, "steel": Color(0.42, 0.43, 0.42), "steel_dk": Color(0.27, 0.28, 0.28), "lamps": 1, "cash": 2, "lamp_base": 0.4},
	{"scale": 0.92, "steel": Color(0.31, 0.39, 0.34), "steel_dk": Color(0.20, 0.26, 0.23), "lamps": 2, "cash": 3, "lamp_base": 0.5},
	{"scale": 1.0, "steel": Color(0.56, 0.25, 0.16), "steel_dk": Color(0.34, 0.16, 0.10), "lamps": 2, "cash": 4, "lamp_base": 0.8}]

func _apply_tier(ti: int, celebrate := true) -> void:
	ti = clampi(ti, 0, TIER_LOOK.size() - 1)
	if ti == _tier_shown or model == null:
		return
	var look: Dictionary = TIER_LOOK[ti]
	var was := _tier_shown
	_tier_shown = ti
	scale = Vector3.ONE * float(look["scale"])
	var from_steel := Color(0.31, 0.39, 0.34)
	var from_dk := Color(0.20, 0.26, 0.23)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in range(m.mesh.get_surface_count()):
			var base := m.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var c := base.albedo_color
			var to := Color(-1, 0, 0)
			if absf(c.r - from_steel.r) + absf(c.g - from_steel.g) + absf(c.b - from_steel.b) < 0.05:
				to = look["steel"]
			elif absf(c.r - from_dk.r) + absf(c.g - from_dk.g) + absf(c.b - from_dk.b) < 0.05:
				to = look["steel_dk"]
			if to.r >= 0.0:
				var dup := base.duplicate() as StandardMaterial3D
				dup.albedo_color = to
				m.set_surface_override_material(i, dup)
	for k in range(_cash_nodes.size()):
		(_cash_nodes[k] as Node3D).set_meta("tier_hidden", k >= int(look["cash"]))
	if lamp2 != null:
		lamp2.visible = int(look["lamps"]) >= 2
	var cage := model.find_child("LampCage", true, false) as Node3D
	if cage != null and int(look["lamps"]) < 2:
		pass                                                                   # (the cage of the missing lamp stays: an empty fitting waiting for the second lamp)
	_set_lamp(float(look["lamp_base"]))
	if celebrate and was >= 0 and is_inside_tree():                            # an upgrade: the lamps flare, sparks, a thump
		_flash_lamps()
		_vibe = 1.0
		if sparks != null:
			sparks.restart()
			sparks.emitting = true
		_sfx(load("res://audio/dig_chink_1.wav"), 0.7, -4.0)

func _set_lamp(level: float) -> void:
	_lamp_level = level
	if _lamp_mat != null:
		_lamp_mat.emission_energy_multiplier = level
	if glow != null:
		glow.light_energy = 0.05 + 0.3 * level

func _lamp_to(level: float, secs: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_lamp, _lamp_level, level, secs)

func _flash_lamps() -> void:                                              # two flashes
	var tw := create_tween()
	for k in range(2):
		tw.tween_method(_set_lamp, 0.6, 3.4, 0.05)
		tw.tween_method(_set_lamp, 3.4, 0.7, 0.09)
	tw.tween_method(_set_lamp, 0.7, 1.6, 0.1)

## The digital displays: the text and how bright it burns (0.5 = dim standby).
func _sale_text(txt: String, bright: float) -> void:
	if sale_display == null:
		return
	sale_display.text = txt
	sale_display.modulate = Color(0.3 * bright + 0.1, 0.95 * minf(bright, 1.0), 0.45 * bright + 0.1, 1.0)

# ------------------------------------------------------------------ the compact payout notification

func _build_note() -> void:
	_note = Node3D.new()
	_note.name = "PayoutNote"
	_note.visible = false
	add_child(_note)
	var face := Node3D.new()
	face.rotation.y = PI                                                  # (a node that looks at the camera shows its -Z side: the quads face +Z)
	_note.add_child(face)
	var specs := [[Vector2(0.64, 0.24), Vector3(0, 0, 0), Color(0.62, 0.42, 0.18, 0.95), null], [Vector2(0.6, 0.2), Vector3(0, 0, 0.002), Color(0.04, 0.035, 0.03, 0.78), null]]
	for sp in specs:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = sp[0]
		q.mesh = qm
		q.position = sp[1]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = sp[2]
		m.no_depth_test = true
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.add_child(q)
		_note_mats.append([m, (sp[2] as Color).a])
	var icon := MeshInstance3D.new()
	var iq := QuadMesh.new()
	iq.size = Vector2(0.17, 0.11)
	icon.mesh = iq
	icon.position = Vector3(-0.21, 0, 0.004)
	var im := StandardMaterial3D.new()
	im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	im.no_depth_test = true
	im.albedo_texture = _bill_icon()
	icon.material_override = im
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.add_child(icon)
	_note_mats.append([im, 1.0])
	_note_label = Label3D.new()
	_note_label.font = QuarryTheme.hud()
	_note_label.font_size = 26
	_note_label.pixel_size = 0.0042
	_note_label.outline_size = 0
	_note_label.shaded = false
	_note_label.no_depth_test = true
	_note_label.modulate = Color(0.55, 1.0, 0.5)
	_note_label.position = Vector3(0.06, 0, 0.006)
	_note_label.double_sided = true
	face.add_child(_note_label)

## A 12 x 8 pixel banknote (green, a lighter middle, a darker border).
func _bill_icon() -> ImageTexture:
	var img := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(12):
			var edge := x == 0 or y == 0 or x == 11 or y == 7
			var mid := (x >= 4 and x <= 7) and (y >= 2 and y <= 5)
			img.set_pixel(x, y, Color(0.16, 0.38, 0.18) if edge else (Color(0.78, 0.95, 0.6) if mid else Color(0.42, 0.74, 0.40)))
	return ImageTexture.create_from_image(img)

func _note_alpha(a: float) -> void:
	for m in _note_mats:
		var c: Color = (m[0] as StandardMaterial3D).albedo_color
		c.a = float(m[1]) * a
		(m[0] as StandardMaterial3D).albedo_color = c
	_note_label.modulate.a = a

## One notification above the front rim: a sale that arrives while it is still up adds to it (one number, never two on top of each other).
func _show_note(money: int) -> void:
	if money <= 0:
		return
	if _note == null:
		_build_note()
	if _note.visible and _live_floats > 0:
		_note_total += money
	else:
		_note_total = money
		_note_base = Vector3(0.0, 2.55, -0.55)
	_note_label.text = "+" + QuarryTheme.money_text(_note_total)
	_note.visible = true
	_live_floats = 1
	_note_alpha(1.0)
	_note.position = _note_base
	if _note_tween != null and _note_tween.is_valid():
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_property(_note, "position:y", _note_base.y + 0.3, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_note_tween.parallel().tween_method(_note_alpha, 1.0, 0.0, 0.5).set_delay(1.0)
	_note_tween.tween_callback(func():
		_note.visible = false
		_live_floats = 0)

# ------------------------------------------------------------------ the temporary look (primitives only)

func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color, rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _part(parent, b, pos, c, rot)

func _build_placeholder() -> void:
	placeholder = Node3D.new()
	placeholder.name = "Placeholder"
	points["Attach_Body"].add_child(placeholder)
	var steel := Color(0.34, 0.40, 0.36)
	var dark := Color(0.16, 0.18, 0.18)
	var rust := Color(0.50, 0.30, 0.16)
	var yellow := Color(0.85, 0.66, 0.16)
	# frame: four legs and a plinth (the machine stands on the ground)
	_box(placeholder, Vector3(1.9, 0.18, 1.9), Vector3(0, 0.09, 0), dark)
	# processing section: a box the funnel feeds, with the front display on its -Z face
	_box(points["Attach_Processor"], Vector3(1.7, 0.95, 1.7), Vector3(0, 0.0, 0), steel)
	_box(points["Attach_Processor"], Vector3(1.8, 0.1, 1.8), Vector3(0, 0.5, 0), rust)
	_box(points["Attach_Processor"], Vector3(1.2, 0.5, 0.06), Vector3(0, 0.40, -0.87), dark)          # the display's panel
	# funnel: a wide cone frustum on top
	var cone := CylinderMesh.new()
	cone.top_radius = 0.95
	cone.bottom_radius = 0.38
	cone.height = 0.9
	cone.radial_segments = 8
	_part(points["Attach_InputFunnel"], cone, Vector3(0, -0.1, 0), rust, Vector3.ZERO, "Funnel")
	var rim := CylinderMesh.new()
	rim.top_radius = 1.0
	rim.bottom_radius = 1.0
	rim.height = 0.08
	rim.radial_segments = 8
	_part(points["Attach_InputFunnel"], rim, Vector3(0, 0.37, 0), yellow, Vector3.ZERO, "Rim")
	# what is waiting in the funnel (grows with the queue)
	var heap := SphereMesh.new()
	heap.radius = 0.7
	heap.height = 0.5
	heap.radial_segments = 8
	heap.rings = 4
	fill = _part(points["Attach_InputFunnel"], heap, Vector3(0, 0.22, 0), Color(0.75, 0.73, 0.66), Vector3.ZERO, "Fill")
	fill.visible = false
	# flywheel on the right side, spins while it works
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.42
	wheel.bottom_radius = 0.42
	wheel.height = 0.14
	wheel.radial_segments = 10
	_part(points["Pivot_Flywheel"], wheel, Vector3(0, 0, 0), yellow, Vector3(0, 0, PI * 0.5), "Flywheel")
	_box(points["Pivot_Flywheel"], Vector3(0.18, 0.1, 0.1), Vector3(0.0, 0, 0), dark)
	_box(points["Pivot_Flywheel"], Vector3(0.1, 0.1, 0.8), Vector3(0.0, 0, 0), dark)
	# impact flap on top of the processing box (kicks on every sale)
	_box(points["Pivot_Flap"], Vector3(1.1, 0.06, 0.5), Vector3(0, 0, 0.3), yellow)
	# output chute at the back
	_box(points["Attach_ConveyorIn"], Vector3(0.7, 0.18, 0.5), Vector3(0, 0, 0), dark)

# ------------------------------------------------------------------ feedback

## Material going in is visible: when the hopper holds more of something than a moment ago, rock tumbles into the funnel.
func _check_intake(delta: float) -> void:
	_intake_cd = maxf(0.0, _intake_cd - delta)
	var items: Dictionary = game.business.outputs[index].get("items", {})
	var best := 0
	var res := ""
	for r in items:
		var gain := int(items[r]) - int(_last_items.get(r, 0))
		if gain > best:
			best = gain
			res = str(r)
	if best > 0 and _intake_cd <= 0.0 and _items_seen:
		_intake_cd = 0.16
		for k in range(clampi(1 + best / 6, 1, 7)):
			_drop_rock(res, 0.07 * float(k))
		_vibe = maxf(_vibe, 0.35)                            # the housing hums when rock lands
	_items_seen = true
	_last_items = items.duplicate()

func _rock_mat(res: String) -> StandardMaterial3D:
	if not _rock_mats.has(res):
		_rock_mats[res] = _mat(QuarryTheme.RES_COLORS.get(res, Color(0.7, 0.7, 0.65)), 0.9)
	return _rock_mats[res]

## Business.cash_sold: the numbers are already booked; this only collects the feedback so a fast hopper groups it into a few bursts.
func on_sold(res: String, units: int, money: int) -> void:
	if not _pending.has(res):
		_pending[res] = [0, 0]
	_pending[res][0] += units
	_pending[res][1] += money

func _process(delta: float) -> void:
	if game == null or index < 0 or index >= game.business.outputs.size() or not game.business.is_cash_hopper(index):
		return
	var b = game.business
	_t += delta
	for cn in _cash_nodes:
		(cn as Node3D).visible = not bool((cn as Node3D).get_meta("tier_hidden", false))
	if anim == null:                                                       # (no Blender clips: the old procedural spin, only while it works)
		var working: bool = b.cash_current(index) != ""
		_work = move_toward(_work, 1.0 if working else 0.0, delta * (4.0 if working else 1.6))
		_fw_speed = move_toward(_fw_speed, (7.0 + 0.5 * minf(b.cash_rate(index), 40.0)) * (1.0 if working else 0.0), delta * (30.0 if working else 7.0))
		(points["Pivot_Flywheel"] as Node3D).rotation.x += delta * _fw_speed
	if _vibe > 0.0 and model != null:                                      # the cabinet's vibration while a sale is registered and processed
		_vibe = maxf(0.0, _vibe - delta * 2.2)
		model.position = Vector3(sin(_t * 95.0) * 0.004 * _vibe, 0.0, cos(_t * 83.0) * 0.003 * _vibe)
		if _vibe <= 0.0:
			model.position = Vector3.ZERO
	if _note != null and _note.visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_note.look_at(cam.global_position, Vector3.UP)
	if fill != null and fill.visible:
		fill.scale = fill.scale.lerp(_fill_target, clampf(delta * 7.0, 0.0, 1.0))      # the heap rises and sinks smoothly with the queue
	_check_intake(delta)
	_burst_t -= delta
	if _burst_t <= 0.0 and not _pending.is_empty():
		_flush()
		_burst_t = maxf(0.12, minf(0.45, 1.6 / maxf(b.cash_rate(index), 0.5)))        # slow hopper: every sale; fast hopper: grouped bursts
	_disp_t -= delta
	if _disp_t <= 0.0:
		_disp_t = 0.2
		_apply_tier(b.cash_tier_index(index))
		_refresh_display()
		_refresh_fill()

func _exit_tree() -> void:
	_seq_running = false

## The sale has ALREADY been booked (Business.cash_sold fires after the money and stock moved). Everything below only shows it: no frame of any animation can pay, or
## pay twice. Sales that arrive during a payout are summed (`_queued_*`) and shown in the same open drawer; the node never touches money.
func _flush() -> void:
	var units := 0
	var money := 0
	var main_res := ""
	var best := -1
	for res in _pending:
		units += int(_pending[res][0])
		money += int(_pending[res][1])
		if int(_pending[res][0]) > best:
			best = int(_pending[res][0])
			main_res = str(res)
	_pending.clear()
	if units <= 0:
		return
	if _seq_running:
		_queued_money += money
		_queued_units += units
		_queued_res = main_res
		return
	_run_sequence(money, units, main_res)

func _wait(t: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(t).timeout
	return is_instance_valid(self) and is_inside_tree()

## Plays a Blender clip; returns how long it takes at that speed (0 when the model has no such clip).
func _play(clip: String, speed := 1.0) -> float:
	if anim == null or not anim.has_animation(clip):
		return 0.0
	anim.play(clip, 0.0, speed)
	return anim.get_animation(clip).length / speed

func _phase(p: String) -> void:
	phase = p

## The six phases (about 3.2 s the first time; a sale within four seconds of the last plays the short version, and sales that arrive meanwhile ride in the same open drawer):
## 1 idle -> 2 sale registered (display shows the amount, lamps flash twice, confirmation click, a shudder) -> 3 processing (gears and rollers turn, the cabinet hums, motor sound)
## -> 4 counting (the inspection window glows) -> 5 payout (the drawer slides out with the cash bundles, a click, the notification and sparks) -> 6 complete (the display says DONE, the
## drawer closes, the lamps dim, back to idle).
func _run_sequence(money: int, units: int, res: String) -> void:
	_seq_running = true
	var quick := Time.get_ticks_msec() < _chain_until_ms
	var drawer_open := false
	var batch_money := money
	var batch_units := units
	var batch_res := res
	var guard := 0
	while true:
		_phase("registered")                                                   # ---- 2
		_sale_text("+" + QuarryTheme.money_text(batch_money), 1.0)
		_play("SaleRegistered", 2.0 if quick else 1.25)
		_sfx(clunk_streams[0] if not clunk_streams.is_empty() else null, 1.6, -9.0)
		_vibe = 1.0
		_flash_lamps()
		for k in range(mini(batch_units, 3)):
			_swallow_rock(batch_res, 0.05 * float(k))
		if not await _wait(0.2 if quick else 0.35):
			return
		_phase("processing")                                                   # ---- 3
		var pt := _play("Processing", 2.4 if quick else 1.4)
		_sfx(load("res://audio/rig_loop.wav"), 1.5, -13.0, pt)
		_thump_sound(batch_units)
		_lamp_to(2.0, 0.15)
		if not await _wait(maxf(pt, 0.3)):
			return
		if not quick:
			_phase("counting")                                                 # ---- 4
			_lamp_to(1.4, 0.1)
			var ct := _play("Counting", 1.75)
			if not await _wait(maxf(ct, 0.3)):
				return
		_phase("payout")                                                       # ---- 5
		if not drawer_open:
			var ot := _play("DrawerOpen", 1.0)
			if not await _wait(maxf(ot, 0.3)):
				return
			drawer_open = true
			_sfx(load("res://audio/dig_chink_1.wav"), 0.9, -6.0)               # the drawer stops with a mechanical click
		_show_note(batch_money)
		if sparks != null:
			sparks.restart()
			sparks.emitting = true
		_coin_sound(batch_units)
		if not await _wait(0.25 if quick else 0.35):
			return
		if _queued_money > 0 and guard < 12:                                   # sales that arrived meanwhile are paid out in the same open drawer
			batch_money = _queued_money
			batch_units = _queued_units
			batch_res = _queued_res
			_queued_money = 0
			_queued_units = 0
			guard += 1
			quick = true
			continue
		break
	_phase("complete")                                                         # ---- 6
	_sale_text("DONE", 0.8)
	if not await _wait(0.2):
		return
	if drawer_open:
		var cl := _play("DrawerClose", 1.0)
		if not await _wait(maxf(cl, 0.2)):
			return
		_sfx(load("res://audio/dig_chink_0.wav"), 0.8, -9.0)
	_lamp_to(float(TIER_LOOK[maxi(_tier_shown, 0)]["lamp_base"]), 0.35)
	var rt := _play("ReturnToIdle", 1.6)
	if not await _wait(maxf(rt, 0.2)):
		return
	_play("Idle")
	_phase("idle")
	_sale_text("READY", 0.5)
	_chain_until_ms = Time.get_ticks_msec() + 4000
	_seq_running = false
	if _queued_money > 0:                                                      # a sale landed during the close: play it next, short
		var m := _queued_money
		var u := _queued_units
		var r := _queued_res
		_queued_money = 0
		_queued_units = 0
		_run_sequence(m, u, r)

func _thump_sound(units: int) -> void:
	_vibe = 1.0
	if audio != null and not clunk_streams.is_empty():
		audio.stream = clunk_streams[_rng.randi() % clunk_streams.size()]
		audio.pitch_scale = _rng.randf_range(0.82, 1.12) * (1.0 - minf(0.2, float(units) * 0.01))
		audio.volume_db = -3.0 + minf(5.0, float(units) * 0.6)
		audio.play()

## A one-shot sound at the machine (freed when it ends, or after `secs`).
func _sfx(stream: AudioStream, pitch: float, vol: float, secs := 0.0) -> void:
	if stream == null or audio == null or not is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = vol
	p.bus = audio.bus
	p.unit_size = audio.unit_size
	p.max_distance = audio.max_distance
	points["Attach_Audio"].add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	if secs > 0.0:
		get_tree().create_timer(secs).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())

func _coin_sound(units: int) -> void:
	_sfx(coin_stream, _rng.randf_range(0.95, 1.2), -7.0 + minf(4.0, float(units) * 0.4))

## Material arriving (a deposit, a belt, a crate): rock tumbles from above into the funnel and lands on the heap (which grows with the queue).
func _drop_rock(res: String, delay: float) -> void:
	var rock := _make_rock(res)
	var spawn: Node3D = points["Attach_RockSpawn"]
	rock.position = spawn.position + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
	rock.visible = false
	var funnel: Node3D = points["Attach_InputFunnel"]
	var end := funnel.position + Vector3(_rng.randf_range(-0.2, 0.2), 0.62, _rng.randf_range(-0.2, 0.2))      # lands on the heap
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): rock.visible = true)
	t.tween_property(rock, "position", end, _rng.randf_range(0.28, 0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(rock, "rotation", rock.rotation + Vector3(2.0, 1.0, 1.5), 0.35)
	t.tween_property(rock, "scale", Vector3.ZERO, 0.12)
	t.tween_callback(rock.queue_free)

## Selling: a rock rolls off the heap and is drawn down the throat (it shrinks as it goes), inside the funnel's mouth.
func _swallow_rock(res: String, delay: float) -> void:
	var rock := _make_rock(res)
	var funnel: Node3D = points["Attach_InputFunnel"]
	rock.position = funnel.position + Vector3(_rng.randf_range(-0.25, 0.25), 0.55, _rng.randf_range(-0.25, 0.25))
	rock.visible = false
	var throat := funnel.position + Vector3(0.0, 0.1, 0.0)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): rock.visible = true)
	t.tween_property(rock, "position", throat, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(rock, "scale", Vector3.ONE * 0.25, 0.2)
	t.tween_callback(rock.queue_free)

func _make_rock(res: String) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sz := _rng.randf_range(0.14, 0.26)
	bm.size = Vector3(sz, sz * 0.8, sz)
	rock.mesh = bm
	rock.material_override = _rock_mat(res)
	rock.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 3.0
	add_child(rock)
	return rock

func _refresh_display() -> void:
	if display == null or game == null or index < 0 or index >= game.business.outputs.size():
		return
	var b = game.business
	var cur: String = b.cash_current(index)
	var q: int = b.cash_queue(index)
	var tier := str(b.cash_tier(index).get("name", "Hopper"))
	display.text = "%s\nNOW  %s\nWAITING  %d / %d\nTODAY  %s\nSPEED  %.0f / s" % [tier.to_upper(), (game.prog.display(cur).to_upper() if cur != "" else "IDLE"), q, b.output_capacity_of(index),
		QuarryTheme.money_text(b.cash_today(index)), b.cash_rate(index)]

func _refresh_fill() -> void:
	if fill == null or game == null:
		return
	var b = game.business
	var q: int = b.cash_queue(index)
	fill.visible = q > 0
	if q > 0:
		var ratio := clampf(float(q) / float(b.output_capacity_of(index)), 0.08, 1.0)
		_fill_target = Vector3(0.5 + 0.5 * ratio, 0.4 + 1.0 * ratio, 0.5 + 0.5 * ratio)
		var cur: String = b.cash_current(index)
		if cur == "":
			for res in b.SELL_ORDER:
				if int(b.outputs[index]["items"].get(res, 0)) > 0:
					cur = res
					break
		if cur != _last_current:
			_last_current = cur
			fill.material_override = _rock_mat(cur)
