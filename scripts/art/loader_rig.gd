extends Node3D
class_name LoaderRig
## Runtime wrapper for the Blender wheel loader (assets/vehicles/VEH_QD_Loader.glb), sibling of ExcavatorRig / TruckRig / DozerRig.
## Gives QuarryVehicle: four rolling wheels, centre articulation (the front frame, wheels and arms swing about the hinge), lift arms and
## bucket tilt with three cylinders that stay pinned for any angles, engine states, lights, dust at the bucket lip and the collision hull.
## Axis convention: Godot rotation.x equals the Blender rotation about X (positive raises the arms / dumps the bucket).

const GLB := "res://assets/vehicles/VEH_QD_Loader.glb"
const MATERIAL_DIRS := ["res://assets/vehicles/materials/", "res://assets/materials/"]
const MATERIAL_OVERRIDES := ["ExcDark", "SteelPlate", "Hazard", "MetalBrushed", "Tire", "Glass"]
const PAINT_MAP := {"PaintYellow": "ExcPaint", "PaintRed": "WornRed", "PaintOrange": "WornOrange"}
const LOOP_CLIPS := ["Idle", "Drive"]
const ENGINE_CLIPS := ["Idle", "EngineStart", "EngineStop"]
const CLIP_FPS := 30.0

signal engine_state_changed(state: StringName)

var model: Node3D
var player: AnimationPlayer
var front: Node3D
var lift: Node3D
var bucket: Node3D
var engine_state: StringName = &"off"
var lights_on := false
var arm_angle := 0.0
var bucket_angle := 0.0

var _wheels: Array = []
var _lift_cyl := {}
var _tilt_barrel: Node3D
var _tilt_rod: Node3D
var _steering_wheel: Node3D
var _lens: Array = []
var _spots: Array = []
var _smoke: CPUParticles3D
var _dust: CPUParticles3D
var _mats := {}

func _ready() -> void:
	build()

func build() -> void:
	if model != null:
		return
	var scene: PackedScene = load(GLB)
	if scene == null:
		push_error("LoaderRig: cannot load %s" % GLB)
		return
	model = scene.instantiate()
	model.name = "Model"
	add_child(model)
	for hull in model.find_children("ColHull_*", "MeshInstance3D", true, false):
		(hull as MeshInstance3D).visible = false
	front = model.find_child("Front", true, false)
	lift = model.find_child("Lift", true, false)
	bucket = model.find_child("Bucket", true, false)
	_steering_wheel = model.find_child("SteeringWheel", true, false)
	for tag in ["L", "R"]:
		_lift_cyl[tag] = [model.find_child("LiftCyl_%s_Barrel" % tag, true, false), model.find_child("LiftCyl_%s_Rod" % tag, true, false)]
	_tilt_barrel = model.find_child("TiltCyl_Barrel", true, false)
	_tilt_rod = model.find_child("TiltCyl_Rod", true, false)
	for node in model.find_children("Wheel_*", "Node3D", true, false):
		_wheels.append(node)
	_swap_materials()
	_setup_lights()
	_setup_particles()
	player = model.find_child("AnimationPlayer", true, false)
	if player != null:
		for clip in player.get_animation_list():
			var a := player.get_animation(clip)
			if clip in ENGINE_CLIPS:
				_keep_only(a, "Shake")
			if clip in LOOP_CLIPS:
				a.loop_mode = Animation.LOOP_LINEAR
				a.length = maxf(0.05, a.length - 1.0 / CLIP_FPS)
			else:
				a.loop_mode = Animation.LOOP_NONE
		player.animation_finished.connect(_on_clip_finished)
	set_arm(0.0, 0.0)

## Godot adds hold-at-rest tracks for every animated node to every imported clip; the engine clips keep only the vibration node.
static func _keep_only(a: Animation, node_name: String) -> void:
	for t in range(a.get_track_count() - 1, -1, -1):
		if not str(a.track_get_path(t).get_concatenated_names()).ends_with(node_name):
			a.remove_track(t)

func _project_material(mat_name: String) -> Material:
	if _mats.has(mat_name):
		return _mats[mat_name]
	var found: Material = null
	for dir in MATERIAL_DIRS:
		var path: String = dir + "M_QD_" + mat_name + ".tres"
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_mats[mat_name] = found
	return found

func set_paint(paint: String) -> void:
	var base := _project_material(PAINT_MAP.get(paint, paint))
	if base == null:
		base = _project_material("ExcPaint")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var imp := mi.mesh.surface_get_material(s)
			if imp != null and imp.resource_name == "CabPaint":
				mi.set_surface_override_material(s, base)

func _swap_materials() -> void:
	set_paint("PaintYellow")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name == "CabGlass":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var imported := mi.mesh.surface_get_material(s)
			if imported != null and imported.resource_name in MATERIAL_OVERRIDES:
				var base := _project_material(imported.resource_name)
				if base != null:
					mi.set_surface_override_material(s, base)
			elif imported is StandardMaterial3D:
				(imported as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

func _setup_lights() -> void:
	for n in ["Light_Head_L", "Light_Head_R", "Light_Rear"]:
		var marker := model.find_child(n, true, false) as Node3D
		if marker == null:
			continue
		var spot := SpotLight3D.new()
		spot.spot_range = 18.0
		spot.spot_angle = 38.0
		spot.light_energy = 2.2
		spot.light_color = Color(1.0, 0.93, 0.75)
		spot.visible = false
		if n == "Light_Rear":
			spot.light_color = Color(1.0, 0.35, 0.25)
			spot.spot_range = 6.0
			spot.rotate_y(PI)
		marker.add_child(spot)
		_spots.append(spot)
	for node in model.find_children("Lamp_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
				var own := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				own.emission_energy_multiplier = 0.0
				mi.set_surface_override_material(s, own)
				_lens.append([own, (m as StandardMaterial3D).emission_energy_multiplier])

func set_lights(on: bool) -> void:
	lights_on = on
	for s in _spots:
		(s as SpotLight3D).visible = on
	for e in _lens:
		(e[0] as StandardMaterial3D).emission_energy_multiplier = float(e[1]) if on else 0.0

func _puff(parent: Node3D, amount: int, life: float, grav: Vector3, color: Color, spread: float, v0: float, v1: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.emitting = false
	p.explosiveness = 1.0 if one_shot else 0.0
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	p.mesh = sm
	var ramp := Curve.new()
	ramp.add_point(Vector2(0, 0.6))
	ramp.add_point(Vector2(1, 1.6 if not one_shot else 0.2))
	p.scale_amount_curve = ramp
	parent.add_child(p)
	return p

func _setup_particles() -> void:
	var tip := model.find_child("Marker_ExhaustTip", true, false) as Node3D
	if tip != null:
		_smoke = _puff(tip, 8, 1.3, Vector3(0.1, 0.25, 0.0), Color(0.32, 0.32, 0.34, 0.5), 9.0, 0.5, 0.9, false)
		_smoke.scale_amount_min = 0.5
		_smoke.scale_amount_max = 0.9
	var lip := model.find_child("Marker_Lip", true, false) as Node3D
	if lip != null:
		_dust = _puff(lip, 10, 0.8, Vector3(0, -0.6, 0), Color(0.62, 0.55, 0.42, 0.7), 55.0, 0.6, 1.4, true)

## A puff of dust at the bucket lip (scooping into a pile, or the load letting go).
func dust_burst() -> void:
	if _dust != null:
		_dust.restart()
		_dust.emitting = true

func start_engine() -> void:
	if engine_state == &"idle" or engine_state == &"starting":
		return
	_set_engine(&"starting")
	if player != null and player.has_animation("EngineStart"):
		player.play("EngineStart")
	else:
		_set_engine(&"idle")

func stop_engine() -> void:
	if engine_state == &"off" or engine_state == &"stopping":
		return
	_set_engine(&"stopping")
	if player != null and player.has_animation("EngineStop"):
		player.play("EngineStop")
	else:
		_set_engine(&"off")

func _set_engine(s: StringName) -> void:
	engine_state = s
	if _smoke != null:
		_smoke.emitting = s == &"starting" or s == &"idle"
	engine_state_changed.emit(s)

func _on_clip_finished(clip: StringName) -> void:
	if clip == &"EngineStart" and engine_state == &"starting":
		_set_engine(&"idle")
		player.play("Idle")
	elif clip == &"EngineStop" and engine_state == &"stopping":
		_set_engine(&"off")

func play_clip(clip: StringName) -> void:
	if player != null and player.has_animation(clip):
		player.play(clip)

func stop_clips() -> void:
	if player != null:
		player.stop()

func clip_names() -> PackedStringArray:
	return player.get_animation_list() if player != null else PackedStringArray()

## Roll all four wheels for a travel speed (m/s, + forward).
func wheel_nodes() -> Array:
	return _wheels.duplicate()

func drive(speed: float, delta: float) -> void:
	for w in _wheels:
		(w as Node3D).rotate_x(-speed * delta / LoaderKin.WHEEL_R)

## Articulation: steering input -1..1 (+ right) swings the front frame about the centre hinge; the steering wheel follows.
func set_steer(input: float) -> void:
	var ang := -clampf(input, -1.0, 1.0) * LoaderKin.ARTIC_MAX
	front.rotation.y = ang
	if _steering_wheel != null:
		_steering_wheel.rotation.y = -ang * 3.0

func _aim(barrel: Node3D, rod: Node3D, v: Vector2) -> void:
	barrel.rotation = Vector3(v.x, 0.0, 0.0)
	rod.position = Vector3(0.0, 0.0, -v.y)

## alpha: arm angle (0 = lowered .. LoaderKin.LIFT_MAX), beta: bucket angle relative to the arm (TILT_MIN curled .. TILT_MAX dumped).
func set_arm(alpha: float, beta: float) -> void:
	if lift == null:
		return
	arm_angle = clampf(alpha, 0.0, LoaderKin.LIFT_MAX)
	bucket_angle = clampf(beta, LoaderKin.TILT_MIN, LoaderKin.TILT_MAX)
	lift.rotation.x = arm_angle
	bucket.rotation.x = bucket_angle
	var l := LoaderKin.lift(arm_angle)
	for tag in ["L", "R"]:
		var pair: Array = _lift_cyl[tag]
		_aim(pair[0], pair[1], l)
	_aim(_tilt_barrel, _tilt_rod, LoaderKin.tilt(bucket_angle))

func collision_hulls() -> Array:
	var out: Array = []
	for node in model.find_children("ColHull_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		out.append([model.global_transform.affine_inverse() * mi.global_transform, mi.mesh.create_convex_shape(true, true)])
		mi.visible = false
	return out
