extends Node3D
## Isolated viewer for the Blender dump truck. Run: godot --path . res://assets/vehicles/test/TruckTest.tscn
## Mouse drag = orbit, wheel = zoom, 1-7 = clips, E = engine start/stop, L = lights, D = tip the bed (toggle), arrows = drive / steer
## (Up/Down speed, Left/Right steer), R = reset, P = paint (yellow / red-orange). Nothing here touches the game.

const CLIP_KEYS := {KEY_1: "Idle", KEY_2: "EngineStart", KEY_3: "EngineStop", KEY_4: "DumpUp", KEY_5: "DumpDown", KEY_6: "DumpCycle", KEY_7: "Drive", KEY_8: "Steer"}

var rig: TruckRig
var cam: Camera3D
var yaw := 0.9
var pitch := -0.28
var dist := 12.0
var target := Vector3(0.0, 1.2, 0.0)
var label: Label
var manual := false
var speed := 0.0
var steer := 0.0
var tip := false
var tilt := 0.0
var paint_i := 0

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
	rig = TruckRig.new()
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
	label.text = "Quarry Days dump truck   engine: %s   lights: %s   mode: %s\n1 Idle  2 Start  3 Stop  4 DumpUp  5 DumpDown  6 DumpCycle  7 Drive  8 Steer\nE engine   L lights   D tip bed   arrows drive/steer   P paint   R reset   drag = orbit   wheel = zoom" % [rig.engine_state, "on" if rig.lights_on else "off", "manual" if manual else "clip"]

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= e.relative.x * 0.008
		pitch = clampf(pitch - e.relative.y * 0.006, -1.3, 0.1)
		_orbit()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: dist = maxf(3.0, dist * 0.92)
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = minf(35.0, dist * 1.08)
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
		elif e.keycode == KEY_D:
			manual = true
			rig.stop_clips()
			tip = not tip
		elif e.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			manual = true
			rig.stop_clips()
		elif e.keycode == KEY_P:
			paint_i = (paint_i + 1) % 2
			rig.set_paint("PaintYellow" if paint_i == 0 else "PaintRed", "PaintYellow" if paint_i == 0 else "PaintOrange")
		elif e.keycode == KEY_R:
			manual = false
			tip = false
			tilt = 0.0
			speed = 0.0
			steer = 0.0
			rig.stop_clips()
			rig.set_bed_angle(0.0)
			rig.set_steer(0.0)
			rig.set_suspension(0.0, 0.0, 0.0)
		_hud()

func _process(delta: float) -> void:
	if not manual:
		return
	speed = move_toward(speed, (float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))) * 5.0, delta * 3.0)
	steer = move_toward(steer, float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)), delta * 3.0)
	tilt = move_toward(tilt, TruckKin.BED_MAX if tip else 0.0, delta * 0.8)
	rig.drive(speed, delta)
	rig.set_steer(steer)
	rig.set_bed_angle(tilt)
	rig.set_suspension(0.0, clampf(-speed * 0.002, -0.03, 0.03), clampf(steer * speed * 0.004, -0.04, 0.04))
