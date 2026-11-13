extends CharacterBody3D
class_name QuarryVehicle
## Lightweight kinematic heavy-machinery controller shared by the front loader and the
## dump truck. Arcade bicycle steering, momentum, load-dependent acceleration and
## move_and_slide collisions against terrain, structures, workers and other vehicles.
## Material lives in QuarryFleet as unit counts; the meshes only visualise it.

const RESOURCE_COLORS := {"limestone": Color(0.67, 0.66, 0.56), "coal": Color(0.17, 0.19, 0.21), "iron_ore": Color(0.52, 0.29, 0.23), "crushed_stone": Color(0.75, 0.73, 0.66), "copper_ore": Color(0.36, 0.52, 0.42), "gold_ore": Color(0.78, 0.62, 0.24)}

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
	cam_yaw -= rel.x * 0.003
	cam_pitch = clampf(cam_pitch - rel.y * 0.003, -1.1, 0.25)

func control(delta: float) -> void:
	data = fleet.vehicle(vehicle_id)
	if data.is_empty():
		return
	var throttle := float(input["throttle"]) if driven else 0.0
	var steer := float(input["steer"]) if driven else 0.0
	var braking := bool(input["brake"]) if driven else true
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
	var parked := not driven and absf(speed) < 0.01 and is_on_floor() and settled_frames > 5
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
func _pull_camera_in() -> void:
	var dist := cam_distance()
	var want_local := Vector3(0, 1.6, dist)
	var from := cam_pivot.global_position
	var to := cam_pivot.to_global(want_local)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		camera.position = want_local
		return
	var p: Vector3 = hit["position"] + (hit["normal"] as Vector3) * 0.35
	var l := cam_pivot.to_local(p)
	camera.position = l if l.length() > 1.8 else want_local.normalized() * 1.8

func _animate(delta: float) -> void:
	if driven:
		cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
		_pull_camera_in()
		if absf(speed) > 1.0:
			cam_yaw = lerp_angle(cam_yaw, 0.0, delta * 0.6)
	for w in wheels:
		w.rotate_x(-speed * delta / 0.5)
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
		arm.rotation.x = lerpf(-0.12, 0.75, lift) + boom_m * 0.45
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
		bed.rotation.x = -0.95 * smoothstep(0.0, 0.95, bed_tilt) # ram eases in and out
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
	swing = clampf(swing + float(joint_in["swing"]) * 1.1 * delta, -PI * 0.75, PI * 0.75)
	boom_m = clampf(boom_m + float(joint_in["boom"]) * 0.9 * delta, -1.0, 1.0)
	stick_m = clampf(stick_m + float(joint_in["stick"]) * 0.9 * delta, -1.0, 1.0)
	curl_m = clampf(curl_m + float(joint_in["curl"]) * 0.9 * delta, -1.0, 1.0)
	if turret != null:
		turret.rotation.y = swing

func start_unload(target: Dictionary) -> void:
	unload_target = target
	unload_timer = 2.2
	speed = 0.0

func save_into(record: Dictionary) -> void:
	record["position"] = [global_position.x, global_position.y, global_position.z]
	record["yaw"] = rotation.y
