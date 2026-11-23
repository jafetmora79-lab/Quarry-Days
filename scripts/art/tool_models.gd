extends RefCounted
class_name ToolModels
## The player's tools and gloved hands, modelled in Blender (tools/tool_models/build_tools.py -> assets/tools/*.glb). Same conventions as the
## procedural models they replace (GearModels, QuarryToolView): handle along +Y from the grip, working end toward -Z, same tip and grip points.
## Moving parts are nodes named "Spinner" (drill bit, hammer ram, chisel) and "Lever" (the hand splitter), exposed as the "spinner" / "lever"
## meta of the returned root. The glTF materials carry only a NAME; the project's own materials are swapped in here, so the tools look like
## the rest of the game. If a model is missing (or not imported) every function returns null and the caller falls back to the procedural one.

const DIR := "res://assets/tools/"
const LADDER := {0: "rock_hammer", 1: "pickaxe_worn", 2: "pickaxe_reinforced", 3: "drill", 4: "jackhammer"}

const COLOURS := {
	"OldWood": Color(0.37, 0.27, 0.18), "Rope": Color(0.62, 0.52, 0.34), "Blue": Color(0.24, 0.34, 0.46), "Paper": Color(0.86, 0.82, 0.68),
	"Glove": Color(0.17, 0.18, 0.21), "GloveDark": Color(0.08, 0.08, 0.10), "SkinDark": Color(0.62, 0.46, 0.35), "PlaidDark": Color(0.33, 0.06, 0.05), "Skin": Color(0.80, 0.62, 0.48), "Sleeve": Color(0.27, 0.30, 0.33), "SleeveDark": Color(0.17, 0.19, 0.21), "Band": Color(0.86, 0.86, 0.78),
}

static var _scenes := {}

## Model key for a tool tier: the five ladder tools, or the Phase 9 tool's id.
static func key_of(tier: int) -> String:
	if tier >= GearModels.TIER_BASE:
		return GearModels.id_of(tier)
	return str(LADDER.get(tier, ""))

static func _scene(file: String) -> PackedScene:
	if _scenes.has(file):
		return _scenes[file]
	var ps: PackedScene = null
	var path := DIR + file
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_scenes[file] = ps
	return ps

static func has_tool(key: String) -> bool:
	return key != "" and _scene("TOOL_QD_%s.glb" % key) != null

## Meshy-generated tools (assets/tools/meshy): file -> how to turn the raw model so the handle runs up +Y and the working end points up/forward (-Z),
## its butt `butt` below the grip, `length` tall in total. Meshy models are one static mesh with their own painted texture, so they are NOT dressed.
const MESHY := {
	"pickaxe_worn": {"basis": Vector3(0, 90, 0), "length": 0.74},                    # raw: handle -Y, head along X
	"pickaxe_reinforced": {"basis": Vector3(0, 0, -90), "length": 0.80},             # raw: handle +X, head at -X, spikes along Z
	"steel_pickaxe": {"basis": Vector3(0, 90, -90), "length": 0.80},                 # raw: handle +X, head at -X, curved along Y
	"pointed_chisel": {"basis": Vector3(0, 0, -90), "length": 0.62},                 # raw: handle +X, point at -X
	"rock_hammer": {"basis": Vector3(0, 90, 0), "length": 0.66},                     # raw: handle -Y, head on top along X
	"sledgehammer": {"basis": Vector3(0, 90, 0), "length": 0.90},
	"shovel": {"basis": Vector3(0, 0, 180), "length": 0.92},                         # raw: D-grip on top, blade at the bottom: flipped
	# powered tools are rigged by Meshy (an auto-rig chain, no clips): `pivot` is the raw point that becomes the grip origin, `scale` fixes the size.
	# "pump" = the whole machine is wrapped in a "Spinner" node the rig rattles; "bone" = twist this bone chain about its own axis for "rotate".
	"jackhammer": {"basis": Vector3.ZERO, "pivot": Vector3(0, 1.52, 0), "scale": 0.394, "pump": true},
	"pneumatic_chisel": {"basis": Vector3.ZERO, "pivot": Vector3(0, 1.6, 0), "scale": 0.38, "pump": true},
	"drill": {"basis": Vector3(0, -90, 0), "pivot": Vector3(0.2, 0.75, 0), "scale": 0.3, "bone": "Bone_002"},
}
const MESHY_BUTT := -0.12

static func _meshy(key: String) -> Node3D:
	var spec: Dictionary = MESHY[key]
	var ps := _scene("meshy/%s.glb" % key)
	if ps == null:
		return null
	var raw := ps.instantiate() as Node3D
	if raw == null:
		return null
	var rot := Basis.from_euler(Vector3(deg_to_rad(spec["basis"].x), deg_to_rad(spec["basis"].y), deg_to_rad(spec["basis"].z)))
	# bounds of the rotated model, to scale it to the wanted length and drop its butt to MESHY_BUTT
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for mi in raw.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb := m.get_aabb()
		for i in 8:
			var c: Vector3 = rot * (m.transform * bb.get_endpoint(i))
			lo = lo.min(c)
			hi = hi.max(c)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := Node3D.new()
	n.name = "Tool_" + key
	var holder := Node3D.new()
	if spec.has("pivot"):
		var sc2 := float(spec["scale"])
		holder.transform = Transform3D(rot * sc2, (rot * sc2) * (-(spec["pivot"] as Vector3)))
	else:
		var sc := float(spec["length"]) / maxf(hi.y - lo.y, 0.001)
		holder.transform = Transform3D(rot * sc, Vector3(0, MESHY_BUTT - lo.y * sc, 0))
	holder.add_child(raw)
	if spec.get("pump", false):
		# the whole machine sits in a node called Spinner at the pose code's rest height (y -0.42), so its pump_y rattle moves the machine
		var sp := Node3D.new()
		sp.name = "Spinner"
		sp.position = Vector3(0, -0.42, 0)
		holder.position += Vector3(0, 0.42, 0)
		sp.add_child(holder)
		n.add_child(sp)
		n.set_meta("spinner", sp)
	else:
		n.add_child(holder)
		if spec.has("bone"):
			var sk := raw.find_child("*", true, false) as Skeleton3D
			for c in raw.find_children("*", "Skeleton3D", true, false):
				sk = c as Skeleton3D
			if sk != null:
				var bs := BoneSpin.new()
				bs.name = "Spinner"
				bs.setup(sk, str(spec["bone"]))
				n.add_child(bs)
				n.set_meta("spinner", bs)
	return n

## Twists one bone of a Meshy auto-rig about its own axis (toward its child) by this node's rotation.z, so the pose code's `spinner.rotate_z()` turns a bit or chuck.
class BoneSpin extends Node3D:
	var sk: Skeleton3D
	var bone := -1
	var axis := Vector3.UP
	var rest: Quaternion
	func setup(s: Skeleton3D, bone_name: String) -> void:
		sk = s
		bone = s.find_bone(bone_name)
		if bone < 0:
			return
		var ch := s.get_bone_children(bone)
		var g := s.get_bone_global_rest(bone)
		if ch.size() > 0:
			axis = (g.basis.inverse() * (s.get_bone_global_rest(ch[0]).origin - g.origin)).normalized()
		rest = s.get_bone_rest(bone).basis.get_rotation_quaternion()
	func _process(_d: float) -> void:
		if sk != null and bone >= 0:
			sk.set_bone_pose_rotation(bone, rest * Quaternion(axis, rotation.z))

## One tool, ready to parent under the swing pivot; null if there is no Blender model for it.
static func load_tool(key: String) -> Node3D:
	if MESHY.has(key):
		var mn := _meshy(key)
		if mn != null:
			return mn
	var ps := _scene("TOOL_QD_%s.glb" % key) if key != "" else null
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	n.name = "Tool_" + key
	_dress(n)
	var sp := n.find_child("Spinner", true, false)
	if sp != null:
		n.set_meta("spinner", sp)
	var lv := n.find_child("Lever", true, false)
	if lv != null:
		n.set_meta("lever", lv)
	return n

## A gloved hand with its cuff and sleeve: the right or the left one. The grip axis is local Y, the forearm runs out along +Z.
static func load_hand(right: bool) -> Node3D:
	var ps := _scene("HAND_QD_R.glb" if right else "HAND_QD_L.glb")
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	n.name = "Hand_" + ("R" if right else "L")
	_dress(n)
	return n

static func material_for(name: String) -> Material:
	match name:
		"Wood": return MeshKit.mat(QuarryArt.M_WOOD)
		"Steel": return MeshKit.mat("SteelPlate")
		"Bright": return MeshKit.mat(QuarryArt.M_BRUSHED)
		"Rust": return MeshKit.mat(QuarryArt.M_RUSTED)
		"Rubber": return MeshKit.mat(QuarryArt.M_RUBBER)
		"Red": return MeshKit.mat("PaintRed")
		"Orange": return MeshKit.mat("PaintOrange")
		"Yellow": return MeshKit.mat("PaintYellow")
	if COLOURS.has(name):
		return MeshKit.flat(COLOURS[name])
	return null

static func _dress(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			var mat := material_for(src.resource_name) if src != null else null
			if mat != null:
				if m.mesh.get_surface_count() == 1:
					m.material_override = mat          # one material per mesh object: the whole mesh wears it
				else:
					m.set_surface_override_material(s, mat)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static var _plaid: StandardMaterial3D

## The red work-shirt plaid of the sleeves: a 16 px grey check multiplied by the shirt red, nearest filtered, repeating every 8 cm.
static func plaid() -> StandardMaterial3D:
	if _plaid != null:
		return _plaid
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			var v := 1.0
			var hy := y >= 4 and y < 8
			var hx := x >= 4 and x < 8
			if hy and hx:
				v = 0.50
			elif hy or hx:
				v = 0.72
			elif y == 12 or x == 12:
				v = 0.88
			img.set_pixel(x, y, Color(v, v, v))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.74, 0.16, 0.12)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(12, 12, 12)
	m.roughness = 1.0
	_plaid = m
	return m
