extends RefCounted
class_name WorldModels
## The landscape's Blender models (tools/world_models/build_world.py -> assets/world/WLD_QD_<key>.glb): the forest set, mountains, the tunnel portal and lining, the deer and
## the rabbit. glTF materials carry only a NAME; the game's own flat, nearest-filtered materials are swapped in here. Foliage (needles, leaves, grass, ferns, flowers) uses one
## shared sway shader per colour: the wind bends it more toward the tips (its height above the model's base), phased by where the instance stands, so a forest moves gently
## without any per-tree script. `mesh(key)` gives a merged static mesh for MultiMesh use; `animal(key)` gives a node with its holders (Head, Ears, Legs ...) kept for animation.

const DIR := "res://assets/world/"

const COLOURS := {
	"Bark": Color(0.34, 0.23, 0.15), "BirchBark": Color(0.86, 0.84, 0.77), "Moss": Color(0.28, 0.44, 0.20),
	"RockA": Color(0.62, 0.55, 0.45), "RockB": Color(0.50, 0.45, 0.39), "RockC": Color(0.72, 0.65, 0.52), "RockD": Color(0.42, 0.40, 0.38),
	"Fur": Color(0.62, 0.42, 0.25), "FurLight": Color(0.88, 0.78, 0.62), "Antler": Color(0.82, 0.74, 0.56), "Dark": Color(0.10, 0.09, 0.08),
	"RabbitFur": Color(0.60, 0.50, 0.40), "RabbitWhite": Color(0.93, 0.91, 0.86), "Pink": Color(0.92, 0.62, 0.62),
	"PickGreen": Color(0.30, 0.42, 0.31), "PickDark": Color(0.19, 0.28, 0.21), "PickWood": Color(0.45, 0.32, 0.20), "PickSeat": Color(0.44, 0.30, 0.19),
	"PickDash": Color(0.20, 0.18, 0.16), "PickTrim": Color(0.66, 0.66, 0.62), "PickTyre": Color(0.07, 0.07, 0.07), "PickRed": Color(0.75, 0.12, 0.10), "PickRust": Color(0.45, 0.24, 0.12),
	"DinoSkin": Color(0.41, 0.36, 0.26), "DinoSkinDk": Color(0.30, 0.26, 0.19), "DinoPlate": Color(0.25, 0.22, 0.17), "DinoPlateLt": Color(0.43, 0.37, 0.27),
	"DinoBelly": Color(0.66, 0.60, 0.45), "DinoBone": Color(0.88, 0.84, 0.70), "DinoEye": Color(0.05, 0.04, 0.04), "DinoWhite": Color(0.96, 0.95, 0.90),
	"DinoBlush": Color(0.84, 0.52, 0.42), "DinoMoss": Color(0.34, 0.42, 0.22), "DinoHide2": Color(0.52, 0.45, 0.33), "DinoHide3": Color(0.33, 0.30, 0.22), "DinoClaw": Color(0.20, 0.17, 0.13), "DinoIris": Color(0.74, 0.50, 0.14), "DinoHorn": Color(0.64, 0.57, 0.42), "DinoHornDk": Color(0.42, 0.36, 0.26), "EggShell": Color(0.86, 0.82, 0.66), "EggSpot": Color(0.52, 0.44, 0.30),
	"EggCrust": Color(0.62, 0.58, 0.50), "EggInner": Color(0.92, 0.70, 0.40), "Straw": Color(0.82, 0.68, 0.34), "StrawDk": Color(0.62, 0.48, 0.24), "Wool": Color(0.88, 0.84, 0.76),
	"Brass": Color(0.78, 0.60, 0.24), "IncWood": Color(0.50, 0.34, 0.20), "IncWoodDk": Color(0.34, 0.22, 0.13), "IncTin": Color(0.62, 0.64, 0.62), "IncRed": Color(0.78, 0.18, 0.14),
	"IncWater": Color(0.40, 0.62, 0.78), "FossilBone": Color(0.84, 0.78, 0.62), "FossilEgg": Color(0.66, 0.62, 0.54), "Slab": Color(0.46, 0.42, 0.36), "SlabLt": Color(0.60, 0.55, 0.46),
	"HopSteel": Color(0.31, 0.39, 0.34), "HopSteelDk": Color(0.20, 0.26, 0.23), "HopRust": Color(0.49, 0.27, 0.13), "HopRustDk": Color(0.33, 0.18, 0.09),
	"HopYellow": Color(0.90, 0.69, 0.13), "HopIron": Color(0.15, 0.15, 0.16), "HopBrass": Color(0.80, 0.61, 0.24), "HopConcrete": Color(0.50, 0.50, 0.47), "HopStain": Color(0.22, 0.20, 0.17),
	"HopScreen": Color(0.10, 0.18, 0.12), "HopBill": Color(0.45, 0.70, 0.42), "HopWood": Color(0.42, 0.29, 0.17), "HopRock": Color(0.70, 0.68, 0.62),
	"LimeDark": Color(0.66, 0.62, 0.54), "LimeLight": Color(0.86, 0.82, 0.72), "LimeBand": Color(0.74, 0.58, 0.44),
	"CoalBody": Color(0.10, 0.10, 0.11), "CoalDark": Color(0.05, 0.05, 0.06), "CoalSheen": Color(0.42, 0.46, 0.52),
	"IronRock": Color(0.36, 0.26, 0.21), "IronRed": Color(0.66, 0.24, 0.11), "IronBlack": Color(0.15, 0.13, 0.13),
	"CopperRock": Color(0.28, 0.36, 0.30), "Malachite": Color(0.20, 0.64, 0.46), "CopperOrange": Color(0.82, 0.44, 0.19),
	"QuartzRock": Color(0.70, 0.68, 0.64), "QuartzWhite": Color(0.92, 0.92, 0.88),
	"PebbleA": Color(0.58, 0.52, 0.44), "PebbleB": Color(0.45, 0.41, 0.37), "PebbleC": Color(0.70, 0.64, 0.54),
	"ClodDark": Color(0.27, 0.18, 0.12), "ClodMid": Color(0.40, 0.28, 0.18), "ClodLight": Color(0.52, 0.37, 0.25), "ClodStone": Color(0.62, 0.57, 0.49),
	"BucketSteel": Color(0.46, 0.49, 0.51), "BucketRim": Color(0.30, 0.32, 0.35), "BucketRust": Color(0.50, 0.28, 0.14), "BucketBand": Color(0.36, 0.38, 0.40),
	"BucketHandle": Color(0.16, 0.16, 0.17), "BucketDirt": Color(0.40, 0.28, 0.18), "BucketInner": Color(0.12, 0.11, 0.10),
	"RkPaint": Color(0.70, 0.58, 0.22), "RkSteel": Color(0.47, 0.49, 0.52), "RkDark": Color(0.08, 0.08, 0.09), "RkBrass": Color(0.80, 0.60, 0.22), "RkRed": Color(0.72, 0.12, 0.10),
	"RkCream": Color(0.90, 0.85, 0.70), "RkRubber": Color(0.13, 0.14, 0.17), "RkRust": Color(0.42, 0.22, 0.12), "RkYellow": Color(0.92, 0.72, 0.14), "RkTerminal": Color(0.62, 0.64, 0.66),
	"RkPlus": Color(0.80, 0.14, 0.10), "RkMinus": Color(0.06, 0.06, 0.07),
	"Timber": Color(0.45, 0.31, 0.18), "Steel": Color(0.38, 0.40, 0.42), "Concrete": Color(0.55, 0.55, 0.53), "Hazard": Color(0.90, 0.72, 0.10), "Paint": Color(0.90, 0.78, 0.20)}
const FOLIAGE := {
	"Pine": Color(0.16, 0.33, 0.20), "PineLight": Color(0.25, 0.43, 0.24), "Leaf": Color(0.42, 0.55, 0.20), "LeafWarm": Color(0.68, 0.58, 0.20),
	"Grass": Color(0.50, 0.56, 0.25), "Fern": Color(0.20, 0.45, 0.23), "FlowerW": Color(0.95, 0.94, 0.88), "FlowerY": Color(0.96, 0.80, 0.22),
	"FlowerP": Color(0.66, 0.40, 0.76), "FlowerR": Color(0.85, 0.28, 0.22)}

static var _mats := {}
static var _meshes := {}
static var _shader: Shader

static func path_of(key: String) -> String:
	return DIR + "WLD_QD_%s.glb" % key

static func has(key: String) -> bool:
	return ResourceLoader.exists(path_of(key))

static func _sway_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color = vec4(0.3, 0.5, 0.25, 1.0);
uniform float sway = 0.045;
uniform float speed = 1.15;
void vertex() {
	float h = max(VERTEX.y, 0.0);
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 0.19 + wp.z * 0.23;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + wp.x * 0.04);
	VERTEX.x += sin(TIME * speed + ph) * sway * h * 0.35 * gust;
	VERTEX.z += cos(TIME * speed * 0.83 + ph * 1.3) * sway * h * 0.22 * gust;
}
void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""
	return _shader

const ROCK_TINT := {"RockA": Color(1.0, 0.92, 0.80), "RockB": Color(0.80, 0.74, 0.66), "RockC": Color(1.0, 0.96, 0.84), "RockD": Color(0.64, 0.62, 0.60), "Moss": Color(0.62, 0.78, 0.50)}

## Mountain rock: the game's strata texture (pixelated, nearest-filtered) mapped in WORLD space on all three axes, so a face never stretches however steep it is, tinted per
## stratum, drawn on both sides so a mis-oriented face can never turn into a hole.
static func _rock(name: String) -> Material:
	var base := MeshKit.mat("CliffStrata")
	var m: StandardMaterial3D
	if base is StandardMaterial3D:
		m = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		m = StandardMaterial3D.new()
	m.albedo_color = ROCK_TINT[name]
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.11, 0.11, 0.11)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	return m

static func material_for(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m: Material = null
	if ROCK_TINT.has(name):
		m = _rock(name)
	elif FOLIAGE.has(name):
		var sm := ShaderMaterial.new()
		sm.shader = _sway_shader()
		sm.set_shader_parameter("albedo", FOLIAGE[name])
		m = sm
	elif name == "Lamp":
		m = MeshKit.flat(Color(1.0, 0.86, 0.55), 1.2)
	elif name == "GoldNugget":
		m = MeshKit.flat(Color(1.0, 0.78, 0.16), 0.45)
	elif name == "HopLamp":
		m = MeshKit.flat(Color(0.9, 0.2, 0.12), 1.2)
	elif name == "HopAmber":
		m = MeshKit.flat(Color(1.0, 0.64, 0.16), 1.8)
	elif name == "HopScreenG":
		m = MeshKit.flat(Color(0.05, 0.16, 0.09), 0.6)
	elif name == "HopGearGlow":
		m = MeshKit.flat(Color(1.0, 0.5, 0.12), 1.5)
	elif name == "HopGlow":
		m = MeshKit.flat(Color(1.0, 0.8, 0.3), 1.5)
	elif name == "HopCoin":
		m = MeshKit.flat(Color(0.98, 0.78, 0.22), 0.3)
	elif name == "Amber":
		m = MeshKit.flat(Color(1.0, 0.72, 0.30), 1.6)
	elif name == "PickGlass":
		var gm := StandardMaterial3D.new()                       # window glass: see-through, both sides
		gm.albedo_color = Color(0.62, 0.78, 0.82, 0.16)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		gm.roughness = 0.2
		m = gm
	elif COLOURS.has(name):
		var sm2 := StandardMaterial3D.new()
		sm2.albedo_color = COLOURS[name]
		sm2.roughness = 1.0
		sm2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m = sm2
	_mats[name] = m
	return m

## Merges every MeshInstance3D below `n` (transforms baked) into ONE ArrayMesh, a surface per source material, with the game's materials set.
static func _merge(n: Node3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != n:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		for si in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(si)
			var nm: String = src.resource_name if src != null else ""
			var arr := m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				verts[i] = xf * verts[i]
			for i in norms.size():
				norms[i] = (xf.basis * norms[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = null                      # the glTF's baked grime is not used: the instance colour tints the foliage
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var idx := out.get_surface_count() - 1
			var mat := material_for(nm)
			if mat != null:
				out.surface_set_material(idx, mat)
			out.surface_set_name(idx, nm)
	return out

static func _instance(key: String) -> Node3D:
	if not has(key):
		return null
	var ps := load(path_of(key)) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	var ap := n.find_child("AnimationPlayer", false, false) as AnimationPlayer
	if ap != null and n.get_child_count() == 2 and str(n.get_child(0).name).begins_with("QD_"):
		# an animated model: the clips address the parts as "QD_x/Part:property". Lift the parts up one level (the QD_ wrapper goes) and rewrite the clips' paths to match.
		var wrapper := n.get_child(0) as Node3D
		var prefix := str(wrapper.name) + "/"
		for ch in wrapper.get_children():
			wrapper.remove_child(ch)
			n.add_child(ch)
		n.remove_child(wrapper)
		wrapper.free()
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for an in lib.get_animation_list():
				var anim: Animation = lib.get_animation(an)
				for ti in range(anim.get_track_count()):
					var tp := str(anim.track_get_path(ti))
					if tp.begins_with(prefix):
						anim.track_set_path(ti, NodePath(tp.substr(prefix.length())))
		return n
	if n.get_child_count() == 1 and str(n.get_child(0).name).begins_with("QD_"):
		var inner := n.get_child(0) as Node3D
		n.remove_child(inner)
		n.free()
		n = inner
	return n

static var _ore_parts := {}

## One loose-ore chunk of the Blender set ("ore_pieces"): resource "limestone", "coal", "iron_ore", "copper_ore", "gold_ore", "gravel" or "soil", variant 0..2. Null if the model is missing.
static func ore_piece(res: String, variant: int) -> ArrayMesh:
	if _ore_parts.is_empty():
		var a := animal("ore_pieces")
		if a.is_empty():
			_ore_parts["_none"] = true
			return null
		for k in a["parts"]:
			_ore_parts[k] = ((a["parts"][k] as Node3D).get_node("Mesh") as MeshInstance3D).mesh
		(a["root"] as Node).free()
	return _ore_parts.get("%s_%d" % [res, variant % 3], null)

## A model with its node hierarchy kept (holders, markers, named parts) and the game's materials on every surface: for models whose named parts and empties matter
## (the excavator's repair kit). Returns a fresh Node3D each call, or null when the file is missing.
static func dressed(key: String) -> Node3D:
	var n := _instance(key)
	if n == null:
		return null
	n.name = key
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(si)
			var mat := material_for(src.resource_name if src != null else "")
			if mat != null:
				m.set_surface_override_material(si, mat)
	return n

## A static mesh of model `key` (its Body), cached; null when the file is missing.
static func mesh(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var n := _instance(key)
	if n == null:
		return null
	var all := _merge(n)
	n.free()
	_meshes[key] = all
	return all

## An animal (or any model with hinge holders): a Node3D named after the key whose children are the holders ("Body", "Head", "EarL", "LegFL" ...), each with ONE merged mesh.
## Returns {"root": Node3D, "parts": {name: Node3D}} or {}.
static func animal(key: String) -> Dictionary:
	var n := _instance(key)
	if n == null:
		return {}
	n.name = key
	var parts := {}
	for c in n.get_children():
		if not c is Node3D:
			continue
		var am := _merge(c as Node3D)
		for old in c.get_children():
			c.remove_child(old)
			old.free()
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.name = "Mesh"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(mi)
		parts[str(c.name)] = c
	return {"root": n, "parts": parts}

## A placed static model (portal, lining, a mountain) as one node with a single merged mesh.
static func placed(key: String) -> Node3D:
	var m := mesh(key)
	if m == null:
		return null
	var n := Node3D.new()
	n.name = "World_" + key
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = m
	mi.set_meta("art", true)
	n.add_child(mi)
	return n
