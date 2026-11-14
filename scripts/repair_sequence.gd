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

# ------------------------------------------------------------------ battery

func _battery() -> void:
	# the pocket in the hood (x 0.34..0.78, z 0.33..0.57, floor at y 1.33): the battery is lifted over it, lowered down INTO it until it rests on the floor with its top a
	# hand's breadth proud of the hood, then the two cables are clipped to the terminals and laid away over the top
	var rest := Vector3(0.56, 1.33, 0.45)
	var bat := OpeningModels.part("battery")
	bat.position = _hand()
	props.add_child(bat)
	var cable_r := _mesh(props, Vector3(0.02, 0.02, 0.22), Color(0.8, 0.12, 0.1), Vector3(0.66, 1.66, 0.62))
	var cable_b := _mesh(props, Vector3(0.02, 0.02, 0.22), Color(0.08, 0.08, 0.09), Vector3(0.46, 1.66, 0.62))
	cable_r.visible = false
	cable_b.visible = false
	var tw := _chain()
	tw.tween_property(bat, "position", rest + Vector3(0, 0.75, 0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)       # lifted over the pocket
	tw.tween_property(bat, "position", rest + Vector3(0, 0.1, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)           # lowered into it
	tw.tween_property(bat, "position", rest, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)                                # and down onto the floor
	tw.tween_callback(func(): game.sfx["hit_reinforced"].play())
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		cable_r.visible = true
		_spark(Vector3(0.66, 1.62, 0.5)))                                                                                           # first terminal
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		cable_b.visible = true
		_spark(Vector3(0.46, 1.62, 0.5)))                                                                                           # second terminal
	tw.tween_interval(0.3)
	tw.tween_callback(_commit)
	tw.tween_interval(0.4)
	tw.tween_callback(func(): _end(true))

# ------------------------------------------------------------------ hydraulic hose

func _hose() -> void:
	var coil := OpeningModels.part("hose")
	coil.position = _hand()
	props.add_child(coil)
	var tube := MeshInstance3D.new()
	tube.material_override = MeshKit.flat(Color(0.2, 0.24, 0.3))
	props.add_child(tube)
	var fit_a := _mesh(props, Vector3(0.06, 0.06, 0.06), Color(0.75, 0.55, 0.2), HOSE_A)
	var fit_b := _mesh(props, Vector3(0.06, 0.06, 0.06), Color(0.75, 0.55, 0.2), HOSE_B)
	fit_a.visible = false
	fit_b.visible = false
	var lay := func(t: float):
		var pts := []
		for k in range(0, 15):
			var u := t * float(k) / 14.0
			var p := HOSE_A.lerp(HOSE_B, u)
			p.y += -0.05 * sin(PI * u) + 0.02 * sin(TAU * u * 2.0)                    # it follows the boom's side with a little sag
			pts.append(p)
		var so := MeshKit.Soup.new()
		MeshKit.tube_into(so, pts, 0.026, 6)
		tube.mesh = so.mesh()
	var tw := _chain()
	tw.tween_property(coil, "position", HOSE_A + Vector3(0.1, 0.1, -0.05), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)   # the coil goes to the boom-foot fitting
	tw.tween_callback(func():
		fit_a.visible = true
		_spark(HOSE_A))                                                                                              # first end screwed on
	tw.tween_interval(0.3)
	tw.tween_callback(func(): coil.visible = false)
	tw.tween_method(lay, 0.02, 1.0, 1.4)                                                                             # the hose is laid out along the boom
	tw.tween_callback(func():
		fit_b.visible = true
		_spark(HOSE_B))                                                                                              # second end secured
	tw.tween_interval(0.35)
	tw.tween_callback(func(): game.sfx["hit_reinforced"].play())                                                     # clamp tightened
	tw.tween_interval(0.25)
	tw.tween_callback(_commit)
	tw.tween_interval(0.3)
	tw.tween_callback(func(): _end(true))

# ------------------------------------------------------------------ fuel

func _fuel() -> void:
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
	var can := OpeningModels.part("fuel")
	can.position = _hand()
	props.add_child(can)
	var stream := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.012
	sm.bottom_radius = 0.012
	sm.height = 0.3
	sm.radial_segments = 5
	stream.mesh = sm
	var amber := MeshKit.flat(Color(0.9, 0.7, 0.2))
	stream.material_override = amber
	stream.position = f + Vector3(0, 0.17, 0)
	stream.visible = false
	props.add_child(stream)
	var tw := _chain()
	tw.tween_property(cap, "position", f + Vector3(0.18, 0.25, 0), 0.5).set_trans(Tween.TRANS_SINE)                    # the cap comes off and is held aside
	tw.parallel().tween_property(cap, "rotation:z", 1.2, 0.5)
	tw.tween_callback(func(): game.sfx["hit_pick"].play())
	tw.tween_property(can, "position", f + Vector3(0.16, 0.46, 0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)   # the can is brought over the filler
	tw.tween_property(can, "rotation:z", -1.15, 0.45).set_trans(Tween.TRANS_SINE)                                     # and tipped
	tw.tween_callback(func(): stream.visible = true)
	for k in range(4):                                                                                               # pouring: glug, glug...
		tw.tween_callback(func(): game.sfx["ui_pop"].play())
		tw.tween_property(stream, "scale:x", 1.5, 0.2)
		tw.tween_property(stream, "scale:x", 0.8, 0.2)
	tw.tween_callback(_commit)
	tw.tween_callback(func(): stream.visible = false)
	tw.tween_property(can, "rotation:z", 0.0, 0.35)
	tw.tween_property(can, "position", f + Vector3(0.5, 0.9, 0.3), 0.4)                                               # the empty can is taken away
	tw.tween_callback(func(): can.visible = false)
	tw.tween_property(cap, "position", f + Vector3(0, 0.03, 0), 0.35).set_trans(Tween.TRANS_SINE)                    # the cap goes back on
	tw.parallel().tween_property(cap, "rotation:z", 0.0, 0.35)
	tw.tween_callback(func(): game.sfx["hit_reinforced"].play())
	tw.tween_interval(0.3)
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
