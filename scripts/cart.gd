extends CharacterBody3D
class_name QuarryCart
## Phase 9.6: a hand cart or wheelbarrow standing in the yard. It is a real container (QuarryState.cart_load): the player loads it from
## the bag or the storage crate, pushes (wheelbarrows) or pulls (hand cart) it, and unloads it into the crate or the office.
## Movement is deliberately simple and stable: while held, the cart is eased toward a spot in front of (or behind) the player and slides
## along walls through move_and_slide(); if it cannot keep up the main script lets go of it. No rigid-body physics.

const SIZE := {"hand_cart": Vector3(0.95, 0.9, 1.5), "wheelbarrow": Vector3(0.7, 0.9, 1.6), "reinforced_wheelbarrow": Vector3(0.8, 0.95, 1.7)}

var cart_id := ""
var model: Node3D
var held := false
var tilt: Node3D                 ## carries the model; hinged at the front axle so the barrow can tip its load out over the wheel
var wheels: Array = []           ## the model's turning wheels
var tip_t := 0.0                 ## > 0 while tipping out (seconds left)
var _prev := Vector3.INF
var _prev_yaw := 0.0
var _roll := 0.0
var _bob := 0.0
var _anim_frame := -1
var grip_hands: Node3D           ## the player's gloved hands on the handles of a push cart: shown only while the cart is held
var rolled_total := 0.0         ## signed radians the first wheel has turned in all (tests)
const TIP_TIME := 1.6
const TIP_ANGLE := 0.62
const AXLE := {"hand_cart": Vector3(0, 0.3, 0.1), "wheelbarrow": Vector3(0, 0.24, -0.62), "reinforced_wheelbarrow": Vector3(0, 0.26, -0.72)}

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
	tilt = Node3D.new()
	tilt.name = "Tilt"
	var axle: Vector3 = AXLE.get(id, Vector3(0, 0.25, 0))
	tilt.position = axle
	model.position = -axle
	add_child(tilt)
	tilt.add_child(model)
	for w in model.get_children():
		if str(w.name).begins_with("Wheel"):
			wheels.append(w)
	if mode_of(id) == "push":
		_add_grip_hands()
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
	_animate(delta)
	var rest := target - global_position
	rest.y = 0.0
	return rest.length()

## Wheels turn with the distance really rolled, the body leans into a turn and bobs gently over the ground, and unloading tips it forward over the front
## wheel (the load slides toward the lip as it tips).
const GRIPS := {"wheelbarrow": Vector3(0.18, 0.42, 1.05), "reinforced_wheelbarrow": Vector3(0.2, 0.44, 1.12)}

## Gloved fists closed on the two handle grips with the jacket sleeves running back toward the player, so someone is visibly pushing the barrow. (A hand
## cart is pulled from the bar behind the player's back, out of view, so it has none.)
func _add_grip_hands() -> void:
	var g: Vector3 = GRIPS.get(cart_id, Vector3(0.18, 0.42, 1.05))
	grip_hands = Node3D.new()
	grip_hands.name = "GripHands"
	model.add_child(grip_hands)
	for sx in [-1.0, 1.0]:
		var at := Vector3(sx * g.x, g.y + 0.015, g.z)
		var dir := Vector3(sx * 0.3, 0.35, 0.89).normalized()                    # back toward the player, slightly up and out
		var basis := VeilRig.basis_zy(dir, Vector3.UP)
		var fist := MeshKit.inst(grip_hands, MeshKit.box(Vector3(0.09, 0.08, 0.1)), MeshKit.flat(QuarryToolView.GLOVE), at)
		fist.basis = basis
		var band := MeshKit.inst(grip_hands, MeshKit.box(Vector3(0.1, 0.1, 0.02)), MeshKit.flat(QuarryToolView.BAND), at + dir * 0.08)
		band.basis = basis
		var arm := MeshKit.inst(grip_hands, MeshKit.box(Vector3(0.095, 0.095, 0.5)), MeshKit.flat(QuarryToolView.SLEEVE), at + dir * 0.34)
		arm.basis = basis
		for gi in [fist, band, arm]:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grip_hands.visible = false

func _physics_process(delta: float) -> void:
	if _anim_frame != Engine.get_physics_frames():       # not driven by follow() this frame: still settle, tip and (if shoved) roll
		_animate(delta)

func _animate(delta: float) -> void:
	_anim_frame = Engine.get_physics_frames()
	if grip_hands:
		grip_hands.visible = held
	var travelled := 0.0
	var fwd := -global_transform.basis.z
	if _prev != Vector3.INF:
		var dp := global_position - _prev
		dp.y = 0.0
		if dp.length() < 2.0:
			travelled = dp.dot(fwd)
	_prev = global_position
	for w in wheels:
		w.rotate_x(-travelled / float(w.get_meta("radius", 0.25)))
	if not wheels.is_empty():
		rolled_total += -travelled / float(wheels[0].get_meta("radius", 0.25))
	var yaw_rate := angle_difference(_prev_yaw, rotation.y) / maxf(delta, 0.0001)
	_prev_yaw = rotation.y
	var speed := absf(travelled) / maxf(delta, 0.0001)
	_roll = lerpf(_roll, clampf(yaw_rate * speed * 0.012, -0.09, 0.09), 1.0 - exp(-8.0 * delta))
	_bob += absf(travelled) * 5.0
	var settle := 0.0
	if tip_t > 0.0:
		tip_t = maxf(0.0, tip_t - delta)
		var k := 1.0 - tip_t / TIP_TIME                                  # 0..1 through the tip
		settle = smoothstep(0.0, 0.35, k) * (1.0 - smoothstep(0.7, 1.0, k))
	tilt.rotation.x = -TIP_ANGLE * settle + sin(_bob) * 0.012
	tilt.rotation.z = _roll
	var load_node: Node3D = model.get_node_or_null("Load")
	if load_node:
		load_node.position.z = -0.25 * settle * float(load_node.get_meta("slide", 1.0))

## Starts the tipping animation (the real transfer happens in the game state; this only shows it).
func tip() -> void:
	if tip_t <= 0.0:
		tip_t = TIP_TIME

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
