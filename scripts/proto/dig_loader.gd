extends CharacterBody3D
class_name DigLoader
## PROTOTYPE: front loader that digs real volume out of DigTerrain and carries it in its bucket.
## Reuses the Phase 4 loader model (VehicleModels.loader). LMB lowers the bucket (it cuts the ground as you
## drive into it); releasing carries; RMB raises and tips the bucket (it pours out at the lip).

const BUCKET_CAPACITY := 1.6          # m3
const HALF_WIDTH := 1.0
const LOWERED := -0.66
const CARRY := -0.05
const RAISED := 0.7
const POUR_RATE := 1.1                # m3/s while tipped

var terrain: DigTerrain
var driven := false
var input := {"throttle": 0.0, "steer": 0.0, "brake": false, "dig": false, "dump": false}
var speed := 0.0
var wheels: Array = []
var arm: Node3D
var bucket: Node3D
var bucket_load: MeshInstance3D
var lip: Marker3D
var visual: Node3D
var cam_pivot: Node3D
var camera: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.3
var arm_angle := CARRY
var tilt := -0.25
var load_dirt := 0.0
var load_rock := 0.0
var cutting := false
var pouring := false
var stats := {"cut": 0.0, "poured": 0.0}
var last_cut_volume := 0.0

func setup(t: DigTerrain) -> void:
	terrain = t
	name = "DigLoader"
	collision_layer = 8
	collision_mask = 1 | 4
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(42)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.3, 3.0)
	cs.shape = box
	cs.position = Vector3(0, 0.75, 0.2)
	add_child(cs)
	VehicleModels.loader(self)
	visual = Node3D.new()
	visual.name = "Visual"
	for c in get_children():
		if not c is CollisionShape3D:
			remove_child(c)
			visual.add_child(c)
	add_child(visual)
	lip = Marker3D.new()
	lip.position = Vector3(0, -0.16, -0.64)
	bucket.add_child(lip)
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0, 2.2, 0)
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.8, 7.0)
	camera.far = 150.0
	cam_pivot.add_child(camera)

func load_total() -> float:
	return load_dirt + load_rock

func rock_fraction() -> float:
	var t := load_total()
	return load_rock / t if t > 0.0 else 0.0

func lip_position() -> Vector3:
	return lip.global_position

func rotate_camera(rel: Vector2) -> void:
	cam_yaw -= rel.x * 0.003
	cam_pitch = clampf(cam_pitch - rel.y * 0.003, -1.1, 0.25)

func _physics_process(delta: float) -> void:
	var throttle: float = input["throttle"] if driven else 0.0
	var steer: float = input["steer"] if driven else 0.0
	var braking: bool = input["brake"] if driven else true
	var want_dig: bool = driven and bool(input["dig"])
	var want_dump: bool = driven and bool(input["dump"])
	# --- bucket: lowered while digging, raised and tipped while dumping, carried otherwise
	var arm_goal := CARRY
	var tilt_goal := -0.25
	if want_dump:
		arm_goal = RAISED
		tilt_goal = 1.1 if absf(arm_angle - RAISED) < 0.25 else -0.25
	elif want_dig:
		arm_goal = LOWERED
		tilt_goal = 0.0
	arm_angle = move_toward(arm_angle, arm_goal, delta * 1.1)
	tilt = move_toward(tilt, tilt_goal, delta * 1.6)
	arm.rotation.x = arm_angle
	bucket.rotation.x = -arm_angle - tilt
	# --- drive: heavy, momentum, slower when loaded or cutting
	var fill := load_total() / BUCKET_CAPACITY
	var top := 5.2 * (1.0 - 0.25 * fill)
	if cutting:
		top = minf(top, 2.2)
	var accel := 3.0 * (1.0 - 0.35 * fill)
	if braking:
		speed = move_toward(speed, 0.0, 9.0 * delta)
	elif absf(throttle) > 0.05:
		if signf(throttle) != signf(speed) and absf(speed) > 0.2:
			speed = move_toward(speed, 0.0, 9.0 * delta)
		else:
			speed = clampf(speed + throttle * accel * delta, -2.6, top)
	else:
		speed = move_toward(speed, 0.0, 1.8 * delta)
	if speed > top:
		speed = move_toward(speed, top, 6.0 * delta)
	rotation.y -= steer * 1.4 * clampf(speed / 2.5, -1.0, 1.0) * delta
	var f := -global_transform.basis.z
	velocity.x = f.x * speed
	velocity.z = f.z * speed
	velocity.y = velocity.y - 22.0 * delta if not is_on_floor() else -0.5
	move_and_slide()
	var real := get_real_velocity()
	var along := real.x * f.x + real.z * f.z
	if absf(along) < absf(speed):
		speed = along
	_follow_ground(delta)
	_work_ground(delta)
	_animate(delta)
	if driven:
		cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
		if absf(speed) > 1.0:
			cam_yaw = lerp_angle(cam_yaw, 0.0, delta * 0.6)

## Tilt the body model to the slope under it (wheels stay on the ground visually).
func _follow_ground(delta: float) -> void:
	var f := -global_transform.basis.z
	var r := global_transform.basis.x
	var hf := terrain.height_at(global_position.x + f.x * 1.3, global_position.z + f.z * 1.3)
	var hb := terrain.height_at(global_position.x - f.x * 1.3, global_position.z - f.z * 1.3)
	var hl := terrain.height_at(global_position.x - r.x * 0.9, global_position.z - r.z * 0.9)
	var hr := terrain.height_at(global_position.x + r.x * 0.9, global_position.z + r.z * 0.9)
	var pitch := atan2(hf - hb, 2.6)
	var roll := atan2(hr - hl, 1.8)
	visual.rotation.x = lerp_angle(visual.rotation.x, pitch, minf(1.0, delta * 6.0))
	visual.rotation.z = lerp_angle(visual.rotation.z, clampf(roll, -0.4, 0.4), minf(1.0, delta * 6.0))

func _work_ground(delta: float) -> void:
	cutting = false
	pouring = false
	var lp := lip_position()
	var bt := bucket.global_transform.basis
	var right := Vector3(bt.x.x, 0, bt.x.z).normalized()
	var fwd := Vector3(-bt.z.x, 0, -bt.z.z).normalized()
	# digging: bucket low, lip below the surface, room left in the bucket
	if driven and arm_angle < LOWERED + 0.35 and tilt < 0.4 and load_total() < BUCKET_CAPACITY - 0.001:
		var res := terrain.cut_box(lp, right, fwd, HALF_WIDTH, 0.15, 0.4, minf(BUCKET_CAPACITY - load_total(), 3.0 * delta))
		var got: float = res["dirt"] + res["rock"]
		if got > 0.0:
			load_dirt += res["dirt"]
			load_rock += res["rock"]
			stats["cut"] += got
			last_cut_volume = got
			cutting = true
	# pouring: bucket raised and tipped
	if tilt > 0.55 and load_total() > 0.0:
		var amount := minf(load_total(), POUR_RATE * delta)
		var rf := rock_fraction()
		pouring = true
		var spot := lp + fwd * 0.35
		var left := pour_to(spot, amount, rf)
		var poured := amount - left
		load_rock = maxf(0.0, load_rock - poured * rf)
		load_dirt = maxf(0.0, load_dirt - poured * (1.0 - rf))
		stats["poured"] += poured
		if load_total() < 0.0005:
			load_dirt = 0.0
			load_rock = 0.0

## Overridden by the test scene so material can go into the box instead of the ground.
var pour_target := Callable()
func pour_to(spot: Vector3, amount: float, rock_frac: float) -> float:
	if pour_target.is_valid():
		return pour_target.call(spot, amount, rock_frac)
	return terrain.deposit(spot, 0.9, amount, rock_frac)

func _animate(delta: float) -> void:
	for w in wheels:
		w.rotate_x(-speed * delta / 0.55)
	var t := load_total()
	bucket_load.visible = t > 0.01
	if bucket_load.visible:
		bucket_load.scale = Vector3(1.0, clampf(t / BUCKET_CAPACITY * 1.3, 0.25, 1.4), 1.0)
		bucket_load.material_override = MeshKit.mat("RockLimestone" if rock_fraction() > 0.5 else "ExcavatedDirt")
