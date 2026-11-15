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
	"Glove": Color(0.17, 0.18, 0.21), "GloveDark": Color(0.08, 0.08, 0.10), "Skin": Color(0.80, 0.62, 0.48), "Sleeve": Color(0.86, 0.46, 0.16), "Band": Color(0.86, 0.86, 0.78),
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

## One tool, ready to parent under the swing pivot; null if there is no Blender model for it.
static func load_tool(key: String) -> Node3D:
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
