extends CharacterBody3D
class_name QuarryPlayer

## Mouse look reads screen pixels (`screen_relative`), not the stretch-scaled `relative`, so the turn per hand movement does not depend on the window size.
## 0.75 keeps the feel the game had at its default 1280x720 window (960x540 canvas).
const MOUSE_LOOK_SCALE := 0.75

var camera: Camera3D
var pitch := 0.0
var locked := false
var scripted_camera := false         ## a cinematic move (boarding, a repair) owns the camera's orientation: the pitch is not forced back each frame
var drive_wish := Vector3.INF
var speed_mult := 1.0          ## 0.8 while pushing or pulling a cart
var load_mult := 1.0           ## slower with every full bucket carried (set by the game)
var tool_view: QuarryToolView
var blueprint: QuarryBlueprintHands
var pickaxe: Node3D # kept for older callers: the tool view node
var shake := 0.0
var kick := 0.0
var _shake_t := 0.0
var crouching := false        ## Ctrl held (stays down under a low ceiling)
var _crouch := 0.0            ## 0 standing .. 1 fully crouched (eased)
var _capsule: CapsuleShape3D
var _collider: CollisionShape3D
const CROUCH_DROP := 0.6      ## how far the eyes sink (m)
const CROUCH_HEIGHT := 1.15   ## capsule height while crouched (m)
const STAND_HEIGHT := 1.75

func _ready() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.9
	_capsule = capsule
	_collider = collider
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.current = true
	camera.fov = 72.0
	camera.near = 0.06
	add_child(camera)
	tool_view = QuarryToolView.new()
	camera.add_child(tool_view)
	pickaxe = tool_view
	blueprint = QuarryBlueprintHands.new()
	blueprint.tool_view = tool_view
	camera.add_child(blueprint)
	floor_snap_length = 0.35
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not event.is_echo():
		_jump_buf = JUMP_BUFFER                    # Space shortly before touching down still counts
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not locked and not game_touch():
		var look: Vector2 = event.screen_relative * MOUSE_LOOK_SCALE     # screen pixels: the same turn per hand movement in any window size
		rotate_y(-look.x * 0.0024)
		pitch = clampf(pitch - look.y * 0.0024, -1.42, 1.42)

## Touch builds look with finger drags (touch_controls.gd); emulated mouse motion must not rotate the camera too.
func game_touch() -> bool:
	var m := get_parent()
	return m != null and "touch_mode" in m and bool(m.touch_mode)

## Legacy: a swing with no gameplay effect (empty air, depleted rock).
func swing_pickaxe() -> void:
	if tool_view and not tool_view.is_busy() and tool_view.tier < 3:
		tool_view.swing(0.45, Callable())

## Subtle camera feedback on impact: a tiny upward kick and a short, damped shake.
func impact_feedback(strength := 1.0) -> void:
	if tool_view != null:
		strength *= tool_view.kick_scale
	kick = minf(0.022, kick + 0.012 * strength)
	shake = minf(0.03, shake + 0.012 * strength)

func _process(delta: float) -> void:
	_shake_t += delta
	kick = move_toward(kick, 0.0, delta * 0.12)
	shake = move_toward(shake, 0.0, delta * 0.16)
	if not scripted_camera:
		camera.rotation.x = pitch + kick - mantle_dip
	camera.h_offset = sin(_shake_t * 63.0) * shake * 0.6
	camera.v_offset = cos(_shake_t * 71.0) * shake * 0.5
	if tool_view:
		tool_view.moving = clampf(Vector2(velocity.x, velocity.z).length() / 4.2, 0.0, 1.5) if is_on_floor() else 0.0

func _physics_process(delta: float) -> void:
	if locked:
		velocity.x = move_toward(velocity.x, 0, delta * 20)
		velocity.z = move_toward(velocity.z, 0, delta * 20)
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var wish := global_transform.basis * Vector3(dir.x, 0, dir.y)
		var want := Input.is_action_pressed("crouch") and _input_ok()
		if want != crouching and (want or _can_stand()):
			crouching = want
		var speed := 6.0 if Input.is_action_pressed("sprint") and not crouching else 4.2
		if crouching:
			speed = 2.2
		if drive_wish != Vector3.INF:        # scripted walking (tests): a world-space direction instead of the keyboard
			wish = drive_wish.normalized() if drive_wish.length() > 0.01 else Vector3.ZERO
			speed = 4.2
		speed *= speed_mult * load_mult
		velocity.x = move_toward(velocity.x, wish.x * speed, delta * 18)
		velocity.z = move_toward(velocity.z, wish.z * speed, delta * 18)
		_wish_flat = Vector3(wish.x, 0.0, wish.z)
	_update_crouch(delta)
	_jump_buf = maxf(0.0, _jump_buf - delta)
	if _mantle_t > 0.0:
		# climbing onto a ledge: up the face, then over the edge, eased, with the head dipping toward the ledge
		_mantle_t = maxf(0.0, _mantle_t - delta)
		var p := 1.0 - _mantle_t / MANTLE_TIME
		if p < 0.55:
			global_position = _mantle_from.lerp(_mantle_up, smoothstep(0.0, 1.0, p / 0.55))
		else:
			global_position = _mantle_up.lerp(_mantle_to, smoothstep(0.0, 1.0, (p - 0.55) / 0.45))
		mantle_dip = sin(p * PI) * 0.16
		velocity = Vector3.ZERO
		if _mantle_t <= 0.0:
			mantle_dip = 0.0
		return
	var on_floor_before := is_on_floor()
	velocity.y -= GRAVITY * delta
	var input_ok := _input_ok()
	if not locked and input_ok:
		if _jump_buf > 0.0 and on_floor_before and not crouching:
			if _try_mantle(true):                  # Space at a reachable ledge climbs it; anywhere else it jumps
				_jump_buf = 0.0
				return
			velocity.y = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
			_jump_buf = 0.0
			jumped.emit()
		else:
			_try_mantle()
			if _mantle_t > 0.0:
				return
	var fall_v := velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor_before and fall_v < -3.0:
		_land(-fall_v)

## Eases the body down / up: the capsule shrinks from the head (feet stay put) and the eyes sink. Cinematics that set the camera height themselves are left alone while standing.
func _update_crouch(delta: float) -> void:
	var target := 1.0 if crouching else 0.0
	if _crouch == target:
		return
	_crouch = move_toward(_crouch, target, delta * 6.0)
	var h := lerpf(STAND_HEIGHT, CROUCH_HEIGHT, _crouch)
	_capsule.height = h
	_collider.position.y = h * 0.5 + 0.025
	camera.position.y = 1.58 - CROUCH_DROP * _crouch

## Is there room overhead to stand up?
func _can_stand() -> bool:
	if _capsule == null:
		return true
	var shape := CapsuleShape3D.new()
	shape.radius = _capsule.radius - 0.02
	shape.height = STAND_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.06, 0))
	q.exclude = [get_rid()]
	q.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

## Is the game giving the player control (no dialogue, card, menu or cinematic)?
func _input_ok() -> bool:
	var g := get_parent()
	if g != null and g.has_method("gameplay_input_allowed"):
		return bool(g.gameplay_input_allowed())
	return true

## A soft landing: a small dip of the view that grows a little with the speed of the fall (no shake).
func _land(speed: float) -> void:
	kick = maxf(kick, -minf(0.03, 0.004 * speed))
	landed.emit(speed)

signal jumped
signal landed(speed: float)

# ------------------------------------------------------------------ ledge climbing (Phase 8.1)

const JUMP_HEIGHT := 0.9          ## how high a jump lifts the feet (m)
const GRAVITY := 22.0
const JUMP_BUFFER := 0.12
var mantle_max := 1.25            ## the tallest ledge that can be climbed (m): one rock tier (1.2 m) with a little slack. Configurable.
const MANTLE_TIME := 0.5
var mantle_dip := 0.0
var _jump_buf := 0.0
var _mantle_up := Vector3.ZERO
var _mantle_t := 0.0
var _wish_flat := Vector3.ZERO
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO

## Walking into a low rock or ground ledge climbs it, so a one-tier step in the excavation is never a trap.
## Only quarry ground and rock count: never vehicles, machines or buildings.
func _try_mantle(explicit := false) -> bool:
	if not is_on_floor():
		return false
	var dir := -global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	if not explicit:
		if _wish_flat.length() < 0.3:
			return false                         # only when the player is pushing against the ledge
		dir = _wish_flat.normalized()
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, dir * (0.6 if explicit else 0.2), hit):
		return false
	# only a real wall in front counts as a ledge: touching the flat ground (floor-top contact, a seam, the safe margin) used to start a climb that lifted
	# the player 20 cm and froze them for 0.2 s - the "bump" while walking across open ground
	var n: Vector3 = hit.get_normal()
	if n.y > 0.45 or n.dot(dir) > -0.35:
		return false
	var c = hit.get_collider()
	if c == null or not (c is QuarryFormation or (c is Node and ((c as Node).has_meta("ground") or (c as Node).has_meta("climbable")))):
		return false
	var reach := hit.get_travel().length() + 0.62          # from here to just past the edge (the player's radius is 0.34)
	for h in [0.25, 0.5, 0.9, mantle_max]:
		var up := global_transform.translated(Vector3(0, h, 0))
		if test_move(global_transform, Vector3(0, h, 0)):
			break                                 # head room is gone: higher is no better
		if test_move(up, dir * reach):
			continue
		var over := up.translated(dir * reach)
		if not test_move(over, Vector3(0, -(h + 0.1), 0)):
			continue                              # nothing to stand on up there
		_mantle_from = global_position
		_mantle_up = up.origin
		_mantle_to = over.origin
		_mantle_t = MANTLE_TIME
		return true
	return false
