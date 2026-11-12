extends Node3D
class_name QuarryDoor
## A hinged wooden house door you open and close with E. The panel swings into the house; a worker walking up to it
## opens it as well, so nobody is ever locked out or in. The collider sits on the panel, so it blocks only while shut.

const W := 1.38
const H := 2.35
const THICK := 0.07

var game
var hinge_side := -1.0      ## -1: hinge on the left of the doorway (panel extends +x), +1: on the right
var open_amount := 0.0
var want_open := false
var body: StaticBody3D
var shape: CollisionShape3D
var swing := 1.75

## centre: middle of the doorway on the floor; the wall plane is centre.z
func build(main_node, centre: Vector3, hinge: float, label: String) -> void:
	game = main_node
	hinge_side = hinge
	name = label
	position = centre + Vector3(hinge * W * 0.5, 0.16, 0.0)   # hinge post; the sill is the 16 cm foundation
	game.world.add_child(self)
	var wood: Material = load(QuarryArt.M_WOOD)
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, H, THICK)
	panel.mesh = bm
	panel.position = Vector3(-hinge * W * 0.5, H * 0.5, 0.0)
	panel.material_override = wood
	add_child(panel)
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(W * 0.55, 0.7, THICK + 0.02)
	glass.mesh = gm
	glass.position = Vector3(-hinge * W * 0.5, H * 0.68, 0.0)
	glass.material_override = MeshKit.flat(Color(0.55, 0.72, 0.80), 0.25)
	add_child(glass)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.12, 0.05, 0.16)
	handle.mesh = hm
	handle.position = Vector3(-hinge * (W - 0.14), 1.0, 0.0)
	handle.material_override = MeshKit.flat(Color(0.75, 0.72, 0.6))
	add_child(handle)
	body = StaticBody3D.new()
	body.name = label + " panel"
	body.position = Vector3(-hinge * W * 0.5, H * 0.5, 0.0)
	body.set_meta("kind", "door")
	body.set_meta("door", label)
	body.set_meta("nav_skip", true)
	body.set_meta("art", true)
	shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(W, H, THICK + 0.04)
	shape.shape = bs
	body.add_child(shape)
	add_child(body)

func toggle() -> void:
	want_open = not want_open

func is_open() -> bool:
	return open_amount > 0.5

func _workers_near() -> bool:
	var c := global_position + Vector3(-hinge_side * W * 0.5, 0.0, 0.0)
	for w in game.worker_nodes.values():
		if Vector2(w.global_position.x, w.global_position.z).distance_to(Vector2(c.x, c.z)) < 1.9:
			return true
	return false

func _physics_process(delta: float) -> void:
	var target := 1.0 if (want_open or _workers_near()) else 0.0
	open_amount = move_toward(open_amount, target, delta * 2.4)
	# swing toward +z (into the house): y-rotation sign depends on which side the hinge is
	rotation.y = hinge_side * swing * smoothstep(0.0, 1.0, open_amount)
