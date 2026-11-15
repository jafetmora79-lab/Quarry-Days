extends Node3D
## BUILDING VIEWER: the Blender-built yard buildings on a flat ground, lit like the game, nothing else.
##   godot --path . res://BuildingViewer.tscn
## Keys: 1 front, 2 corner, 3 inside (looking at the back wall), 4 roof | W A S D move, Q / E down / up, Shift fast, hold the right mouse button to look | Esc quits.

const BUILDINGS := ["Office"]
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var looking := false

func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.8
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.52, 0.46, 0.36)
	ground.material_override = gm
	add_child(ground)
	var x := 0.0
	for b in BUILDINGS:
		var n := BuildingModels.load_model(b)
		if n == null:
			continue
		n.position = Vector3(x, 0, 0)
		add_child(n)
		x += 9.0
	var inside := OmniLight3D.new()
	inside.position = Vector3(0, 2.3, 0.3)
	inside.light_color = Color(1.0, 0.86, 0.62)
	inside.omni_range = 6.0
	add_child(inside)
	cam = Camera3D.new()
	cam.far = 200.0
	add_child(cam)
	_stop(1)

func _stop(i: int) -> void:
	match i:
		1: cam.position = Vector3(0, 1.7, -9.0); cam.look_at(Vector3(0, 1.8, 0))
		2: cam.position = Vector3(-7.0, 3.2, -7.5); cam.look_at(Vector3(0, 1.6, 0))
		3: cam.position = Vector3(0, 1.6, -1.6); cam.look_at(Vector3(0, 1.3, 2.3))
		4: cam.position = Vector3(0, 9.0, -7.0); cam.look_at(Vector3(0, 2.5, 0))
	yaw = cam.rotation.y
	pitch = cam.rotation.x

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		looking = e.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseMotion and looking:
		yaw -= e.relative.x * 0.003
		pitch = clampf(pitch - e.relative.y * 0.003, -1.5, 1.5)
		cam.rotation = Vector3(pitch, yaw, 0)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1: _stop(1)
			KEY_2: _stop(2)
			KEY_3: _stop(3)
			KEY_4: _stop(4)
			KEY_ESCAPE: get_tree().quit()

func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): v.z -= 1
	if Input.is_key_pressed(KEY_S): v.z += 1
	if Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_E): v.y += 1
	if Input.is_key_pressed(KEY_Q): v.y -= 1
	if v != Vector3.ZERO:
		cam.position += cam.global_transform.basis * v.normalized() * (10.0 if Input.is_key_pressed(KEY_SHIFT) else 3.0) * delta
