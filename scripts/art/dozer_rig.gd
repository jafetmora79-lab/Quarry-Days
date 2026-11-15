extends Node3D
class_name DozerRig
## Runtime wrapper for the Blender bulldozer (assets/vehicles/VEH_QD_Bulldozer.glb), the third sibling of ExcavatorRig / TruckRig.
## Gives QuarryVehicle: independently driven left / right tracks (belts scroll, sprockets / idlers / rollers spin), the C-frame lift and
## blade tilt with three hydraulic cylinders that stay pinned for any angles, the pile of pushed material in front of the blade, dust at
## the cutting edge, engine states, lights and the collision hulls. Axis convention: Godot rotation.x equals the Blender rotation about X
## (positive raises the blade); a positive tilt is Blender rotation about +Y = Godot rotation.z of -tilt.

const GLB := "res://assets/vehicles/VEH_QD_Bulldozer.glb"
const MATERIAL_DIRS := ["res://assets/vehicles/materials/", "res://assets/materials/"]
const MATERIAL_OVERRIDES := ["ExcDark", "ExcTrack", "SteelPlate", "Hazard", "MetalBrushed", "Tire", "Glass"]
const PAINT_MAP := {"PaintYellow": "ExcPaint", "PaintRed": "WornRed", "PaintOrange": "WornOrange"}
const LOOP_CLIPS := ["Idle", "Drive", "Turn"]
const ENGINE_CLIPS := ["Idle", "EngineStart", "EngineStop"]
const CLIP_FPS := 30.0
const BELT_PITCH := 0.2

signal engine_state_changed(state: StringName)

var model: Node3D
var player: AnimationPlayer
var lift: Node3D
var blade: Node3D
var shake: Node3D
var lever_l: Node3D
var lever_r: Node3D
var engine_state: StringName = &"off"
var lights_on := false
var blade_alpha := 0.0
var blade_tilt := 0.0

var _wheels_l: Array = []
var _wheels_r: Array = []
var _belts := {}
var _lift_cyl := {}
var _tilt_barrel: Node3D
var _tilt_rod: Node3D
var _lens: Array = []
var _spots: Array = []
var _smoke: CPUParticles3D
var _dust: CPUParticles3D
var _pile: MeshInstance3D
var _mats := {}

func _ready() -> void:
	build()

func build() -> void:
	if model != null:
		return
	var scene: PackedScene = load(GLB)
	if scene == null:
		push_error("DozerRig: cannot load %s" % GLB)
		return
	model = scene.instantiate()
	model.name = "Model"
	add_child(model)
	for hull in model.find_children("ColHull_*", "MeshInstance3D", true, false):
		(hull as MeshInstance3D).visible = false
	lift = model.find_child("Lift", true, false)
	blade = model.find_child("Blade", true, false)
	shake = model.find_child("Shake", true, false)
	lever_l = model.find_child("Lever_L", true, false)
	lever_r = model.find_child("Lever_R", true, false)
	for tag in ["L", "R"]:
		_lift_cyl[tag] = [model.find_child("LiftCyl_%s_Barrel" % tag, true, false), model.find_child("LiftCyl_%s_Rod" % tag, true, false)]
	_tilt_barrel = model.find_child("TiltCyl_Barrel", true, false)
	_tilt_rod = model.find_child("TiltCyl_Rod", true, false)
	for node in model.find_children("*", "Node3D", true, false):
		var nm := str(node.name)
		for key in ["Sprocket_", "Idler_", "Roller_", "Carrier_"]:
			if nm.begins_with(key):
				(_wheels_l if nm.substr(key.length(), 1) == "L" else _wheels_r).append([node, _wheel_radius(nm)])
	_swap_materials()
	for side in ["L", "R"]:
		var mi := model.find_child("Track_" + side, true, false) as MeshInstance3D
		if mi != null:
			var own := (mi.get_surface_override_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			mi.set_surface_override_material(0, own)
			_belts[side] = own
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
	set_blade(0.2, 0.0)

static func _wheel_radius(nm: String) -> float:
	if nm.begins_with("Sprocket"): return 0.34
	if nm.begins_with("Idler"): return 0.35
	if nm.begins_with("Roller"): return 0.115
	return 0.085

## Godot adds hold-at-rest tracks for every animated node to every imported clip, which would pin the blade, wheels and levers
## (code-driven) while the engine clips play. The engine clips keep only the vibration node.
static func _keep_only(a: Animation, node_name: String) -> void:
	for t in range(a.get_track_count() - 1, -1, -1):
		if not str(a.track_get_path(t).get_concatenated_names()).ends_with(node_name):
			a.remove_track(t)

# ------------------------------------------------------------------ materials

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

## Body paint: "PaintYellow" (default livery), "PaintRed", "PaintOrange" (worn variants), or any project paint name.
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

# ------------------------------------------------------------------ lights, particles

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
	var edge := model.find_child("Marker_Edge", true, false) as Node3D
	if edge != null:
		_dust = _puff(edge, 8, 0.7, Vector3(0, -0.5, 0), Color(0.62, 0.55, 0.42, 0.6), 50.0, 0.5, 1.2, false)
		_dust.scale_amount_min = 0.6
		_dust.scale_amount_max = 1.0
	var pm := model.find_child("Marker_Pile", true, false) as Node3D
	if pm != null:
		_pile = MeshKit.inst(pm, MeshKit.rock(Vector3(2.1, 0.8, 0.9), 51, 3, 8), MeshKit.mat("ExcavatedDirt"), Vector3(0.0, 0.0, -0.25))
		_pile.visible = false

## Dust along the cutting edge while it digs in and pushes.
func set_dust(on: bool) -> void:
	if _dust != null and _dust.emitting != on:
		_dust.emitting = on

## The mound of pushed material in front of the blade: fraction 0..1 of the blade's capacity, tinted for the material.
func set_pile(fraction: float, material: Material = null) -> void:
	if _pile == null:
		return
	_pile.visible = fraction > 0.04
	if _pile.visible:
		_pile.scale = Vector3(1.0, 0.25 + 0.75 * clampf(fraction, 0.0, 1.0), 0.45 + 0.55 * clampf(fraction, 0.0, 1.0))
		if material != null:
			_pile.material_override = material

# ------------------------------------------------------------------ engine

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

# ------------------------------------------------------------------ tracks

## Each track follows its own speed (m/s, + forward): the turning machine's outer track runs faster.
func wheel_nodes() -> Array:
	var out := []
	for w in _wheels_l + _wheels_r:
		out.append(w[0])
	return out

func belt_mats() -> Array:
	return _belts.values()

func drive(speed_l: float, speed_r: float, delta: float) -> void:
	for w in _wheels_l:
		(w[0] as Node3D).rotate_x(-speed_l * delta / float(w[1]))
	for w in _wheels_r:
		(w[0] as Node3D).rotate_x(-speed_r * delta / float(w[1]))
	if _belts.has("L"):
		var m := _belts["L"] as StandardMaterial3D
		m.uv1_offset.x = fposmod(m.uv1_offset.x + speed_l * delta / BELT_PITCH, 1000.0)
	if _belts.has("R"):
		var m := _belts["R"] as StandardMaterial3D
		m.uv1_offset.x = fposmod(m.uv1_offset.x + speed_r * delta / BELT_PITCH, 1000.0)

## Convenience: straight speed + steering input (-1..1, + right) -> the two track speeds.
func drive_steered(speed: float, steer: float, delta: float) -> void:
	drive(speed * (1.0 + steer * DozerKin.TRACK_V), speed * (1.0 - steer * DozerKin.TRACK_V), delta)

# ------------------------------------------------------------------ blade + hydraulics

func _look(barrel: Node3D, dir_blender_xz: Vector2) -> void:
	# Blender (dx, 0, dz) -> Godot (dx, dz, 0); the barrel's axis is its local -Z
	var d := Vector3(dir_blender_xz.x, dir_blender_xz.y, 0.0)
	barrel.basis = Basis.looking_at(d.normalized(), Vector3(0, 0, 1))

## alpha: arm angle in rad (DozerKin.LIFT_MIN..LIFT_MAX, positive raises the blade); tilt: -TILT_MAX..TILT_MAX.
func set_blade(alpha: float, tilt: float) -> void:
	if lift == null:
		return
	blade_alpha = clampf(alpha, DozerKin.LIFT_MIN, DozerKin.LIFT_MAX)
	blade_tilt = clampf(tilt, -DozerKin.TILT_MAX, DozerKin.TILT_MAX)
	lift.rotation.x = blade_alpha
	blade.rotation.z = -blade_tilt
	var l := DozerKin.lift(blade_alpha)
	for tag in ["L", "R"]:
		var pair: Array = _lift_cyl[tag]
		(pair[0] as Node3D).rotation = Vector3(l.x, 0.0, 0.0)
		(pair[1] as Node3D).position = Vector3(0.0, 0.0, -l.y)
	var t := DozerKin.tilt(blade_tilt)
	_look(_tilt_barrel, Vector2(t.x, t.y))
	_tilt_rod.position = Vector3(0.0, 0.0, -t.z)
	if lever_r != null:
		lever_r.rotation = Vector3(-(blade_alpha - 0.19) * 0.6, blade_tilt * 1.6, 0.0)

## Left lever follows the steering (cosmetic).
func set_steer_lever(steer: float) -> void:
	if lever_l != null:
		lever_l.rotation = Vector3(0.0, -steer * 0.25, 0.0)

## Height of the cutting edge above the ground for an arm angle (model metres): used to decide when the blade digs in.
static func edge_height(alpha: float) -> float:
	return DozerKin.TRUNNION.y - 0.50 + DozerKin.ARM_LEN * sin(alpha)

func collision_hulls() -> Array:
	var out: Array = []
	for node in model.find_children("ColHull_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		out.append([model.global_transform.affine_inverse() * mi.global_transform, mi.mesh.create_convex_shape(true, true)])
		mi.visible = false
	return out
