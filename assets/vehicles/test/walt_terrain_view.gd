extends Node3D
## Viewer for the Walt + terrain polish sprint. Run: godot --path . res://assets/vehicles/test/WaltTerrainView.tscn
## Left: Grandpa Walt (T = idle / talk, 1 = Walt close-up, 2 = overview). Row of 7 ground patches: topsoil floor, excavated dirt, gravel,
## limestone, cut limestone, coal, iron (each patch is a floor tile with a small block beside it). Drag = orbit, wheel = zoom.

var cam: Camera3D
var yaw := 0.3
var pitch := -0.35
var dist := 7.0
var target := Vector3(0, 1.0, 0)
var rig: VeilRig
var state := "idle"
var label: Label

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.72, 0.7)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var walt: Node3D = (load("res://assets/characters/CHR_QD_Walter.glb") as PackedScene).instantiate()
	walt.position = Vector3(-4.0, 0, 0)
	walt.rotation.y = 0.5
	add_child(walt)
	var sk := walt.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty():
		rig = VeilRig.new()
		rig.setup(sk[0], 3.3)
	var names := ["QuarryFloor", "ExcavatedDirt", "RockGravel", "RockLimestone", "CutLimestone", "RockCoal", "RockIron"]
	for i in names.size():
		var m := load("res://assets/materials/M_QD_%s.tres" % names[i]) as Material
		var x := -1.0 + i * 2.2
		var floor_mesh := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(2.0, 2.0)
		floor_mesh.mesh = pm
		floor_mesh.material_override = m
		floor_mesh.position = Vector3(x, 0.0, 1.0)
		add_child(floor_mesh)
		var block := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.6, 1.4, 1.0)
		block.mesh = bm
		block.material_override = m
		block.position = Vector3(x, 0.7, -0.8)
		add_child(block)
		var l := Label3D.new()
		l.text = names[i].replace("Rock", "")
		l.font_size = 40
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(x, 1.8, -0.8)
		add_child(l)
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
	_hud()

func _hud() -> void:
	label.text = "Walt + terrain viewer   Walt: %s\nT idle / talk   1 Walt close-up   2 overview   drag = orbit   wheel = zoom" % state

func _orbit() -> void:
	cam.position = target + Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(target, Vector3.UP)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= e.relative.x * 0.008
		pitch = clampf(pitch - e.relative.y * 0.006, -1.3, 0.2)
		_orbit()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: dist = maxf(1.2, dist * 0.92)
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = minf(30.0, dist * 1.08)
		_orbit()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_T:
			state = "talk" if state == "idle" else "idle"
		elif e.keycode == KEY_1:
			target = Vector3(-4.0, 1.45, 0)
			dist = 1.9
			yaw = 0.5
			pitch = -0.08
			_orbit()
		elif e.keycode == KEY_2:
			target = Vector3(0, 1.0, 0)
			dist = 7.0
			yaw = 0.3
			pitch = -0.35
			_orbit()
		_hud()

func _process(delta: float) -> void:
	if rig != null:
		rig.pose(delta, state, 0.0, "miner", false)
