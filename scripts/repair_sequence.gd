extends RefCounted
class_name RepairSequence
## The excavator's three repairs, each a short first-person sequence at the part's real place on the machine (all positions are in the cab's own frame, the same
## frame OpeningModels.fitted() draws the permanent parts in, so what animates is exactly where it stays):
##   battery  the tray's access panel opens, the battery is lowered in and settles, the terminals are clamped (spark), the panel closes
##   hose     the coil goes to the boom-foot fitting, the hose is laid along the boom to the cab fitting and clamped
##   fuel     the filler cap comes off, the jerry can tips and pours a visible stream, the cap goes back on
## About 4-5 s each. The part is consumed exactly once, at the commit step (after the player can no longer cancel with Esc); a cancel before that leaves everything
## as it was. Mining is blocked for the whole time (the player is locked, see Main.gameplay_input_allowed).

const SOCKET := {"battery": Vector3(0.56, 1.5, 0.45), "hose": Vector3(0.72, 1.07, -1.04), "fuel": Vector3(-0.62, 1.54, 0.55)}
## The hose runs along the boom's right face (the boom stands at x 0.55): from the pump port on the front of the boom pedestal to the cylinder port on the boom itself.
## (It used to float in front of the cab, attached to nothing.) VANTAGE: where the person stands to do each job, so the part and the socket are both in view.
const HOSE_A := Vector3(0.72, 0.93, -0.68)         ## the pump port on the boom pedestal
const HOSE_B := Vector3(0.72, 1.2, -1.4)           ## the cylinder port on the boom
const VANTAGE := {"battery": Vector3(1.9, 2.05, 0.95), "hose": Vector3(2.7, 1.8, -0.5), "fuel": Vector3(-1.8, 2.05, 1.2)}

static func _look(pos: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at((at - pos).normalized(), Vector3.UP), pos)

var game
var v: QuarryVehicle
var cab: Node3D
var part := ""
var props: Node3D
var tweens: Array = []
var committed := false
var finished := false
var cam_home := Vector3.ZERO

func start(game_node, vehicle: QuarryVehicle, part_id: String) -> void:
	game = game_node
	v = vehicle
	part = part_id
	cab = v.turret if v.turret != null else v.model_root
	if v.turret != null and v.turret.has_node("OpeningFrame"):
		cab = v.turret.get_node("OpeningFrame")         # the Blender excavator: the procedural turret space, moved onto its hood
	props = Node3D.new()
	props.name = "RepairProps"
	cab.add_child(props)
	game.repair_busy = true
	game.player.locked = true
	game.repair_seq = self
	# the head moves to where the person stands for this job, eased, and looks at the socket (the part is then held in view of it)
	cam_home = game.player.camera.position
	game.player.scripted_camera = true
	if game.player.tool_view != null:
		game.player.tool_view.visible = false                 # both hands are on the part
	var cam: Camera3D = game.player.camera
	var a := cam.global_transform
	var b := _look(cab.to_global(VANTAGE[part]), cab.to_global(SOCKET[part] + Vector3(0, 0.03, 0)))
	var tw: Tween = game.create_tween()
	tweens.append(tw)
	tw.tween_method(func(w: float): cam.global_transform = a.interpolate_with(b, w), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.1)
	tw.tween_callback(_begin_part)

func _begin_part() -> void:
	if part == "battery":
		_battery()
	elif part == "hose":
		_hose()
	else:
		_fuel()

## Esc: stop before the part is fitted; nothing is consumed and nothing stays half done.
func cancel() -> void:
	if finished or committed:
		return
	for t in tweens:
		if t and t.is_valid():
			t.kill()
	game._notify("You put the part down for now.")
	_end(false)

func _hand() -> Vector3:
	return cab.to_local(game.player.camera.global_transform * Vector3(0.22, -0.28, -0.55))

func _mesh(parent: Node3D, size: Vector3, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = MeshKit.flat(color)
	m.position = at
	parent.add_child(m)
	return m

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
	game._decorate_starter()                                   # the permanent parts, drawn where this animation just put them
	game._spawn_repair_parts()
	game.sfx["unlock"].play()

func _spark(at_local: Vector3) -> void:
	game.fx.impact(cab.to_global(at_local), "iron_ore", 0.7, Vector3.UP)
	game.sfx["hit_reinforced"].play()

# ------------------------------------------------------------------ hands

## A gloved hand (the first-person glove model) gripping something at `at` in `parent`'s frame: its grip axis is `axis`, the forearm runs back toward the
## person's head. Parented to the thing it holds, so it moves, tips and sinks with it and never lets go of it by accident.
func _glove(parent: Node3D, right: bool, at: Vector3, axis := Vector3.UP) -> Node3D:
	var h := ToolModels.load_hand(right)
	if h == null:
		return Node3D.new()
	var toward := parent.to_local(cab.to_global(VANTAGE[part])) - at
	var ya := axis.normalized()
	var za := toward - ya * toward.dot(ya)
	if za.length() < 0.05:
		za = ya.cross(Vector3.RIGHT)
	za = za.normalized()
	h.basis = Basis(ya.cross(za).normalized(), ya, za)
	h.position = at
	h.name = "Glove_" + ("R" if right else "L")
	parent.add_child(h)
	return h

# ------------------------------------------------------------------ battery

func _battery() -> void:
	# 1 the service cover over the pocket (x 0.34..0.78, z 0.33..0.57) swings open on its rear hinge, 2 both hands lift the battery by its strap and carry it over,
	# 3 it is lowered DOWN into the pocket until it rests on the floor, 4 a hand clips each terminal, 5 the cover closes
	var rest := Vector3(0.56, 1.33, 0.45)
	var hinge := Node3D.new()
	hinge.position = Vector3(0.56, 1.5, 0.33)
	props.add_child(hinge)
	_mesh(hinge, Vector3(0.5, 0.03, 0.27), Color(0.45, 0.47, 0.5), Vector3(0, 0, 0.135))
	var bat := OpeningModels.part("battery")
	bat.position = _hand()
	props.add_child(bat)
	var gl := _glove(bat, false, Vector3(-0.12, 0.29, 0.0), Vector3.RIGHT)               # both hands hold the strap across the top
	var gr := _glove(bat, true, Vector3(0.12, 0.29, 0.0), Vector3.RIGHT)
	var cable_r := _mesh(props, Vector3(0.02, 0.02, 0.22), Color(0.8, 0.12, 0.1), Vector3(0.66, 1.66, 0.62))
	var cable_b := _mesh(props, Vector3(0.02, 0.02, 0.22), Color(0.08, 0.08, 0.09), Vector3(0.46, 1.66, 0.62))
	cable_r.visible = false
	cable_b.visible = false
	var tr := _glove(props, true, Vector3(0.66, 1.72, 0.5), Vector3.RIGHT)               # the hands that will clip the terminals, out of sight until then
	var tl := _glove(props, false, Vector3(0.46, 1.72, 0.5), Vector3.RIGHT)
	tr.visible = false
	tl.visible = false
	var tw := _chain()
	tw.tween_property(hinge, "rotation:x", -1.7, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)                             # the cover opens
	tw.tween_callback(func(): game.sfx["hit_pick"].play())
	tw.tween_property(bat, "position", rest + Vector3(0, 0.75, 0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)       # lifted over the pocket
	tw.tween_property(bat, "position", rest + Vector3(0, 0.1, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)             # lowered into it
	tw.tween_property(bat, "position", rest, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)                                # and down onto the floor
	tw.tween_callback(func():
		game.sfx["hit_reinforced"].play()
		gl.visible = false                                                                                                              # hands let go of the strap...
		gr.visible = false
		tr.visible = true                                                                                                               # ...and go to the terminals
		tl.visible = true)
	tw.tween_property(tr, "position:y", 1.68, 0.12)                                                                                      # a brief press on each clamp
	tw.tween_callback(func():
		cable_r.visible = true
		_spark(Vector3(0.66, 1.62, 0.5)))
	tw.tween_property(tr, "position:y", 1.72, 0.1)
	tw.tween_property(tl, "position:y", 1.68, 0.12)
	tw.tween_callback(func():
		cable_b.visible = true
		_spark(Vector3(0.46, 1.62, 0.5)))
	tw.tween_property(tl, "position:y", 1.72, 0.1)
	tw.tween_callback(func():
		tr.visible = false
		tl.visible = false)
	tw.tween_property(hinge, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)                                # the cover closes
	tw.tween_callback(func(): game.sfx["hit_reinforced"].play())
	tw.tween_callback(_commit)
	tw.tween_interval(0.3)
	tw.tween_callback(func(): _end(true))

# ------------------------------------------------------------------ hydraulic hose

func _hose() -> void:
	# 1 the coil is picked up in both hands, 2 carried to the first fitting and screwed on, 3 the hose is paid out along the boom (the free end in the right hand,
	# the left hand holds the first fitting), 4 the second end is screwed on, 5 a short look along the hose
	var coil := OpeningModels.part("hose")
	coil.position = _hand()
	props.add_child(coil)
	_glove(coil, true, Vector3(0.2, 0.12, 0.0), Vector3(0, 0, 1))
	_glove(coil, false, Vector3(-0.19, 0.1, 0.0), Vector3(0, 0, 1))
	var tube := MeshInstance3D.new()
	tube.material_override = MeshKit.flat(Color(0.2, 0.24, 0.3))
	props.add_child(tube)
	var fit_a := _mesh(props, Vector3(0.06, 0.06, 0.06), Color(0.75, 0.55, 0.2), HOSE_A)
	var fit_b := _mesh(props, Vector3(0.06, 0.06, 0.06), Color(0.75, 0.55, 0.2), HOSE_B)
	fit_a.visible = false
	fit_b.visible = false
	var axis := (HOSE_B - HOSE_A).normalized()
	var hold := _glove(props, false, HOSE_A + Vector3(0.0, 0.0, 0.06), axis)                  # left hand steadies the first fitting
	var pull := _glove(props, true, HOSE_A + Vector3(0.0, 0.0, -0.1), axis)                   # right hand leads the free end along the boom
	hold.visible = false
	pull.visible = false
	var lay := func(t: float):
		var pts := []
		for k in range(0, 15):
			var u := t * float(k) / 14.0
			var pt := HOSE_A.lerp(HOSE_B, u)
			pt.y += -0.05 * sin(PI * u) + 0.02 * sin(TAU * u * 2.0)                    # it follows the boom's side with a little sag
			pts.append(pt)
		var so := MeshKit.Soup.new()
		MeshKit.tube_into(so, pts, 0.026, 6)
		tube.mesh = so.mesh()
		pull.position = pts.back() as Vector3
	var cam: Camera3D = game.player.camera
	var tw := _chain()
	tw.tween_property(coil, "position", HOSE_A + Vector3(0.1, 0.1, -0.05), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)   # the coil goes to the first fitting
	tw.tween_callback(func():
		fit_a.visible = true
		_spark(HOSE_A))                                                                                              # first end screwed on
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		coil.visible = false
		hold.visible = true
		pull.visible = true)
	tw.tween_method(lay, 0.02, 1.0, 1.2)                                                                             # the hose is paid out along the boom
	tw.tween_callback(func():
		fit_b.visible = true
		_spark(HOSE_B))                                                                                              # second end secured
	tw.tween_interval(0.25)
	tw.tween_callback(func(): game.sfx["hit_reinforced"].play())                                                     # clamp tightened
	tw.tween_callback(func():
		hold.visible = false
		pull.visible = false)
	# the visual check: the head follows the hose from the pump port to the cylinder port
	var look_a := _look(cab.to_global(VANTAGE[part]), cab.to_global(HOSE_A))
	var look_b := _look(cab.to_global(VANTAGE[part]), cab.to_global(HOSE_B))
	var here := [Transform3D.IDENTITY]
	tw.tween_callback(func(): here[0] = cam.global_transform)
	tw.tween_method(func(w: float): cam.global_transform = (here[0] as Transform3D).interpolate_with(look_a, w), 0.0, 1.0, 0.25)
	tw.tween_method(func(w: float): cam.global_transform = look_a.interpolate_with(look_b, w), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_commit)
	tw.tween_interval(0.15)
	tw.tween_callback(func(): _end(true))

# ------------------------------------------------------------------ fuel

func _fuel() -> void:
	# 1 the filler cap is unscrewed (a hand turns it) and put aside, 2 both hands take the can (handle bar and side), 3 it is brought over the filler and
	# tipped, the fuel pours (glug sounds), 4 it returns upright and is taken away, 5 the cap goes back on and is tightened. Fitted only once the cap is on.
	var f: Vector3 = SOCKET["fuel"]
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.075
	cm.height = 0.04
	cm.radial_segments = 8
	cap.mesh = cm
	cap.material_override = MeshKit.flat(Color(0.86, 0.66, 0.12))
	cap.position = f + Vector3(0, 0.03, 0)
	props.add_child(cap)
	var cap_hand := _glove(cap, true, Vector3(0.0, 0.0, 0.0), Vector3.UP)            # the hand that turns the cap
	var can := OpeningModels.part("fuel")
	can.position = _hand()
	props.add_child(can)
	var ch := _glove(can, true, Vector3(0.0, 0.46, 0.0), Vector3.RIGHT)               # right hand on the handle bar
	var cu := _glove(can, false, Vector3(0.18, 0.18, 0.0), Vector3.UP)                # left hand on the can's side
	cap_hand.visible = false
	ch.visible = false
	cu.visible = false
	var stream := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.012
	sm.bottom_radius = 0.012
	sm.height = 0.3
	sm.radial_segments = 5
	stream.mesh = sm
	stream.material_override = MeshKit.flat(Color(0.9, 0.7, 0.2))
	stream.position = f + Vector3(0, 0.17, 0)
	stream.visible = false
	props.add_child(stream)
	var tw := _chain()
	tw.tween_callback(func(): cap_hand.visible = true)
	tw.tween_property(cap, "rotation:y", 1.6, 0.2)                                                                    # unscrew
	tw.tween_property(cap, "position", f + Vector3(0.18, 0.25, 0), 0.4).set_trans(Tween.TRANS_SINE)                    # the cap comes off and is held aside
	tw.parallel().tween_property(cap, "rotation:z", 1.2, 0.4)
	tw.tween_callback(func():
		game.sfx["hit_pick"].play()
		cap_hand.visible = false
		ch.visible = true
		cu.visible = true)                                                                                             # the cap rests aside; both hands take the can
	tw.tween_property(can, "position", f + Vector3(0.16, 0.46, 0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)   # brought over the filler
	tw.tween_property(can, "rotation:z", -1.15, 0.4).set_trans(Tween.TRANS_SINE)                                     # and tipped
	tw.tween_callback(func(): stream.visible = true)
	for k in range(2):                                                                                               # pouring: glug, glug...
		tw.tween_callback(func(): game.sfx["ui_pop"].play())
		tw.tween_property(stream, "scale:x", 1.5, 0.2)
		tw.tween_property(stream, "scale:x", 0.8, 0.2)
	tw.tween_callback(func(): stream.visible = false)
	tw.tween_property(can, "rotation:z", 0.0, 0.35)                                                                    # upright again
	tw.tween_property(can, "position", f + Vector3(0.5, 0.9, 0.3), 0.4)                                               # and taken away
	tw.tween_callback(func():
		can.visible = false
		cap_hand.visible = true)
	tw.tween_property(cap, "position", f + Vector3(0, 0.03, 0), 0.3).set_trans(Tween.TRANS_SINE)                      # the cap goes back on...
	tw.parallel().tween_property(cap, "rotation:z", 0.0, 0.3)
	tw.tween_property(cap, "rotation:y", 0.0, 0.2)                                                                    # ...and is screwed tight
	tw.tween_callback(func(): game.sfx["hit_reinforced"].play())
	tw.tween_callback(_commit)                                                                                       # fitted only now that the cap is on
	tw.tween_interval(0.25)
	tw.tween_callback(func(): _end(true))

# ------------------------------------------------------------------ finish

func _end(done: bool) -> void:
	if finished:
		return
	finished = true
	if props and is_instance_valid(props):
		props.queue_free()
	var p = game.prog
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
			game.player.tool_view.visible = true
		game.player.locked = false
		game.repair_busy = false
		game.repair_seq = null
		if done and p.repairs_complete():
			game._excavator_start_scene(v))
