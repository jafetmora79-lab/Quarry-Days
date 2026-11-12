extends SubViewportContainer
class_name QuarryPreview
## Phase 8.4: the small window that shows the real thing you are about to buy, turning slowly under its own light. It builds
## the model with the same code the game uses (vehicle models, rig builder, tool models, crusher dressing), in its own
## 3D world inside a SubViewport. Rendering stops when the window goes away or is hidden.

var viewport: SubViewport
var pivot: Node3D
var model: Node3D
var camera: Camera3D
var spin_speed := 0.55
var radius := 2.0
var built := false

## A stand-in for QuarryVehicle: the model builders only need these fields.
class PreviewVehicle extends Node3D:
	var model_root: Node3D
	var wheels: Array = []
	var arm: Node3D
	var bucket: Node3D
	var bucket_load: MeshInstance3D
	var bed: Node3D
	var bed_load: MeshInstance3D
	var paint_cab := "PaintRed"
	var paint_bed := "PaintOrange"
	var paint_main := "PaintYellow"

func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(280, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(game, spec: Dictionary) -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.76, 0.66)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(32), 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.25
	viewport.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-4, 3, 4)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.5
	fill.omni_range = 14.0
	viewport.add_child(fill)
	pivot = Node3D.new()
	viewport.add_child(pivot)
	model = build_model(game, spec)
	if model == null:
		model = Node3D.new()
	pivot.add_child(model)
	# centre the model on the turntable and frame it
	var box := _bounds(model)
	var centre := box.get_center()
	model.position = -centre
	radius = maxf(0.6, box.size.length() * 0.5)
	var stand := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 1.05
	cyl.bottom_radius = radius * 1.1
	cyl.height = 0.08
	stand.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.2, 0.15, 0.1)
	sm.roughness = 1.0
	stand.material_override = sm
	stand.position = Vector3(0, -box.size.y * 0.5 - 0.04, 0)
	pivot.add_child(stand)
	camera = Camera3D.new()
	camera.fov = 34.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, radius * 0.55, radius * 3.0), Vector3(0, -radius * 0.05, 0), Vector3.UP)
	camera.current = true
	pivot.rotation.y = deg_to_rad(-30)
	built = true

func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := _xform_to(n, m)
		var bb: AABB = xf * m.mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out if not first else AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))

func _xform_to(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _process(delta: float) -> void:
	if built and pivot and is_visible_in_tree():
		pivot.rotation.y += delta * spin_speed

## Called when the shop closes: nothing is rendered or processed any more.
func stop() -> void:
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)

static func build_model(game, spec: Dictionary) -> Node3D:
	var kind := str(spec.get("kind", ""))
	match kind:
		"vehicle":
			var type := str(spec["type"])
			var sp: Dictionary = game.fleet.spec(type)
			var k: String = game.fleet.kind(type)
			var pv := PreviewVehicle.new()
			pv.paint_cab = str(sp.get("cab_paint", pv.paint_cab))
			pv.paint_bed = str(sp.get("bed_paint", pv.paint_bed))
			pv.paint_main = str(sp.get("paint", pv.paint_main))
			pv.model_root = Node3D.new()
			pv.add_child(pv.model_root)
			var s: Array = sp["size"]
			var base := Vector3(2.0, 1.5, 3.0) if k == "loader" else (Vector3(2.2, 1.8, 4.6) if k == "truck" else Vector3(2.0, 2.2, 3.4))
			pv.model_root.scale = Vector3(float(s[0]) / base.x, float(s[1]) / base.y, float(s[2]) / base.z)
			match k:
				"loader": VehicleModels.loader(pv)
				"excavator": VehicleModels.excavator(pv)
				_: VehicleModels.truck(pv)
			return pv
		"rig":
			var r := QuarryRig.new()
			r.prog = game.prog
			r.rtype = str(spec["type"])
			r.rkind = str(game.prog.machine(r.rtype).get("kind", "drill"))
			r._build()
			return r
		"tool":
			var tv := QuarryToolView.new()
			var m: Node3D = tv._build(int(spec["tier"]))
			var holder := Node3D.new()
			holder.add_child(m)
			m.scale = Vector3.ONE * 2.2
			m.rotation = Vector3(0, 0, deg_to_rad(65))
			tv.free()
			return holder
		"crusher":
			var body := StaticBody3D.new()
			body.collision_layer = 0
			var tier := int(spec.get("tier", 1))
			var box := Vector3(1.8, 1.14, 1.6) if tier < 2 else Vector3(2.0, 1.14, 1.9)
			game._visual_box(body, Vector3(0, 0.57, 0), box, Color(0.22, 0.27, 0.29))
			game._visual_box(body, Vector3(0, 0.68, 0), Vector3(1.0, 0.45, 1.0), Color(0.44, 0.39, 0.28))
			if game.art:
				game.art.dress_crusher(body, tier)
			return body
		"output":
			var body := StaticBody3D.new()
			body.collision_layer = 0
			game._visual_box(body, Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 1.4), Color(0.24, 0.30, 0.22))
			game._visual_box(body, Vector3(0, 1.12, 0), Vector3(1.5, 0.08, 1.5), Color(0.40, 0.36, 0.22))
			var fill: MeshInstance3D = game._visual_box(body, Vector3(0, 0.85, 0), Vector3(1.2, 0.5, 1.2), Color(0.75, 0.73, 0.66))
			body.set_meta("fill", fill)
			if game.art:
				game.art.dress_output(body)
			return body
		"conveyor":
			var body := Node3D.new()
			var bk := str(spec.get("belt", "straight"))
			game._visual_box(body, Vector3(0, 0.13, 0), Vector3(0.9, 0.26, 2.0), Color(0.16, 0.17, 0.18))
			game._visual_box(body, Vector3(0, 0.28, 0), Vector3(0.7, 0.04, 2.0 if bk == "straight" else 0.7), Color(0.07, 0.07, 0.07))
			if bk != "straight":
				var sgn := -1.0 if bk == "left" else 1.0
				game._visual_box(body, Vector3(sgn * 0.5, 0.28, -0.0), Vector3(1.0, 0.04, 0.7), Color(0.07, 0.07, 0.07))
			for z in [-0.95, 0.95]:
				game._visual_box(body, Vector3(0, 0.13, z), Vector3(1.05, 0.24, 0.1), Color(0.85, 0.70, 0.15))
			return body
	return Node3D.new()
