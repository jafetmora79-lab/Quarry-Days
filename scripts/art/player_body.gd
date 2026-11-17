extends Node3D
class_name PlayerBody
## The protagonist's body (assets/characters/CHR_QD_Player.glb, built by tools/character_cast/build_cast.py from the Quarry Owner spec): the same 22-bone humanoid as the whole cast, so VeilRig
## animates it unchanged (idle, walk, run, turn, carry, interact, seated). The mining satchel is four separate meshes (QD_Player_Bag0..3) of which exactly one is shown, chosen from how full
## the BAG is: EMPTY 0-25 %, PARTIAL 26-60 %, MOSTLY FULL 61-90 %, FULL 91-100 %. The cross-body strap is part of the body and always shown.
## In first person the body is only a shadow (nothing to obstruct the camera); in a vehicle it is the seated driver (the satchel is taken off the seat while seated).

const MODEL := "res://assets/characters/CHR_QD_Player.glb"
const BAG_LIMITS := [25.0, 60.0, 90.0]            ## percent of the bag where the next state starts

static var _packed: PackedScene

var rig: VeilRig
var skel: Skeleton3D
var bags: Array = []                               ## the four satchel meshes, in order of fullness
var bag_state := -1
var seated := false : set = set_seated
var first_person := false : set = set_first_person
var shadow_only := false : set = set_shadow_only
var _head := -1

## 0..3 for a bag holding `used` of `cap` units.
static func state_for(used: int, cap: int) -> int:
	if used <= 0 or cap <= 0:
		return 0
	var pct := 100.0 * float(used) / float(cap)
	if pct <= BAG_LIMITS[0]:
		return 0
	if pct <= BAG_LIMITS[1]:
		return 1
	if pct <= BAG_LIMITS[2]:
		return 2
	return 3

func build() -> bool:
	if _packed == null:
		_packed = load(MODEL)
	var body: Node3D = _packed.instantiate()
	body.name = "Model"
	add_child(body)
	for gi in body.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var found := body.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	skel = found[0]
	rig = VeilRig.new()
	rig.setup(skel, 0.0)
	_head = skel.find_bone("Head")
	bags = [null, null, null, null]
	for mi in body.find_children("*Bag*", "MeshInstance3D", true, false):
		var nm := str(mi.name)
		for i in 4:
			if nm.ends_with("Bag%d" % i) or nm.contains("Bag%d" % i):
				bags[i] = mi
	set_bag_state(0)
	return true

func set_bag_state(i: int) -> void:
	if i == bag_state:
		return
	bag_state = i
	_apply_bag()

func _apply_bag() -> void:
	for k in bags.size():
		if bags[k] != null:
			(bags[k] as Node3D).visible = (k == bag_state) and not seated

## Updates the satchel from the real BAG: units carried and its capacity.
func set_bag(used: int, cap: int) -> void:
	set_bag_state(state_for(used, cap))

func set_seated(on: bool) -> void:
	seated = on
	if rig != null:
		rig.seated = on
	_apply_bag()

## Hides only the head (and the hair on it) so the camera inside it never sees the inside of a skull.
func set_first_person(on: bool) -> void:
	first_person = on
	if skel != null and _head >= 0:
		skel.set_bone_pose_scale(_head, Vector3.ONE * (0.001 if on else 1.0))

## The body as a shadow only (on-foot first person): it casts the character's shadow and is never drawn into the camera.
func set_shadow_only(on: bool) -> void:
	shadow_only = on
	for gi in find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

## One animation step. state: idle / walk / turn / interact / work ...; speed in m/s; carrying: a load in the hands.
func animate(delta: float, state: String, speed: float, work_kind := "miner", carrying := false, phase := -1.0, yaw_rate := 0.0) -> void:
	if rig != null:
		rig.pose(delta, state, speed, work_kind, carrying, phase, yaw_rate)
	if first_person and skel != null and _head >= 0:
		skel.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
