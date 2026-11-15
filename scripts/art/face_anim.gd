extends RefCounted
class_name FaceAnim
## Blinking, talking and brow accents by swapping the painted head texture between frames made by tools/character_cast/paint_faces.py
## (assets/characters/faces/<Name>_<frame>.png): base, blink, m1 / m2 (mouth part / wide open), brow, browm1. Same pixel style as the rest of the
## cast, no extra geometry or bones, one texture assignment when the frame changes. The head material is duplicated per character, so the
## shared model resource is never touched.

const DIR := "res://assets/characters/faces/"
const FRAMES := ["blink", "m1", "m2", "brow", "browm1"]

var ok := false
var current := "base"
var _mat: StandardMaterial3D
var _tex := {}
var _rng := RandomNumberGenerator.new()
var _blink_in := 2.5
var _blink_left := 0.0
var _double := false
var _mouth := 0
var _mouth_in := 0.0
var _syllables := 0
var _brow_in := 1.6
var _brow_left := 0.0

## Finds the head mesh under `root` and loads this character's frames. False (and nothing changes) if the character has no frames.
func setup(root: Node, who: String, seed_value := 0) -> bool:
	_rng.seed = 7919 + seed_value * 131 + who.length()
	_blink_in = _rng.randf_range(1.5, 4.0)
	var head: MeshInstance3D = null
	for n in root.find_children("*_Head", "MeshInstance3D", true, false):
		head = n as MeshInstance3D
		break
	if head == null or head.mesh == null or head.mesh.get_surface_count() == 0:
		return false
	var src := head.get_active_material(0) as StandardMaterial3D
	if src == null:
		return false
	for f in FRAMES:
		var path: String = DIR + who + "_" + f + ".png"
		if not ResourceLoader.exists(path):
			return false
		_tex[f] = load(path)
	_tex["base"] = src.albedo_texture
	_mat = src.duplicate() as StandardMaterial3D
	head.set_surface_override_material(0, _mat)
	ok = true
	return true

## Call every frame. `talking` drives the mouth and the brow accents; the blink runs always. `smile_brow` raises the brows for the whole
## time it is true (a greeting, a wave).
func update(delta: float, talking: bool, smile_brow := false) -> void:
	if not ok:
		return
	# blink: every 2-5 s, 0.13 s closed; one blink in six is a double
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0 and _double:
			_double = false
			_blink_left = 0.11                      # the second blink follows straight away
	else:
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_left = 0.13
			_double = _rng.randf() < 0.17
			_blink_in = _rng.randf_range(2.2, 5.2)
	# speech: a new mouth shape every 70-170 ms, a breath (closed mouth) every handful of syllables
	if talking:
		_mouth_in -= delta
		if _mouth_in <= 0.0:
			_syllables += 1
			if _syllables % _rng.randi_range(6, 11) == 0:
				_mouth = 0
				_mouth_in = _rng.randf_range(0.22, 0.4)
			else:
				var r := _rng.randf()
				_mouth = 1 if r < 0.5 else (2 if r < 0.82 else 0)
				_mouth_in = _rng.randf_range(0.07, 0.17)
		_brow_in -= delta
		if _brow_in <= 0.0 and _brow_left <= 0.0:
			_brow_left = _rng.randf_range(0.35, 0.6)
			_brow_in = _rng.randf_range(1.2, 2.8)
	else:
		_mouth = 0
		_mouth_in = 0.0
	_brow_left = maxf(0.0, _brow_left - delta)
	_apply_frame(_pick(talking, smile_brow))

func _pick(talking: bool, smile_brow: bool) -> String:
	if _blink_left > 0.0:
		return "blink"
	var brow := smile_brow or (talking and _brow_left > 0.0)
	if brow:
		return "browm1" if _mouth > 0 else "brow"
	return "base" if _mouth == 0 else ("m1" if _mouth == 1 else "m2")

func _apply_frame(frame: String) -> void:
	if frame == current:
		return
	current = frame
	_mat.albedo_texture = _tex[frame]
