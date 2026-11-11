extends CharacterBody3D
class_name QuarryPlayer

var camera: Camera3D
var pitch := 0.0
var locked := false
var tool_view: QuarryToolView
var pickaxe: Node3D # kept for older callers: the tool view node
var shake := 0.0
var kick := 0.0
var _shake_t := 0.0

func _ready() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.current = true
	camera.fov = 72.0
	camera.near = 0.03
	add_child(camera)
	tool_view = QuarryToolView.new()
	camera.add_child(tool_view)
	pickaxe = tool_view
	floor_snap_length = 0.35
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not locked and not game_touch():
		rotate_y(-event.relative.x * 0.0024)
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.42, 1.42)

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
	kick = minf(0.022, kick + 0.012 * strength)
	shake = minf(0.03, shake + 0.012 * strength)

func _process(delta: float) -> void:
	_shake_t += delta
	kick = move_toward(kick, 0.0, delta * 0.12)
	shake = move_toward(shake, 0.0, delta * 0.16)
	camera.rotation.x = pitch + kick
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
		var speed := 6.0 if Input.is_action_pressed("sprint") else 4.2
		velocity.x = move_toward(velocity.x, wish.x * speed, delta * 18)
		velocity.z = move_toward(velocity.z, wish.z * speed, delta * 18)
	velocity.y -= 22.0 * delta
	move_and_slide()
