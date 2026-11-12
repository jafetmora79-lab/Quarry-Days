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
	add_child(shape)
	if vtype == "loader":
		_build_loader()
	else:
		_build_truck()
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0, 2.0, 0)
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 7.5 if vtype == "truck" else 6.5)
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

## Point in front of the loader bucket / behind the truck bed where material is handled.
func work_point() -> Vector3:
	if vtype == "loader":
		return global_transform * Vector3(0, 0, -size.z * 0.5 - 1.1)
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
	velocity.x = f.x * speed
	velocity.z = f.z * speed
	velocity.y = velocity.y - 22.0 * delta if not is_on_floor() else -0.5
	move_and_slide()
	settled_frames = settled_frames + 1 if is_on_floor() else 0
	# Collisions bleed speed: only motion along the heading survives.
	var real := get_real_velocity()
	var along := real.x * f.x + real.z * f.z
	if absf(along) < absf(speed):
		speed = along
	_track_safety(delta)
	_animate(delta)

func _track_safety(delta: float) -> void:
	if global_position.y < -8.0:
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
	var dist := 7.5 if vtype == "truck" else 6.5
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
	if vtype == "loader":
		bucket_lift = move_toward(bucket_lift, bucket_target, delta * 0.9)
		dump_timer = maxf(0.0, dump_timer - delta)
		curl_timer = maxf(0.0, curl_timer - delta)
		var lift := smoothstep(0.0, 1.0, bucket_lift) # hydraulic arm accelerates and settles
		arm.rotation.x = lerpf(-0.12, 0.75, lift)
		var tilt := sin(clampf(dump_timer / 1.0, 0.0, 1.0) * PI) * 1.1
		var curl := sin(clampf(curl_timer / 0.6, 0.0, 1.0) * PI) * 0.45
		bucket.rotation.x = -arm.rotation.x - tilt + curl # level while lifting, curls back to scoop
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

func start_unload(target: Dictionary) -> void:
	unload_target = target
	unload_timer = 2.2
	speed = 0.0

func save_into(record: Dictionary) -> void:
	record["position"] = [global_position.x, global_position.y, global_position.z]
	record["yaw"] = rotation.y
