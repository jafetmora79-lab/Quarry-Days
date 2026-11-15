extends Node3D
## Isolated viewer for the Blender-built excavator. Run: godot --path . res://assets/vehicles/test/ExcavatorTest.tscn
## Mouse drag = orbit, wheel = zoom, 1-9/0 = clips, E = engine start/stop, L = lights, M = manual joints (arrows/Z X/C V),
## T = drive tracks, R = reset pose, P = print stats. Nothing here touches the game.

const CLIP_KEYS := {KEY_1: "Idle", KEY_2: "EngineStart", KEY_3: "EngineStop", KEY_4: "Swing", KEY_5: "BoomUpDown", KEY_6: "StickInOut", KEY_7: "BucketCurlDump", KEY_8: "TrackDrive", KEY_9: "DigCycle", KEY_0: "TruckLoad"}

var rig: ExcavatorRig
var cam: Camera3D
var yaw := 0.7
var pitch := -0.30
var dist := 11.0
var target := Vector3(0.2, 1.4, -0.6)
var manual := false
var driving := false
var joints := {"swing": 0.0, "boom": 0.0, "stick": 0.0, "bucket": 0.0}
var label: Label

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.72, 0.76)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := load("res://assets/materials/M_QD_QuarryFloor.tres") as Material
	if gm != null:
		var dup := gm.duplicate() as StandardMaterial3D
		dup.uv1_scale = Vector3(30, 30, 1)
		ground.material_override = dup
	add_child(ground)
	rig = ExcavatorRig.new()
	add_child(rig)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 200.0
	add_child(cam)
	var layer := CanvasLayer.new()
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	add_child(layer)
	_orbit()
	rig.engine_state_changed.connect(func(_s): _hud())
	_hud()

func _orbit() -> void:
	cam.position = target + Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(target, Vector3.UP)

func _hud() -> void:
	label.text = "Quarry Days excavator   engine: %s   lights: %s   mode: %s\n1 Idle  2 Start  3 Stop  4 Swing  5 Boom  6 Stick  7 Bucket  8 TrackDrive  9 DigCycle  0 TruckLoad\nE engine   L lights   M manual (arrows swing/boom, Z/X stick, C/V bucket)   T drive tracks   R reset   drag = orbit   wheel = zoom" % [rig.engine_state, "on" if rig.lights_on else "off", "manual" if manual else ("clip" if rig.player != null and rig.player.is_playing() else "idle")]

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= e.relative.x * 0.008
		pitch = clampf(pitch - e.relative.y * 0.006, -1.3, 0.1)
		_orbit()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: dist = maxf(3.0, dist * 0.92)
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = minf(30.0, dist * 1.08)
		_orbit()
	elif e is InputEventKey and e.pressed and not e.echo:
		if CLIP_KEYS.has(e.keycode):
			manual = false
			var clip: String = CLIP_KEYS[e.keycode]
			if clip == "EngineStart": rig.start_engine()
			elif clip == "EngineStop": rig.stop_engine()
			else: rig.play_clip(clip)
		elif e.keycode == KEY_E:
			if rig.engine_state == &"off": rig.start_engine()
			else: rig.stop_engine()
		elif e.keycode == KEY_L: rig.set_lights(not rig.lights_on)
		elif e.keycode == KEY_M:
			manual = not manual
			rig.stop_clips()
		elif e.keycode == KEY_T: driving = not driving
		elif e.keycode == KEY_R:
			manual = false
			joints = {"swing": 0.0, "boom": 0.0, "stick": 0.0, "bucket": 0.0}
			rig.stop_clips()
			rig.set_pose(0.0, ExcavatorKin.REST["boom"], ExcavatorKin.REST["stick"], ExcavatorKin.REST["bucket"])
		elif e.keycode == KEY_P: print("clips: ", rig.clip_names(), " engine: ", rig.engine_state)
		_hud()

func _process(delta: float) -> void:
	if manual:
		joints["swing"] = wrapf(joints["swing"] + (float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))) * 1.1 * delta, -PI, PI)
		joints["boom"] = clampf(joints["boom"] + (float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))) * 0.9 * delta, -1.0, 1.0)
		joints["stick"] = clampf(joints["stick"] + (float(Input.is_key_pressed(KEY_X)) - float(Input.is_key_pressed(KEY_Z))) * 0.9 * delta, -1.0, 1.0)
		joints["bucket"] = clampf(joints["bucket"] + (float(Input.is_key_pressed(KEY_C)) - float(Input.is_key_pressed(KEY_V))) * 0.9 * delta, -1.0, 1.0)
		rig.set_pose_normalized(joints["swing"], joints["boom"], joints["stick"], joints["bucket"])
	if driving:
		rig.drive(1.6, delta)
