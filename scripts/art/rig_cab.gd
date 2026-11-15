extends RefCounted
class_name RigCab
## The cab data the game's boarding and cab view need ("cab" meta, see CabInterior / QuarryBoarding) for the Blender machines. The Blender models already have
## a seat, dash, controls, glass and (mostly) foot steps; what they lack is the *moving* parts of getting in: a hinged door, an ignition key and dash lamps, plus
## the keyframe anchors (door sill, top step, eyes). Those are placed here from the model's own `Marker_Eye` and its measured cab (the numbers below are
## the Blender build constants converted to Godot axes: godot z = -blender y), in the space of `ref` (the excavator's turret; the rig node for the others).
##
##   hinge   front edge of the door at sill height, on the cab's outer face      depth  door length (extends toward +Z, like CabInterior.door)
##   height  door height above the sill   lower  painted lower panel height     side   -1 door on the left, +1 on the right
##   step    the top foot step (outside the door)                                base_y where the lowest foot step rises from, or -1 when the model has its own steps
##   dash    [x centre, top y, driver-facing z, width] of the dash the lamps and the ignition go on

const SPEC := {
	"excavator": {"hinge": Vector3(-0.17, 0.13, -0.58), "depth": 0.48, "height": 1.1, "lower": 0.35, "side": 1.0, "step": Vector3(-0.19, 0.13, -0.3), "base_y": -0.77,
		"dash": [-0.58, 0.56, -0.40, 0.7], "paint": "main"},
	"truck": {"hinge": Vector3(-0.985, 1.0, -1.55), "depth": 0.62, "height": 1.2, "lower": 0.45, "side": -1.0, "step": Vector3(-1.05, 0.82, -1.28), "base_y": -1.0,
		"dash": [0.0, 1.42, -1.54, 1.5], "paint": "cab"},
	"loader": {"hinge": Vector3(-0.69, 1.06, 0.3), "depth": 0.58, "height": 1.15, "lower": 0.5, "side": -1.0, "step": Vector3(-1.0, 0.78, 0.4), "base_y": -1.0,
		"dash": [0.0, 1.38, 0.36, 1.1], "paint": "main"},
	"dozer": {"hinge": Vector3(-0.725, 1.08, 0.08), "depth": 0.6, "height": 1.2, "lower": 0.3, "side": -1.0, "step": Vector3(-1.12, 1.0, 0.35), "base_y": 0.0,
		"dash": [0.0, 1.38, -0.02, 1.2], "paint": "main"},
}

## `ref` is the node the spec's positions are in, `model` the instanced GLB (it holds Marker_Eye).
static func attach(v, kind: String, ref: Node3D, model: Node3D, paint_key: String) -> void:
	var s: Dictionary = SPEC[kind]
	var side: float = s["side"]
	var eye_marker := model.find_child("Marker_Eye", true, false) as Node3D
	var eye := Vector3(0, 1.8, 0) if eye_marker == null else pos_in(eye_marker, ref)
	var hinge: Vector3 = s["hinge"]
	var depth: float = s["depth"]
	var door := CabInterior.door(ref, hinge, depth, float(s["height"]), float(s["lower"]), paint_key, side, VehicleModels.GLASS)
	if float(s["base_y"]) > -0.99:
		CabInterior.steps(ref, s["step"], float(s["base_y"]), side)
	var step: Vector3 = s["step"]
	var inter := Node3D.new()
	inter.name = "Interior"
	ref.add_child(inter)
	var d: Array = s["dash"]
	var parts := _dash(inter, Vector3(d[0], d[1], d[2]), float(d[3]))
	v.set_meta("cab", {"ref": ref, "eye": eye, "door": door, "door_c": hinge + Vector3(side * 0.02, 0.0, depth * 0.5), "open": CabInterior.open_angle(side), "side": side,
		"key": parts["key"], "lamps": parts["lamps"], "step": step})

## Five dash lamps (dark until the key is turned) and the ignition switch with its key.
static func _dash(parent: Node3D, dash: Vector3, w: float) -> Dictionary:
	var lamps := []
	var colors := [Color(0.9, 0.2, 0.15), Color(1.0, 0.7, 0.15), Color(0.3, 0.9, 0.35), Color(0.7, 0.9, 1.0), Color(0.7, 0.9, 1.0)]
	var gx := dash.x - w * 0.3
	for k in range(5):
		var gm := MeshKit.flat(colors[k] * 0.25)
		var gs := MeshKit.Soup.new()
		var size := Vector3(0.05, 0.05, 0.016) if k >= 3 else Vector3(0.04, 0.025, 0.016)
		MeshKit.box_into(gs, Vector3(gx + float(k) * w * 0.12, dash.y + 0.04, dash.z + 0.012), size)
		var mi := MeshKit.inst(parent, gs.mesh(), gm)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamps.append({"mat": gm, "color": colors[k]})
	var ik := Vector3(dash.x + w * 0.28, dash.y + 0.02, dash.z + 0.012)
	var plate := MeshKit.Soup.new()
	MeshKit.box_into(plate, ik, Vector3(0.06, 0.06, 0.016))
	MeshKit.inst(parent, plate.mesh(), MeshKit.mat("SteelPlate")).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var key := Node3D.new()
	key.name = "Key"
	key.position = ik + Vector3(0, 0, 0.016)
	parent.add_child(key)
	var ks := MeshKit.Soup.new()
	MeshKit.box_into(ks, Vector3(0, 0.03, 0.015), Vector3(0.018, 0.05, 0.012))
	MeshKit.box_into(ks, Vector3(0, 0.0, 0.0), Vector3(0.024, 0.024, 0.02))
	MeshKit.inst(key, ks.mesh(), MeshKit.flat(Color(0.85, 0.7, 0.2))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"key": key, "lamps": lamps}

## Where `n` sits in `ref`'s space (works before either is in the tree).
static func pos_in(n: Node3D, ref: Node3D) -> Vector3:
	var p := Vector3.ZERO
	var cur := n
	while cur != null and cur != ref:
		p = cur.transform * p
		cur = cur.get_parent() as Node3D
	return p
