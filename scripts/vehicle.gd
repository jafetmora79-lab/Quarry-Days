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

var driven := false
var auto_drive := false         ## the auto crew (scripts/auto_crew.gd) is steering it: `input` is obeyed like a driver's, but with no camera
var speed := 0.0
var input := {"throttle": 0.0, "steer": 0.0, "brake": false}
var settled_frames := 0

var cam_pivot: Node3D
var camera: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.32

# loader
var arm: Node3D
var turret: Node3D            ## excavator: the upper body, swings on the slewing ring
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
var bed_load: MeshInstance3D
var bed_tilt := 0.0
var unload_timer := 0.0
var unload_target := {}
var wheels: Array = []
var track_mats: Array = []     ## excavator tread materials: the texture scrolls as the machine moves
var _prev_pos := Vector3.INF
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
	add_child(model_root)
	var base := Vector3(2.0, 1.5, 3.0) if vkind == "loader" else (Vector3(2.2, 1.8, 4.6) if vkind == "truck" else Vector3(2.0, 2.2, 3.4))
	model_root.scale = Vector3(size.x / base.x, size.y / base.y, size.z / base.z)    # bigger machines are the same build, larger
	match vkind:
		"loader": _build_loader()
		"excavator": VehicleModels.excavator(self)
		_: _build_truck()
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
func _build_loader() -> void:
	VehicleModels.loader(self)

func _build_truck() -> void:
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
	if vkind == "loader":
		return global_transform * Vector3(0, 0, -size.z * 0.5 - 1.1)
	if vkind == "excavator":
		var reach := float(fleet.spec(vtype).get("dig_reach", 4.0)) * 0.55 * clampf(1.0 + 0.5 * stick_m - 0.35 * boom_m, 0.45, 1.6)
		return global_transform * (Basis(Vector3.UP, swing) * Vector3(0, 0, -size.z * 0.5 - reach))
	return global_transform * Vector3(0, 0, size.z * 0.5 + 1.0)

func bed_center() -> Vector3:
	return global_transform * Vector3(0, 0, 0.7)

# ------------------------------------------------------------------ driving

func rotate_camera(rel: Vector2) -> void:
	if vkind == "excavator" and turret != null:
		swing = wrapf(swing - rel.x * 0.003, -PI, PI)      # the mouse spins the cab on its slewing ring; the tracks stay put (WASD)
	else:
		cam_yaw -= rel.x * 0.003
	cam_pitch = clampf(cam_pitch - rel.y * 0.003, -1.1, 0.25)

func control(delta: float) -> void:
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
	if driven:
		cam_pivot.rotation = Vector3(cam_pitch, swing if (vkind == "excavator" and turret != null) else cam_yaw, 0)
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
	for w in wheels:
		w.rotate_x(-travelled / float(w.get_meta("radius", 0.5)) if w.has_meta("radius") else -travelled / 0.5)
	# crawler tracks run at different speeds when the machine turns (a skid-steer: the inside track slows, the outside one speeds up)
	var yaw_d := angle_difference(_prev_yaw, rotation.y) if delta > 0.0 else 0.0
	_prev_yaw = rotation.y
	if absf(yaw_d) > 1.0:
		yaw_d = 0.0
	for ti in range(track_mats.size()):
		var sm := track_mats[ti] as StandardMaterial3D
		var side := -1.0 if ti == 0 else 1.0                  # track_mats are built left (x -0.8) then right (x +0.8)
		sm.uv1_offset.x = fposmod(sm.uv1_offset.x + float(sm.get_meta("scroll_sign", 1.0)) * (travelled + side * yaw_d * 0.8), 1.0)
	var n := fleet.cargo_total(data)
	# cargo visuals ease: material pours out over the dump instead of vanishing in one frame
	shown_load = move_toward(shown_load, float(n), delta * maxf(4.0, absf(float(n) - shown_load) * 2.2))
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
		turret.position.y = (0.004 * sin(_vib_t * 53.0) + 0.002 * sin(_vib_t * 31.0)) if working else move_toward(turret.position.y, 0.0, delta * 0.05)

func start_unload(target: Dictionary) -> void:
	unload_target = target
	unload_timer = 2.2
	speed = 0.0

func save_into(record: Dictionary) -> void:
	record["position"] = [global_position.x, global_position.y, global_position.z]
	record["yaw"] = rotation.y
