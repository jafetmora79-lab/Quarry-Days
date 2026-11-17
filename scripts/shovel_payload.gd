extends RefCounted
class_name ShovelPayload
## What is on the shovel's blade: a small low-poly heap that sits in the concave face (model space: the face looks toward -Z, the blade runs from y 0.72 to 1.0, 0.18 m across) and is built
## from the material that was really dug - a soil mound, loose gravel, blocky rock chunks, ore chunks with the mineral showing - in that material's own pixel texture.
## The tool view shows it only when the strike really collected units (see QuarryToolView.set_payload) and removes it when the load is tipped off; nothing here touches quantities.

const BLADE_CENTER := Vector3(0.0, 0.855, -0.045)

static var _cache := {}

## The holder (hidden) under the tool model; its local +Y points out of the blade's face, local X across the blade and local Z along it.
static func attach(model: Node3D) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Payload"
	holder.position = BLADE_CENTER
	holder.rotation.x = -PI * 0.5                  # local +Y -> model -Z (out of the face), local +Z -> model +Y (along the blade)
	holder.visible = false
	model.add_child(holder)
	model.set_meta("payload", holder)
	return holder

static func _mat_name(res: String) -> String:
	return BucketView.MATS.get(res, "ExcavatedDirt")

## Rebuilds the heap for `res`.
static func fill(holder: Node3D, res: String) -> void:
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	var kind := BucketView.kind_of(res)
	var mat := MeshKit.mat(_mat_name(res))
	var node := Node3D.new()
	holder.add_child(node)
	node.scale = Vector3(1.3, 1.4, 2.0)            # the blade is longer than it is wide; a generous scoop
	match kind:
		"dirt":
			MeshKit.inst(node, PileModels.dirt_mesh(0.07, 0.05, 11), mat, Vector3(0, -0.004, 0))
		"gravel":
			var s := MeshKit.Soup.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in range(22):
				var a := rng.randf() * TAU
				var d := 0.07 * sqrt(rng.randf())
				var sz := rng.randf_range(0.014, 0.026)
				PileModels.chunk_into(s, Vector3(cos(a) * d, sz * 0.2 + 0.018 * (1.0 - d / 0.07), sin(a) * d), Vector3(sz * 1.3, sz, sz * 1.2), rng)
			MeshKit.inst(node, s.mesh(), mat)
		_:
			var s2 := MeshKit.Soup.new()
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 8
			for i in range(8):
				var a2 := rng2.randf() * TAU
				var d2 := 0.055 * sqrt(rng2.randf())
				var sz2 := rng2.randf_range(0.024, 0.04)
				PileModels.chunk_into(s2, Vector3(cos(a2) * d2, sz2 * 0.25 + 0.025 * (1.0 - d2 / 0.06), sin(a2) * d2), Vector3(sz2 * 1.2, sz2 * 0.9, sz2 * 1.1), rng2)
			MeshKit.inst(node, s2.mesh(), mat)
			if kind == "ore":
				var o := MeshKit.Soup.new()
				for j in range(3):
					var a3 := rng2.randf() * TAU
					var sz3 := rng2.randf_range(0.014, 0.022)
					PileModels.chunk_into(o, Vector3(cos(a3) * 0.03, 0.04, sin(a3) * 0.03), Vector3(sz3 * 1.2, sz3, sz3), rng2)
				MeshKit.inst(node, o.mesh(), MeshKit.flat(QuarryTheme.RES_COLORS.get(res, Color(0.9, 0.7, 0.2)), 0.12))
