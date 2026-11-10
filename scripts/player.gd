extends CharacterBody3D
class_name QuarryPlayer

var camera: Camera3D
var pitch := 0.0
var locked := false
var pickaxe: Node3D
var swing := 0.0

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
	add_child(camera)
	pickaxe = Node3D.new()
	pickaxe.position = Vector3(0.36, -0.34, -0.72)
	camera.add_child(pickaxe)
	var handle := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.026
	cylinder.bottom_radius = 0.035
	cylinder.height = 0.53
	handle.mesh = cylinder
	handle.rotation.z = 0.3
	handle.material_override = _material(Color(0.23, 0.14, 0.09))
	pickaxe.add_child(handle)
	var head := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.075, 0.075)
	head.mesh = box
	head.position.y = 0.26
	head.material_override = _material(Color(0.33, 0.35, 0.36))
	pickaxe.add_child(head)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not locked:
		rotate_y(-event.relative.x * 0.0024)
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.42, 1.42)
		camera.rotation.x = pitch

func swing_pickaxe() -> void:
	swing = 1.0

func _physics_process(delta: float) -> void:
	if swing > 0.0:
		swing = maxf(0.0, swing - delta * 3.8)
		pickaxe.rotation.x = -sin(swing * PI) * 0.9
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
