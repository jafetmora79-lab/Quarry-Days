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
	"Attach_FloatText": Vector3(0, 2.6, 0), "Attach_Display": Vector3(0.4, 1.0, -0.91), "Attach_SaleDisplay": Vector3(0, 1.64, -0.77), "Attach_Sign": Vector3(0, 1.28, -0.95),
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
var _drawer_out := 0.0
var _drawer_pos0 := Vector3.ZERO
var _boost := 0.0                        ## 0..1: a sale is being processed (lamps and gears race)
var _funnel_y0 := 0.0                    ## the heights the funnel and the ram stand at (their shiver and pumping are offsets from these, not absolute heights)
var _piston_y0 := 0.0
var lamp: MeshInstance3D                 ## the status lamp: green while selling, amber when idle
var _t := 0.0
var _work := 0.0                         ## 0..1 how hard the machine is working (eased: it winds up and down)
var _fw_speed := 0.0
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
					points[k].global_transform = n.global_transform
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
					points[k].global_transform = n.global_transform      # the model decides where its own parts are
					if k.begins_with("Pivot_"):
						points[k] = n                                   # the pivots hold the model's own meshes: those are the nodes that turn
			piston = model.find_child("Pivot_Piston", true, false) as Node3D
			funnel_node = model.find_child("Pivot_Funnel", true, false) as Node3D
			lamp = model.find_child("Lamp_Status", true, false) as MeshInstance3D
			fill = model.find_child("Fill", true, false) as MeshInstance3D
			if fill != null:
				fill.visible = false
	if funnel_node != null:
		_funnel_y0 = funnel_node.position.y
	if piston != null:
		_piston_y0 = piston.position.y
	if drawer != null:
		_drawer_pos0 = drawer.position
	if model == null:
		_build_placeholder()
	display = Label3D.new()
	display.name = "Display"
	display.pixel_size = 0.0016 if drawer != null else 0.0027
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

## The sale display on top, the CASH HOPPER plaque and the amber glow (the model has the frames; the letters and the light are the game's).
func _build_extras() -> void:
	sale_display = Label3D.new()
	sale_display.name = "SaleDisplay"
	sale_display.text = "---"
	sale_display.font_size = 64
	sale_display.pixel_size = 0.0026
	sale_display.outline_size = 4
	sale_display.shaded = false
	sale_display.modulate = Color(0.25, 0.9, 0.4, 0.45)
	sale_display.outline_modulate = Color(0.0, 0.1, 0.03)
	sale_display.rotation = Vector3(-0.69, PI, 0)
	points["Attach_SaleDisplay"].add_child(sale_display)
	var sign_l := Label3D.new()
	sign_l.name = "Plaque"
	sign_l.text = "CASH HOPPER"
	sign_l.font_size = 40
	sign_l.pixel_size = 0.0034
	sign_l.outline_size = 6
	sign_l.modulate = Color(1.0, 0.82, 0.3)
	sign_l.outline_modulate = Color(0.1, 0.07, 0.02)
	sign_l.rotation = Vector3(0, PI, 0)
	points["Attach_Sign"].add_child(sign_l)
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.62, 0.2)
	glow.light_energy = 0.0
	glow.omni_range = 3.2
	glow.shadow_enabled = false
	glow.position = Vector3(0, 1.8, -0.9)
	add_child(glow)

## The sale display: the amount flashes, then holds, then goes dim.
func _sale_display_show(money: int) -> void:
	if sale_display == null:
		return
	sale_display.text = "+" + QuarryTheme.money_text(money)
	var tw := create_tween()
	for k in range(3):
		tw.tween_property(sale_display, "modulate:a", 0.25, 0.05)
		tw.tween_property(sale_display, "modulate:a", 1.0, 0.07)
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		sale_display.text = "---")
	tw.tween_property(sale_display, "modulate:a", 0.45, 0.3)

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
		if funnel_node != null:
			funnel_node.rotation.z = 0.02                  # the funnel rings when rock lands
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
	_flap_kick = 1.0

func _process(delta: float) -> void:
	if game == null or index < 0 or index >= game.business.outputs.size() or not game.business.is_cash_hopper(index):
		return
	var b = game.business
	var working: bool = b.cash_current(index) != ""
	_t += delta
	_work = move_toward(_work, 1.0 if working else 0.0, delta * (4.0 if working else 1.6))               # it spins up quickly and coasts down
	var fw: Node3D = points["Pivot_Flywheel"]
	_fw_speed = move_toward(_fw_speed, (7.0 + 0.5 * minf(b.cash_rate(index), 40.0)) * (1.0 if working else 0.0), delta * (30.0 if working else 7.0))
	fw.rotation.x += delta * _fw_speed
	if piston != null:
		piston.position.y = _piston_y0 + sin(_t * (9.0 + 0.15 * minf(b.cash_rate(index), 60.0))) * 0.05 * _work         # the ram pumps
	if funnel_node != null:
		funnel_node.rotation.z = sin(_t * 41.0) * 0.006 * _work                                                # the funnel shivers
		funnel_node.position.y = _funnel_y0 + absf(sin(_t * 33.0)) * 0.004 * _work
	_boost = maxf(0.0, _boost - delta * 1.1)
	if drawer != null:
		drawer.position = _drawer_pos0 + Vector3(0.0, 0.0, -0.22 * _drawer_out)
		var gs := (0.5 + 5.0 * _work + 6.0 * _boost) * delta
		if gear_a != null:
			gear_a.rotation.z += gs
		if gear_b != null:
			gear_b.rotation.z -= gs * 1.45
		if glow != null:
			glow.light_energy = 0.25 + 0.9 * _work + 1.4 * _boost + 0.08 * sin(_t * 9.0)
	if lamp != null and (_lamp_on != int(working) or drawer != null):
		_lamp_on = int(working)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(1.0, 0.62, 0.16)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.58, 0.12)
		lm.emission_energy_multiplier = 1.0 + 1.6 * _work + 1.6 * _boost + 0.25 * sin(_t * 7.0)
		if drawer == null:
			lm.albedo_color = Color(0.35, 0.9, 0.35) if working else Color(0.9, 0.55, 0.15)
			lm.emission = lm.albedo_color
			lm.emission_energy_multiplier = 1.6 if working else 0.8
		lamp.material_override = lm
		if lamp2 != null:
			lamp2.material_override = lm
	_flap_kick = maxf(0.0, _flap_kick - delta * 6.0)
	(points["Pivot_Flap"] as Node3D).rotation.x = -_flap_kick * 0.35
	_thump = maxf(0.0, _thump - delta * 7.0)
	if model != null:
		model.position.y = -0.012 * _thump                    # the whole housing jolts down a hair on each crush
	if fill != null and fill.visible:
		fill.scale = fill.scale.lerp(_fill_target, clampf(delta * 7.0, 0.0, 1.0))      # the heap rises and sinks smoothly with the queue
	_check_intake(delta)
	_float_cd = maxf(0.0, _float_cd - delta)
	if _float_acc > 0 and _float_cd <= 0.0:
		_float_cd = 0.5
		_show_float(_float_acc)
		_float_acc = 0
	_burst_t -= delta
	if _burst_t <= 0.0 and not _pending.is_empty():
		_flush()
		_burst_t = maxf(0.12, minf(0.45, 1.6 / maxf(b.cash_rate(index), 0.5)))        # slow hopper: every sale; fast hopper: grouped bursts
	_disp_t -= delta
	if _disp_t <= 0.0:
		_disp_t = 0.2
		_refresh_display()
		_refresh_fill()

## One sale burst, in the order the machine really works: (1) rock leaves the heap and is swallowed by the throat, (2) the ram thumps and the housing clunks while it is
## crushed and appraised, (3) the payout slot pushes out the money: bills slide out and drop into the tray, coins ring, the amount floats up. Each stage follows the
## one before it (never at the same moment), so the eye can follow the rock to the cash.
const SLOT := Vector3(0.0, 0.64, -0.9)           ## the payout slot in the front of the housing
const TRAY := Vector3(0.0, 0.5, -1.0)            ## where bills and coins land (the drawer, once it has slid out: see TRAY_OUT)
const TRAY_OUT := Vector3(0.0, 0.5, -1.2)

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
	for k in range(mini(units, 3)):                                  # 1. rock goes down the throat
		_swallow_rock(main_res, 0.06 * float(k))
	_after(0.22, _thump_sound.bind(units))                           # 2. the crush: ram, housing and a clunk
	_sale_display_show(money)                                         # 0. the sale is registered: the LED flashes the amount, the lamps flare
	_boost = 1.0
	_after(0.44, _payout.bind(units, money))                         # 3. the money comes out of the slot

func _after(t: float, f: Callable) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			f.call())

func _thump_sound(units: int) -> void:
	_thump = 1.0
	_flap_kick = 1.0
	if audio != null:
		audio.stream = clunk_streams[_rng.randi() % clunk_streams.size()]
		audio.pitch_scale = _rng.randf_range(0.82, 1.12) * (1.0 - minf(0.2, float(units) * 0.01))
		audio.volume_db = -3.0 + minf(5.0, float(units) * 0.6)
		audio.play()

func _payout(units: int, money: int) -> void:
	if drawer != null:                                              # the drawer slides out, holds while the cash settles, and slides back
		var dt := create_tween()
		dt.tween_property(self, "_drawer_out", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		dt.tween_interval(1.3)
		dt.tween_property(self, "_drawer_out", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	_bills(units)
	_coin_burst(units)
	_after(0.06, _coin_sound.bind(units))
	_float_text(money, units)

## Paper money slides out of the slot (flat, toward the viewer), tips over the chute and settles in the tray; a few at a time.
func _bills(units: int) -> void:
	var n := clampi(1 + units / 8, 1, 4)
	for k in range(n):
		var bill := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.008, 0.1)
		bill.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.50, 0.76, 0.46)
		m.roughness = 0.9
		bill.material_override = m
		var sx := _rng.randf_range(-0.12, 0.12)
		bill.position = SLOT + Vector3(sx, 0.0, 0.06)
		bill.rotation = Vector3(0.0, _rng.randf_range(-0.12, 0.12), 0.0)
		add_child(bill)
		var rest := TRAY_OUT + Vector3(sx + _rng.randf_range(-0.1, 0.1), 0.02 * float(k), _rng.randf_range(-0.02, 0.04))
		var tw := create_tween()
		tw.tween_interval(0.09 * float(k))
		tw.tween_property(bill, "position", SLOT + Vector3(sx, 0.0, -0.16), 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bill, "position", rest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(bill, "rotation", Vector3(0.0, bill.rotation.y + _rng.randf_range(-0.4, 0.4), 0.0), 0.16)
		tw.tween_interval(0.9)
		tw.tween_property(bill, "scale", Vector3.ZERO, 0.2)
		tw.tween_callback(bill.queue_free)

## Gold coins are spat out of the slot in little arcs, spinning, land on the tray with a bounce and a glint, and lie there a moment before they vanish (never one per unit).
func _coin_burst(units: int) -> void:
	if model == null:
		return
	var n := clampi(2 + units / 3, 2, 8)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = 0.014
	cm.radial_segments = 14
	var rim := CylinderMesh.new()                                         # a raised rim: the coin reads as a coin from every angle
	rim.top_radius = 0.052
	rim.bottom_radius = 0.052
	rim.height = 0.009
	rim.radial_segments = 14
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.80, 0.22)
	m.metallic = 0.7
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color(1.0, 0.72, 0.15)
	m.emission_energy_multiplier = 0.45
	for k in range(n):
		var coin := MeshInstance3D.new()
		coin.mesh = cm
		coin.material_override = m
		var face := MeshInstance3D.new()
		face.mesh = rim
		face.position = Vector3(0, 0.003, 0)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(1.0, 0.9, 0.5)
		fm.emission_enabled = true
		fm.emission = Color(1.0, 0.85, 0.35)
		fm.emission_energy_multiplier = 0.5
		face.material_override = fm
		face.scale = Vector3(0.66, 1.0, 0.66)
		coin.add_child(face)
		var x0 := _rng.randf_range(-0.16, 0.16)
		var start := SLOT + Vector3(x0, 0.0, -0.01)
		coin.position = start
		coin.scale = Vector3.ZERO
		coin.rotation = Vector3(_rng.randf() * 3.0, _rng.randf() * 3.0, 0.0)
		add_child(coin)
		var land := TRAY_OUT + Vector3(clampf(x0 * 1.3 + _rng.randf_range(-0.08, 0.08), -0.2, 0.2), 0.0, _rng.randf_range(-0.05, 0.07))
		var apex_h := 0.2 + _rng.randf() * 0.12
		var spin := Vector3(_rng.randf_range(9.0, 15.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0))
		var tw := create_tween()
		tw.tween_interval(0.06 * float(k))
		tw.tween_property(coin, "scale", Vector3.ONE, 0.04)
		tw.tween_method(_coin_arc.bind(coin, start, land, apex_h, spin), 0.0, 1.0, 0.36)
		tw.tween_callback(_coin_land.bind(land, k))
		var hop := land + Vector3(_rng.randf_range(-0.04, 0.04), 0.0, _rng.randf_range(0.02, 0.06))
		tw.tween_method(_coin_arc.bind(coin, land, hop, 0.05, spin * 0.2), 0.0, 1.0, 0.16)
		tw.tween_property(coin, "rotation", Vector3(0.0, coin.rotation.y, _rng.randf_range(-0.15, 0.15)), 0.1)     # settles flat
		tw.tween_interval(0.9)
		tw.tween_property(coin, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(coin.queue_free)

## One point on a coin's arc: ground path from a to b, a parabola of height h over it, and the spin easing off.
func _coin_arc(t: float, coin: Node3D, a: Vector3, b: Vector3, h: float, spin: Vector3) -> void:
	if not is_instance_valid(coin):
		return
	coin.position = a.lerp(b, t) + Vector3(0.0, 4.0 * h * t * (1.0 - t), 0.0)
	coin.rotation += spin * 0.016 * (1.0 - t)

## A coin touches the tray: a little gold glint.
func _coin_land(at: Vector3, k: int) -> void:
	if not is_inside_tree() or k % 2 == 1:
		return
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.14, 0.14)
	q.mesh = qm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gt := GradientTexture2D.new()                                     # a soft round glow, not a square
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 32
	gt.height = 32
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 0.95, 0.7, 1), Color(1, 0.8, 0.3, 0)])
	gt.gradient = gr
	gm.albedo_texture = gt
	gm.albedo_color = Color(1.0, 0.86, 0.4, 0.95)
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.no_depth_test = true
	q.material_override = gm
	q.position = at + Vector3(0.0, 0.05, -0.02)
	q.scale = Vector3.ZERO
	add_child(q)
	var tw := create_tween()
	tw.tween_property(q, "scale", Vector3.ONE * 1.3, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(q, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(q.queue_free)

func _coin_sound(units: int) -> void:
	if audio == null or not is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = coin_stream
	p.pitch_scale = _rng.randf_range(0.92, 1.3)
	p.volume_db = -6.0 + minf(4.0, float(units) * 0.4)
	p.bus = audio.bus
	p.unit_size = audio.unit_size
	p.max_distance = audio.max_distance
	points["Attach_Audio"].add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

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

var _float_acc := 0
var _float_cd := 0.0

## The amount rises from the tray. A fast hopper pays out many times a second: the amounts are added up and shown about twice a second, so the number reads.
func _float_text(money: int, units: int) -> void:
	if money <= 0:
		return
	_float_acc += money
	if _float_cd > 0.0:
		return
	_float_cd = 0.5
	_show_float(_float_acc)
	_float_acc = 0

func _show_float(money: int) -> void:
	if _live_floats >= 4 or money <= 0:
		return
	_live_floats += 1
	var big := money >= 50
	var l := Label3D.new()
	l.text = "+" + QuarryTheme.money_text(int(round(float(money) * 0.3)))
	l.font_size = 44 if money < 100 else 60
	l.pixel_size = 0.006
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(0.45, 1.0, 0.45) if not big else Color(1.0, 0.84, 0.28)        # green, gold for a big burst
	l.outline_modulate = Color(0.04, 0.14, 0.04) if not big else Color(0.30, 0.16, 0.0)
	var x0 := _rng.randf_range(-0.15, 0.15)
	l.position = TRAY + Vector3(x0, 0.3, -0.15)
	l.scale = Vector3.ONE * 0.3
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "scale", Vector3.ONE * 1.25, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)      # it pops out of the tray ...
	t.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(func(v: float): l.text = "+" + QuarryTheme.money_text(int(round(float(money) * v))), 0.3, 1.0, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)      # ... and counts up
	var rise := create_tween()
	rise.tween_property(l, "position:y", l.position.y + 1.1, 1.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_method(func(v: float): l.position.x = x0 + sin(v * 7.0) * 0.06 * v, 0.0, 1.0, 1.3)
	rise.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.85)
	rise.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.85)
	rise.tween_callback(func():
		_live_floats -= 1
		l.queue_free())

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
