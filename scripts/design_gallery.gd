extends Node3D
## DESIGN GALLERY: every Blender-built tool, the gloved hands and the five Blender machines in one flat scene, built with the same loaders the game uses.
##   godot --path . res://DesignGallery.tscn          (or open DesignGallery.tscn in the editor and press F6)
## Keys: 1 tools, 2 gloves, 3 machines, 4 overview | W A S D move, Q / E down / up, Shift fast, hold the right mouse button to look | Space plays the next
## animation of every machine (dig, dump, lift, drive...) | Esc quits.

const TOOL_KEYS := ["rock_hammer", "pickaxe_worn", "pickaxe_reinforced", "drill", "jackhammer", "pointed_chisel", "flat_chisel", "repaired_pickaxe",
	"sledgehammer", "steel_pickaxe", "hardened_pickaxe", "hand_splitter", "powered_hammer", "pneumatic_chisel", "shovel", "ramp_plan"]
const NICE := {"rock_hammer": "1 Rock hammer", "pickaxe_worn": "2 Worn pickaxe", "pickaxe_reinforced": "3 Reinforced pickaxe", "drill": "4 Corded drill", "jackhammer": "5 Jackhammer"}

var cam: Camera3D
var rigs: Array = []
var clip_index := 0
var yaw := 0.0
var pitch := 0.0
var looking := false

func _ready() -> void:
	_environment()
	_tools()
	_hands()
	_machines()
	cam = Camera3D.new()
	cam.far = 200.0
	add_child(cam)
	_stop(Vector3(0, 1.5, 3.4), Vector3(0, 0.95, 0))
	_label("DESIGN GALLERY   1 tools   2 gloves   3 machines   4 overview   Space = play machine animations", Vector3(0, 2.6, -1.0), 0.006)

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.position = Vector3(2, 0, -8)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.45, 0.35)
	ground.material_override = gm
	add_child(ground)

func _label(text: String, at: Vector3, px := 0.004) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 8
	l.position = at
	add_child(l)

func _tools() -> void:
	var i := 0
	for key in TOOL_KEYS:
		var n := ToolModels.load_tool(key)
		var x := -4.5 + i * 0.6
		if n == null:
			_label("MISSING: " + key, Vector3(x, 0.9, 0))
		else:
			n.position = Vector3(x, 0.55 if key in ["jackhammer", "pneumatic_chisel"] else 0.35, 0)
			add_child(n)
			_label(key.replace("_", " "), Vector3(x, 1.55, 0))
		i += 1

func _hands() -> void:
	for right in [true, false]:
		var h := ToolModels.load_hand(right)
		if h == null:
			continue
		h.position = Vector3(-0.5 if right else 0.5, 1.0, -3.0)
		add_child(h)
		var shaft := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.021
		cm.bottom_radius = 0.021
		cm.height = 0.5
		shaft.mesh = cm
		shaft.material_override = MeshKit.mat(QuarryArt.M_WOOD)
		shaft.position = h.position
		add_child(shaft)
		_label("right glove" if right else "left glove", h.position + Vector3(0, 0.45, 0))

func _machines() -> void:
	var spots := [["excavator", ExcavatorRig, Vector3(-12, 0, -14)], ["dump truck", TruckRig, Vector3(-5, 0, -14)],
		["wheel loader", LoaderRig, Vector3(2, 0, -14)], ["bulldozer", DozerRig, Vector3(9, 0, -14)]]
	for s in spots:
		var r = s[1].new()
		r.position = s[2]
		add_child(r)
		r.build()
		rigs.append(r)
		_label(s[0], s[2] + Vector3(0, 4.2, 0), 0.008)
	var wb: PackedScene = load("res://assets/vehicles/VEH_QD_Wheelbarrow.glb")
	if wb:
		var w := wb.instantiate() as Node3D
		w.position = Vector3(15, 0, -14)
		add_child(w)
		_label("wheelbarrow", Vector3(15, 1.8, -14), 0.006)

func _stop(pos: Vector3, look: Vector3) -> void:
	cam.position = pos
	cam.look_at(look)
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
			KEY_1: _stop(Vector3(0, 1.5, 3.4), Vector3(0, 0.95, 0))
			KEY_2: _stop(Vector3(0, 1.3, -1.6), Vector3(0, 1.0, -3.0))
			KEY_3: _stop(Vector3(2, 4.5, -2.0), Vector3(2, 1.5, -14))
			KEY_4: _stop(Vector3(2, 9.0, 14.0), Vector3(2, 0, -8))
			KEY_SPACE: _next_clip()
			KEY_ESCAPE: get_tree().quit()

func _next_clip() -> void:
	clip_index += 1
	for r in rigs:
		var names: PackedStringArray = r.clip_names()
		if names.size() > 0:
			r.play_clip(names[clip_index % names.size()])

func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): v.z -= 1
	if Input.is_key_pressed(KEY_S): v.z += 1
	if Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_E): v.y += 1
	if Input.is_key_pressed(KEY_Q): v.y -= 1
	if v != Vector3.ZERO:
		var sp := (12.0 if Input.is_key_pressed(KEY_SHIFT) else 3.0) * delta
		cam.position += cam.global_transform.basis * v.normalized() * sp
