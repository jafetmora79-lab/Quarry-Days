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
var display: ScreenFace                  ## the small stats screen on the front: its text is drawn INTO the glass (see ScreenFace)
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
var rig: MeshyHopperRig                  ## the rigged Meshy hopper (when its model is in the game): the payout is played on its bones, its front plate is a live screen
var piston: Node3D                       ## the ram on the front corner: pumps while it works (the Blender model)
var funnel_node: Node3D                  ## the funnel: it shivers while rock goes through
var drawer: Node3D                       ## the payout drawer: it slides out on every payout
var gear_a: Node3D
var gear_b: Node3D
var lamp2: MeshInstance3D
var sale_display: ScreenFace             ## the slanted LED window on top: shows +$ of the sale in progress
var glow: OmniLight3D                    ## amber light round the lamps, brighter while it works
var anim: AnimationPlayer                ## the Blender clips: Idle, SaleRegistered, Processing, Counting, DrawerOpen, DrawerClose, ReturnToIdle
var phase := "idle"                      ## the six phases of a payout: idle, registered, processing, counting, payout, complete
var _seq_running := false
var _queued_money := 0                   ## sales that arrive while a payout is playing are added up and paid out in the same open drawer
var _queued_units := 0
var _queued_res := ""
var _queued_mats := {}                   ## material -> units of the queued sales (the plate names exactly what was sold)
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
var _heap: Node3D                        ## the material lying in the funnel: one pile per material (up to three), in that material's own look
var _heap_sig := ""
var _heap_base := 1.0                    ## how full the funnel was when the piles were built (they shrink and grow smoothly from there)
var _heap_amt := 0.0
var _crumble_t := 0.0
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
	if MeshyHopperRig.available():
		var r := MeshyHopperRig.new()
		r.name = "MeshyHopper"
		if r.build():
			rig = r
			model = r.model
			points["Attach_Body"].add_child(r)
			for k in MeshyHopperRig.MARKERS:
				(points[k] as Node3D).position = MeshyHopperRig.MARKERS[k]
			r.screen.tick.connect(_count_tick)
		else:
			r.free()
	if rig != null:
		pass                                                           # (the Meshy hopper is built; the Blender one below is the fallback)
	elif WorldModels.has("cash_hopper"):
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
	if rig == null:
		display = ScreenFace.new()
		display.name = "Display"
		if drawer != null:
			display.setup(Vector2(0.19, 0.30), Vector2i(114, 180), 12, Color(0.66, 1.0, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
		else:
			display.setup(Vector2(1.2, 0.5), Vector2i(480, 200), 36, Color(0.75, 1.0, 0.7))
		display.position = Vector3(0, 0, -0.003)
		points["Attach_Display"].add_child(display)
	_refresh_display()
	if drawer != null or rig != null:
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
	if rig == null:
		sale_display = ScreenFace.new()
		sale_display.name = "SaleDisplay"
		sale_display.setup(Vector2(0.48, 0.185), Vector2i(260, 100), 44, Color(0.45, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		sale_display.rotation = Vector3(-0.336, 0, 0)
		sale_display.position = Vector3(0, 0.02, -0.075)                         # (on the glass: its centre is 2.6 cm in front of the marker, along the slope)
		points["Attach_SaleDisplay"].add_child(sale_display)
		_sale_text("READY", 0.5)
		var sign_l := ScreenFace.new()                                         # the name, painted on the strip under the emblem (a plate, not a screen)
		sign_l.name = "Plaque"
		sign_l.setup(Vector2(0.5, 0.075), Vector2i(300, 45), 26, Color(1.0, 0.82, 0.3), HORIZONTAL_ALIGNMENT_CENTER, false)
		sign_l.text = "CASH HOPPER"
		sign_l.position = Vector3(0, 0, -0.012)
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
	dust = CPUParticles3D.new()                                            # a puff where a big load lands
	dust.name = "Dust"
	dust.one_shot = true
	dust.emitting = false
	dust.amount = 10
	dust.lifetime = 0.7
	dust.explosiveness = 0.85
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 70.0
	dust.initial_velocity_min = 0.25
	dust.initial_velocity_max = 0.7
	dust.gravity = Vector3(0, 0.15, 0)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 1.8
	var dq := QuadMesh.new()
	dq.size = Vector2(0.16, 0.16)
	dust.mesh = dq
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.albedo_color = Color(1, 1, 1, 0.35)
	dust.material_override = dm
	dust.position = (points["Attach_InputFunnel"] as Node3D).position + Vector3(0, 0.75, 0)
	add_child(dust)
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
	sparks.position = MeshyHopperRig.TRAY_POINT if rig != null else Vector3(0, 0.6, -1.15)
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
	if rig != null:
		rig.apply_tier(ti)                                                     # (the Meshy model is one textured mesh: it is tinted per tier instead of recoloured part by part)
	for mi in ([] if rig != null else model.find_children("*", "MeshInstance3D", true, false)):
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
	if rig != null:
		rig.set_lamp(level)
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
	var k := 0.45 + 0.55 * minf(bright, 1.0)
	sale_display.modulate = Color(k, k, k, 1.0)                                # (the screen dims at standby)

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
	if not _skip.is_empty() and Time.get_ticks_msec() > _skip_until:
		_skip.clear()                                                         # (an intake that moved no stock - nothing to match - must not swallow a later real arrival)
	for r in items:
		var gain := int(items[r]) - int(_last_items.get(r, 0))
		if gain > 0 and int(_skip.get(r, 0)) > 0:                          # (an intake animation already showed these units)
			var used := mini(gain, int(_skip[r]))
			_skip[r] = int(_skip[r]) - used
			gain -= used
		if gain > best:
			best = gain
			res = str(r)
	if best > 0 and _intake_cd <= 0.0 and _items_seen:
		_intake_cd = 0.3
		var belt: Node3D = points["Attach_ConveyorIn"]
		intake("belt", res, best, belt.global_position + Vector3(0.0, 0.85, 0.35))
	_items_seen = true
	_last_items = items.duplicate()

func _rock_mat(res: String) -> Material:
	if not _rock_mats.has(res):
		_rock_mats[res] = _pile_mat(res)                                                       # the same tinted texture as its pile
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
	if anim == null and rig == null:                                       # (no Blender clips: the old procedural spin, only while it works)
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
	if _heap != null and _heap.visible:                                    # the piles sink smoothly as the material is sold and rise as more arrives
		var k := clampf(sqrt(maxf(_heap_amt, 0.02) / maxf(_heap_base, 0.02)), 0.35, 1.35)
		_heap.scale = _heap.scale.lerp(Vector3(k, k, k), clampf(delta * 5.0, 0.0, 1.0))
	_crumble_t -= delta
	var cur_res: String = b.cash_current(index)
	if cur_res != "" and _crumble_t <= 0.0:                                  # while it sells, chunks keep sliding off the pile, down the funnel and through the grate
		_crumble_t = 0.22
		_swallow_rock(cur_res, 0.0)
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
	var mats := {}
	for res in _pending:
		mats[str(res)] = int(_pending[res][0])
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
		for r in mats:
			_queued_mats[r] = int(_queued_mats.get(r, 0)) + int(mats[r])
		return
	_run_sequence(money, units, main_res, mats)

func _wait(t: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(t).timeout
	return is_instance_valid(self) and is_inside_tree()

## Plays a Blender clip; returns how long it takes at that speed (0 when the model has no such clip).
func _play(clip: String, speed := 1.0) -> float:
	if rig != null:
		return rig.play(clip, speed)                                       # (the Meshy hopper plays the same clip names on its own bones)
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
func _run_sequence(money: int, units: int, res: String, mats := {}) -> void:
	_seq_running = true
	var quick := Time.get_ticks_msec() < _chain_until_ms
	var drawer_open := false
	var batch_money := money
	var batch_units := units
	var batch_res := res
	var cur_mats: Dictionary = mats                                            # the materials of the batch being shown now
	var run_money := 0                                                         # what the open drawer has been paid in this sequence (a sale that rides it adds on)
	var run_units := 0
	var run_mats := {}
	var guard := 0
	while true:
		_phase("registered")                                                   # ---- 2
		_sale_text("+" + QuarryTheme.money_text(batch_money), 1.0)
		if rig != null:                                                        # the plate counts the sale up while the machine works; a sale riding an open drawer carries the number on
			var from := rig.screen.shown_amount() if drawer_open else 0
			run_money += batch_money
			run_units += batch_units
			for r in cur_mats:
				run_mats[r] = int(run_mats.get(r, 0)) + int(cur_mats[r])
			rig.screen.sale(run_money, run_units, _mat_names(run_mats), 0.6 if drawer_open else (0.55 if quick else 1.6), from)
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
		if rig != null:
			rig.pay_out(run_money)                                               # the cash is laid in the (still closed) tray as its real bills and coins; it shows as the tray slides out
		if not drawer_open:
			var ot := _play("DrawerOpen", 1.0)
			if not await _wait(maxf(ot, 0.3)):
				return
			drawer_open = true
			_sfx(load("res://audio/dig_chink_1.wav"), 0.9, -6.0)               # the drawer stops with a mechanical click
		_show_note(batch_money)
		if rig != null:
			rig.screen.paid(MeshyHopperRig.breakdown_text(run_money))          # amount locks, white flash, PAID stamp; the footer lists the bills and coins lying in the tray
		if sparks != null:
			sparks.restart()
			sparks.emitting = true
		_coin_sound(batch_units)
		if not await _wait((0.55 if quick else 1.0) if rig != null else (0.25 if quick else 0.35)):      # (the Meshy hopper holds the drawer open longer: the bills land and the PAID stamp is read)
			return
		if _queued_money > 0 and guard < 12:                                   # sales that arrived meanwhile are paid out in the same open drawer
			batch_money = _queued_money
			batch_units = _queued_units
			batch_res = _queued_res
			cur_mats = _queued_mats
			_queued_mats = {}
			_queued_money = 0
			_queued_units = 0
			guard += 1
			quick = true
			continue
		break
	_phase("complete")                                                         # ---- 6
	_sale_text("DONE", 0.8)
	if rig != null:
		rig.screen.done()
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
	if rig != null:
		rig.screen.back_to_idle()
	_chain_until_ms = Time.get_ticks_msec() + 4000
	_seq_running = false
	if _queued_money > 0:                                                      # a sale landed during the close: play it next, short
		var m := _queued_money
		var u := _queued_units
		var r := _queued_res
		var qm := _queued_mats
		_queued_mats = {}
		_queued_money = 0
		_queued_units = 0
		_run_sequence(m, u, r, qm)

## [[display name, units], ...] largest first, for the plate.
func _mat_names(mats: Dictionary) -> Array:
	var list := []
	for r in mats:
		list.append([game.prog.display(str(r)) if game != null else str(r), int(mats[r])])
	list.sort_custom(func(a, c): return int(a[1]) > int(c[1]))
	return list

## A small coin tick each time the plate's number steps up.
func _count_tick() -> void:
	if coin_stream != null:
		_sfx(coin_stream, 1.7 + _rng.randf() * 0.4, -17.0, 0.0)

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

## ------------------------------------------------------------------ material going IN: one animation per way of putting it in
## Called by main.gd at the moment a transaction has moved material into this hopper (the stock is already booked; this only shows it). Sources:
##   "hand"    a bag or crate deposit: a handful tossed in a few arcs from the player's hands
##   "shovel"  the shovel's load flung in with one flick: a tight bunch, fast
##   "bucket"  the carried bucket tipped over the funnel: a steady stream pours from its lip (timed to the tip)
##   "machine" a loader's or excavator's bucket tipped: a wide cascade of big chunks and a puff of dust
##   "truck"   a truck bed raised over it: an avalanche, a heavy thump, a bigger cloud
##   "belt"    anything that arrives by belt (or by any unknown way): one or two pieces dropping off the belt end
## The heap in the funnel only grows when the pieces land (`_inflight` holds the units back), and the first piece of every pour makes the pour sound.
var _skip_until := 0
var _skip := {}                          ## material -> units an intake animation has already shown (the detector below must not show them again)
var _vis := {}                           ## material -> units visibly on the heap
var _vis_init := false
var _inflight := {}                      ## material -> units still falling toward the heap
var dust: CPUParticles3D

func _after(t: float, f: Callable) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			f.call())

func _funnel_top(spread := 0.0) -> Vector3:
	var fp: Node3D = points["Attach_InputFunnel"]
	return fp.position + Vector3(_rng.randf_range(-spread, spread), 0.3 + 0.35 * clampf(_heap_amt, 0.0, 1.0), _rng.randf_range(-spread, spread))

var last_source := ""                    ## the way the latest intake arrived (tests and debugging)

func intake(source: String, res: String, units: int, origin: Vector3) -> void:
	if units <= 0 or points.is_empty() or not is_inside_tree():
		return
	last_source = source
	_skip[res] = int(_skip.get(res, 0)) + units
	_skip_until = Time.get_ticks_msec() + 2000
	_inflight[res] = int(_inflight.get(res, 0)) + units
	var from := to_local(origin)
	var n := 3
	var delay := 0.0
	var span := 0.0
	var dur := 0.4
	var height := 0.5
	var spread := 0.18
	var size := 0.07
	var shake := 0.3
	match source:
		"shovel":
			n = clampi(units / 2, 5, 9)
			delay = 0.28
			span = 0.06
			dur = 0.32
			height = 0.45
			spread = 0.1
			size = 0.08
		"pour":                                                              # a bucket hovering over the funnel, tipped: a stream that starts when it has tilted
			n = clampi(units / 2, 8, 20)
			delay = 1.15
			span = 1.3
			dur = 0.4
			height = 0.04
			spread = 0.09
			size = 0.065
			shake = 0.35
		"bucket":
			n = clampi(units / 2, 6, 16)
			delay = 0.4
			span = 0.75
			dur = 0.3
			height = 0.12
			spread = 0.12
			size = 0.065
			shake = 0.35
		"machine":
			n = clampi(units, 8, 22)
			delay = 0.1
			span = 0.9
			dur = 0.38
			height = 0.25
			spread = 0.3
			size = 0.11
			shake = 0.8
		"truck":
			n = clampi(units * 2 / 3, 12, 26)
			delay = 0.0
			span = 1.3
			dur = 0.45
			height = 0.35
			spread = 0.38
			size = 0.14
			shake = 1.0
		"belt":
			n = clampi(units, 1, 2)
			dur = 0.38
			height = 0.2
			spread = 0.15
			size = 0.07
			shake = 0.15
		_:                                                                  # "hand" and "crate": a handful, a few arcs
			n = clampi(units / 4, 3, 7)
			delay = 0.12
			span = 0.35
			dur = 0.45
			height = 0.65
			spread = 0.2
			size = 0.075
	var land_t := delay + span + dur
	var per_unit := float(units) / float(n)
	for k in range(n):
		var chunk := _make_chunk(res, size * 1.4 * _rng.randf_range(0.7, 1.35))
		chunk.position = from + Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.05, 0.05))
		chunk.scale = Vector3.ZERO
		var end := _funnel_top(spread)
		var t0 := delay + (span * float(k) / float(maxi(n - 1, 1)) if n > 1 else 0.0)
		var spin := Vector3(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-6.0, 6.0), _rng.randf_range(-9.0, 9.0))
		var tw := create_tween()
		tw.tween_interval(t0)
		tw.tween_property(chunk, "scale", Vector3.ONE, 0.04)
		tw.tween_method(_coin_arc_free.bind(chunk, chunk.position, end, height + _rng.randf_range(0.0, 0.2), spin), 0.0, 1.0, dur)
		tw.tween_callback(_landed.bind(res, per_unit, source, k == 0))
		tw.tween_property(chunk, "scale", Vector3.ZERO, 0.1)
		tw.tween_callback(chunk.queue_free)
	_after(land_t, _intake_done.bind(res, units, source, shake))

## The player's bucket floats out of their hands to hover over the funnel, tips and pours, and flies back: the material falls straight into the funnel as it pours, each piece filling the
## heap (and starting the sale) as it lands. `moved` is what the hopper took ({res: units}); the bucket model empties as it pours.
const POUR_FLY := 0.6
const POUR_TILT := 0.5
const POUR_SPAN := 1.4
const POUR_BACK := 0.9
func pour_bucket(moved: Dictionary, player: Node3D, cap: int) -> void:
	if points.is_empty() or not is_inside_tree() or player == null:
		return
	var bucket: Node3D = BucketView.build()
	add_child(bucket)
	var top := _funnel_top()
	var pl := to_local(player.global_position)
	var pd := Vector3(pl.x, 0.0, pl.z)
	pd = pd.normalized() if pd.length() > 0.01 else Vector3(0, 0, -1)
	var hover := top + pd * 0.5 + Vector3(0.0, 0.95, 0.0)
	var axis := Vector3.UP.cross(-pd).normalized()
	var tilt := 1.95
	var tv = player.get("tool_view")
	if tv != null:
		tv.hidden_for_pour = true
	var start_g: Vector3 = game._hand_origin()
	BucketView.set_load(bucket, moved, cap)
	bucket.position = to_local(start_g)
	var lip := to_global(hover - pd * 0.18 + Vector3(0.0, -0.08, 0.0))
	for res in moved:
		if int(moved[res]) > 0:
			intake("pour", str(res), int(moved[res]), lip)
	var total := POUR_FLY + POUR_TILT + POUR_SPAN + POUR_TILT * 0.8 + POUR_BACK
	var last_frac := 2.0
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(bucket):
			return
		var hand := to_local(game._hand_origin())
		var ang := 0.0
		var pos := hover
		if t < POUR_FLY:                                                     # out of the hands and up over the funnel, in an arc
			var k := _ease3(t / POUR_FLY)
			pos = to_local(start_g).lerp(hover, k) + Vector3(0.0, 0.35 * sin(k * PI), 0.0)
		elif t < POUR_FLY + POUR_TILT:                                        # tips toward the funnel
			ang = tilt * _ease3((t - POUR_FLY) / POUR_TILT)
		elif t < POUR_FLY + POUR_TILT + POUR_SPAN:                            # pours: a gentle shake, the load draining
			var pk := (t - POUR_FLY - POUR_TILT) / POUR_SPAN
			ang = tilt + 0.08 * sin(pk * 40.0) * (1.0 - pk * 0.5)
			pos = hover + Vector3(0.0, 0.02 * sin(pk * 55.0), 0.0)
			var frac := snappedf(1.0 - pk, 0.1)
			if frac != last_frac:
				last_frac = frac
				var rest := {}
				for r in moved:
					rest[r] = int(round(float(moved[r]) * frac))
				BucketView.set_load(bucket, rest, cap)
		elif t < POUR_FLY + POUR_TILT + POUR_SPAN + POUR_TILT * 0.8:          # rights itself
			var uk := (t - POUR_FLY - POUR_TILT - POUR_SPAN) / (POUR_TILT * 0.8)
			ang = tilt * (1.0 - _ease3(uk))
		else:                                                                # and floats back into the hands
			var bk := _ease3((t - (total - POUR_BACK)) / POUR_BACK)
			pos = hover.lerp(hand, bk) + Vector3(0.0, 0.25 * sin(bk * PI), 0.0)
		bucket.position = pos
		bucket.basis = Basis(axis, ang), 0.0, total, total)
	tw.tween_callback(func():
		if is_instance_valid(bucket):
			bucket.queue_free()
		if tv != null and is_instance_valid(tv):
			tv.hidden_for_pour = false)

static func _ease3(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## One point on a thrown chunk's path (a parabola over the straight line).
func _coin_arc_free(t: float, chunk: Node3D, a: Vector3, b: Vector3, h: float, spin: Vector3) -> void:
	if not is_instance_valid(chunk):
		return
	chunk.position = a.lerp(b, t) + Vector3(0.0, 4.0 * h * t * (1.0 - t), 0.0)
	chunk.rotation += spin * 0.016 * (1.0 - t * 0.6)

## A piece lands on the heap: its share of the units joins the visible heap; the first piece of a pour makes the sound.
func _landed(res: String, per_unit: float, source: String, first: bool) -> void:
	_inflight[res] = maxf(0.0, float(_inflight.get(res, 0)) - per_unit)
	_vis[res] = float(_vis.get(res, 0.0)) + per_unit
	_disp_t = 0.0                                                           # (look at the heap now)
	_vibe = maxf(_vibe, 0.18)
	if first:
		_sfx(load("res://audio/dig_pour_dirt.wav" if BucketView.kind_of(res) == "dirt" else "res://audio/dig_pour_rock.wav"), _rng.randf_range(0.9, 1.1), -9.0 if source in ["hand", "shovel", "belt"] else -4.0)

func _intake_done(res: String, units: int, source: String, shake: float) -> void:
	_inflight[res] = 0
	_vibe = maxf(_vibe, shake)
	if dust != null and source in ["machine", "truck", "bucket", "pour"]:
		dust.amount = 18 if source == "truck" else 10
		dust.color = (PILE_TINT.get(res, Color(0.7, 0.68, 0.62)) as Color).lightened(0.25)
		dust.restart()
		dust.emitting = true

func _make_chunk(res: String, size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size * 1.3, size, size * 1.15)
	m.mesh = bm
	m.material_override = _rock_mat(res)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 3.0
	add_child(m)
	return m

## The piles in the funnel: the top three materials of what is waiting, each in its own look (soil as a smooth mound, gravel as small chunks, rock as bigger blocks, ore with the mineral
## showing), built when the mix or the fullness changes by a step and scaled smoothly in between.
func _refresh_heap() -> void:
	var b = game.business
	var items: Dictionary = b.outputs[index].get("items", {})
	var cap := float(maxi(1, b.output_capacity_of(index)))
	var total := 0
	var list: Array = []
	if not _vis_init:
		_vis_init = true
		for r in items:
			_vis[r] = float(items[r])                                          # (a loaded game: what is in the hopper is already on the heap)
	for r in items:
		_vis[r] = minf(float(_vis.get(r, 0.0)), float(items[r]))              # selling takes units off the heap; units only join it when their pieces land
		var shown := int(ceil(float(_vis[r])))
		if shown > 0:
			list.append([str(r), shown])
			total += shown
	if total <= 0:
		_heap_amt = 0.0
		if _heap != null and _heap.visible and _heap.scale.x < 0.4:
			_heap.visible = false
		elif _heap != null:
			_heap_amt = 0.02
		return
	list.sort_custom(func(a, c): return int(a[1]) > int(c[1]))
	list = list.slice(0, 3)
	var amt := clampf(0.16 + 0.84 * sqrt(float(total) / cap), 0.16, 1.0)
	_heap_amt = amt
	var sig := "%d|" % int(round(amt * 5.0))
	for e in list:
		sig += str(e[0]) + ","
	if sig == _heap_sig and _heap != null:
		_heap.visible = true
		return
	_heap_sig = sig
	_heap_base = amt
	if _heap == null:
		_heap = Node3D.new()
		_heap.name = "Heap"
		var fp: Node3D = points["Attach_InputFunnel"]
		_heap.position = fp.position + Vector3(0.0, 0.09, 0.0)
		add_child(_heap)
	for ch in _heap.get_children():
		_heap.remove_child(ch)
		ch.queue_free()
	_heap.scale = Vector3.ONE
	_heap.visible = true
	var n := list.size()
	for k in range(n):
		var share := float(list[k][1]) / float(total)
		var r := (0.11 + 0.2 * amt) * (0.65 + 0.35 * sqrt(share)) if n > 1 else 0.17 + 0.34 * amt
		var h := (0.07 + 0.34 * amt) * (0.6 + 0.4 * sqrt(share))
		var pile := _heap_pile(str(list[k][0]), r, h, 17 + k * 31)
		var ang := TAU * float(k) / float(maxi(n, 1)) + 0.5
		pile.position = Vector3(cos(ang), 0.0, sin(ang)) * (0.0 if n == 1 else (0.2 if n == 2 else 0.24))
		_heap.add_child(pile)

## Each material's pile is tinted its own colour on top of its texture, so a mix reads at a glance: grey gravel, cream limestone, black coal, red-brown iron, green copper, yellow gold, dark soil.
const PILE_TINT := {"topsoil": Color(0.62, 0.45, 0.30), "soil": Color(0.62, 0.45, 0.30), "clay": Color(0.85, 0.55, 0.38), "gravel": Color(0.72, 0.72, 0.74), "crushed_stone": Color(0.72, 0.72, 0.74),
	"limestone": Color(1.0, 0.95, 0.78), "coal": Color(0.32, 0.33, 0.37), "iron_ore": Color(1.0, 0.52, 0.38), "copper_ore": Color(0.55, 1.0, 0.78), "gold_ore": Color(1.0, 0.86, 0.3)}
var _pile_mats := {}

func _pile_mat(res: String) -> Material:
	if not _pile_mats.has(res):
		var base := MeshKit.mat(BucketView.MATS.get(res, "ExcavatedDirt"))
		var dup := base.duplicate() as StandardMaterial3D
		if dup != null:
			dup.albedo_color = PILE_TINT.get(res, Color.WHITE)
			_pile_mats[res] = dup
		else:
			_pile_mats[res] = base
	return _pile_mats[res]

func _heap_pile(res: String, r: float, h: float, seed: int) -> Node3D:
	var node := Node3D.new()
	var kind := BucketView.kind_of(res)
	var mat := _pile_mat(res)
	if kind == "dirt":
		MeshKit.inst(node, PileModels.dirt_mesh(r, h, seed), mat)
		return node
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := MeshKit.Soup.new()
	var big := 0.05 if kind == "gravel" else 0.09
	var n := int((10.0 + 90.0 * r * r) * (1.6 if kind == "gravel" else 1.0))
	for i in range(n):
		var a := rng.randf() * TAU
		var d := r * sqrt(rng.randf())
		var sz := rng.randf_range(big * 0.6, big * 1.2)
		var y := h * (1.0 - (d * d) / (r * r)) * 0.85
		PileModels.chunk_into(s, Vector3(cos(a) * d, y + sz * 0.3, sin(a) * d), Vector3(sz * 1.3, sz, sz * 1.2), rng)
	MeshKit.inst(node, s.mesh(), mat)
	if kind == "ore":
		var o := MeshKit.Soup.new()
		for j in range(maxi(3, n / 6)):
			var a2 := rng.randf() * TAU
			var d2 := r * 0.8 * sqrt(rng.randf())
			var sz2 := rng.randf_range(0.035, 0.06)
			PileModels.chunk_into(o, Vector3(cos(a2) * d2, h * (1.0 - (d2 * d2) / (r * r)) * 0.85 + 0.05, sin(a2) * d2), Vector3(sz2 * 1.2, sz2, sz2), rng)
		MeshKit.inst(node, o.mesh(), MeshKit.flat(QuarryTheme.RES_COLORS.get(res, Color(0.9, 0.7, 0.2)).lightened(0.15), 0.25))
	return node

## Material arriving (a deposit, a belt, a crate): rock tumbles from above into the funnel and lands on the heap (which grows with the queue).
func _drop_rock(res: String, delay: float) -> void:
	var rock := _make_rock(res)
	var spawn: Node3D = points["Attach_RockSpawn"]
	rock.position = spawn.position + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
	rock.visible = false
	var funnel: Node3D = points["Attach_InputFunnel"]
	var end := funnel.position + Vector3(_rng.randf_range(-0.2, 0.2), 0.3 + 0.35 * clampf(_heap_amt, 0.0, 1.0), _rng.randf_range(-0.2, 0.2))      # lands on the heap
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
	var a := _rng.randf() * TAU
	var rr := _rng.randf_range(0.05, 0.3)
	rock.position = funnel.position + Vector3(cos(a) * rr, 0.2 + 0.25 * clampf(_heap_amt, 0.0, 1.0), sin(a) * rr)
	rock.scale = Vector3.ONE * 0.45
	rock.visible = false
	var throat := funnel.position + Vector3(cos(a) * 0.05, 0.06, sin(a) * 0.05)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): rock.visible = true)
	t.tween_property(rock, "position", throat, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)          # it slides down the cone ...
	t.parallel().tween_property(rock, "rotation", rock.rotation + Vector3(2.5, 1.0, 1.7), 0.42)
	t.tween_property(rock, "scale", Vector3.ONE * 0.05, 0.14)                                                      # ... and crumbles away through the grate
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
	if (display == null and rig == null) or game == null or index < 0 or index >= game.business.outputs.size():
		return
	var b = game.business
	var cur: String = b.cash_current(index)
	var q: int = b.cash_queue(index)
	var tier := str(b.cash_tier(index).get("name", "Hopper"))
	if rig != null:                                                            # the Meshy hopper's plate: tier name, what is going through, and the day's numbers on one line
		rig.screen.set_idle(tier.to_upper(), (game.prog.display(cur).to_upper() if cur != "" else "READY"),
			"TODAY %s   WAITING %d/%d   SPEED %.0f/s" % [QuarryTheme.money_text(b.cash_today(index)), q, b.output_capacity_of(index), b.cash_rate(index)])
		return
	display.text = "%s\nNOW  %s\nWAITING  %d / %d\nTODAY  %s\nSPEED  %.0f / s" % [tier.to_upper(), (game.prog.display(cur).to_upper() if cur != "" else "IDLE"), q, b.output_capacity_of(index),
		QuarryTheme.money_text(b.cash_today(index)), b.cash_rate(index)]

func _refresh_fill() -> void:
	if game != null and index >= 0 and index < game.business.outputs.size():
		_refresh_heap()
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
