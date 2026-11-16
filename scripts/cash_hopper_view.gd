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
	"Attach_FloatText": Vector3(0, 2.6, 0), "Attach_Display": Vector3(0, 0.95, -0.97),
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
	if ResourceLoader.exists(MODEL_PATH):
		var ps = load(MODEL_PATH)
		if ps is PackedScene:
			model = ps.instantiate() as Node3D
			points["Attach_Body"].add_child(model)
			for k in MARKERS:
				var n := model.find_child(k, true, false) as Node3D
				if n != null:
					points[k].global_transform = n.global_transform      # the model decides where its own parts are
	if model == null:
		_build_placeholder()
	display = Label3D.new()
	display.name = "Display"
	display.pixel_size = 0.006
	display.font_size = 40
	display.outline_size = 6
	display.modulate = Color(0.75, 1.0, 0.7)
	display.outline_modulate = Color(0.04, 0.08, 0.04)
	display.double_sided = false
	display.no_depth_test = false
	display.rotation = Vector3(0, PI, 0)                                  # reads from the front (-Z)
	points["Attach_Display"].add_child(display)
	_refresh_display()

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
	var fw: Node3D = points["Pivot_Flywheel"]
	fw.rotation.x += delta * (7.0 + 3.0 * b.cash_rate(index)) * (1.0 if working else 0.0)
	_flap_kick = maxf(0.0, _flap_kick - delta * 6.0)
	(points["Pivot_Flap"] as Node3D).rotation.x = -_flap_kick * 0.35
	_burst_t -= delta
	if _burst_t <= 0.0 and not _pending.is_empty():
		_flush()
		_burst_t = maxf(0.12, minf(0.45, 1.6 / maxf(b.cash_rate(index), 0.5)))        # slow hopper: every sale; fast hopper: grouped bursts
	_disp_t -= delta
	if _disp_t <= 0.0:
		_disp_t = 0.2
		_refresh_display()
		_refresh_fill()

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
	# rocks falling into the funnel (a few per burst, never one per unit)
	var rocks := mini(units, 5)
	for k in range(rocks):
		_drop_rock(main_res, 0.07 * float(k))
	# sound: a clunk then a coin, a little different every time
	if audio != null:
		var s: AudioStream = clunk_streams[_rng.randi() % clunk_streams.size()]
		audio.stream = s
		audio.pitch_scale = _rng.randf_range(0.82, 1.12) * (1.0 - minf(0.2, float(units) * 0.01))
		audio.volume_db = -3.0 + minf(5.0, float(units) * 0.6)
		audio.play()
		get_tree().create_timer(0.09 + _rng.randf() * 0.05).timeout.connect(_coin_sound.bind(units))
	_float_text(money, units)

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

func _drop_rock(res: String, delay: float) -> void:
	var rock := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sz := _rng.randf_range(0.14, 0.26)
	bm.size = Vector3(sz, sz * 0.8, sz)
	rock.mesh = bm
	rock.material_override = _rock_mat(res)
	var spawn: Node3D = points["Attach_RockSpawn"]
	var start := spawn.position + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
	rock.position = start
	rock.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 3.0
	rock.visible = false
	add_child(rock)
	var funnel: Node3D = points["Attach_InputFunnel"]
	var end := funnel.position + Vector3(_rng.randf_range(-0.1, 0.1), -0.3, _rng.randf_range(-0.1, 0.1))
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): rock.visible = true)
	t.tween_property(rock, "position", end, _rng.randf_range(0.28, 0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(rock, "rotation", rock.rotation + Vector3(2.0, 1.0, 1.5), 0.35)
	t.tween_callback(rock.queue_free)

func _float_text(money: int, units: int) -> void:
	if _live_floats >= 6 or money <= 0:
		return
	_live_floats += 1
	var l := Label3D.new()
	l.text = "+" + QuarryTheme.money_text(money)
	l.font_size = 56 if money < 100 else 72
	l.pixel_size = 0.008
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(0.45, 1.0, 0.45) if money < 50 else Color(1.0, 0.82, 0.25)        # green, amber for a big burst
	l.outline_modulate = Color(0.04, 0.12, 0.04) if money < 50 else Color(0.25, 0.14, 0.0)
	l.position = (points["Attach_FloatText"] as Node3D).position + Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.2, 0.2))
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y + 1.2, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.35)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, 1.1).set_delay(0.35)
	t.tween_callback(func():
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
		fill.scale = Vector3(0.5 + 0.5 * ratio, 0.4 + 1.0 * ratio, 0.5 + 0.5 * ratio)
		var cur: String = b.cash_current(index)
		if cur == "":
			for res in b.SELL_ORDER:
				if int(b.outputs[index]["items"].get(res, 0)) > 0:
					cur = res
					break
		if cur != _last_current:
			_last_current = cur
			fill.material_override = _rock_mat(cur)
