extends Node3D
class_name QuarryDoor
## A hinged wooden house door you open and close with E (it also opens when you or a worker walk up to it). The panel swings into the house; a worker walking up to it
## opens it as well, so nobody is ever locked out or in. The collider sits on the panel, so it blocks only while shut.

const W := 1.38
const H := 2.35
const THICK := 0.07

var game
var hinge_side := -1.0      ## -1: hinge on the left of the doorway (panel extends +x), +1: on the right
var open_amount := 0.0
var want_open := false
var body: StaticBody3D
var shape: CollisionShape3D
var swing := 1.75
var _audio: AudioStreamPlayer3D
var _was_target := 0.0
static var _creak: AudioStreamWAV
static var _thunk: AudioStreamWAV

## Two tiny synthesized sounds (no audio files): a soft hinge creak when the door starts to move, and a low thunk when it meets the frame.
static func _make(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * (0.28 if kind == "creak" else 0.14))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(rate)
		var v := 0.0
		if kind == "creak":
			var env := sin(PI * float(i) / float(n))
			lp = lp * 0.86 + rng.randf_range(-1.0, 1.0) * 0.14
			v = (lp * 0.55 + sin(TAU * (210.0 + 90.0 * t) * t) * 0.18) * env * 0.5
		else:
			var env2 := exp(-t * 34.0)
			lp = lp * 0.9 + rng.randf_range(-1.0, 1.0) * 0.1
			v = (sin(TAU * 78.0 * t) * 0.7 + lp * 0.5) * env2 * 0.9
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _play(kind: String) -> void:
	if _audio == null or not is_inside_tree():
		return
	if _creak == null:
		_creak = _make("creak")
		_thunk = _make("thunk")
	_audio.stream = _creak if kind == "creak" else _thunk
	_audio.play()

## centre: middle of the doorway on the floor; the wall plane is centre.z
func build(main_node, centre: Vector3, hinge: float, label: String) -> void:
	game = main_node
	hinge_side = hinge
	name = label
	position = centre + Vector3(hinge * W * 0.5, 0.16, 0.0)   # hinge post; the sill is the 16 cm foundation
	game.world.add_child(self)
	var wood: Material = load(QuarryArt.M_WOOD)
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, H, THICK)
	panel.mesh = bm
	panel.position = Vector3(-hinge * W * 0.5, H * 0.5, 0.0)
	panel.material_override = wood
	add_child(panel)
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(W * 0.55, 0.7, THICK + 0.02)
	glass.mesh = gm
	glass.position = Vector3(-hinge * W * 0.5, H * 0.68, 0.0)
	glass.material_override = MeshKit.flat(Color(0.55, 0.72, 0.80), 0.25)
	add_child(glass)
	var trim := MeshKit.Soup.new()                               # three hinge knuckles on the hinge edge, and two raised panels: one mesh each
	for hy in [0.35, 1.2, 2.0]:
		MeshKit.box_into(trim, Vector3(-hinge * 0.03, hy, 0.0), Vector3(0.05, 0.14, THICK + 0.05))
	var inset := MeshKit.Soup.new()
	for py in [0.55, 1.55]:
		MeshKit.box_into(inset, Vector3(-hinge * W * 0.5, py, 0.0), Vector3(W * 0.62, 0.5 if py < 1.0 else 0.4, THICK + 0.02))
	for pair in [[trim, Color(0.2, 0.2, 0.22)], [inset, Color(0.5, 0.35, 0.22)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (pair[0] as MeshKit.Soup).mesh()
		mi.material_override = MeshKit.flat(pair[1])
		add_child(mi)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.12, 0.05, 0.16)
	handle.mesh = hm
	handle.position = Vector3(-hinge * (W - 0.14), 1.0, 0.0)
	handle.material_override = MeshKit.flat(Color(0.75, 0.72, 0.6))
	add_child(handle)
	body = StaticBody3D.new()
	body.name = label + " panel"
	body.position = Vector3(-hinge * W * 0.5, H * 0.5, 0.0)
	body.set_meta("kind", "door")
	body.set_meta("door", label)
	body.set_meta("nav_skip", true)
	body.set_meta("art", true)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	_audio.max_distance = 22.0
	_audio.volume_db = -16.0
	_audio.position = Vector3(-hinge * W * 0.5, 1.0, 0.0)
	add_child(_audio)
	shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(W, H, THICK + 0.04)
	shape.shape = bs
	body.add_child(shape)
	add_child(body)

func toggle() -> void:
	want_open = not want_open

func is_open() -> bool:
	return open_amount > 0.5

func _workers_near() -> bool:
	var c := global_position + Vector3(-hinge_side * W * 0.5, 0.0, 0.0)
	if not game.driving and game.player and Vector2(game.player.global_position.x, game.player.global_position.z).distance_to(Vector2(c.x, c.z)) < 1.5:
		return true   # walking up to a door opens it; E still opens and closes it by hand
	for w in game.worker_nodes.values():
		if w.visible and Vector2(w.global_position.x, w.global_position.z).distance_to(Vector2(c.x, c.z)) < 1.9:
			return true
	return false

func _physics_process(delta: float) -> void:
	var target := 1.0 if (want_open or _workers_near()) else 0.0
	var before := open_amount
	open_amount = move_toward(open_amount, target, delta * 2.0)            # about 0.5 s from shut to open
	if target != _was_target:
		_was_target = target
		if open_amount > 0.0 or before > 0.0:
			_play("creak")
	if before > 0.0 and open_amount <= 0.0:
		_play("thunk")                                                      # the leaf meets the frame
	# swing toward +z (into the house): y-rotation sign depends on which side the hinge is
	rotation.y = hinge_side * swing * smoothstep(0.0, 1.0, open_amount)
