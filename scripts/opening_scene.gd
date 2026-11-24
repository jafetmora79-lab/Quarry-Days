extends Node
class_name QuarryOpeningScene
## The new game's opening, played in the real world in first person: the drive to the quarry in Grandpa Walt's pickup (a winding forest road, the mountain tunnel with its headlights,
## the yard), both stepping out, Walt handing over the property deed, and his walk to the old excavator with the first job. Everything is scripted and cheap (a path, a clock, a few
## tweens), the lines come from data/progression.json ("walter"."cinematic": who / text / dur / act / scene), and Esc skips to the same playable state at any moment.
##   scenes: "drive" (in the pickup), "yard" (outside, incl. the deed handoff) and "post" (Walt at the excavator)
## `skip_drive` (headless tests, or a saved intro replay) starts outside, at the yard.

var g                                   ## the game (main.gd)
var active := false
var phase := ""                         ## "drive", "exit", "yard", "post_walk", "post", "done"
var skip_drive := false
var clock := 0.0
var drive_total := 47.0                 ## seconds the drive lasts: the "drive" lines add up to it
var path: PackedVector3Array = PackedVector3Array()
var cum: PackedFloat32Array = PackedFloat32Array()
var path_len := 0.0
var v_cruise := 5.0
var last_s := 0.0
var heading := 0.0
var look_yaw := 0.0
var look_pitch := 0.0
var roll := 0.0
var rig: Node3D                         ## the pickup (the game's own truck_node)
var parts: Dictionary = {}
var tweens: Array = []
var deed: Node3D
var hands: Node3D
var hint: Label
var post_timer := 0.0
var player_path: PackedVector3Array = PackedVector3Array()
var player_path_i := 0
var engine_p: AudioStreamPlayer
var road_p: AudioStreamPlayer
var drone_p: AudioStreamPlayer
var saved_layer := 1
var deed_given := false                 ## the deed has been handed over (once per game, never twice)

const EXIT_YAW_LIMIT := 1.0
const SPEED_A := 2.0
const SPEED_B := 4.0

func start(main, skip := false) -> void:
	g = main
	skip_drive = skip
	active = true
	name = "OpeningScene"
	g.add_child(self)
	g.player.locked = true
	g.walter_intro_running = true
	g._build_truck()
	g._spawn_walter(Vector3.INF, g.player.global_position)
	g.walter_mode = "waiting"
	g.walter_pose = "idle"
	_make_hint()
	if skip_drive or g.truck_node == null or not g.blueprint:
		_begin_yard(false)
	else:
		_begin_drive()

# ------------------------------------------------------------------ the route

## From the tunnel gate along the open lanes (the ones Walt's truck leaves by): down the west lane, east along z = 11.5, then to the parking spot.
static func yard_points(park: Vector3) -> Array:
	var pts := [Vector3(-28.0, 0, 25.4), Vector3(-21.5, 0, 25.4), Vector3(-19.0, 0, 23.3), Vector3(-19.0, 0, 14.0), Vector3(-17.0, 0, 11.5)]
	var x := -10.0
	while x < park.x - 4.0:
		pts.append(Vector3(x, 0, 11.5))
		x += 9.0
	pts.append(Vector3(maxf(park.x - 3.0, -16.0), 0, 11.5))
	pts.append(Vector3(park.x, 0, 11.5 + minf(3.5, absf(park.z - 11.5) * 0.4)))
	pts.append(Vector3(park.x, 0, park.z))
	return pts

## The whole route as a polyline about every metre: the forest road, the straight through the tunnel and the curve to the parking spot. Always ends at the parking spot.
static func build_route(park: Vector3) -> PackedVector3Array:
	var ctl: Array = QuarryOpening.road_curve(2.0)
	ctl.append(Vector3(-100.0, 0, 25.4))
	var tunnel_end := -29.0
	var xx := -100.0
	while xx < tunnel_end:
		xx += 6.0
		ctl.append(Vector3(minf(xx, tunnel_end), 0, 25.4))
	var yp := yard_points(park)
	var tail: Array = []
	var n := yp.size()
	for i in range(n - 1):
		var p0: Vector3 = yp[maxi(i - 1, 0)]
		var p1: Vector3 = yp[i]
		var p2: Vector3 = yp[i + 1]
		var p3: Vector3 = yp[mini(i + 2, n - 1)]
		var steps := maxi(2, int(ceil(p1.distance_to(p2) / 1.0)))
		for k in range(steps):
			tail.append(QuarryOpening._cr(p0, p1, p2, p3, float(k) / float(steps)))
	tail.append(Vector3(park.x, 0, park.z))
	# resample everything at 1 m
	var raw: Array = []
	raw.append_array(ctl)
	raw.append_array(tail)
	var out := PackedVector3Array()
	out.append(raw[0])
	var carry := 0.0
	for i in range(1, raw.size()):
		var a: Vector3 = out[out.size() - 1]
		var b: Vector3 = raw[i]
		var d := a.distance_to(b)
		while d >= 1.0:
			a = a.move_toward(b, 1.0)
			out.append(a)
			d = a.distance_to(b)
	out.append(Vector3(park.x, 0, park.z))
	return out

func _lines(scene_names: Array) -> Array:
	var out := []
	for l in g.prog.walter_cfg().get("cinematic", []):
		if str(l.get("scene", "yard")) in scene_names:
			var e: Dictionary = l.duplicate()
			e["speaker"] = "YOU" if str(l["who"]) == "PLAYER" else "GRANDPA WALTER"
			out.append(e)
	return out

func _tw() -> Tween:
	var t := create_tween()
	tweens.append(t)
	return t

var bar_top: ColorRect
var bar_bottom: ColorRect
const BAR := 0.11                           ## each black bar is this fraction of the screen's height

## Cinematic black bars, top and bottom; they slide in with the first shot and out when the opening ends.
func _make_bars() -> void:
	if g.ui == null:
		return
	for k in range(2):
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.name = "LetterboxTop" if k == 0 else "LetterboxBottom"
		g.ui.add_child(b)
		b.anchor_left = 0.0
		b.anchor_right = 1.0
		if k == 0:
			b.anchor_top = 0.0
			b.anchor_bottom = 0.0
			b.offset_bottom = 0.0
			bar_top = b
		else:
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
			b.offset_top = 0.0
			bar_bottom = b
	var h: float = g.ui.size.y * BAR
	var tw := _tw()
	tw.set_parallel(true)
	tw.tween_property(bar_top, "offset_bottom", h, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bar_bottom, "offset_top", -h, 0.9).set_trans(Tween.TRANS_SINE)

func _bars_off() -> void:
	for b in [bar_top, bar_bottom]:
		if b != null and is_instance_valid(b):
			b.queue_free()
	bar_top = null
	bar_bottom = null

## What the player can press: the drive only listens for Esc; the talk can be moved on with E / Space.
func _set_hint(text: String) -> void:
	if hint != null and is_instance_valid(hint):
		hint.text = text

func _make_hint() -> void:
	if g.ui == null:
		return
	_make_bars()
	hint = Label.new()
	hint.text = "Esc   skip the opening"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.93, 0.85, 0.66, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.ui.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -22.0
	hint.offset_bottom = -(g.ui.size.y * BAR * 0.5 - 9.0)                # centred in the bottom black bar

func _dialog(lines: Array, on_done: Callable) -> void:
	g._open_walter_dialog(lines, on_done, true)
	if g.walter_dialog:
		g.walter_dialog.offset_bottom = -(g.ui.size.y * BAR + 14.0)           # above the cinematic bar
		g.walter_dialog.line_changed.connect(_on_line.bind(lines))
		_on_line(0, lines)

# ------------------------------------------------------------------ A and B: the drive

func _begin_drive() -> void:
	phase = "drive"
	rig = g.truck_node
	saved_layer = rig.collision_layer
	rig.collision_layer = 0
	g.truck_driving = false
	parts = rig.get_meta("pickup", {})
	(parts["interior"] as Node3D).visible = true
	(parts["headlights"] as Node3D).visible = true
	var park: Vector3 = g.truck_node.global_position
	path = build_route(park)
	cum = PackedFloat32Array()
	cum.resize(path.size())
	var acc := 0.0
	for i in range(path.size()):
		if i > 0:
			acc += path[i].distance_to(path[i - 1])
		cum[i] = acc
	path_len = acc
	var lines := _lines(["drive"])
	drive_total = 0.0
	for l in lines:
		drive_total += float(l["dur"])
	v_cruise = path_len / maxf(drive_total - (SPEED_A + SPEED_B) * 0.5, 1.0)
	clock = 0.0
	last_s = 0.0
	heading = _heading_at(0.0)
	_place_rig(0.0, true)
	# Walt at the wheel
	var w: Node3D = g.walter_node
	w.reparent(rig, false)
	w.position = PickupModel.SEAT_WALT
	w.rotation = Vector3.ZERO
	w.scale = Vector3.ONE * 0.95
	g.walter_mode = "waiting"
	g.walter_pose = "idle"
	if w.has_meta("rig"):
		w.get_meta("rig").wheel_hands = true            # both hands on the wheel; they turn with the road
		w.get_meta("rig").seated = true                 # sitting on the bench (legs bent, pelvis down on the cushion), not standing inside it
	# the passenger's eyes
	look_yaw = 0.0
	look_pitch = 0.0
	_seat_player()
	g.hud.fade_to(1.0, 0.0)
	g.hud.fade_to(0.0, 1.8)
	g.hud.toast("QUARRY DAYS", "Grandpa Walt's old pickup, on the way to the quarry.", "info")
	_start_audio()
	g.delivery.set_far_gate(true)
	if not g.delivery.passers.has(rig):
		g.delivery.passers.append(rig)
	_dialog(lines, _drive_done)
	if g.walter_dialog:
		g.walter_dialog.no_advance = true                # the clock drives the drive: only Esc moves it
		g.walter_dialog.next_btn.visible = false
	g.player.tool_view.suppressed = true                 # no shovel in the passenger's hands during the cinematic
	g.player.tool_view.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED         # the mouse looks around the cab

func _dist_at(t: float) -> float:
	var a := SPEED_A
	var b := SPEED_B
	var T := drive_total
	var v := v_cruise
	var s_end := path_len
	if t <= 0.0:
		return 0.0
	if t >= T:
		return s_end
	if t < a:
		return v * t * t / (2.0 * a)
	if t < T - b:
		return v * a * 0.5 + v * (t - a)
	var r := T - t
	return s_end - v * r * r / (2.0 * b)

func _point_at(s: float) -> Vector3:
	s = clampf(s, 0.0, path_len)
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var span := maxf(cum[hi] - cum[lo], 0.0001)
	return path[lo].lerp(path[hi], clampf((s - cum[lo]) / span, 0.0, 1.0))

func _heading_at(s: float) -> float:
	var a := _point_at(maxf(s - 0.5, 0.0))
	var b := _point_at(minf(s + 2.5, path_len))
	var d := b - a
	if d.length() < 0.01:
		return heading
	return atan2(-d.x, -d.z)

func _place_rig(s: float, snap := false) -> void:
	var p := _point_at(s)
	var h := _heading_at(s)
	heading = h if snap else lerp_angle(heading, h, 0.18)
	rig.global_position = p
	rig.rotation = Vector3(0.0, heading, 0.0)

func _seat_player() -> void:
	var eye: Vector3 = rig.global_transform * PickupModel.EYE
	g.player.global_position = eye - Vector3(0, g.player.camera.position.y, 0)
	g.player.rotation.y = heading + look_yaw
	g.player.pitch = look_pitch
	g.player.camera.rotation.x = look_pitch

func _process(delta: float) -> void:
	if not active:
		return
	if phase == "drive" and rig != null and is_instance_valid(rig):
		clock += delta
		var s := _dist_at(clock)
		var ds := s - last_s
		last_s = s
		var prev_h := heading
		_place_rig(s)
		var yaw_rate := angle_difference(prev_h, heading) / maxf(delta, 0.0001)
		if g.walter_node != null and is_instance_valid(g.walter_node) and g.walter_node.has_meta("rig"):
			var wr = g.walter_node.get_meta("rig")
			wr.wheel_angle = lerpf(wr.wheel_angle, clampf(-yaw_rate * 2.2, -0.9, 0.9), clampf(delta * 4.0, 0.0, 1.0))
			var sw = parts.get("steering")
			if sw != null and is_instance_valid(sw):
				(sw as Node3D).basis = Basis(Vector3(0.0, 0.342, 0.94), -wr.wheel_angle * 1.6)       # the wheel turns about its own axis with his hands
		roll = lerpf(roll, clampf(yaw_rate * 0.05, -0.05, 0.05), clampf(delta * 3.0, 0.0, 1.0))
		for w in parts.get("wheels", []):
			if is_instance_valid(w):
				w.rotate_x(-ds / float(w.get_meta("radius", 0.42)))
		var speed := ds / maxf(delta, 0.0001)
		_seat_player()
		var bump := sin(clock * 21.0) * 0.0035 + sin(clock * 13.3) * 0.0025
		g.player.camera.position.y = 1.58 + bump * clampf(speed / 5.0, 0.0, 1.0)
		g.player.camera.rotation.z = roll
		_update_audio(speed)
	elif phase == "post_walk":
		post_timer += delta
		var walking := _player_follow(delta)
		if not walking:
			_watch_walter(delta)
		if (g.walter_mode == "waiting" and not walking) or post_timer > 22.0:
			if g.walter_mode != "waiting":
				g.walter_node.global_position = _post_pos()
				g.walter_mode = "waiting"
			if walking:
				g.player.global_position = _player_post_spot()
			g.walter_speed = 1.7
			_post_line()

func _input(event: InputEvent) -> void:
	if not active or phase != "drive":
		return
	if event is InputEventMouseMotion:
		look_yaw = clampf(look_yaw - event.relative.x * 0.0022, -EXIT_YAW_LIMIT, EXIT_YAW_LIMIT)
		look_pitch = clampf(look_pitch - event.relative.y * 0.0022, -0.42, 0.38)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and g.walter_dialog == null:
		skip_all()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ audio (all synthesised, no files)

func _start_audio() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	engine_p = _player(_engine_wav(), -16.0, bus)
	road_p = _player(_road_wav(), -30.0, bus)
	drone_p = _player(_drone_wav(), -80.0, bus)

func _player(stream: AudioStreamWAV, db: float, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = bus
	add_child(p)
	p.play()
	return p

static func _engine_wav() -> AudioStreamWAV:
	var rate := 22050
	var n := rate
	var d := PackedFloat32Array()
	d.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(rate)
		var pulse := 0.78 + 0.22 * sin(TAU * 19.0 * t)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		d[i] = (sin(TAU * 38.0 * t) * 0.5 + sin(TAU * 76.0 * t) * 0.3 + sin(TAU * 114.0 * t) * 0.12 + lp * 0.25) * pulse * 0.7
	return QuarryAmbience._wav(d, true)

static func _road_wav() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 2
	var d := PackedFloat32Array()
	d.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var lp := 0.0
	for i in range(n):
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.18
		var t := float(i) / float(rate)
		d[i] = lp * (0.65 + 0.35 * sin(TAU * 3.0 * t)) * 0.8
	return QuarryAmbience._wav(QuarryAmbience._seamless(d, 2000), true)

static func _drone_wav() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 2
	var d := PackedFloat32Array()
	d.resize(n)
	for i in range(n):
		var t := float(i) / float(rate)
		d[i] = (sin(TAU * 44.0 * t) * 0.6 + sin(TAU * 66.0 * t) * 0.3 + sin(TAU * 21.0 * t) * 0.3) * 0.7
	return QuarryAmbience._wav(d, true)

func _update_audio(speed: float) -> void:
	if engine_p == null:
		return
	var k := clampf(speed / maxf(v_cruise, 0.1), 0.0, 1.2)
	engine_p.pitch_scale = 0.72 + 0.55 * k
	var in_tunnel: bool = rig.global_position.x > -116.0 and rig.global_position.x < -24.0 and absf(rig.global_position.z - 25.4) < 5.0
	var db := -15.0 + 3.0 * k + (3.0 if in_tunnel else 0.0)
	engine_p.volume_db = lerpf(engine_p.volume_db, db, 0.1)
	road_p.volume_db = lerpf(road_p.volume_db, -34.0 + 10.0 * k, 0.1)
	road_p.pitch_scale = 0.8 + 0.5 * k
	drone_p.volume_db = lerpf(drone_p.volume_db, -22.0 if in_tunnel else -60.0, 0.06)

func _stop_audio() -> void:
	for p in [engine_p, road_p, drone_p]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	engine_p = null
	road_p = null
	drone_p = null

# ------------------------------------------------------------------ park and step out

func _drive_done(skipped: bool) -> void:
	if skipped:
		skip_all()
		return
	phase = "exit"
	g.hud.fade_to(1.0, 0.7)
	var t := _tw()
	t.tween_interval(0.8)
	t.tween_callback(func(): _begin_yard(true))

func _truck_cfg() -> Dictionary:
	return g.prog.walter_cfg().get("truck", {})

func _truck_spot() -> Vector3:
	var p: Array = _truck_cfg().get("pos", [-8.6, 0, 4.8])
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _truck_basis() -> Basis:
	return Basis(Vector3.UP, float(_truck_cfg().get("yaw", 1.5708)))

## Where Walt stands when they have stepped out (by the driver's door) and where the player faces him from.
func walt_spot() -> Vector3:
	if not g.blueprint:
		return g.walter_pos()                                   # the old layout (legacy saves, old tests): where Walt has always stood
	return _truck_spot() + _truck_basis() * Vector3(-2.7, 0.0, -0.9)

func player_spot() -> Vector3:
	if not g.blueprint:
		return g.walter_pos() + Vector3(2.4, 0.2, 1.4)
	return _truck_spot() + _truck_basis() * Vector3(-2.7, 0.2, -4.0)

## Outside, at the parked truck: the truck is back at its own spot, Walt stands by it, the player faces him.
func _begin_yard(from_truck: bool) -> void:
	phase = "yard"
	_stop_audio()
	_restore_truck()
	var wp: Vector3 = walt_spot()
	var meet: Vector3 = player_spot()
	var w: Node3D = g.walter_node
	if w.get_parent() != g.world:
		w.reparent(g.world, false)
	w.scale = Vector3.ONE
	w.global_position = wp
	w.rotation = Vector3.ZERO
	g._walter_face_player_to(meet)
	g.walter_mode = "waiting"
	g.player.global_position = meet
	g._face_player_at(wp + Vector3(0, 1.4, 0))
	g.player.camera.position.y = 1.58
	g.player.camera.rotation.z = 0.0
	if from_truck:
		g.hud.fade_to(1.0, 0.0)
		g.hud.fade_to(0.0, 1.2)
	else:
		g.hud.fade_to(0.0, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_hint("E / Space   next line        Esc   skip the opening")
	_dialog(_lines(["yard"]), _yard_done)

## The pickup stays where the game has always parked Walt's truck.
func _restore_truck() -> void:
	if g.walter_node != null and is_instance_valid(g.walter_node) and g.walter_node.has_meta("rig"):
		g.walter_node.get_meta("rig").wheel_hands = false
		g.walter_node.get_meta("rig").seated = false
	if rig != null and is_instance_valid(rig):
		rig.global_position = _truck_spot()
		rig.rotation = Vector3(0.0, float(_truck_cfg().get("yaw", 1.5708)), 0.0)
		rig.collision_layer = saved_layer
		if parts.has("interior"):
			(parts["interior"] as Node3D).visible = false
		if rig.has_node("Pickup/Headlights"):
			rig.get_node("Pickup/Headlights").visible = false
	if g.delivery != null:
		g.delivery.passers.erase(rig)
		g.delivery.set_far_gate(false)
	if g.player != null:
		g.player.camera.position.y = 1.58
		g.player.camera.rotation.z = 0.0

func _on_line(i: int, lines: Array) -> void:
	if i < 0 or i >= lines.size() or g.walter_node == null or not is_instance_valid(g.walter_node):
		return
	var l: Dictionary = lines[i]
	var act := str(l.get("act", "talk"))
	var who := str(l.get("who", "WALTER"))
	if phase == "yard" or phase == "post":
		g.walter_pose = "talk" if who == "WALTER" else "idle"
	elif phase == "drive":
		g.walter_pose = "talk" if who == "WALTER" else "idle"
	match act:
		"deed":
			_deed_begin()
		"deed_read":
			_deed_read()
		"deed_away":
			_deed_away()
		"point":
			g.walter_pose = "point"
			_point_at_excavator()

# ------------------------------------------------------------------ C: the deed

const PAPER := Vector2(0.30, 0.21)

func _make_deed() -> Node3D:
	var d := Node3D.new()
	d.name = "Deed"
	var sheet := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(PAPER.x, 0.004, PAPER.y)
	sheet.mesh = bm
	sheet.material_override = MeshKit.flat(Color(0.93, 0.89, 0.76))
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(sheet)
	# an inked border and the rule lines that stand for the small print
	var ink := Color(0.22, 0.17, 0.12)
	for e in [[Vector3(0, 0.0031, -PAPER.y * 0.46), Vector3(PAPER.x * 0.92, 0.001, 0.003)], [Vector3(0, 0.0031, PAPER.y * 0.46), Vector3(PAPER.x * 0.92, 0.001, 0.003)],
			[Vector3(-PAPER.x * 0.46, 0.0031, 0), Vector3(0.003, 0.001, PAPER.y * 0.92)], [Vector3(PAPER.x * 0.46, 0.0031, 0), Vector3(0.003, 0.001, PAPER.y * 0.92)]]:
		_ink(d, e[0], e[1], ink)
	for k in range(5):
		_ink(d, Vector3(0.0, 0.0031, -0.002 + k * 0.016), Vector3(PAPER.x * (0.66 if k == 4 else 0.74), 0.001, 0.0025), Color(0.45, 0.4, 0.32))
	_ink(d, Vector3(0.07, 0.0031, 0.082), Vector3(0.10, 0.001, 0.0018), ink)                  # the signature line
	var seal := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.016
	cm.bottom_radius = 0.016
	cm.height = 0.002
	cm.radial_segments = 8
	seal.mesh = cm
	seal.position = Vector3(-0.09, 0.0034, 0.07)
	seal.material_override = MeshKit.flat(Color(0.62, 0.14, 0.12))
	d.add_child(seal)
	_label(d, "PROPERTY DEED", Vector3(0, 0.0036, -0.070), 44, ink)
	_label(d, "GREYHAVEN QUARRY", Vector3(0, 0.0036, -0.045), 30, Color(0.36, 0.22, 0.12))
	_label(d, "Walter", Vector3(0.07, 0.0036, 0.070), 30, Color(0.1, 0.16, 0.42))             # his signature, over the line
	_label(d, "owner", Vector3(0.07, 0.0036, 0.094), 16, Color(0.45, 0.4, 0.32))
	return d

func _ink(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = MeshKit.flat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

func _label(parent: Node3D, text: String, pos: Vector3, fsize: int, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = fsize
	l.pixel_size = 0.00048
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = pos
	l.rotation_degrees = Vector3(-90, 0, 0)               # lies on the sheet's top face, upright for a reader holding it with the top edge away
	parent.add_child(l)

func _make_hands() -> Node3D:
	var h := Node3D.new()
	h.name = "DeedHands"
	var skin := MeshKit.flat(Color(0.82, 0.64, 0.5))
	var sleeve := MeshKit.flat(Color(0.28, 0.34, 0.42))
	for sx in [-1.0, 1.0]:
		var hand := Node3D.new()
		hand.name = "Hand" + ("L" if sx < 0 else "R")
		hand.position = Vector3(sx * 0.165, 0, 0)
		h.add_child(hand)
		var palm := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.075, 0.02, 0.085)
		palm.mesh = pm
		palm.material_override = skin
		hand.add_child(palm)
		for f in range(4):                                                                    # four fingers curl over the paper's edge
			var fi := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.014, 0.016, 0.05)
			fi.mesh = fm
			fi.material_override = skin
			fi.position = Vector3(-sx * 0.0, 0.012, -0.065)
			fi.position.x = -0.027 + f * 0.018
			fi.rotation_degrees = Vector3(-35, 0, 0)
			hand.add_child(fi)
		var thumb := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.018, 0.016, 0.05)
		thumb.mesh = tm
		thumb.material_override = skin
		thumb.position = Vector3(-sx * 0.05, 0.012, -0.02)
		thumb.rotation_degrees = Vector3(0, -sx * 28.0, 0)
		hand.add_child(thumb)
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.07, 0.07, 0.5)
		arm.mesh = am
		arm.material_override = sleeve
		arm.position = Vector3(sx * 0.02, -0.02, 0.3)
		arm.rotation_degrees = Vector3(10, 0, 0)
		hand.add_child(arm)
	return h

## The deed leaves Walt's pocket, he holds it out, and it settles into the player's hands (held up in front of the camera) where it can be read.
func _deed_begin() -> void:
	if deed != null and is_instance_valid(deed):
		return
	deed = _make_deed()
	g.world.add_child(deed)
	var w: Node3D = g.walter_node
	var fwd: Vector3 = -w.global_transform.basis.z
	var right: Vector3 = w.global_transform.basis.x
	g.walter_pose = "offer"
	var pocket: Vector3 = w.global_position + Vector3(0, 1.05, 0) + fwd * 0.12 + right * 0.2
	var held: Vector3 = w.global_position + Vector3(0, 1.2, 0) + fwd * 0.55
	deed.global_position = pocket
	deed.scale = Vector3(0.55, 1.0, 0.7)                                          # still folded in his pocket
	var toward: Vector3 = (g.player.camera.global_position - held).normalized()
	deed.global_transform.basis = _facing_basis(toward).scaled(deed.scale)
	var t := _tw()
	t.tween_property(deed, "global_position", held, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(deed, "scale", Vector3.ONE, 1.1)
	t.tween_interval(0.5)
	t.tween_callback(_deed_to_player)

## A basis whose +Y (the sheet's top face) points along `n`.
static func _facing_basis(n: Vector3) -> Basis:
	var up := n.normalized()
	var ref := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)

func _deed_to_player() -> void:
	if deed == null or not is_instance_valid(deed):
		return
	var cam: Camera3D = g.player.camera
	hands = _make_hands()
	cam.add_child(hands)
	# the hands rise in from below the frame to the paper's lower corners; the sheet is carried into them
	hands.position = Vector3(0, -0.7, -0.38)
	hands.rotation_degrees = Vector3(78, 0, 0)
	var start_xf: Transform3D = cam.global_transform.affine_inverse() * deed.global_transform
	deed.get_parent().remove_child(deed)
	cam.add_child(deed)
	deed.transform = start_xf
	var target_pos := Vector3(0, -0.12, -0.4)
	var target_rot := Vector3(80, 0, 0)
	var target_xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(target_rot.x), 0, 0)), target_pos)
	var t := _tw()
	t.tween_method(func(k: float):
		if deed != null and is_instance_valid(deed):
			deed.transform = start_xf.interpolate_with(target_xf, k), 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(hands, "position", Vector3(0, -0.19, -0.4), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(g.player.camera, "rotation:x", -0.12, 1.2)
	t.tween_callback(_deed_received)

## The deed is in the player's hands: this happens once per game (the flag is saved).
func _deed_received() -> void:
	if not bool(g.prog.story.get("deed_received", false)):
		g.prog.story["deed_received"] = true
		g.prog.journal_add("handover")
		if g.hud:
			g.hud.toast("Property deed received", "Greyhaven Quarry is yours now.", "unlock")
	deed_given = true

func _deed_read() -> void:
	if deed == null or not is_instance_valid(deed):
		return
	var t := _tw()
	t.tween_property(g.player.camera, "rotation:x", -0.32, 0.8).set_trans(Tween.TRANS_SINE)

func _deed_away() -> void:
	if deed == null or not is_instance_valid(deed):
		return
	var t := _tw()
	t.tween_property(g.player.camera, "rotation:x", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(deed, "position", Vector3(0, -0.8, -0.35), 0.7)
	if hands != null and is_instance_valid(hands):
		t.parallel().tween_property(hands, "position", Vector3(0, -0.8, -0.38), 0.7)
	t.tween_callback(_clear_deed)

func _clear_deed() -> void:
	if deed != null and is_instance_valid(deed):
		deed.queue_free()
	if hands != null and is_instance_valid(hands):
		hands.queue_free()
	deed = null
	hands = null
	if g.walter_pose == "offer":
		g.walter_pose = "idle"

# ------------------------------------------------------------------ D: Walt walks to the excavator

func _yard_done(skipped: bool) -> void:
	if skipped:
		skip_all()
		return
	_clear_deed()
	phase = "post_walk"
	post_timer = 0.0
	g.walter_pose = "idle"
	g.walter_mode = "to_post"
	g.walter_speed = 2.3
	g._walter_goto(_post_pos())
	g.player.locked = true
	var from: Vector3 = g.player.global_position
	var goal: Vector3 = _player_post_spot()
	player_path = NavigationServer3D.map_get_path(g.nav_map, from, goal, true) if g.nav_ready() else PackedVector3Array()
	if player_path.size() < 2:
		player_path = PackedVector3Array([from, goal])
	player_path_i = 0

## Where the player ends up standing, next to Walt, looking at the machine.
func _player_post_spot() -> Vector3:
	var ex := _excavator_pos()
	var post := _post_pos()
	var away: Vector3 = (post - ex)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	return post + away * 1.2 + Vector3(0, 0.2, 0) + Vector3(-away.z, 0, away.x) * 1.7

func _post_pos() -> Vector3:
	var gc: Array = g.prog.opening_cfg().get("grandpa", {}).get("pos", [-14.9, 0.0, 5.6])
	return Vector3(float(gc[0]), float(gc[1]), float(gc[2]))

func _excavator_pos() -> Vector3:
	var ex: Array = g.prog.opening_cfg().get("excavator", {}).get("pos", [-12.0, 0.0, 6.6])
	var exv = g._starter_vehicle()
	return exv.global_position if exv != null else Vector3(float(ex[0]), 0.0, float(ex[2]))

## The player walks the same way a few steps behind him (the camera keeps him in view). True while still walking.
func _player_follow(delta: float) -> bool:
	var pl: CharacterBody3D = g.player
	while player_path_i < player_path.size():
		var wp: Vector3 = player_path[player_path_i]
		var d := Vector3(wp.x - pl.global_position.x, 0.0, wp.z - pl.global_position.z)
		if d.length() < 0.25:
			player_path_i += 1
			continue
		var step := d.normalized() * minf(2.4 * delta, d.length())
		pl.global_position += step
		pl.global_position.y = wp.y + 0.05
		var yaw := atan2(-d.x, -d.z)
		pl.rotation.y = lerp_angle(pl.rotation.y, yaw, clampf(delta * 3.0, 0.0, 1.0))
		pl.camera.rotation.x = lerpf(pl.camera.rotation.x, 0.0, clampf(delta * 3.0, 0.0, 1.0))
		return true
	return false

## While he walks the player turns to follow him with their eyes.
func _watch_walter(delta: float) -> void:
	if g.walter_node == null or not is_instance_valid(g.walter_node):
		return
	var d: Vector3 = g.walter_node.global_position + Vector3(0, 1.3, 0) - g.player.camera.global_position
	var yaw := atan2(-d.x, -d.z)
	g.player.rotation.y = lerp_angle(g.player.rotation.y, yaw, clampf(delta * 2.5, 0.0, 1.0))
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.3, 0.3)
	g.player.camera.rotation.x = lerpf(g.player.camera.rotation.x, pitch, clampf(delta * 2.5, 0.0, 1.0))

func _post_line() -> void:
	phase = "post"
	g.walter_mode = "waiting"
	var ex := _excavator_pos()
	g._walter_face_player_to(ex)
	_dialog(_lines(["post"]), _post_done)

func _point_at_excavator() -> void:
	var ex := _excavator_pos()
	var wd: Vector3 = ex - g.walter_node.global_position
	var pd: Vector3 = ex - g.player.global_position
	var t := _tw()
	t.set_parallel(true)
	t.tween_property(g.walter_node, "rotation:y", g.walter_node.rotation.y + angle_difference(g.walter_node.rotation.y, atan2(-wd.x, -wd.z)), 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(g.player, "rotation:y", g.player.rotation.y + angle_difference(g.player.rotation.y, atan2(-pd.x, -pd.z)), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(g.player.camera, "rotation:x", 0.08, 1.4).set_trans(Tween.TRANS_SINE)

func _post_done(skipped: bool) -> void:
	_finish(skipped)

# ------------------------------------------------------------------ the end, and the skip

## Hands back to the game: the same state whether it played out or was skipped (Walt at his post, the deed given once, the objective showing, the player free).
func _finish(skipped: bool) -> void:
	if phase == "done":
		return
	phase = "done"
	active = false
	for t in tweens:
		if t and t.is_valid():
			t.kill()
	tweens.clear()
	_stop_audio()
	_clear_deed()
	if not bool(g.prog.story.get("deed_received", false)):
		g.prog.story["deed_received"] = true                   # skipped before the handoff: the deed is still theirs, once
	if hint != null and is_instance_valid(hint):
		hint.queue_free()
	_bars_off()
	g.player.tool_view.suppressed = false
	g.player.tool_view.visible = true
	g.player.camera.position.y = 1.58
	g.player.camera.rotation.z = 0.0
	g._end_walter_intro(skipped)
	queue_free()

func skip_all() -> void:
	if not active or phase == "done":
		return
	for t in tweens:
		if t and t.is_valid():
			t.kill()
	tweens.clear()
	if g.walter_dialog != null:
		var d: Node = g.walter_dialog
		g.walter_dialog = null
		d.queue_free()
	_stop_audio()
	_clear_deed()
	_restore_truck()
	var w: Node3D = g.walter_node
	if w != null and is_instance_valid(w):
		if w.get_parent() != g.world:
			w.reparent(g.world, false)
		w.scale = Vector3.ONE
		w.global_position = _post_pos()
		g.walter_path = PackedVector3Array()
		g.walter_mode = "waiting"
	g.walter_speed = 1.7
	g.player.global_position = _player_post_spot()
	g._face_player_at(_post_pos() + Vector3(0, 1.4, 0))
	g.hud.fade_to(0.0, 0.0)
	_finish(true)
