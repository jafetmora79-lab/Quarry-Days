extends StaticBody3D
class_name QuarryRig
## Stationary mining machines on a formation's drilling pad (data/progression.json "machines"):
##  * Drilling rig: crawler base, slewing turret and a mast that aims at the column being drilled; the drill
##    rod spins and feeds into the rock only while the rig is really extracting.
##  * Industrial rock breaker: two-link hydraulic arm (procedural IK) that reaches the rock face and hammers it.
## Extraction is done by QuarryProgression.tick_rigs (the same column units the player and staff mine);
## this node only shows it. Joints move with limited angular speed and eased spin/strike rates.

var game
var prog: QuarryProgression
var index := 0
var rtype := "drill_rig"
var rkind := "drill"          ## "drill" (mast and rod) or "breaker" (hydraulic hammer arm); several machine types share each
var turret: Node3D
var boom: Node3D
var stick: Node3D
var tool_node: Node3D       # drill rod (spins/feeds) or breaker chisel (strikes)
var bin_fill: MeshInstance3D
var label: Label3D
var audio: AudioStreamPlayer3D
var blow_audio: AudioStreamPlayer3D
var work := 0.0             # eased 0..1 operating level
var yaw := 0.0
var pitch_a := 0.0
var pitch_b := 0.0
var feed := 0.0
var _t := 0.0
var _fx_t := 0.0
var _blow := 0.0
var pad_pos := Vector3.ZERO
var fwd := Vector3.FORWARD
var advance := 0.0          # metres crept forward from the pad toward the receding rock face
var _nav_adv := 0.0
const PIVOT_H := 1.0
const L1 := 1.9
const L2 := 1.75

func setup(main_node, p: QuarryProgression, i: int) -> void:
	game = main_node
	prog = p
	index = i
	var r: Dictionary = prog.rigs[i]
	rtype = str(r["type"])
	rkind = str(prog.machine(rtype).get("kind", "drill" if rtype == "drill_rig" else "breaker"))
	var pad := prog.pad(str(r["formation"]), int(r["pad"]))
	name = "Rig_%d" % int(r["id"])
	pad_pos = pad["pos"]
	position = pad_pos
	rotation.y = float(pad["yaw"])
	fwd = QuarryBusiness.forward(rotation.y)
	advance = clampf(float(r.get("advance", 0.0)), 0.0, 4.5)
	_nav_adv = advance
	position = pad_pos + fwd * advance
	set_meta("kind", "rig")
	set_meta("index", i)
	set_meta("ground_y", position.y)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.7, 2.9)
	cs.shape = box
	cs.position = Vector3(0, 0.85, 0.65)
	add_child(cs)
	_build()
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.font_size = 26
	label.pixel_size = 0.006
	label.outline_size = 7
	label.position = Vector3(0, 2.6, 0.9)
	label.visibility_range_end = 18.0
	add_child(label)
	audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://audio/rig_loop.wav")
	audio.unit_size = 5.0
	audio.max_distance = 40.0
	audio.volume_db = -8.0
	add_child(audio)
	if rkind == "breaker":
		blow_audio = AudioStreamPlayer3D.new()
		blow_audio.stream = load("res://audio/breaker_hit.wav")
		blow_audio.unit_size = 5.0
		blow_audio.max_distance = 40.0
		blow_audio.volume_db = -6.0
		add_child(blow_audio)

func _soups(keys: Array) -> Dictionary:
	var d := {}
	for k in keys:
		d[k] = MeshKit.Soup.new()
	return d

func _emit(parent: Node3D, parts: Dictionary) -> void:
	MeshKit.repair(parts)
	for k in parts:
		if parts[k].verts.size() > 0:
			MeshKit.inst(parent, parts[k].mesh(), MeshKit.mat(k))

func _build() -> void:
	var paint := str(prog.machine(rtype).get("paint", "PaintYellow" if rkind == "drill" else "PaintRed"))
	var p := _soups(["Tire", "SteelPlate", "SteelGreen", paint, "Hazard"])
	for x in [-0.72, 0.72]:
		MeshKit.box_into(p["Tire"], Vector3(x, 0.22, 0.6), Vector3(0.38, 0.44, 2.7), Vector2(1.0, 0.92))     # crawler tracks
		for z in [-0.6, 1.8]:
			MeshKit.drum_into(p["SteelPlate"], Vector3(x, 0.24, z), 0.2, 0.4, 8)                           # sprockets
	MeshKit.box_into(p[paint], Vector3(0, 0.6, 0.6), Vector3(1.62, 0.3, 2.6))                               # deck
	MeshKit.box_into(p["Hazard"], Vector3(0, 0.6, -0.71), Vector3(1.62, 0.18, 0.03))
	MeshKit.box_into(p["SteelGreen"], Vector3(0, 1.15, 1.25), Vector3(1.4, 0.8, 1.0))                       # power pack
	MeshKit.frustum_into(p["SteelPlate"], Vector3(0.45, 1.55, 1.5), 0.07, 0.06, 0.7, 6)                     # exhaust
	MeshKit.box_into(p[paint], Vector3(-0.45, 1.2, 0.25), Vector3(0.66, 0.9, 0.7))                          # operator cab
	MeshKit.box_into(p["SteelGreen"], Vector3(0.5, 1.0, 0.25), Vector3(0.5, 0.5, 0.6))                      # output bin
	MeshKit.box_into(p["SteelPlate"], Vector3(0.5, 0.7, 0.25), Vector3(0.52, 0.1, 0.62))
	_emit(self, p)
	MeshKit.inst(self, MeshKit.box(Vector3(0.5, 0.42, 0.04)), MeshKit.mat(QuarryArt.M_GLASS), Vector3(-0.45, 1.35, -0.11))
	bin_fill = MeshKit.inst(self, MeshKit.rock(Vector3(0.44, 0.3, 0.54), 91, 3, 6), MeshKit.mat("RockLimestone"), Vector3(0.5, 1.02, 0.25))
	bin_fill.visible = false
	turret = Node3D.new()
	turret.position = Vector3(0, 0.75, -0.55)
	add_child(turret)
	var tp := _soups(["SteelPlate", paint])
	MeshKit.frustum_into(tp["SteelPlate"], Vector3.ZERO, 0.42, 0.38, 0.22, 8)
	MeshKit.box_into(tp[paint], Vector3(0, PIVOT_H - 0.75 - 0.05, 0), Vector3(0.5, 0.3, 0.45))
	_emit(turret, tp)
	boom = Node3D.new()
	boom.position = Vector3(0, PIVOT_H - 0.75, 0)
	turret.add_child(boom)
	if rkind == "drill":
		# lattice mast along -Z with a feed beam; the rod rides on it
		var m := _soups(["PaintYellow", "SteelPlate", "Hazard"])
		for x in [-0.12, 0.12]:
			for y in [-0.1, 0.1]:
				MeshKit.box_into(m["PaintYellow"], Vector3(x, y, -0.9), Vector3(0.05, 0.05, 1.8))
		for k in range(5):
			MeshKit.box_into(m["PaintYellow"], Vector3(0, 0, -0.2 - k * 0.38), Vector3(0.3, 0.04, 0.04))     # lattice rungs
		MeshKit.box_into(m["SteelPlate"], Vector3(0, -0.16, -1.75), Vector3(0.22, 0.14, 0.2))               # rod guide
		MeshKit.box_into(m["Hazard"], Vector3(0, 0.13, -0.9), Vector3(0.26, 0.012, 0.5))
		_emit(boom, m)
		tool_node = Node3D.new()
		tool_node.position = Vector3(0, -0.16, -0.9)
		boom.add_child(tool_node)
		var rod := MeshKit.Soup.new()
		MeshKit.frustum_into(rod, Vector3.ZERO, 0.045, 0.045, 1.2, 6, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
		MeshKit.box_into(rod, Vector3(0, 0, -0.6), Vector3(0.11, 0.02, 1.1))                                # flute shows the spin
		MeshKit.frustum_into(rod, Vector3.ZERO, 0.08, 0.02, 0.18, 6, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -1.2)))
		MeshKit.inst(tool_node, rod.mesh(), MeshKit.mat("SteelPlate"))
	else:
		var b := _soups(["PaintRed", "SteelPlate"])
		MeshKit.box_into(b["PaintRed"], Vector3(0, 0, -L1 * 0.5), Vector3(0.28, 0.32, L1), Vector2(0.85, 0.9))
		MeshKit.frustum_into(b["SteelPlate"], Vector3.ZERO, 0.06, 0.06, 1.3, 6, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.24, -0.2)))   # hydraulic ram
		_emit(boom, b)
		stick = Node3D.new()
		stick.position = Vector3(0, 0, -L1)
		boom.add_child(stick)
		var st := _soups(["PaintRed", "SteelPlate"])
		MeshKit.box_into(st["PaintRed"], Vector3(0, 0, -0.6), Vector3(0.22, 0.24, 1.2), Vector2(0.85, 0.85))
		MeshKit.box_into(st["SteelPlate"], Vector3(0, 0, -1.3), Vector3(0.26, 0.26, 0.42))                 # hammer housing
		_emit(stick, st)
		tool_node = Node3D.new()
		tool_node.position = Vector3(0, 0, -1.5)
		stick.add_child(tool_node)
		var ch := MeshKit.Soup.new()
		MeshKit.box_into(ch, Vector3(0, 0, -0.14), Vector3(0.08, 0.08, 0.3), Vector2(0.5, 0.5))
		MeshKit.inst(tool_node, ch.mesh(), MeshKit.mat("SteelPlate"))
	for gi in find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Point on the rock the tool should touch (face of the target column toward the rig).
func target_point() -> Vector3:
	var r: Dictionary = prog.rigs[index]
	var id := str(r["formation"])
	var col := int(r["target"])
	if col < 0:
		return global_transform * Vector3(0, 0.8, -2.4)
	var cp := prog.column_pos(id, col)
	var to_rig := global_position - cp
	to_rig.y = 0.0
	var cell := float(prog.fdef(id)["cell"])
	var face := cp + to_rig.normalized() * (cell * 0.5 + 0.05)
	var top := float(prog.chunks_left(id, col)) * float(prog.fdef(id)["tier_h"])
	face.y = cp.y + clampf(top - 0.5, 0.35, 1.8)
	return face

func _desired_advance(tp: Vector3) -> float:
	if int(prog.rigs[index]["target"]) < 0:
		return advance
	var turret0 := pad_pos + fwd * 0.55
	var want := clampf(Vector2(tp.x - turret0.x, tp.z - turret0.z).length() - 2.0, 0.0, 4.5)
	var r: Dictionary = prog.rigs[index]
	var id := str(r["formation"])
	var half := float(prog.fdef(id)["cell"]) * 0.5 + 0.05
	var side := Vector3(fwd.z, 0, -fwd.x)
	var a := 0.0
	while a < want:
		var front := pad_pos + fwd * (0.95 + a + 0.25)
		var blocked := false
		for i in range(prog.column_count(id)):
			if prog.column_units(id, i) <= 0:
				continue
			var c := prog.column_pos(id, i)
			for s in [-0.85, 0.0, 0.85]:
				var q: Vector3 = front + side * s
				if absf(q.x - c.x) < half and absf(q.z - c.z) < half:
					blocked = true
		if blocked:
			break
		a += 0.25
	return minf(a, want)

func _process(delta: float) -> void:
	if index >= prog.rigs.size():
		return
	_t += delta
	var r: Dictionary = prog.rigs[index]
	var working := bool(r["working"])
	work = move_toward(work, 1.0 if working else 0.0, delta * (0.9 if working else 0.6))
	var e := work * work * (3.0 - 2.0 * work)
	# crawl: keep a ~2 m standoff from the receding face, never driving into remaining rock
	var tp := target_point()
	var want_adv := _desired_advance(tp)
	advance = move_toward(advance, want_adv, delta * 0.3)
	position = pad_pos + fwd * advance
	r["advance"] = advance
	if absf(advance - _nav_adv) > 0.4 and absf(advance - want_adv) < 0.01:
		_nav_adv = advance
		game.nav_dirty = true
	# aim: slew the turret and set the boom joints toward the rock (rate-limited, never snaps)
	var local := turret.global_transform.affine_inverse() * tp
	var want_yaw := atan2(-local.x, -local.z)
	yaw = move_toward(yaw, clampf(want_yaw, -1.1, 1.1), delta * 0.8)
	turret.rotation.y = yaw
	var horiz := Vector2(local.x, local.z).length()
	var up := local.y - (PIVOT_H - 0.75)
	if rkind == "drill":
		var want_p := atan2(up, horiz)
		pitch_a = move_toward(pitch_a, clampf(want_p, -0.9, 0.5), delta * 0.6)
		boom.rotation.x = pitch_a
		var reach := Vector2(horiz, up).length()
		feed = move_toward(feed, clampf(reach - 2.1, 0.0, 0.7) * e, delta * 0.5)
		tool_node.position.z = -0.9 - feed
		tool_node.rotate_z(delta * 30.0 * e)
		boom.position.x = sin(_t * 47.0) * 0.006 * e # vibration
	else:
		# two-link IK in the boom plane (law of cosines), elbow up
		var d := clampf(Vector2(horiz, up).length(), 0.6, L1 + L2 - 0.05)
		var a2 := acos(clampf((L1 * L1 + L2 * L2 - d * d) / (2.0 * L1 * L2), -1.0, 1.0))
		var a1 := atan2(up, horiz) + acos(clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0))
		pitch_a = move_toward(pitch_a, a1, delta * 0.7)
		pitch_b = move_toward(pitch_b, -(PI - a2), delta * 0.7)
		boom.rotation.x = pitch_a
		stick.rotation.x = pitch_b
		if working:
			_blow += delta * 4.0
			if _blow >= 1.0:
				_blow -= 1.0
				if blow_audio and game.player and game.player.global_position.distance_to(global_position) < 35.0:
					blow_audio.pitch_scale = randf_range(0.92, 1.08)
					blow_audio.play()
		var strike := pow(maxf(0.0, sin(_blow * TAU)), 6.0) * e
		tool_node.position.z = -1.5 - 0.18 * strike
		stick.position.y = 0.02 * strike
	# contact effects only while really extracting
	_fx_t -= delta
	if working and _fx_t <= 0.0 and game.fx:
		_fx_t = 0.35 if rkind == "drill" else 0.25
		var res := str(prog.fdef(str(r["formation"]))["resource"])
		game.fx.impact(tp, res, 0.9)
	if working and not audio.playing:
		audio.play()
	audio.volume_db = lerpf(-30.0, -8.0, e)
	if work <= 0.01 and audio.playing:
		audio.stop()
	var n := prog.rig_bin_total(r)
	bin_fill.visible = n > 0
	if n > 0:
		bin_fill.scale = Vector3(1, clampf(float(n) / float(prog.rig_bin_cap(r)), 0.2, 1.0), 1)
		bin_fill.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(prog.rig_resource(r), "RockLimestone"))
	var m := prog.machine(rtype)
	label.text = "%s  Lv %d\n%s\n%.0f %s / h   bin %d/%d" % [str(m["title"]).to_upper(), int(r["level"]) + 1, str(r["status"]), prog.rig_rate_per_hour(r), prog.display(str(prog.fdef(str(r["formation"]))["resource"])).to_upper(), n, prog.rig_bin_cap(r)]
	label.modulate = Color(0.75, 0.95, 0.6) if working else Color(1.0, 0.75, 0.5)
