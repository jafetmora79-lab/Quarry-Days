extends CharacterBody3D
class_name QuarryCart
## Phase 9.6: a hand cart or wheelbarrow standing in the yard. It is a real container (QuarryState.cart_load): the player loads it from
## the bag or the storage crate, pushes (wheelbarrows) or pulls (hand cart) it, and unloads it into the crate or the selling station.
## Movement is deliberately simple and stable: while held, the cart is eased toward a spot in front of (or behind) the player and slides
## along walls through move_and_slide(); if it cannot keep up the main script lets go of it. No rigid-body physics.

const SIZE := {"hand_cart": Vector3(0.95, 0.9, 1.5), "wheelbarrow": Vector3(0.7, 0.9, 1.6), "reinforced_wheelbarrow": Vector3(0.8, 0.95, 1.7)}

var cart_id := ""
var model: Node3D
var held := false

## "push": the player stands behind the handles; "pull": the player walks ahead of the pull bar.
static func mode_of(id: String) -> String:
	return "pull" if id == "hand_cart" else "push"

## Where the cart origin should be relative to the player: distance along the player's facing (negative = behind).
static func offset_of(id: String) -> float:
	return -2.0 if id == "hand_cart" else 1.8

func setup(id: String) -> void:
	cart_id = id
	name = "Cart_" + id
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.4
	set_meta("kind", "cart")
	set_meta("cart", id)
	model = GearModels.build_prop(id)
	add_child(model)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var sz: Vector3 = SIZE.get(id, Vector3(0.9, 0.9, 1.5))
	box.size = sz
	cs.shape = box
	cs.position = Vector3(0, sz.y * 0.5, 0.15)
	add_child(cs)

## Eases toward `target` (world position) and turns to `yaw`. Returns how far the cart still is from the target (metres).
func follow(target: Vector3, yaw: float, delta: float) -> float:
	var d := target - global_position
	d.y = 0.0
	var v := d * 9.0
	if v.length() > 7.0:
		v = v.normalized() * 7.0
	velocity.x = v.x
	velocity.z = v.z
	velocity.y -= 20.0 * delta
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * 9.0))
	move_and_slide()
	var rest := target - global_position
	rest.y = 0.0
	return rest.length()

## Shows what the cart carries: the pile grows with the load and takes the colour of the main material.
func show_load(contents: Dictionary, capacity: int) -> void:
	var load: Node3D = model.get_node_or_null("Load") if model else null
	if load == null:
		return
	var total := 0
	var top := ""
	var top_n := -1
	for k in contents:
		total += int(contents[k])
		if int(contents[k]) > top_n:
			top_n = int(contents[k])
			top = str(k)
	var fill := clampf(float(total) / float(maxi(1, capacity)), 0.0, 1.0)
	load.visible = total > 0
	load.scale = Vector3(1.0, 0.25 + 0.9 * fill, 1.0)
	if top != "":
		(load.get_meta("pile") as MeshInstance3D).material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(top, "RockLimestone"))
