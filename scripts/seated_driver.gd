extends Node3D
class_name SeatedDriver
## The person at the controls: the operator model (THE VEIL cast rig) sitting in the cab, attached to the cab node so it travels, turns and tilts with the machine.
## One per vehicle, built lazily by `attach_to(v)`, shown only while that machine is driven. Placement comes from named markers on the cab node:
##   Marker_DriverSeat       the pelvis (seat point), Marker_DriverCamera the driver's eyes, Marker_VehicleExitPoint a standing place beside the door
## (created from the cab's own eye/door data, so every drivable machine - excavator, trucks, loaders, dozer - works the same way).
## `first_person` hides only the head (so the camera inside it never sees the inside of a skull); the body stays for the hands on the controls.

const HIP_TO_EYE := 0.70                         ## the model's hip joint to its eyes (standing, scale 1)

var vehicle
var body: PlayerBody                         ## the protagonist (CHR_QD_Player)
var rig: VeilRig
var skel: Skeleton3D
var first_person := false : set = _set_first_person
var _head := -1

## The marker nodes a cab gets (idempotent). Returns the cab dictionary's `ref` node.
static func ensure_markers(v) -> Node3D:
	var c: Dictionary = QuarryBoarding.cab(v)
	if c.is_empty():
		return null
	var ref: Node3D = c["ref"]
	var eye: Vector3 = c["eye"]
	_marker(ref, "Marker_DriverCamera", eye)
	_marker(ref, "Marker_DriverSeat", eye + Vector3(0.0, -HIP_TO_EYE, 0.12))
	var side: float = c["side"]
	var dc: Vector3 = c["door_c"]
	var ground_y: float = ref.to_local(Vector3(0, v.global_position.y, 0)).y        # the ground in the cab's own space
	_marker(ref, "Marker_VehicleExitPoint", Vector3(dc.x + side * 1.3, ground_y, dc.z))
	return ref

static func _marker(ref: Node3D, n: String, at: Vector3) -> Node3D:
	var m := ref.get_node_or_null(n) as Node3D
	if m == null:
		m = Node3D.new()
		m.name = n
		ref.add_child(m)
	m.position = at
	return m

static func marker(v, n: String) -> Node3D:
	var c: Dictionary = QuarryBoarding.cab(v)
	return null if c.is_empty() else (c["ref"] as Node3D).get_node_or_null("Marker_" + n) as Node3D

## Builds the driver for `v` (once) and returns it, hidden. Null for a machine without a cab.
static func attach_to(v) -> SeatedDriver:
	if v == null or not QuarryBoarding.has_cab(v):
		return null
	if v.has_meta("seated_driver") and is_instance_valid(v.get_meta("seated_driver")):
		return v.get_meta("seated_driver")
	var ref := ensure_markers(v)
	var d := SeatedDriver.new()
	d.name = "SeatedDriver"
	d.vehicle = v
	ref.add_child(d)
	d.build()
	d.visible = false
	v.set_meta("seated_driver", d)
	return d

func build() -> void:
	body = PlayerBody.new()
	add_child(body)
	if not body.build():
		return
	skel = body.skel
	rig = body.rig
	body.seated = true                              # legs bent, the satchel off the seat
	for gi in body.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var kind := str(vehicle.vtype)
	rig.wheel_hands = not (kind.contains("excavator") or kind.contains("dozer"))      # a steering wheel on trucks and loaders, the consoles' panel on the tracked machines
	_head = rig.bone("Head")
	_place()

## Pelvis on the seat marker: the rig's origin is the floor under it (hips stand 0.95 above the feet, SEAT_DROP lower when seated).
func _place() -> void:
	var seat := get_parent().get_node_or_null("Marker_DriverSeat") as Node3D
	if seat == null:
		return
	position = seat.position - Vector3(0.0, 0.95 - VeilRig.SEAT_DROP, 0.0)
	rotation = Vector3.ZERO

func show_driver(on: bool) -> void:
	visible = on
	if on:
		_place()

func _set_first_person(on: bool) -> void:
	first_person = on
	if skel != null and _head >= 0:
		skel.set_bone_pose_scale(_head, Vector3.ONE * (0.001 if on else 1.0))

func _process(delta: float) -> void:
	if rig == null or not visible:
		return
	rig.pose(delta, "idle", 0.0, "operator", false)
	if _head >= 0 and first_person:
		skel.set_bone_pose_scale(_head, Vector3.ONE * 0.001)          # (the pose pass rewrites rotations only, but keep it hidden regardless)
	# hands follow the road: the wheel turns with the steering input
	if rig.wheel_hands and vehicle != null:
		rig.wheel_angle = lerpf(rig.wheel_angle, float(vehicle.input.get("steer", 0.0)) * 1.2, 1.0 - exp(-8.0 * delta))
