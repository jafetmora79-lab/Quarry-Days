extends CharacterBody3D
class_name QuarryVehicle
## Lightweight kinematic heavy-machinery controller shared by the front loader and the
## dump truck. Arcade bicycle steering, momentum, load-dependent acceleration and
## move_and_slide collisions against terrain, structures, workers and other vehicles.
## Material lives in QuarryFleet as unit counts; the meshes only visualise it.

const RESOURCE_COLORS := {"limestone": Color(0.67, 0.66, 0.56), "coal": Color(0.17, 0.19, 0.21), "iron_ore": Color(0.52, 0.29, 0.23), "crushed_stone": Color(0.75, 0.73, 0.66), "copper_ore": Color(0.36, 0.52, 0.42), "gold_ore": Color(0.78, 0.62, 0.24), "topsoil": Color(0.4, 0.29, 0.19), "gravel": Color(0.6, 0.57, 0.5)}

var game
var fleet: QuarryFleet
var vehicle_id := 0
var vtype := ""
var vkind := "loader"          ## family: loader / truck / excavator (a type can be any of the vehicles in data/vehicles.json)
var model_root: Node3D
var paint_cab := "PaintRed"
var paint_bed := "PaintOrange"
var paint_main := "PaintYellow"
var digging := false
var dig_phase := 0.0
var data: Dictionary
var size := Vector3(2, 1.5, 3)

var driven := false:
	set(v):
		if v == driven:
			return
		driven = v
		_engine_toggle(v)
var cab_view := false           ## Tab: the camera sits in the driver's seat (see CabInterior / QuarryBoarding) instead of behind the machine
var auto_drive := false         ## the auto crew (scripts/auto_crew.gd) is steering it: `input` is obeyed like a driver's, but with no camera
var speed := 0.0
var input := {"throttle": 0.0, "steer": 0.0, "brake": false}
var settled_frames := 0

var cam_pivot: Node3D
var camera: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.32

# Blender-built excavator (scripts/art/excavator_rig.gd). Null = the procedural fallback model (VehicleModels.excavator).
const OPENING_OFFSET := Vector3(0.0, -0.99, 0.0)   ## procedural turret space -> the Blender turret (the hood at y 1.55 there is 0.56 here)
const USE_RIG_EXCAVATOR := true
const USE_RIG_TRUCK := true       ## Blender dump truck (scripts/art/truck_rig.gd); false = the old procedural truck
var rig: ExcavatorRig
var trig: TruckRig
const USE_RIG_LOADER := true       ## Blender wheel loader (scripts/art/loader_rig.gd); false = the old procedural loader
var lrig: LoaderRig
var _prev_arm := 0.0
var _loader_dump_armed := true
var drig: DozerRig                ## Blender bulldozer (scripts/art/dozer_rig.gd)
var blade_goal := 0.32            ## wanted arm angle: 0.32 = blade carried clear of the ground, -0.08 = cutting edge digging in
var blade_tilt_goal := 0.0
var pushing_t := 0.0              ## > 0 while the blade is moving material (dust, sound)
var push_acc := 0.0
var _dozer_alpha := 0.32
var _dozer_tilt := 0.0
var _prev_blade := 0.0
var _steer_vis := 0.0
var _steer_show := 0.0
var _prev_speed := 0.0
var _susp_pitch := 0.0
var _susp_roll := 0.0
var _bounce := 0.0
var _bounce_v := 0.0
var _prev_bed := 0.0
var _tip_armed := true
var vaudio: VehicleAudio
var dig_aim := Vector3.INF     ## world point of the rock / soil being dug (set by main.gd while digging): the bucket reaches for it
var _kick := 0.0               ## tiny camera pitch kick when the bucket bites
var _bite_armed := true
var _prev_dump := 0.0
var _prev_joints := Vector4.ZERO
var _throttle_s := 0.0
var _steer_s := 0.0
var _dust: CPUParticles3D
# loader
var arm: Node3D
var turret: Node3D            ## excavator: the upper body, swings on the slewing ring
var turret_rest_y := 0.0      ## its height on the undercarriage (the Blender turret sits 0.78 m up on the slewing ring): the engine shake is added to THIS, never replaces it
var stick: Node3D             ## excavator: the stick, hinged at the boom's elbow
var swing := 0.0              ## manual excavator joints: turret yaw (rad) and boom / stick / bucket (-1..1)
var boom_m := 0.0
var stick_m := 0.0
var curl_m := 0.0
var _keys_live := false
var turret_yaw := 0.0         ## what the cab actually shows: it eases toward `swing` (slewing has inertia) instead of snapping
var _turret_vel := 0.0
var _turret_roll := 0.0
var _prev_yaw := 0.0
var _vib_t := 0.0
var joint_in := {"swing": 0.0, "boom": 0.0, "stick": 0.0, "curl": 0.0}   ## -1..1 per joint; read from the keys while driven
var bucket: Node3D
var bucket_load: MeshInstance3D
var bucket_lift := 0.0
var bucket_target := 0.0
var dump_timer := 0.0
# truck
var bed: Node3D
var truck_aim := Vector3.INF      ## excavator: the point above a truck's bed the bucket goes to while it tips (set by Main.vehicle_dump, derived from the real bed)
var _bed_box := AABB()           ## truck: its cargo bed in the truck's own frame, measured from the model (see bed_box())

const DUMP_ATT_CARRY := -0.58   ## bucket attitude while it carries a load up (see _animate_rig) and when it is tipped over the bed
const DUMP_ATT_TIP := 1.22
const GROUND_LIFT := 0.05       ## the collision hull's bottom sits this far above the body origin, so the visible model is lifted by the same: tracks and tyres touch the ground
var bed_load: MeshInstance3D
var bed_tilt := 0.0
var unload_timer := 0.0
var unload_target := {}
var wheels: Array = []
var track_mats: Array = []     ## excavator tread materials: the texture scrolls as the machine moves
var _prev_pos := Vector3.INF
var _travel_speed := 0.0         ## m/s the machine really moves along its heading (driven, delivered by script or carried): what the rigs' wheels and belts follow
var rig_drives_wheels := false   ## the Blender rigs turn their own wheels and belts (`wheels` / `track_mats` list them for tests and tools)
# Phase 5: smoothed visuals
var shown_load := 0.0       ## visual cargo that eases toward the real cargo (spills out / fills in)
var curl_timer := 0.0       ## loader bucket curl when it scoops

# stuck recovery
var safe_position := Vector3.ZERO
var safe_yaw := 0.0
var safe_timer := 0.0

func setup(main_node, f: QuarryFleet, record: Dictionary) -> void:
	game = main_node
	fleet = f
	data = record
	vehicle_id = int(record["id"])
	vtype = str(record["type"])
	vkind = fleet.kind(vtype)
	var sp: Dictionary = fleet.spec(vtype)
	paint_cab = str(sp.get("cab_paint", paint_cab))
	paint_bed = str(sp.get("bed_paint", paint_bed))
	paint_main = str(sp.get("paint", paint_main))
	name = "Vehicle_%d" % vehicle_id
	var s: Array = fleet.spec(vtype)["size"]
	size = Vector3(float(s[0]), float(s[1]), float(s[2]))
	collision_layer = 8
	collision_mask = 1 | 4 | 8 | 16 # world, workers, vehicles, conveyors
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(40)
	set_meta("kind", "vehicle")
	set_meta("vehicle_id", vehicle_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5 + 0.05, 0)
	shape.disabled = true          # kept only as the machine's footprint (navigation obstacle, tests); the hull below collides
	add_child(shape)
	# The body collides as a hull with bevelled bottom edges: a flat box catches on the seams between neighbouring ground
	# boxes (the loader used to stall on the join between the corridor and the plateau).
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var pts := PackedVector3Array()
	# Phase 8.7: the nose and tail are chamfered at about 20 degrees (a real approach angle), so the machine rolls onto and over
	# the crest of a ramp or a small lip as a floor instead of catching on it as a wall.
	var ramp_len := minf(0.9, hz * 0.4)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pts.append(Vector3(sx * (hx - 0.14), 0.05, sz * (hz - ramp_len)))
			pts.append(Vector3(sx * hx, 0.05 + 0.14, sz * (hz - ramp_len)))
			pts.append(Vector3(sx * hx, 0.05 + ramp_len * 0.36, sz * hz))
			pts.append(Vector3(sx * hx, 0.05 + size.y, sz * hz))
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	var hull_shape := CollisionShape3D.new()
	hull_shape.name = "BodyHull"
	hull_shape.shape = hull
	add_child(hull_shape)
	model_root = Node3D.new()
	model_root.name = "Model"
	model_root.position.y = GROUND_LIFT
	add_child(model_root)
	var base := Vector3(2.0, 1.5, 3.0) if vkind == "loader" else (Vector3(2.2, 1.8, 4.6) if vkind == "truck" else (Vector3(2.6, 2.45, 4.7) if vkind == "bulldozer" else Vector3(2.0, 2.2, 3.4)))
	model_root.scale = Vector3(size.x / base.x, size.y / base.y, size.z / base.z)    # bigger machines are the same build, larger
	match vkind:
		"loader": _build_loader()
		"excavator": _build_excavator()
		"bulldozer": _build_bulldozer()
		_: _build_truck()
	vaudio = VehicleAudio.new()
	vaudio.name = "Audio"
	add_child(vaudio)
	if driven:
		_engine_toggle(true)
	if rig != null or trig != null:
		# the Blender machines scale uniformly (the heavy excavator and the industrial truck are the same machine, bigger, not stretched):
		# the mean of the three size ratios; the collision hull and the game's footprint still come from the spec
		var u := (model_root.scale.x + model_root.scale.y + model_root.scale.z) / 3.0
		model_root.scale = Vector3(u, u, u)
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0, 2.0, 0)
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, cam_distance())
	camera.far = 700
	cam_pivot.add_child(camera)
	var p: Array = record["position"]
	position = Vector3(float(p[0]), maxf(0.02, float(p[1])), float(p[2]))
	rotation.y = float(record.get("yaw", 0.0))
	safe_position = position
	safe_yaw = rotation.y

## The Blender excavator when its GLB loads; otherwise the old procedural model (kept as the fallback).
func _build_excavator() -> void:
	if USE_RIG_EXCAVATOR and ResourceLoader.exists(ExcavatorRig.GLB):
		var r := ExcavatorRig.new()
		r.name = "Rig"
		model_root.add_child(r)
		r.build()
		if r.model != null and r.turret != null and r.boom != null and r.stick != null and r.bucket != null:
			rig = r
			turret = r.turret
			turret_rest_y = turret.position.y
			arm = r.boom
			stick = r.stick
			bucket = r.bucket
			if paint_main != "PaintYellow":
				r.set_paint(paint_main)
			bucket_load = MeshKit.inst(r.bucket, MeshKit.rock(Vector3(0.62, 0.30, 0.45), 43, 3, 6), MeshKit.mat("RockLimestone"), Vector3(0.0, -0.36, 0.10))
			bucket_load.visible = false
			_use_rig_wheels(r.wheel_nodes(), r.belt_mats())
			RigCab.attach(self, "excavator", r.turret, r.model, paint_main)
			# the repair story (battery pocket, filler, hose) is drawn in the procedural excavator's turret space: this offset maps that onto the Blender hood
			r.turret.set_meta("opening_offset", OPENING_OFFSET)
			var frame := Node3D.new()
			frame.name = "OpeningFrame"
			frame.position = OPENING_OFFSET
			r.turret.add_child(frame)
			if vtype != "starter_excavator":
				OpeningModels.fitted(r.turret, true, false, true, null, null, true)       # a bought machine has its battery in the pocket from the start
			_make_dust()
			return
		r.queue_free()
	VehicleModels.excavator(self)

func _make_dust() -> void:
	var tip := rig.model.find_child("Marker_BucketTip", true, false) as Node3D
	if tip == null:
		return
	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.one_shot = true
	_dust.emitting = false
	_dust.amount = 9
	_dust.lifetime = 0.75
	_dust.explosiveness = 1.0
	_dust.direction = Vector3.UP
	_dust.spread = 55.0
	_dust.initial_velocity_min = 0.6
	_dust.initial_velocity_max = 1.4
	_dust.gravity = Vector3(0, -0.6, 0)
	_dust.scale_amount_min = 0.8
	_dust.scale_amount_max = 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.42, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	_dust.mesh = sm
	var ramp := Curve.new()
	ramp.add_point(Vector2(0, 0.6))
	ramp.add_point(Vector2(1, 0.1))
	_dust.scale_amount_curve = ramp
	tip.add_child(_dust)

func _engine_toggle(on: bool) -> void:
	if lrig != null:
		if on:
			lrig.start_engine()
		else:
			lrig.stop_engine()
	if drig != null:
		if on:
			drig.start_engine()
		else:
			drig.stop_engine()
	if trig != null:
		if on:
			trig.start_engine()
		else:
			trig.stop_engine()
	if rig != null:
		if on:
			rig.start_engine()
		else:
			rig.stop_engine()
	if vaudio != null:
		if on:
			vaudio.start_engine()
		else:
			vaudio.stop_engine()

func _box(parent: Node3D, pos: Vector3, s: Vector3, color: Color) -> MeshInstance3D:
	return game._visual_box(parent, pos, s, color)

func _wheel(x: float, z: float, r: float) -> void:
	var w := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.38
	c.radial_segments = 8
	w.mesh = c
	w.material_override = game._mat(Color(0.09, 0.09, 0.09))
	w.rotation.z = PI / 2
	w.position = Vector3(x, r, z)
	add_child(w)
	wheels.append(w)

## Phase 4: modelled vehicles (scripts/art/vehicle_models.gd) in THE VEIL pixel style.
## The Blender rigs roll their own wheels and scroll their own belts (from `_travel_speed`); the lists are kept here so everything that looks for a machine's
## turning parts (tests, tools) finds them in the same place as on the procedural machines.
func _use_rig_wheels(nodes: Array, belts: Array) -> void:
	wheels = nodes
	track_mats = belts
	rig_drives_wheels = true

func _build_loader() -> void:
	if USE_RIG_LOADER and ResourceLoader.exists(LoaderRig.GLB):
		var r := LoaderRig.new()
		r.name = "Rig"
		model_root.add_child(r)
		r.build()
		if r.model != null and r.lift != null and r.bucket != null and r.front != null:
			lrig = r
			r.set_paint(paint_main)
			arm = r.lift
			bucket = r.bucket
			bucket_load = MeshKit.inst(r.bucket, MeshKit.rock(Vector3(1.7, 0.45, 0.6), 41, 3, 7), MeshKit.mat("RockLimestone"), Vector3(0, -0.10, -0.18))
			bucket_load.visible = false
			_use_rig_wheels(r.wheel_nodes(), [])
			RigCab.attach(self, "loader", r, r.model, paint_main)
			return
		r.queue_free()
	VehicleModels.loader(self)

## The bulldozer is Blender-only (there is no procedural fallback model): a plain box stands in if its GLB cannot load.
func _build_bulldozer() -> void:
	var r := DozerRig.new()
	r.name = "Rig"
	model_root.add_child(r)
	r.build()
	if r.model != null and r.lift != null and r.blade != null:
		drig = r
		r.position = Vector3(0, 0, 0.47)              # the model's centre is 0.47 m behind its footprint centre: recentre it
		r.set_paint(paint_main)
		_use_rig_wheels(r.wheel_nodes(), r.belt_mats())
		RigCab.attach(self, "dozer", r, r.model, paint_main)
		return
	r.queue_free()
	_box(model_root, Vector3(0, 1.0, 0), Vector3(size.x * 0.6, 1.4, size.z * 0.8), Color(0.75, 0.6, 0.2))

func _build_truck() -> void:
	if USE_RIG_TRUCK and ResourceLoader.exists(TruckRig.GLB):
		var r := TruckRig.new()
		r.name = "Rig"
		model_root.add_child(r)
		r.build()
		if r.model != null and r.bed != null and r.sprung != null and r.tailgate != null:
			trig = r
			r.set_paint(paint_cab, paint_bed)
			bed = r.bed
			bed_load = MeshKit.inst(r.bed, MeshKit.rock(Vector3(1.8, 0.55, 2.4), 42, 3, 8), MeshKit.mat("RockLimestone"), Vector3(0, 0.16, -1.45))
			bed_load.visible = false
			_use_rig_wheels(r.wheel_nodes(), [])
			RigCab.attach(self, "truck", r, r.model, paint_cab)
			return
		r.queue_free()
	VehicleModels.truck(self)

# ------------------------------------------------------------------ geometry helpers

func forward() -> Vector3:
	return -global_transform.basis.z

func has_bucket() -> bool:
	return vkind == "loader" or vkind == "excavator"

func cam_distance() -> float:
	return 6.5 + maxf(0.0, size.z - 3.0) * (0.45 if vkind == "truck" else 1.0)

## Point in front of the loader bucket / behind the truck bed where material is handled.
func work_point() -> Vector3:
	if vkind == "bulldozer":
		return global_transform * Vector3(0, 0, -size.z * 0.5 - 0.5)       # just ahead of the blade
	if vkind == "loader":
		return global_transform * Vector3(0, 0, -size.z * 0.5 - 1.1)
	if vkind == "excavator":
		var reach := float(fleet.spec(vtype).get("dig_reach", 4.0)) * 0.55 * clampf(1.0 + 0.5 * stick_m - 0.35 * boom_m, 0.45, 1.6)
		return global_transform * (Basis(Vector3.UP, swing) * Vector3(0, 0, -size.z * 0.5 - reach))
	return global_transform * Vector3(0, 0, size.z * 0.5 + 1.0)

func bed_center() -> Vector3:
	var b := bed_box()
	return global_transform * (b.get_center() if b.size != Vector3.ZERO else Vector3(0, 0, 0.7))

## The truck's cargo bed as a box in the truck's own frame (rim height = top), measured from the bed's visible meshes while the bed lies flat.
## The loading logic uses this instead of a fixed point, so it follows the real model and its scale.
func bed_box() -> AABB:
	if vkind != "truck":
		return AABB()
	if _bed_box.size != Vector3.ZERO:
		return _bed_box
	if bed == null or not is_inside_tree() or absf(bed.rotation.x) > 0.02:
		var hx := size.x * 0.5
		var hz := size.z * 0.5
		return AABB(Vector3(-hx * 0.85, 0.9, -hz * 0.95), Vector3(hx * 1.7, 1.2, hz * 1.5))      # before the model exists: a rough bed
	var inv := global_transform.affine_inverse()
	var box := AABB()
	var first := true
	var parts: Array = [bed]
	parts.append_array(bed.find_children("*", "MeshInstance3D", true, false))        # the Bed node is itself a mesh (floor and walls); the tailgate hangs under it
	for n in parts:
		var mi := n as MeshInstance3D
		if mi == null or mi == bed_load or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.x < 1.0 or box.size.z < 1.2:
		return AABB(Vector3(-size.x * 0.4, 0.9, -size.z * 0.4), Vector3(size.x * 0.8, 1.2, size.z * 0.8))
	_bed_box = box
	return _bed_box

## Is world point `p` over this truck's bed (within `margin` m of its footprint)? {over, outside (m), rim (world y of the bed rim), top (rim point above the bed centre)}
func bed_check(p: Vector3, margin := 0.2) -> Dictionary:
	var b := bed_box()
	var l := to_local(p)
	var ox := maxf(0.0, maxf(b.position.x - l.x, l.x - b.end.x))
	var oz := maxf(0.0, maxf(b.position.z - l.z, l.z - b.end.z))
	var out := Vector2(ox, oz).length()
	var c := b.get_center()
	var top := to_global(Vector3(c.x, b.end.y, c.z))
	return {"over": out <= margin, "outside": out, "rim": top.y, "top": top}

## Can the excavator's arm put the bucket lip at world point `aim` (above or at its own ground level)? Uses the rig's real inverse kinematics.
func can_reach(aim: Vector3) -> bool:
	if rig == null:
		return false
	var k := maxf(model_root.scale.z, 0.01)
	var d := Vector2(aim.x - global_position.x, aim.z - global_position.z).length() / k
	var h := (aim.y - global_position.y - GROUND_LIFT) / k
	for att in [DUMP_ATT_CARRY, DUMP_ATT_TIP]:           # the arm must get there carrying the load AND with the bucket tipped
		if ExcavatorKin.ik(Vector2(d, h), att) == Vector3.INF:
			return false
	return true

## Where the bucket should tip into `truck` with the cab facing `at_swing` (default: the current swing): a point above the bed on the line the arm
## sweeps, at the bed rim plus clearance, its height taken from the truck's real position (so it works when the truck is higher or lower or tilted).
## Returns {"aim": Vector3} or {"why": "swing" | "reach"}: swing = the arm does not point at the bed, reach = the truck is too far / too high / too low.
func truck_dump_aim(truck: QuarryVehicle, at_swing := NAN) -> Dictionary:
	var a := swing if is_nan(at_swing) else at_swing
	var fwd := (global_transform.basis * (Basis(Vector3.UP, a) * Vector3(0, 0, -1)))
	fwd.y = 0.0
	fwd = fwd.normalized()
	var c := truck.bed_check(truck.global_position)["top"] as Vector3
	# Every point of the line the arm sweeps that is over the bed (kept 25 cm inside its edges when the bed allows), nearest the bed's centre first.
	# The centre itself can be beyond the arm's reach while a point nearer the machine, still well inside the bed, is not: the first REACHABLE one is used
	# (the bucket lip clears the rim by as much as the arm allows, up to 0.65 m and at least 0.2 m). A truck none of whose bed the arm can reach is out of reach.
	var any_over := false
	for inset in [0.25, 0.0]:
		var cands := []
		var s := 1.2
		while s <= 6.5:
			var p := global_position + fwd * s
			var chk := truck.bed_check(p, -inset)
			if bool(chk["over"]):
				any_over = true
				cands.append([Vector2(p.x - c.x, p.z - c.z).length(), Vector3(p.x, float(chk["rim"]), p.z)])
			s += 0.15
		cands.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
		for clear in [0.65, 0.5, 0.35, 0.2]:                   # the most clearance the arm can manage anywhere over the bed, then the point nearest the centre
			for cd in cands:
				var aim: Vector3 = (cd[1] as Vector3) + Vector3(0, clear, 0)
				if can_reach(aim):
					return {"aim": aim}
	if not any_over:
		return {"why": "swing"}
	return {"why": "reach"}

# ------------------------------------------------------------------ driving

func rotate_camera(rel: Vector2) -> void:
	if vkind == "excavator" and turret != null:
		swing = wrapf(swing - rel.x * 0.003, -PI, PI)      # the mouse spins the cab on its slewing ring; the tracks stay put (WASD)
	else:
		cam_yaw -= rel.x * 0.003
	cam_pitch = clampf(cam_pitch - rel.y * 0.003, -1.1, 0.25)

## The model stands on the surface you SEE: the yard's gravel, slabs and asphalt are drawn above the collision ground, so the model is lifted by the height of
## the visible layer under the machine's footprint (its highest corner, so no track or tyre is ever buried), eased so it never jumps at a slab's edge.
var _lift_now := GROUND_LIFT
var _settle_rise := 0.0        ## how far the body was just pushed UP by ground that appeared under it: the model eases down from there instead of popping

## Soil changed under (or beside) the machine: leave the parked state so the ground is resolved again.
func wake() -> void:
	settled_frames = 0

## The soil cells the machine's hull stands on (a little wider than the tracks).
func support_cells(soil: QuarrySoil) -> Dictionary:
	if soil == null:
		return {}
	return soil.cells_under(global_transform, Vector2(size.x * 0.5 + 0.15, size.z * 0.5 + 0.15))

func _update_ground_lift(delta: float) -> void:
	if model_root == null or game_art() == null:
		return
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var best := 0.0
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 0.0, 1.0]:
			var p := global_transform * Vector3(sx * hx, 0.0, sz * hz)
			best = maxf(best, game_art().visual_ground_y(p.x, p.z))
	_lift_now = move_toward(_lift_now, GROUND_LIFT + best, delta * 0.4)
	_settle_rise = move_toward(_settle_rise, 0.0, delta * 1.2)
	model_root.position.y = _lift_now - _settle_rise

func game_art():
	var g = get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else null
	return g.art if g != null and "art" in g else null

func control(delta: float) -> void:
	_update_ground_lift(delta)
	data = fleet.vehicle(vehicle_id)
	if data.is_empty():
		return
	var live := driven or auto_drive
	var throttle := float(input["throttle"]) if live else 0.0
	var steer := float(input["steer"]) if live else 0.0
	var braking := bool(input["brake"]) if live else true
	var busy := unload_timer > 0.0 or dump_timer > 0.0
	if busy:
		throttle = 0.0
	if rig != null or trig != null or drig != null or lrig != null:
		# weighty but comfortable: the stick eases in and out instead of snapping
		# the throttle eases only on the tracked machines (excavator, bulldozer); trucks and the loader keep their original pedal response,
		# which the acceleration / engine-upgrade / transport tests and the economy pacing are tuned against
		_throttle_s = move_toward(_throttle_s, throttle, 3.2 * delta if rig != null else 2.0 * delta)
		_steer_s = move_toward(_steer_s, steer, 4.5 * delta if rig != null else 3.0 * delta)
		if rig != null or drig != null:
			throttle = _throttle_s
			steer = _steer_s
	_steer_vis = steer
	_steer_show = move_toward(_steer_show, steer, 3.5 * delta)       # what the wheels / steering wheel / articulation show: eased, the driving itself is not
	var s := fleet.spec(vtype)
	var top := fleet.max_speed(data)
	var a := fleet.accel(data)
	if braking:
		speed = move_toward(speed, 0.0, float(s["brake"]) * delta)
	elif absf(throttle) > 0.05:
		if signf(throttle) != signf(speed) and absf(speed) > 0.2:
			speed = move_toward(speed, 0.0, float(s["brake"]) * delta) # throttle against motion brakes first
		else:
			speed = clampf(speed + throttle * a * delta, -float(s["reverse_speed"]), top)
	else:
		speed = move_toward(speed, 0.0, 1.6 * delta) # rolling resistance: heavy, coasts a little
	var steer_grip := clampf(speed / 2.5, -1.0, 1.0)
	rotation.y -= steer * float(s["turn"]) * steer_grip * delta
	if has_meta("delivering"):
		_animate(delta) # an NPC is driving it into its bay (see scripts/delivery.gd)
		return
	var parked := not live and absf(speed) < 0.01 and is_on_floor() and settled_frames > 5
	if parked:
		# A parked machine is not simulated (no gravity, no drift). When the soil under it changes, `wake()` (called from the soil field) puts it back on the normal
		# path for a moment: soil grown into the tracks pushes it up out of the heap, soil cut away from under it lets it fall until something solid holds it.
		_animate(delta)
		return
	var f := forward()
	# On a slope the machine drives along the ground (up or down it) instead of pressing into it: the old constant
	# downward push slid it back on ramps, and the resulting tiny negative speed then stopped it from ever accelerating.
	var heading := f
	if is_on_floor():
		var fn := get_floor_normal()
		heading = f.slide(fn)
		heading = heading.normalized() if heading.length() > 0.01 else f
		velocity = heading * speed
	else:
		velocity.x = f.x * speed
		velocity.z = f.z * speed
		velocity.y = velocity.y - 22.0 * delta
	move_and_slide()
	settled_frames = settled_frames + 1 if is_on_floor() else 0
	# Collisions bleed speed: only motion along the heading survives.
	var real := get_real_velocity()
	var along := real.dot(heading)
	if absf(along) < absf(speed):
		speed = along
	_track_safety(delta)
	_animate(delta)

func _track_safety(delta: float) -> void:
	var void_y: float = (game.pit_zone.deepest_y - 3.0) if game and game.pit_zone else -8.0   # below the deepest quarry floor
	if global_position.y < void_y:
		recover() # fell out of the world: never leave it lost
		return
	safe_timer += delta
	if safe_timer > 1.5 and is_on_floor() and absf(speed) > 0.5:
		safe_timer = 0.0
		safe_position = global_position
		safe_yaw = rotation.y

## Manual or automatic recovery: back to the last position where it drove freely.
func recover() -> void:
	speed = 0.0
	velocity = Vector3.ZERO
	global_position = safe_position + Vector3(0, 0.2, 0)
	rotation.y = safe_yaw
	settled_frames = 0

# ------------------------------------------------------------------ animation & feedback

## Chase camera that never ends up behind a wall: a ray from the pivot toward the wanted spot stops it at the first
## solid thing (hangar back wall, building, rock), so you always see the vehicle, also inside the equipment garage.
const CAM_PROBE := 0.32          ## radius of the sphere swept from the pivot to the wanted camera spot (a little more than the near-plane half-size)

## Frame-rate-independent exponential easing: the same feel at 30 and 144 fps (a fixed lerp factor per frame is not).
static func ease_toward(cur: Vector3, goal: Vector3, rate: float, dt: float) -> Vector3:
	return cur.lerp(goal, 1.0 - exp(-rate * dt))

## The chase camera never ends up inside a wall: a SPHERE swept from the pivot toward the wanted spot stops at the first solid thing (hangar
## back wall, building, rock), so the lens never pokes into geometry. It pulls in at once when blocked (no clipping frame) and eases back out.
func _pull_camera_in(delta := -1.0) -> void:
	var dist := cam_distance()
	var want_local := Vector3(0, 1.6, dist)
	var from := cam_pivot.global_position
	var to := cam_pivot.to_global(want_local)
	var sp := SphereShape3D.new()
	sp.radius = CAM_PROBE
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sp
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.motion = to - from
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var fr: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(q)
	var goal := want_local
	if fr.size() == 2 and fr[0] < 1.0:
		goal = cam_pivot.to_local(from.lerp(to, fr[0]))
		if goal.length() < 1.8:
			goal = want_local.normalized() * 1.8
	if delta < 0.0 or goal.length() < camera.position.length():
		camera.position = goal                                      # blocked, or no time step given: place it at once
	else:
		camera.position = ease_toward(camera.position, goal, 7.0, delta)   # open space again: glide back out

func _animate(delta: float) -> void:
	if driven and cab_view and has_meta("cab"):
		var c: Dictionary = get_meta("cab")
		cam_pivot.rotation = Vector3(clampf(cam_pitch, -0.9, 0.45), swing if (vkind == "excavator" and turret != null) else cam_yaw, 0)
		camera.global_position = (c["ref"] as Node3D).to_global(c["eye"])          # the head of the person in the seat; the mouse looks around
	elif driven:
		_kick = move_toward(_kick, 0.0, delta * 0.06)
		cam_pivot.rotation = Vector3(cam_pitch + _kick, swing if (vkind == "excavator" and turret != null) else cam_yaw, 0)
		_pull_camera_in(delta)
		if absf(speed) > 1.0:
			cam_yaw = lerp_angle(cam_yaw, 0.0, 1.0 - exp(-0.6 * delta))      # the view swings back behind the machine at the same pace at any frame rate
	# wheels, rollers and tracks follow the distance the machine has really travelled along its heading: driven, delivered by script,
	# or carried by anything else, they turn the same way
	var travelled := 0.0
	if _prev_pos != Vector3.INF:
		var dp := global_position - _prev_pos
		if dp.length() < 3.0:
			travelled = dp.dot(forward())
	_prev_pos = global_position
	if absf(travelled) < 0.0005 and absf(speed) > 0.05 and not has_meta("delivering"):
		travelled = speed * delta
	_travel_speed = travelled / maxf(delta, 0.0001)
	for w in wheels:
		if rig_drives_wheels:
			break
		w.rotate_x(-travelled / float(w.get_meta("radius", 0.5)) if w.has_meta("radius") else -travelled / 0.5)
	# crawler tracks run at different speeds when the machine turns (a skid-steer: the inside track slows, the outside one speeds up)
	var yaw_d := angle_difference(_prev_yaw, rotation.y) if delta > 0.0 else 0.0
	_prev_yaw = rotation.y
	if absf(yaw_d) > 1.0:
		yaw_d = 0.0
	if rig != null and track_mats.size() == 2:
		# the Blender excavator scrolls its belts with the distance itself; turning on the spot runs the two sides against each other here (0.85 m = half the track gauge)
		for ti in range(2):
			var bm := track_mats[ti] as StandardMaterial3D
			bm.uv1_offset.x = fposmod(bm.uv1_offset.x + (-1.0 if ti == 0 else 1.0) * yaw_d * 0.85 / ExcavatorRig.BELT_PITCH, 1000.0)
	for ti in range(0 if rig_drives_wheels else track_mats.size()):
		var sm := track_mats[ti] as StandardMaterial3D
		var side := -1.0 if ti == 0 else 1.0                  # track_mats are built left (x -0.8) then right (x +0.8)
		sm.uv1_offset.x = fposmod(sm.uv1_offset.x + float(sm.get_meta("scroll_sign", 1.0)) * (travelled + side * yaw_d * 0.8), 1.0)
	var n := fleet.cargo_total(data)
	# cargo visuals ease: material pours out over the dump instead of vanishing in one frame
	shown_load = move_toward(shown_load, float(n), delta * maxf(4.0, absf(float(n) - shown_load) * 2.2))
	if rig != null:
		_animate_rig(delta)
		return
	if trig != null:
		_animate_truck(delta)
		return
	if drig != null:
		_animate_dozer(delta)
		return
	if lrig != null:
		_animate_loader(delta)
		return
	if has_bucket():
		bucket_lift = move_toward(bucket_lift, bucket_target, delta * 0.9)
		dump_timer = maxf(0.0, dump_timer - delta)
		curl_timer = maxf(0.0, curl_timer - delta)
		var lift := smoothstep(0.0, 1.0, bucket_lift) # hydraulic arm accelerates and settles
		var dig_curl := 0.0
		if vkind == "excavator" and digging:
			# digging: the boom lowers into the rock, the bucket bites and curls back, then the boom rises
			dig_phase += delta * 2.4
			lift = 0.5 + 0.5 * sin(dig_phase)
			dig_curl = maxf(0.0, -cos(dig_phase)) * 0.6
		if vkind == "excavator":
			_joints(delta)
		var base_th := lerpf(-0.12, 0.75, lift)
		var th := base_th + boom_m * 0.45
		if vkind == "excavator" and stick != null:
			# the bucket may bite into the soil but never goes through the ground: the boom is held up at the lowest the stick and bucket allow
			var guard := 0
			while _tip_y(th, stick_m * 0.7) < -0.3 and guard < 30:
				th += 0.03
				guard += 1
			boom_m = clampf((th - base_th) / 0.45, -1.0, 1.0)
		arm.rotation.x = th
		if vkind == "excavator":
			VehicleModels.update_boom_ram(self)
		if stick != null:
			stick.rotation.x = stick_m * 0.7
		var tilt := sin(clampf(dump_timer / 1.0, 0.0, 1.0) * PI) * 1.1
		var curl := sin(clampf(curl_timer / 0.6, 0.0, 1.0) * PI) * 0.45 + dig_curl
		bucket.rotation.x = -arm.rotation.x - (stick.rotation.x if stick != null else 0.0) - tilt + curl + curl_m * 0.8 # level while lifting, curls back to scoop
		bucket_load.visible = shown_load > 0.2
		if bucket_load.visible:
			bucket_load.scale.y = clampf(shown_load / float(fleet.capacity(data)), 0.2, 1.0)
			if not data["cargo"].is_empty():
				bucket_load.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(data["cargo"].keys()[0], "RockLimestone"))
	else:
		if unload_timer > 0.0:
			unload_timer -= delta
			if unload_timer <= 0.8 and not unload_target.is_empty():
				game.truck_finish_unload(self, unload_target)
				unload_target = {}
		var want := 0.95 if unload_timer > 0.0 else 0.0
		bed_tilt = move_toward(bed_tilt, want, delta * 1.1)
		bed.rotation.x = 0.95 * smoothstep(0.0, 0.95, bed_tilt) # the front of the bed (-z) rises about the rear hinge; the ram eases in and out
		VehicleModels.update_truck_ram(self)
		bed_load.visible = shown_load > 0.2
		if bed_load.visible:
			bed_load.scale.y = clampf(shown_load / float(fleet.capacity(data)), 0.15, 1.0)
			if not bed_load.has_meta("base_z"):
				bed_load.set_meta("base_z", bed_load.position.z)
			# the load slides toward the tailgate as the bed tips
			bed_load.position.z = float(bed_load.get_meta("base_z")) + 0.6 * smoothstep(0.4, 0.95, bed_tilt)
			if not data["cargo"].is_empty():
				bed_load.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(data["cargo"].keys()[0], "RockLimestone"))

## Wheel loader on its Blender rig: same game state as the procedural loader (bucket_target / curl_timer / dump_timer), the arms lift on
## their pivot with the bucket held level, the scoop curls it back, the dump rolls it forward; the frame articulates into turns.
func _animate_loader(delta: float) -> void:
	bucket_lift = move_toward(bucket_lift, bucket_target, delta * 0.9)
	dump_timer = maxf(0.0, dump_timer - delta)
	curl_timer = maxf(0.0, curl_timer - delta)
	var lift := smoothstep(0.0, 1.0, bucket_lift)
	var alpha := lift * LoaderKin.LIFT_MAX * 0.92
	var tilt := sin(clampf(dump_timer / 1.0, 0.0, 1.0) * PI) * 1.15
	var curl := sin(clampf(curl_timer / 0.6, 0.0, 1.0) * PI) * 0.5
	lrig.set_arm(alpha, -alpha - 0.06 - curl + tilt)
	lrig.drive(_travel_speed, delta)
	lrig.set_steer(_steer_show)
	bucket_load.visible = shown_load > 0.2
	if bucket_load.visible:
		bucket_load.scale.y = clampf(shown_load / float(fleet.capacity(data)), 0.2, 1.0)
		if not data["cargo"].is_empty():
			bucket_load.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(data["cargo"].keys()[0], "RockLimestone"))
	if dump_timer > 0.0 and _loader_dump_armed:
		_loader_dump_armed = false
		lrig.dust_burst()
		vaudio.dump()
	elif dump_timer <= 0.0:
		_loader_dump_armed = true
	if curl_timer > 0.55:
		lrig.dust_burst()
		vaudio.dig()
	var hyd := absf(lrig.arm_angle - _prev_arm) / maxf(delta, 0.001) / 0.8
	_prev_arm = lrig.arm_angle
	vaudio.update(delta, clampf(absf(speed) / maxf(fleet.max_speed(data), 0.1), 0.0, 1.0) * 0.7 + (0.3 if curl_timer > 0.0 else 0.0), hyd)

## Bulldozer: the blade follows its goal (set by the left click toggle and the arrow keys), tilts a little into turns, the two tracks run at
## their own speeds, the pile of pushed material grows in front of the blade and dust rises while it pushes.
func _animate_dozer(delta: float) -> void:
	if driven:
		blade_goal = clampf(blade_goal + (float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))) * 0.7 * delta, DozerKin.LIFT_MIN, DozerKin.LIFT_MAX)
		blade_tilt_goal = clampf(blade_tilt_goal + (float(Input.is_physical_key_pressed(KEY_X)) - float(Input.is_physical_key_pressed(KEY_Z))) * 0.35 * delta, -DozerKin.TILT_MAX, DozerKin.TILT_MAX)
	_dozer_alpha = move_toward(_dozer_alpha, blade_goal, delta * 0.8)
	_dozer_tilt = move_toward(_dozer_tilt, clampf(blade_tilt_goal - _steer_vis * 0.04 * minf(absf(speed), 3.0), -DozerKin.TILT_MAX, DozerKin.TILT_MAX), delta * 0.6)
	drig.set_blade(_dozer_alpha, _dozer_tilt)
	drig.drive_steered(_travel_speed, _steer_vis, delta)
	drig.set_steer_lever(_steer_vis)
	pushing_t = maxf(0.0, pushing_t - delta)
	drig.set_dust(pushing_t > 0.0)
	var frac := clampf(shown_load / maxf(float(fleet.capacity(data)), 1.0), 0.0, 1.0)
	var pile_mat: Material = MeshKit.mat("ExcavatedDirt")
	if not data["cargo"].is_empty() and not data["cargo"].has("soil"):
		pile_mat = MeshKit.mat(QuarryArt.ROCK_MAT.get(data["cargo"].keys()[0], "RockLimestone"))
	drig.set_pile(frac, pile_mat)
	var hyd := absf(drig.blade_alpha - _prev_blade) / maxf(delta, 0.001) / 0.8
	_prev_blade = drig.blade_alpha
	vaudio.update(delta, clampf(absf(speed) / maxf(fleet.max_speed(data), 0.1), 0.0, 1.0) * 0.7 + (0.35 if pushing_t > 0.0 else 0.0), hyd)

## Rig version of the truck animation: same game state as the procedural truck (unload_timer / bed_tilt / shown_load), but the bed
## tips on its real hinge with the ram pinned, the tailgate swings, wheels roll and steer and the body rides on its suspension.
func _animate_truck(delta: float) -> void:
	if unload_timer > 0.0:
		unload_timer -= delta
		if unload_timer <= 0.8 and not unload_target.is_empty():
			game.truck_finish_unload(self, unload_target)
			unload_target = {}
	var want := 0.95 if unload_timer > 0.0 else 0.0
	bed_tilt = move_toward(bed_tilt, want, delta * 1.1)
	trig.set_bed_angle(TruckKin.BED_MAX * smoothstep(0.0, 0.95, bed_tilt))
	trig.drive(_travel_speed, delta)
	trig.set_steer(_steer_show)
	# suspension: nose lifts when accelerating and dives when braking, the body leans out of a turn, a spring-damper takes the bumps
	var acc := (speed - _prev_speed) / maxf(delta, 0.001)
	_prev_speed = speed
	var k := 1.0 - exp(-6.0 * delta)
	_susp_pitch = lerpf(_susp_pitch, clampf(acc * 0.006, -0.05, 0.05), k)
	_susp_roll = lerpf(_susp_roll, clampf(_steer_show * speed * 0.004, -0.05, 0.05), k)
	_bounce_v += (-70.0 * _bounce - 7.0 * _bounce_v + (randf() - 0.5) * 0.9 * minf(absf(speed), 6.0) / 6.0) * delta
	_bounce += _bounce_v * delta
	var load_frac := clampf(shown_load / maxf(float(fleet.capacity(data)), 1.0), 0.0, 1.0)
	trig.set_suspension(_bounce - 0.015 * load_frac, _susp_pitch, _susp_roll)
	# cargo in the bed: fills with the real load and slides to the tailgate as the bed tips
	bed_load.visible = shown_load > 0.2
	if bed_load.visible:
		bed_load.scale.y = clampf(shown_load / float(fleet.capacity(data)), 0.15, 1.0)
		if not bed_load.has_meta("base_z"):
			bed_load.set_meta("base_z", bed_load.position.z)
		bed_load.position.z = float(bed_load.get_meta("base_z")) + 0.7 * smoothstep(0.4, 0.95, bed_tilt)
		if not data["cargo"].is_empty():
			bed_load.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(data["cargo"].keys()[0], "RockLimestone"))
	# the load lets go: dust at the tailgate and the clatter
	if bed_tilt > 0.55 and _tip_armed and shown_load > 0.2:
		_tip_armed = false
		trig.dust_burst()
		vaudio.dump()
	elif bed_tilt < 0.1:
		_tip_armed = true
	var hyd := absf(trig.bed_angle - _prev_bed) / maxf(delta, 0.001) / 0.9
	_prev_bed = trig.bed_angle
	vaudio.update(delta, clampf(absf(speed) / maxf(fleet.max_speed(data), 0.1), 0.0, 1.0) * 0.8 + (0.3 if unload_timer > 0.0 else 0.0), hyd)

## Rig version of the arm animation. Same game state as the procedural model (bucket_lift / digging / dump_timer / manual joints), but
## the arm is placed with IK so the bucket lip really goes to the dig point and the hydraulics follow the actual joint angles.
func _animate_rig(delta: float) -> void:
	bucket_lift = move_toward(bucket_lift, bucket_target, delta * 0.9)
	dump_timer = maxf(0.0, dump_timer - delta)
	curl_timer = maxf(0.0, curl_timer - delta)
	var lift := smoothstep(0.0, 1.0, bucket_lift)
	var dig_curl := 0.0
	if digging:
		dig_phase += delta * 2.4
		lift = 0.5 + 0.5 * sin(dig_phase)
		dig_curl = maxf(0.0, -cos(dig_phase))
	elif shown_load > 0.2 and dump_timer <= 0.0:
		lift = maxf(lift, 0.6)                              # carrying a load: the arm lifts it clear of the ground
	_joints(delta)
	var k := maxf(model_root.scale.z, 0.01)
	var reach := (size.z * 0.5 + float(fleet.spec(vtype).get("dig_reach", 4.0)) * 0.55 * clampf(1.0 + 0.5 * stick_m - 0.35 * boom_m, 0.45, 1.6)) / k
	if digging and dig_aim != Vector3.INF:
		var d := global_position.distance_to(Vector3(dig_aim.x, global_position.y, dig_aim.z))
		reach = lerpf(reach, d / k, 0.85)                   # reach for the rock / soil actually being dug
	reach = clampf(reach, 2.0, 3.5)
	var tip := Vector2(reach, 0.0).lerp(Vector2(2.4, 1.9), lift) + Vector2(stick_m * 0.5, boom_m * 0.6)
	var att := lerpf(0.2, -1.1, lift) - dig_curl * 0.55 + curl_m * 0.6
	var dump := sin(clampf(dump_timer / 1.0, 0.0, 1.0) * PI)
	if truck_aim != Vector3.INF and dump_timer > 0.0:
		# tipping into a truck: the bucket goes to the point above ITS bed (real height and distance), tips there, and comes back
		var u := 1.0 - dump_timer
		var env := smoothstep(0.0, 0.38, u) * (1.0 - smoothstep(0.82, 1.0, u))
		var d := Vector2(truck_aim.x - global_position.x, truck_aim.z - global_position.z).length() / k
		var h := (truck_aim.y - global_position.y - GROUND_LIFT) / k
		tip = tip.lerp(Vector2(d, h), env)
		att += 1.8 * smoothstep(0.5, 0.72, u) * (1.0 - smoothstep(0.86, 1.0, u))
	else:
		tip += Vector2(0.6, 0.3) * dump
		att += 1.8 * dump
		if dump_timer <= 0.0:
			truck_aim = Vector3.INF
	tip.y = maxf(tip.y, 0.0)
	rig.pose_for_tip(turret_yaw, tip, att)      # the cab eases toward `swing` (slewing inertia), as on the procedural excavator
	rig.drive(_travel_speed, delta)
	# bucket contents
	bucket_load.visible = shown_load > 0.2
	if bucket_load.visible:
		bucket_load.scale.y = clampf(shown_load / float(fleet.capacity(data)), 0.2, 1.0)
		if not data["cargo"].is_empty():
			bucket_load.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(data["cargo"].keys()[0], "RockLimestone"))
	# feedback: the bite at the bottom of each dig stroke, the dump
	if digging and lift < 0.12 and _bite_armed:
		_bite_armed = false
		_kick = -0.012
		if _dust != null:
			_dust.restart()
			_dust.emitting = true
		vaudio.dig()
	elif lift > 0.5:
		_bite_armed = true
	if dump_timer > 0.0 and _prev_dump <= 0.0:
		vaudio.dump()
		if _dust != null:
			_dust.restart()
			_dust.emitting = true
	_prev_dump = dump_timer
	# engine note follows speed and effort; hydraulic whine follows how fast the joints move
	var jt := Vector4(turret.rotation.y, arm.rotation.x, stick.rotation.x, bucket.rotation.x)
	var hyd := (absf(jt.x - _prev_joints.x) * 0.6 + absf(jt.y - _prev_joints.y) + absf(jt.z - _prev_joints.z) + absf(jt.w - _prev_joints.w)) / maxf(delta, 0.001) / 2.0
	_prev_joints = jt
	vaudio.update(delta, clampf(absf(speed) / maxf(fleet.max_speed(data), 0.1), 0.0, 1.0) * 0.7 + (0.35 if digging else 0.0), hyd)

## Height of the bucket's lowest point above the machine's ground for a boom angle `th` and stick angle `sg` (rad, positive = up / out).
func _tip_y(th: float, sg: float) -> float:
	var elbow := 1.05 - 0.1 * cos(th) + 1.95 * sin(th)
	return elbow - 0.95 * cos(th + sg)

## Manual excavator controls: arrows swing the upper body and raise / lower the boom, Z / X work the stick, C / V curl the bucket.
func _joints(delta: float) -> void:
	if driven and turret != null:
		joint_in["swing"] = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
		joint_in["boom"] = float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
		joint_in["stick"] = float(Input.is_physical_key_pressed(KEY_X)) - float(Input.is_physical_key_pressed(KEY_Z))
		joint_in["curl"] = float(Input.is_physical_key_pressed(KEY_C)) - float(Input.is_physical_key_pressed(KEY_V))
		_keys_live = true
	elif _keys_live:
		_keys_live = false         # the driver got out with a key held
		for k in joint_in:
			joint_in[k] = 0.0
	swing = wrapf(swing + float(joint_in["swing"]) * 1.1 * delta, -PI, PI)
	boom_m = clampf(boom_m + float(joint_in["boom"]) * 0.9 * delta, -1.0, 1.0)
	stick_m = clampf(stick_m + float(joint_in["stick"]) * 0.9 * delta, -1.0, 1.0)
	curl_m = clampf(curl_m + float(joint_in["curl"]) * 0.9 * delta, -1.0, 1.0)
	if turret != null:
		# the cab spins up and slows down like a real slewing ring (a short critically-damped ease), leans a touch into the start and stop,
		# and the engine shakes it very slightly while the machine is working
		var prev := turret_yaw
		turret_yaw = lerp_angle(turret_yaw, swing, 1.0 - exp(-14.0 * delta))
		var vel := angle_difference(prev, turret_yaw) / maxf(delta, 0.0001)
		var acc := (vel - _turret_vel) / maxf(delta, 0.0001)
		_turret_vel = vel
		_turret_roll = lerpf(_turret_roll, clampf(-acc * 0.004, -0.035, 0.035), 1.0 - exp(-12.0 * delta))
		turret.rotation.y = turret_yaw
		turret.rotation.z = _turret_roll
		_vib_t += delta
		var working := driven or digging
		# The engine shakes the cab a few millimetres about its REST height. (This used to write the shake as the absolute height, so the whole upper body slid down
		# from its slewing ring into the tracks: 0.78 m in 15 s when idle, at once while digging.)
		turret.position.y = turret_rest_y + ((0.004 * sin(_vib_t * 53.0) + 0.002 * sin(_vib_t * 31.0)) if working else move_toward(turret.position.y - turret_rest_y, 0.0, delta * 0.05))

func start_unload(target: Dictionary) -> void:
	unload_target = target
	unload_timer = 2.2
	speed = 0.0

func save_into(record: Dictionary) -> void:
	record["position"] = [global_position.x, global_position.y, global_position.z]
	record["yaw"] = rotation.y
