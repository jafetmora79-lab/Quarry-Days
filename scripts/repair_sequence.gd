extends RefCounted
class_name RepairSequence
## The excavator's three repairs, each a short first-person inspection at the part's REAL place on the machine. No hands are shown: the parts move by themselves, as if the person were
## working just outside the camera. Every position is computed from the markers of the machine's repair kit (scripts/repair_kit.gd: FuelFiller, FuelCapRest, FuelPourTarget, BatteryTray,
## BatteryPositive/Negative, HydraulicHoseStart/HydraulicHoseEnd ...), so it works however the machine is turned, whatever the ground, and the parts end exactly where they stay.
##
##   fuel     the cap unscrews (counter-clockwise, rising as the thread lets go) and swings to its rest on the tether; the jerry can comes up from below the view, its spout lines up over the
##            filler, it tilts about the spout tip and holds; the stream runs only while the spout is over the opening and ends inside the neck; the stream stops, the can rights itself and
##            leaves; the cap comes back and screws on.                                         (about 7 s)
##   hose     both end fittings of the new hose rise into view; the pump end is brought up to its port, slides on, the coupling nut tightens (click); the hose bends as the boom end is lifted
##            to its port, slides on and tightens; the hose settles. It is then drawn live from the two ports, so it stays connected when the boom, stick and bucket move.   (about 5 s)
##   battery  the battery is brought over the tray, lowered until it rests on the floor, the positive then the negative lead is lifted to its terminal and clamped (a small spark), the
##            tray cover swings shut.                                                          (about 5 s)
## The part is consumed exactly once, at the commit step (after the player can no longer cancel with Esc); a cancel before that leaves everything as it was. After the commit the rest of
## the animation can be skipped (Esc or E): the state update has already happened. Mining is blocked for the whole time (the player is locked, see Main.gameplay_input_allowed).

static func _look(pos: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at((at - pos).normalized(), Vector3.UP), pos)

var game
var v: QuarryVehicle
var kit: RepairKit
var part := ""
var props: Node3D
var tweens: Array = []
var committed := false
var finished := false
var cam_home := Vector3.ZERO
var _before := {}
var _final: Callable
var _stream: MeshInstance3D
var _can: Node3D
var _stream_on := false

func start(game_node, vehicle: QuarryVehicle, part_id: String) -> void:
	game = game_node
	v = vehicle
	part = part_id
	kit = RepairKit.attach_to(v)
	if kit == null:
		_legacy_commit()                                       # no kit model: fit the part without the sequence
		return
	_before = kit.state.duplicate()
	props = Node3D.new()
	props.name = "RepairProps"
	kit.turret_part.add_child(props)
	game.repair_busy = true
	game.player.locked = true
	game.repair_seq = self
	cam_home = game.player.camera.position
	game.player.scripted_camera = true
	if game.player.tool_view != null:
		game.player.tool_view.suppressed = true                 # no tool in the view (the blueprint hands would show it again every frame otherwise)
		game.player.tool_view.visible = false
	var cam: Camera3D = game.player.camera
	var a := cam.global_transform
	var b := _vantage()
	var tw: Tween = game.create_tween()
	tweens.append(tw)
	tw.tween_method(func(w: float): cam.global_transform = a.interpolate_with(b, w), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.1)
	tw.tween_callback(_begin_part)

func _legacy_commit() -> void:
	game.prog.install_part()
	game._decorate_starter()
	game._spawn_repair_parts()
	game.sfx["unlock"].play()

## Where the head goes for this job: outside the machine, looking at the work, computed from the kit's markers and the turret's own axes.
func _vantage() -> Transform3D:
	var tb: Basis = kit.turret_part.global_basis
	var focus: Vector3
	var off: Vector3
	match part:
		"fuel":
			focus = kit.m("FuelFiller").global_position + tb * Vector3(0.0, 0.06, 0.0)
			off = Vector3(0.95, 0.65, 0.65)
		"battery":
			focus = kit.m("BatteryTray").global_position + tb * Vector3(0.0, 0.1, 0.0)
			off = Vector3(-1.0, 1.0, 0.3)
		_:
			focus = (kit.m("HydraulicHoseStart").global_position + kit.m("HydraulicHoseEnd").global_position) * 0.5
			off = Vector3(1.7, 0.35, 0.4)
	var pos := focus + tb * off
	pos.y = maxf(pos.y, v.global_position.y + 1.2)                 # never lower than a standing person's chest
	return _look(pos, focus)

func _begin_part() -> void:
	if part == "battery":
		_battery()
	elif part == "hose":
		_hose()
	else:
		_fuel()

## Esc / E. Before the part is fitted: put it down (nothing consumed, nothing half done). After: skip what is left of the animation.
func cancel() -> void:
	if finished:
		return
	if committed:
		skip()
		return
	for t in tweens:
		if t and t.is_valid():
			t.kill()
	game._notify("You put the part down for now.")
	kit.apply_state(_before["battery"], _before["hose"], _before["fuel"])
	_end(false)

## Skips the rest: every part jumps to where it ends. The repair itself has been fitted already (committed).
func skip() -> void:
	if finished:
		return
	for t in tweens:
		if t and t.is_valid():
			t.kill()
	if _final.is_valid():
		_final.call()
	_end(true)

func _chain() -> Tween:
	var tw: Tween = game.create_tween()
	tweens.append(tw)
	return tw

func _commit() -> void:
	if committed or finished:
		return
	if game.prog.carried_part() != part:
		_end(false)                                            # the part is no longer in hand (never consume twice)
		return
	committed = true
	game.prog.install_part()
	game._decorate_starter()                                   # the permanent state, drawn from the same kit (the parts are already exactly there)
	game._spawn_repair_parts()
	game.sfx["unlock"].play()

func _snd(name: String, db := -4.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://audio/%s.wav" % name)
	p.volume_db = db
	p.unit_size = 6.0
	game.add_child(p)
	p.global_position = kit.turret_part.global_position + Vector3(0, 1.2, 0)
	p.finished.connect(p.queue_free)
	p.play()

func _spark(at: Vector3) -> void:
	game.fx.impact(at, "iron_ore", 0.5, Vector3.UP)
	_snd("repair_zap", -6.0)

static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

# ------------------------------------------------------------------ fuel

const CAN_SCALE := 0.7

func _fuel() -> void:
	var cap := kit.cap
	var f := kit.m("FuelFiller")
	var rest := kit.cap_rest_xf()
	var seat := kit.cap_seated_xf()
	var tb: Basis = kit.turret_part.global_basis
	_can = RepairKit.part("fuel_can")
	props.add_child(_can)
	var tip_local: Vector3 = (_can.find_child("Marker_SpoutTip", true, false) as Node3D).position
	_stream = MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.011
	sm.bottom_radius = 0.009
	sm.height = 1.0
	sm.radial_segments = 6
	_stream.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.92, 0.66, 0.12)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stream.material_override = smat
	_stream.top_level = true
	_stream.visible = false
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(_stream)
	_can.visible = false
	# the cap starts screwed on
	cap.global_transform = seat
	kit.tether_free = true
	var cam: Camera3D = game.player.camera
	# --- the cap: unscrew (counter-clockwise from above = +Y), rising a little as the thread lets go, then swing to its resting place on the tether
	var top := seat
	top.basis = seat.basis.rotated(seat.basis.y, TAU * 1.25)
	top.origin = seat.origin + seat.basis.y * 0.022
	var unscrew := func(w: float):
		var e := _ease(w)
		var xf := seat
		xf.basis = seat.basis.rotated(seat.basis.y, TAU * 1.25 * e)
		xf.origin = seat.origin + seat.basis.y * (0.022 * e)
		cap.global_transform = xf
	var to_rest := func(w: float):
		var e := _ease(w)
		cap.global_transform = Transform3D(top.basis.slerp(rest.basis, e), top.origin.lerp(rest.origin, e) + seat.basis.y * (0.09 * sin(PI * e)))
	# --- the can: below the view -> over the filler (upright, outside the tank) -> over the opening tilting about the spout tip -> pour -> back out
	var pour_tip: Vector3 = f.global_position + tb.y * 0.10
	var hover_tip: Vector3 = f.global_position + tb.x * 0.60 + tb.y * 0.34
	var start_tip: Vector3 = cam.global_position + cam.global_basis * Vector3(0.45, -0.55, -0.55)
	var can_pose := func(tip: Vector3, tilt: float):
		var b := tb * Basis(Vector3(0, 0, 1), tilt)
		var bs := b.scaled(Vector3.ONE * CAN_SCALE)
		_can.global_transform = Transform3D(bs, tip - bs * tip_local)
		_can.visible = true
		var tip_w: Vector3 = _can.to_global(tip_local)
		# the fuel runs only while the can is tipped far enough AND the spout is over the opening
		var over: bool = Vector2(tip_w.x - f.global_position.x, tip_w.z - f.global_position.z).length() < 0.012 and tilt > deg_to_rad(80.0) and tip_w.y > f.global_position.y
		if OS.has_environment("QD_REPAIR_TRACE"):
			print("TRACE tilt %.0f tip-to-filler %s over %s stream_on %s" % [rad_to_deg(tilt), str((tip_w - f.global_position).snapped(Vector3.ONE * 0.01)), str(over), str(_stream_on)])
		if over and _stream_on:
			var target: Vector3 = kit.m("FuelPourTarget").global_position
			_stream.global_basis = Basis(Vector3.RIGHT, Vector3.UP * (tip_w.y - target.y), Vector3.BACK)         # a vertical column from the spout tip to the target inside the neck
			_stream.global_position = (tip_w + target) * 0.5
			_stream.visible = true
		else:
			_stream.visible = false
	var tw := _chain()
	tw.tween_callback(func(): _snd("repair_unscrew", -3.0))
	tw.tween_method(unscrew, 0.0, 1.0, 0.7)
	tw.tween_method(to_rest, 0.0, 1.0, 0.35)
	tw.tween_callback(func(): _snd("repair_clank", -8.0))
	tw.tween_interval(0.05)
	# the can arrives from below the frame, up and over, tilting a little as it goes
	tw.tween_method(func(w: float): can_pose.call(start_tip.lerp(hover_tip, _ease(w)), deg_to_rad(8.0) * _ease(w)), 0.0, 1.0, 0.6)
	tw.tween_method(func(w: float): can_pose.call(hover_tip.lerp(pour_tip + tb.y * 0.06, _ease(w)), deg_to_rad(8.0 + 30.0 * _ease(w))), 0.0, 1.0, 0.4)
	# tip over the opening about the spout tip: aligned first, then tilting to the pouring angle
	tw.tween_method(func(w: float): can_pose.call((pour_tip + tb.y * 0.06).lerp(pour_tip, _ease(w)), deg_to_rad(38.0 + 67.0 * _ease(w))), 0.0, 1.0, 0.6)
	tw.tween_callback(func():
		_stream_on = true
		_snd("repair_glug", -3.0))
	tw.tween_method(func(w: float): can_pose.call(pour_tip, deg_to_rad(105.0 + 2.0 * sin(w * 9.0))), 0.0, 1.0, 0.8)           # holds the pouring angle
	tw.tween_callback(func():
		_stream_on = false
		_stream.visible = false)                                                                                           # the flow stops BEFORE the can rights itself
	tw.tween_interval(0.1)
	tw.tween_method(func(w: float): can_pose.call(pour_tip.lerp(pour_tip + tb.y * 0.06, _ease(w)), deg_to_rad(105.0 - 67.0 * _ease(w))), 0.0, 1.0, 0.4)
	tw.tween_method(func(w: float): can_pose.call((pour_tip + tb.y * 0.06).lerp(hover_tip, _ease(w)), deg_to_rad(38.0 - 30.0 * _ease(w))), 0.0, 1.0, 0.35)
	tw.tween_method(func(w: float): can_pose.call(hover_tip.lerp(start_tip, _ease(w)), deg_to_rad(8.0) * (1.0 - _ease(w))), 0.0, 1.0, 0.5)
	tw.tween_callback(func(): _can.visible = false)
	# the cap comes back: over the filler, then screwed on clockwise, lowering as it tightens
	var back := func(w: float):
		var e := _ease(w)
		cap.global_transform = Transform3D(rest.basis.slerp(top.basis, e), rest.origin.lerp(top.origin, e) + seat.basis.y * (0.09 * sin(PI * e)))
	var screw := func(w: float):
		var e := _ease(w)
		var xf := seat
		xf.basis = seat.basis.rotated(seat.basis.y, TAU * 1.25 * (1.0 - e))
		xf.origin = seat.origin + seat.basis.y * (0.022 * (1.0 - e))
		cap.global_transform = xf
	tw.tween_method(back, 0.0, 1.0, 0.35)
	tw.tween_callback(func(): _snd("repair_screw", -3.0))
	tw.tween_method(screw, 0.0, 1.0, 0.6)
	tw.tween_callback(func():
		_snd("repair_click", -3.0)
		kit.tether_free = false)
	tw.tween_callback(_commit)                                  # fitted only now that the cap is on
	tw.tween_interval(0.15)
	tw.tween_callback(func(): _end(true))
	_final = func():
		cap.global_transform = seat
		kit.tether_free = false
		_can.visible = false
		_stream.visible = false
		_commit()

# ------------------------------------------------------------------ hydraulic hose

func _hose() -> void:
	var fa := kit.hose_a
	var fb := kit.hose_b
	kit.hose_live = true
	kit.stub_mesh.visible = false                               # the torn stub is taken off
	kit.hose_mesh.visible = true
	fa.visible = true
	fb.visible = true
	fa.set_meta("follow", false)
	fb.set_meta("follow", false)
	kit.hose_slack = 0.16
	var cam: Camera3D = game.player.camera
	var seat_b := kit.fitting_xf("HydraulicHoseEnd")
	var nut_a: Node3D = fa.get_node_or_null("Nut") as Node3D
	var nut_b: Node3D = fb.get_node_or_null("Nut") as Node3D
	# the two ends start low in front of the view, held up toward the ports
	var free_a := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)) * cam.global_basis, cam.global_position + cam.global_basis * Vector3(-0.30, -0.45, -0.7))
	var free_b := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-30.0)) * cam.global_basis, cam.global_position + cam.global_basis * Vector3(0.30, -0.55, -0.75))
	fa.global_transform = free_a
	fb.global_transform = free_b
	var appr_a := kit.fitting_xf("HydraulicHoseStart", 0.20)
	var appr_b := kit.fitting_xf("HydraulicHoseEnd", 0.20)
	var hang_b := Transform3D(seat_b.basis, seat_b.origin + Vector3(0, -0.30, 0.18) + kit.turret_part.global_basis * Vector3(0.12, 0, 0))
	var tw := _chain()
	# 1 both ends rise into view; the pump end is lifted toward its port, the boom end hangs lower
	tw.tween_method(func(w: float):
		var e := _ease(w)
		fa.global_transform = free_a.interpolate_with(appr_a, e)
		fb.global_transform = free_b.interpolate_with(hang_b, e), 0.0, 1.0, 1.1)
	# 2 the pump end slides onto its port, the coupling nut turning on the thread, then clicks home
	tw.tween_callback(func(): _snd("repair_tighten", -4.0))
	tw.tween_method(func(w: float):
		var e := _ease(w)
		fa.global_transform = kit.fitting_xf("HydraulicHoseStart", 0.20 * (1.0 - e))
		if nut_a != null:
			nut_a.rotation.y = TAU * 0.9 * e, 0.0, 1.0, 0.9)
	tw.tween_callback(func(): _snd("repair_click", -2.0))
	tw.tween_interval(0.2)
	# 3 the hose bends as the boom end is lifted to its port (it leaves the fitting along its own axis, so there is no sharp bend)
	tw.tween_method(func(w: float): fb.global_transform = hang_b.interpolate_with(kit.fitting_xf("HydraulicHoseEnd", 0.20), _ease(w)), 0.0, 1.0, 0.9)
	tw.tween_callback(func(): _snd("repair_tighten", -4.0))
	tw.tween_method(func(w: float):
		var e := _ease(w)
		fb.global_transform = kit.fitting_xf("HydraulicHoseEnd", 0.20 * (1.0 - e))
		if nut_b != null:
			nut_b.rotation.y = TAU * 0.9 * e, 0.0, 1.0, 0.8)
	tw.tween_callback(func(): _snd("repair_click", -2.0))
	# 4 the hose settles into its final shape (the slack eases out)
	tw.tween_method(func(w: float): kit.hose_slack = lerpf(0.16, 0.06, _ease(w)), 0.0, 1.0, 0.7)
	tw.tween_callback(func():
		fa.set_meta("follow", true)
		fb.set_meta("follow", true))
	tw.tween_callback(_commit)
	tw.tween_interval(0.35)
	tw.tween_callback(func(): _end(true))
	_final = func():
		fa.set_meta("follow", true)
		fb.set_meta("follow", true)
		kit.hose_slack = 0.06
		_commit()

# ------------------------------------------------------------------ battery

func _battery() -> void:
	var bat := kit.battery_node
	var cover := kit.cover
	var tb: Basis = kit.turret_part.global_basis
	var tray: Transform3D = kit.battery_seated_xf()
	bat.visible = true
	cover.rotation.x = 1.75                                      # the cover is up
	var cam: Camera3D = game.player.camera
	var start := Transform3D(tb, cam.global_position + cam.global_basis * Vector3(0.0, -0.55, -0.6))
	var hover := Transform3D(tray.basis, tray.origin + tb.y * 0.55)
	bat.global_transform = start
	var lugs := kit.lugs
	var loose := {}
	for k in ["pos", "neg"]:
		loose[k] = (lugs[k] as Node3D).global_position
	var raise_lug := func(k: String, w: float):
		var e := _ease(w)
		var from: Vector3 = loose[k]
		var to: Vector3 = kit.terminal_point(k) + Vector3(0, 0.005, 0)
		var p := from.lerp(to, e)
		p += tb.y * (0.10 * sin(PI * e))                         # up and over, then down onto the post
		(lugs[k] as Node3D).global_position = p
	var tw := _chain()
	tw.tween_method(func(w: float): bat.global_transform = start.interpolate_with(hover, _ease(w)), 0.0, 1.0, 0.9)                  # brought over the tray
	tw.tween_interval(0.12)
	tw.tween_method(func(w: float): bat.global_transform = hover.interpolate_with(tray, w * w), 0.0, 1.0, 0.65)                     # lowered straight down into it
	tw.tween_callback(func(): _snd("repair_thud", -2.0))
	tw.tween_method(func(w: float): bat.global_transform = Transform3D(tray.basis, tray.origin + tb.y * (0.012 * sin(PI * w) * (1.0 - w))), 0.0, 1.0, 0.18)   # a small settle
	tw.tween_interval(0.15)
	for k in ["pos", "neg"]:
		tw.tween_method(func(w: float): raise_lug.call(k, w), 0.0, 1.0, 0.6)
		tw.tween_callback(func():
			_snd("repair_click", -5.0)
			_spark(kit.terminal_point(k)))
		tw.tween_interval(0.1)
	tw.tween_method(func(w: float): cover.rotation.x = lerpf(1.75, 0.0, _ease(w)), 0.0, 1.0, 0.5)                                   # the cover swings shut
	tw.tween_callback(func(): _snd("repair_clank", -3.0))
	tw.tween_callback(_commit)
	tw.tween_interval(0.35)
	tw.tween_callback(func(): _end(true))
	_final = func():
		bat.global_transform = tray
		cover.rotation.x = 0.0
		for k in ["pos", "neg"]:
			(lugs[k] as Node3D).global_position = kit.terminal_point(k) + Vector3(0, 0.005, 0)
		_commit()

# ------------------------------------------------------------------ finish

func _end(done: bool) -> void:
	if finished:
		return
	finished = true
	if props and is_instance_valid(props):
		props.queue_free()
	var p = game.prog
	if kit != null and done:
		kit.apply_state(p.repair_done("battery"), p.repair_done("hose"), p.repair_done("fuel"))
	if done:
		game.hud.toast(str(p.opening_cfg().get("parts", {}).get(part, {}).get("title", part)) + " fitted", "%d of 3 repairs done" % p.repairs_done(), "unlock")
	var cam: Camera3D = game.player.camera
	var from := cam.global_transform
	var ground: Transform3D = game.player.global_transform * Transform3D(Basis(), cam_home)
	var back: Tween = game.create_tween()
	back.tween_method(func(w: float): cam.global_transform = from.interpolate_with(ground, w), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_callback(func():
		cam.position = cam_home
		cam.rotation = Vector3.ZERO
		game.player.scripted_camera = false
		if game.player.tool_view != null:
			game.player.tool_view.suppressed = false
			game.player.tool_view.visible = true
		game.player.locked = false
		game.repair_busy = false
		game.repair_seq = null
		if done and p.repairs_complete():
			game._excavator_start_scene(v))
