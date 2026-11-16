extends Node3D
class_name ExcavatorRig
## Runtime wrapper for the Blender-built hydraulic excavator (assets/vehicles/VEH_QD_Excavator.glb).
##
## It does NOT touch gameplay: nothing in the game uses it yet. It gives a future QuarryVehicle one object that
##   * loads the GLB and swaps in the project's pixel materials (vertex-colour grime kept),
##   * exposes the mechanical joints (turret, boom, stick, bucket) and drives the hydraulics so cylinders and the
##     bucket 4-bar linkage stay connected for ANY joint angles (set_pose), not only the baked clips,
##   * plays the baked clips (Idle, EngineStart, EngineStop, Swing, BoomUpDown, StickInOut, BucketCurlDump,
##     TrackDrive, DigCycle, TruckLoad) and runs the engine state machine,
##   * scrolls the track belts and spins sprocket / idler / rollers from a travel speed,
##   * switches the work lights and turns the baked collision hulls into CollisionShape3D nodes.
## One owner per property: while a baked joint clip plays (boom / stick / bucket / swing clips), do not call set_pose().
## Axis convention: Godot node rotation.x equals the Blender rotation about X (positive raises the arm).

const GLB := "res://assets/vehicles/VEH_QD_Excavator.glb"
const MATERIAL_DIRS := ["res://assets/vehicles/materials/", "res://assets/materials/"]
const MATERIAL_OVERRIDES := ["ExcPaint", "ExcDark", "ExcTrack", "SteelPlate", "Hazard", "MetalBrushed", "Tire", "PaintYellow", "Glass"]
const LOOP_CLIPS := ["Idle", "TrackDrive"]
const CLIP_FPS := 30.0
const ENGINE_CLIPS := ["Idle", "EngineStart", "EngineStop"]
const BELT_PITCH := 0.2          ## metres of belt per texture repeat (grouser pitch)

signal engine_state_changed(state: StringName)

var model: Node3D
var player: AnimationPlayer
var turret: Node3D
var boom: Node3D
var stick: Node3D
var bucket: Node3D
var exhaust_cap: Node3D
var engine_state: StringName = &"off"         # off / starting / idle / stopping
var lights_on := false
var drive_speed := 0.0                         # m/s along the tracks (+ forward)

var _wheels: Array = []                        # [Node3D, radius]
var _belts: Array = []                         # StandardMaterial3D (one per belt, instance-unique)
var _barrels := {}
var _rods := {}
var _links := {}
var _lens_mats: Array = []
var _spots: Array = []
var _smoke: CPUParticles3D
var _materials := {}

func _ready() -> void:
	build()

## Loads the model. Safe to call before the node is in the tree (QuarryVehicle builds it during setup()); a second call does nothing.
func build() -> void:
	if model != null:
		return
	var scene: PackedScene = load(GLB)
	if scene == null:
		push_error("ExcavatorRig: cannot load %s" % GLB)
		return
	model = scene.instantiate()
	model.name = "Model"
	add_child(model)
	for hull in model.find_children("ColHull_*", "MeshInstance3D", true, false):
		(hull as MeshInstance3D).visible = false          # collision proxies are exported as meshes: never draw them
	turret = model.find_child("Turret", true, false)
	boom = model.find_child("Boom", true, false)
	stick = model.find_child("Stick", true, false)
	bucket = model.find_child("Bucket", true, false)
	exhaust_cap = model.find_child("ExhaustCap", true, false)
	for n in ["BoomCyl_L", "BoomCyl_R", "StickCyl", "BucketCyl"]:
		_barrels[n] = model.find_child(n + "_Barrel", true, false)
		_rods[n] = model.find_child(n + "_Rod", true, false)
	for n in ["IdlerLink_L", "IdlerLink_R", "BucketLink_L", "BucketLink_R"]:
		_links[n] = model.find_child(n, true, false)
	_swap_materials(model)
	_collect_wheels_and_belts()
	_setup_lights()
	_setup_smoke()
	player = model.find_child("AnimationPlayer", true, false)
	if player != null:
		for clip in player.get_animation_list():
			var a := player.get_animation(clip)
			if clip in ENGINE_CLIPS:
				_prune_engine_clip(a)
			if clip in LOOP_CLIPS:
				a.loop_mode = Animation.LOOP_LINEAR
				a.length = maxf(0.05, a.length - 1.0 / CLIP_FPS)     # the baked last frame repeats the first: drop it so the loop does not stall
			else:
				a.loop_mode = Animation.LOOP_NONE
		player.animation_finished.connect(_on_clip_finished)
	set_pose(ExcavatorKin.REST["swing"], ExcavatorKin.REST["boom"], ExcavatorKin.REST["stick"], ExcavatorKin.REST["bucket"])

## Godot adds hold-at-rest tracks for every animated node to every imported clip, which would pin the joints, swing and tracks
## (code-driven) at rest while the engine clips play. The engine clips keep only the vibration (Turret position) and the exhaust cap.
static func _prune_engine_clip(a: Animation) -> void:
	for t in range(a.get_track_count() - 1, -1, -1):
		var path := str(a.track_get_path(t).get_concatenated_names())
		# Only the exhaust cap stays baked. A track on the Turret itself (even just its position) makes the AnimationPlayer write the turret's WHOLE transform every frame while
		# the engine clips play, which reset the cab's rotation to zero: the upper body could not be turned with the mouse. The cab's shake is done in code (Vehicle._joints).
		var keep := path.ends_with("ExhaustCap")
		if not keep:
			a.remove_track(t)

# ------------------------------------------------------------------ materials

func _project_material(mat_name: String) -> Material:
	if _materials.has(mat_name):
		return _materials[mat_name]
	var found: Material = null
	for dir in MATERIAL_DIRS:
		var path: String = dir + "M_QD_" + mat_name + ".tres"
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_materials[mat_name] = found
	return found

func _swap_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var has_colour: bool = mi.mesh.get_surface_count() > 0 and (mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0 and mi.name != "CabGlass"
		if mi.name == "CabGlass":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF         # see-through glass must not shade the cab interior
		for s in mi.mesh.get_surface_count():
			var imported: Material = mi.mesh.surface_get_material(s)
			if imported == null:
				continue
			var mat_name := imported.resource_name
			if mat_name in MATERIAL_OVERRIDES:
				var key := mat_name + ("_vc" if has_colour else "")
				if not _materials.has(key):
					var base := _project_material(mat_name)
					if base != null:
						var m := base.duplicate() as StandardMaterial3D
						m.vertex_color_use_as_albedo = has_colour
						_materials[key] = m
				if _materials.has(key):
					mi.set_surface_override_material(s, _materials[key])
			elif imported is StandardMaterial3D:
				var sm := imported as StandardMaterial3D
				sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				if sm.vertex_color_use_as_albedo == false and has_colour:
					sm.vertex_color_use_as_albedo = true

# ------------------------------------------------------------------ wheels, belts

func _collect_wheels_and_belts() -> void:
	var radii := {"Sprocket": 0.25, "Idler": 0.26, "Roller": 0.095, "Carrier": 0.065}
	for node in model.get_children():
		_scan_wheels(node, radii)
	for side in ["Track_L", "Track_R"]:
		var mi := model.find_child(side, true, false) as MeshInstance3D
		if mi == null:
			continue
		var m := mi.get_surface_override_material(0)
		if m == null:
			m = mi.mesh.surface_get_material(0)
		var own := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, own)
		_belts.append(own)

func _scan_wheels(node: Node, radii: Dictionary) -> void:
	for key in radii:
		if node.name.begins_with(key) and node is Node3D:
			_wheels.append([node, float(radii[key])])
	for c in node.get_children():
		_scan_wheels(c, radii)

## Call every frame with the travel speed (m/s, + forward). Rolls the wheels and scrolls the belts.
func wheel_nodes() -> Array:
	var out := []
	for w in _wheels:
		out.append(w[0])
	return out

func belt_mats() -> Array:
	return _belts.duplicate()

func drive(speed: float, delta: float) -> void:
	drive_speed = speed
	for w in _wheels:
		(w[0] as Node3D).rotate_x(-speed * delta / float(w[1]))
	for m in _belts:
		var mat := m as StandardMaterial3D
		mat.uv1_offset.x = fposmod(mat.uv1_offset.x + speed * delta / BELT_PITCH, 1000.0)    # the bottom run moves backwards as the machine moves forward

# ------------------------------------------------------------------ lights, smoke

func _setup_lights() -> void:
	for n in ["Light_Cab_L", "Light_Cab_R", "Light_Boom", "Light_Rear"]:
		var marker := model.find_child(n, true, false) as Node3D
		if marker == null:
			continue
		var spot := SpotLight3D.new()
		spot.name = "Spot"
		spot.spot_range = 16.0
		spot.spot_angle = 38.0
		spot.light_energy = 2.4
		spot.light_color = Color(1.0, 0.93, 0.75)
		spot.visible = false
		if n == "Light_Rear":
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
				_lens_mats.append([own, (m as StandardMaterial3D).emission_energy_multiplier])

func set_lights(on: bool) -> void:
	lights_on = on
	for s in _spots:
		(s as SpotLight3D).visible = on
	for e in _lens_mats:
		(e[0] as StandardMaterial3D).emission_energy_multiplier = float(e[1]) if on else 0.0

func _setup_smoke() -> void:
	var tip := model.find_child("Marker_ExhaustTip", true, false) as Node3D
	if tip == null:
		return
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.amount = 10
	_smoke.lifetime = 1.6
	_smoke.emitting = false
	_smoke.direction = Vector3.UP
	_smoke.spread = 10.0
	_smoke.initial_velocity_min = 0.5
	_smoke.initial_velocity_max = 0.9
	_smoke.gravity = Vector3(0.12, 0.25, 0.0)
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.5
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.32, 0.34, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	_smoke.mesh = sm
	var ramp := Curve.new()
	ramp.add_point(Vector2(0, 0.5))
	ramp.add_point(Vector2(1, 2.4))
	_smoke.scale_amount_curve = ramp
	tip.add_child(_smoke)

# ------------------------------------------------------------------ engine state machine

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

## Play a work clip (BoomUpDown, StickInOut, BucketCurlDump, Swing, DigCycle, TruckLoad, TrackDrive...).
func play_clip(clip: StringName) -> void:
	if player != null and player.has_animation(clip):
		player.play(clip)

func stop_clips() -> void:
	if player != null:
		player.stop()

func clip_names() -> PackedStringArray:
	return player.get_animation_list() if player != null else PackedStringArray()

# ------------------------------------------------------------------ joints + hydraulics

## Absolute joint angles (rad). Rest pose = ExcavatorKin.REST. The bucket angle is relative to the stick.
## Clamped to the mechanical limits so the 4-bar linkage and the cylinder strokes stay valid.
func set_pose(swing: float, boom_a: float, stick_a: float, bucket_a: float) -> void:
	if turret == null:
		return
	var lim := ExcavatorKin.LIMITS
	boom_a = clampf(boom_a, (lim["boom"] as Vector2).x, (lim["boom"] as Vector2).y)
	stick_a = clampf(stick_a, (lim["stick"] as Vector2).x, (lim["stick"] as Vector2).y)
	bucket_a = clampf(bucket_a, (lim["bucket"] as Vector2).x, (lim["bucket"] as Vector2).y)
	turret.rotation.y = swing
	boom.rotation.x = boom_a
	stick.rotation.x = stick_a
	bucket.rotation.x = bucket_a
	_solve_hydraulics(boom_a, stick_a, bucket_a)

## -1..1 per joint (what QuarryVehicle's manual controls use) -> absolute angles, centred on the rest pose and filling each range.
func set_pose_normalized(swing: float, boom_n: float, stick_n: float, bucket_n: float) -> void:
	var lim := ExcavatorKin.LIMITS
	var r: Dictionary = ExcavatorKin.REST
	set_pose(swing, _lerp_range(r["boom"], lim["boom"], boom_n), _lerp_range(r["stick"], lim["stick"], stick_n), _lerp_range(r["bucket"], lim["bucket"], bucket_n))

func _lerp_range(rest: float, r: Vector2, n: float) -> float:
	return rest + n * ((r.y - rest) if n > 0.0 else (rest - r.x))

func _aim(barrel: Node3D, base: Vector2, target: Vector2) -> float:
	var d := target - base
	barrel.rotation = Vector3(atan2(d.y, d.x), 0.0, 0.0)
	return d.length()

func _solve_hydraulics(b: float, s: float, k: float) -> void:
	# boom cylinders: base pin on the turret, rod pin on the boom (model-plane coordinates)
	var boom_target := ExcavatorKin.P0 + ExcavatorKin.rot(ExcavatorKin.BOOM_CYL_ROD, b)
	for tag in ["BoomCyl_L", "BoomCyl_R"]:
		var d := _aim(_barrels[tag], ExcavatorKin.BOOM_CYL_BASE, boom_target)
		(_rods[tag] as Node3D).position = Vector3(0.0, 0.0, -d)
	# stick cylinder (boom-local)
	var st_target := ExcavatorKin.BOOM_E + ExcavatorKin.rot(ExcavatorKin.STICK_CYL_ROD, s)
	var ds := _aim(_barrels["StickCyl"], ExcavatorKin.STICK_CYL_BASE, st_target)
	(_rods["StickCyl"] as Node3D).position = Vector3(0.0, 0.0, -ds)
	# bucket cylinder + 4-bar (stick-local)
	var j := ExcavatorKin.bucket_j(k)
	if j == Vector2.INF:
		return
	var db := _aim(_barrels["BucketCyl"], ExcavatorKin.BUCKET_CYL_BASE, j)
	(_rods["BucketCyl"] as Node3D).position = Vector3(0.0, 0.0, -db)
	var jb := ExcavatorKin.rot(j - ExcavatorKin.STICK_W, -k)
	for tag in ["L", "R"]:
		_aim(_links["IdlerLink_" + tag], ExcavatorKin.LINK_K, j)
		_aim(_links["BucketLink_" + tag], ExcavatorKin.LINK_L, jb)

# ------------------------------------------------------------------ collision

## Returns [Transform3D relative to the rig, ConvexPolygonShape3D] for every ColHull_* proxy and hides the proxy meshes.
func collision_hulls() -> Array:
	var out: Array = []
	for node in model.find_children("ColHull_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var shape := mi.mesh.create_convex_shape(true, true)
		var xf := model.global_transform.affine_inverse() * mi.global_transform
		out.append([xf, shape])
		mi.visible = false
	return out

## Adds one CollisionShape3D per hull under `body` (a CharacterBody3D / StaticBody3D that is at this rig's origin).
func add_collision_to(body: Node3D) -> void:
	for h in collision_hulls():
		var cs := CollisionShape3D.new()
		cs.shape = h[1]
		cs.transform = h[0]
		body.add_child(cs)

## World position of the bucket lip (teeth), for dig-point logic.
func bucket_tip() -> Vector3:
	var m := model.find_child("Marker_BucketTip", true, false) as Node3D
	return m.global_position if m != null else global_position

## Pose the arm so the bucket lip is at `tip` (model plane: y forward, z up, metres at model scale) with an absolute bucket
## attitude (0 = teeth rear-down, negative = curled). Reach is shortened until the arm can get there. Returns false if clamped hard.
func pose_for_tip(swing: float, tip: Vector2, attitude: float) -> bool:
	var target := tip
	for i in 12:
		var a := ExcavatorKin.ik(target, attitude)
		if a != Vector3.INF:
			set_pose(swing, a.x, a.y, a.z)
			return i == 0
		target = Vector2(lerpf(target.x, ExcavatorKin.P0.x + 1.0, 0.12), target.y)
	return false

## Swap the body paint (ExcPaint surfaces) for another project paint material, e.g. "PaintOrange"; keeps the vertex-colour grime.
func set_paint(paint_name: String) -> void:
	var base := _project_material(paint_name)
	if base == null:
		return
	var m := base.duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var cur := mi.get_surface_override_material(s)
			if cur != null and cur.resource_name == "M_QD_ExcPaint":
				mi.set_surface_override_material(s, m)
