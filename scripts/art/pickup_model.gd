extends RefCounted
class_name PickupModel
## Grandpa Walt's old pickup: a weathered green single-cab truck with a wooden-sided bed, built from a few dozen flat boxes (no assets). Forward is -Z, up +Y, the driver sits on the
## left (-X). `build()` returns {"root", "wheels" (pivots with a "radius" meta), "interior" (the cab furnishings, shown only while someone rides in it), "headlights", "seat_walt",
## "eye"}. The cab has real openings (windscreen, side windows, a rear window) so the view from the passenger seat is a proper one.

const BODY := Color(0.30, 0.42, 0.31)
const BODY_DARK := Color(0.20, 0.30, 0.22)
const TRIM := Color(0.62, 0.62, 0.58)
const TYRE := Color(0.07, 0.07, 0.07)
const WOOD := Color(0.45, 0.32, 0.20)
const SEAT := Color(0.44, 0.30, 0.19)
const DASH := Color(0.20, 0.18, 0.16)

## Boxes are collected per parent and colour and emitted as ONE mesh each by _flush() (the whole pickup is about two dozen mesh nodes, not two hundred).
static var _acc := {}

static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive := 0.0, rot := Vector3.ZERO) -> void:
	var key := "%d|%s|%s" % [parent.get_instance_id(), color.to_html(), str(emissive)]
	if not _acc.has(key):
		_acc[key] = {"soup": MeshKit.Soup.new(), "parent": parent, "color": color, "emissive": emissive}
	var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), pos)
	MeshKit.box_into(_acc[key]["soup"], Vector3.ZERO, size, Vector2.ONE, xf)

static func _flush() -> void:
	for key in _acc:
		var e: Dictionary = _acc[key]
		var mi := MeshInstance3D.new()
		mi.mesh = (e["soup"] as MeshKit.Soup).mesh()
		mi.material_override = MeshKit.flat(e["color"], float(e["emissive"]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(e["parent"] as Node3D).add_child(mi)
	_acc.clear()

static func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.78, 0.82, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.2
	return m

static func _quad(parent: Node3D, pos: Vector3, size: Vector2, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## The Blender model (tools/world_models/build_world.py -> WLD_QD_pickup.glb) when it is there; the box-built one below is the fallback.
static func build() -> Dictionary:
	if WorldModels.has("pickup"):
		var d: Dictionary = WorldModels.animal("pickup")
		if not d.is_empty():
			return _from_model(d)
	return _build_procedural()

static func _from_model(d: Dictionary) -> Dictionary:
	var root: Node3D = d["root"]
	root.name = "Pickup"
	var parts: Dictionary = d["parts"]
	var wheels: Array = []
	for k in ["WheelFL", "WheelFR", "WheelBL", "WheelBR"]:
		if parts.has(k):
			(parts[k] as Node3D).set_meta("radius", 0.42)
			wheels.append(parts[k])
	var lights := Node3D.new()
	lights.name = "Headlights"
	lights.position = Vector3(0, 1.0, -2.5)
	for sx in [-1.0, 1.0]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(sx * 0.66, 0, 0)
		sp.rotation_degrees = Vector3(-4, 0, 0)
		sp.spot_range = 30.0
		sp.spot_angle = 34.0
		sp.light_energy = 2.2
		sp.light_color = Color(1.0, 0.92, 0.72)
		sp.shadow_enabled = false
		lights.add_child(sp)
	root.add_child(lights)
	return {"root": root, "wheels": wheels, "interior": parts.get("Interior"), "headlights": lights, "steering": parts.get("SteeringWheel")}

static func _build_procedural() -> Dictionary:
	_acc.clear()
	var root := Node3D.new()
	root.name = "Pickup"
	# ---- chassis, hood, grille, lights, bumpers
	_box(root, Vector3(0, 0.58, 0.1), Vector3(1.8, 0.28, 4.9), DASH)
	_box(root, Vector3(0, 0.98, -1.55), Vector3(1.8, 0.45, 1.55), BODY)
	_box(root, Vector3(0, 1.0, -2.34), Vector3(1.3, 0.42, 0.06), BODY_DARK)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * 0.66, 1.02, -2.38), Vector3(0.3, 0.2, 0.08), Color(1.0, 0.9, 0.6), 1.2)
		_box(root, Vector3(sx * 0.96, 0.96, -1.55), Vector3(0.22, 0.12, 1.15), BODY)          # fender over the wheel
		_box(root, Vector3(sx * 0.96, 0.62, 0.0), Vector3(0.1, 0.06, 4.1), TRIM)              # running board / sill
	_box(root, Vector3(0, 0.55, -2.42), Vector3(1.95, 0.16, 0.16), TRIM)
	_box(root, Vector3(0, 0.6, 2.95), Vector3(1.95, 0.16, 0.16), TRIM)
	# ---- the cab: floor, door skins, pillars, roof, rear wall with a window
	_box(root, Vector3(0, 0.66, -0.08), Vector3(1.86, 0.06, 1.42), DASH)                      # floor
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * 0.93, 0.95, -0.08), Vector3(0.06, 0.58, 1.42), BODY)          # door skins below the window line
		_box(root, Vector3(sx * 0.93, 1.67, -0.74), Vector3(0.1, 0.94, 0.1), BODY)              # A pillars
		_box(root, Vector3(sx * 0.93, 1.67, 0.6), Vector3(0.1, 0.94, 0.1), BODY)               # rear pillars
		_box(root, Vector3(sx * 0.93, 2.16, -0.08), Vector3(0.1, 0.06, 1.42), BODY)           # roof rails
	_box(root, Vector3(0, 2.17, -0.08), Vector3(1.96, 0.07, 1.5), BODY)                       # roof
	_box(root, Vector3(0, 1.3, 0.6), Vector3(1.86, 0.3, 0.06), BODY)                          # rear wall, lower
	_box(root, Vector3(0, 2.1, 0.6), Vector3(1.86, 0.1, 0.06), BODY)                        # rear wall, header
	_box(root, Vector3(0, 0.95, -0.78), Vector3(1.86, 0.55, 0.06), BODY_DARK)                 # firewall
	var gm := _glass()
	_quad(root, Vector3(0, 1.68, -0.8), Vector2(1.76, 0.92), Vector3(-12, 0, 0), gm)          # windscreen
	for sx in [-1.0, 1.0]:
		_quad(root, Vector3(sx * 0.93, 1.67, -0.08), Vector2(1.32, 0.9), Vector3(0, 90, 0), gm)
	_quad(root, Vector3(0, 1.78, 0.6), Vector2(1.5, 0.5), Vector3(0, 0, 0), gm)
	for sx in [-1.0, 1.0]:                                                                    # wing mirrors
		_box(root, Vector3(sx * 1.06, 1.46, -0.8), Vector3(0.05, 0.22, 0.14), Color(0.1, 0.1, 0.1))
	# ---- the bed: floor, wooden sides, tailgate, a coil of rope and a crate
	_box(root, Vector3(0, 0.8, 1.78), Vector3(1.82, 0.12, 2.3), DASH)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * 0.9, 1.08, 1.78), Vector3(0.1, 0.46, 2.3), WOOD)
		_box(root, Vector3(sx * 0.9, 1.34, 1.78), Vector3(0.14, 0.06, 2.34), TRIM)
	_box(root, Vector3(0, 1.08, 0.68), Vector3(1.82, 0.46, 0.1), WOOD)
	_box(root, Vector3(0, 1.08, 2.92), Vector3(1.82, 0.46, 0.1), WOOD)
	_box(root, Vector3(-0.35, 1.02, 1.2), Vector3(0.5, 0.34, 0.4), Color(0.62, 0.5, 0.3))
	_box(root, Vector3(0.4, 0.95, 2.3), Vector3(0.45, 0.2, 0.45), Color(0.5, 0.42, 0.28))
	# ---- wheels (pivots turn about X as it drives)
	var wheels: Array = []
	for wz in [-1.55, 1.75]:
		for sx in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(sx * 0.9, 0.42, wz)
			piv.set_meta("radius", 0.42)
			var cm := CylinderMesh.new()
			cm.top_radius = 0.42
			cm.bottom_radius = 0.42
			cm.height = 0.28
			cm.radial_segments = 14
			var tire := MeshInstance3D.new()
			tire.mesh = cm
			tire.rotation_degrees = Vector3(0, 0, 90)
			tire.material_override = MeshKit.flat(TYRE)
			tire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piv.add_child(tire)
			var hm := CylinderMesh.new()
			hm.top_radius = 0.2
			hm.bottom_radius = 0.2
			hm.height = 0.3
			hm.radial_segments = 8
			var hub := MeshInstance3D.new()
			hub.mesh = hm
			hub.rotation_degrees = Vector3(0, 0, 90)
			hub.material_override = MeshKit.flat(TRIM)
			hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piv.add_child(hub)
			_box(piv, Vector3(0, 0.0, 0.0), Vector3(0.32, 0.06, 0.06), Color(0.3, 0.3, 0.3))     # a spoke so the turning shows
			root.add_child(piv)
			wheels.append(piv)
	# ---- the cab furnishings (only while somebody rides in it)
	var inside := Node3D.new()
	inside.name = "Interior"
	root.add_child(inside)
	_box(inside, Vector3(0, 0.95, -0.55), Vector3(1.8, 0.5, 0.42), DASH)                      # dashboard
	_box(inside, Vector3(0, 1.21, -0.62), Vector3(1.7, 0.03, 0.3), Color(0.14, 0.13, 0.12))   # its top pad
	_box(inside, Vector3(-0.45, 1.12, -0.34), Vector3(0.5, 0.14, 0.04), Color(0.08, 0.08, 0.08))  # the instrument binnacle
	for k in range(3):
		_box(inside, Vector3(-0.58 + k * 0.13, 1.12, -0.315), Vector3(0.08, 0.08, 0.01), Color(0.9, 0.78, 0.45), 0.8)
	_box(inside, Vector3(0.45, 1.0, -0.33), Vector3(0.6, 0.2, 0.04), Color(0.16, 0.15, 0.14))  # the glovebox door
	_box(inside, Vector3(0.45, 0.98, -0.305), Vector3(0.1, 0.03, 0.02), TRIM)
	_box(inside, Vector3(0.0, 1.05, -0.33), Vector3(0.28, 0.16, 0.04), Color(0.1, 0.1, 0.1))   # the radio
	var col := MeshInstance3D.new()                                                          # steering column and wheel
	var colm := CylinderMesh.new()
	colm.top_radius = 0.025
	colm.bottom_radius = 0.025
	colm.height = 0.3
	col.mesh = colm
	col.position = Vector3(-0.45, 1.1, -0.36)
	col.rotation_degrees = Vector3(70, 0, 0)
	col.material_override = MeshKit.flat(Color(0.1, 0.1, 0.1))
	inside.add_child(col)
	var wheel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.19
	tm.rings = 12
	tm.ring_segments = 6
	wheel.mesh = tm
	wheel.position = Vector3(-0.45, 1.2, -0.2)
	wheel.rotation_degrees = Vector3(70, 0, 0)
	wheel.material_override = MeshKit.flat(Color(0.08, 0.08, 0.08))
	inside.add_child(wheel)
	wheel.name = "SteeringWheel"
	_box(inside, Vector3(-0.45, 1.2, -0.2), Vector3(0.1, 0.03, 0.1), TRIM, 0.0, Vector3(70, 0, 0))   # the hub
	_box(inside, Vector3(0, 0.82, 0.1), Vector3(1.78, 0.22, 0.58), SEAT)                      # bench seat
	_box(inside, Vector3(0, 1.26, 0.42), Vector3(1.78, 0.66, 0.16), SEAT)                     # backrest
	_box(inside, Vector3(0, 0.98, 0.08), Vector3(0.04, 0.12, 0.5), Color(0.34, 0.22, 0.14))    # the seam
	_box(inside, Vector3(0, 2.12, -0.08), Vector3(1.82, 0.03, 1.44), Color(0.7, 0.66, 0.58))    # headliner
	_box(inside, Vector3(0, 1.98, -0.72), Vector3(0.16, 0.05, 0.02), Color(0.14, 0.14, 0.14))  # rear-view mirror
	_box(inside, Vector3(0, 2.05, -0.72), Vector3(0.02, 0.1, 0.02), Color(0.14, 0.14, 0.14))
	_box(inside, Vector3(0.1, 1.88, -0.72), Vector3(0.03, 0.07, 0.005), Color(0.3, 0.75, 0.35))  # the air freshener
	for sx in [-1.0, 1.0]:
		_box(inside, Vector3(sx * 0.45, 2.07, -0.62), Vector3(0.7, 0.03, 0.26), Color(0.16, 0.14, 0.12))   # sun visors
		_box(inside, Vector3(sx * 0.88, 0.95, -0.08), Vector3(0.05, 0.5, 1.36), Color(0.36, 0.25, 0.16))  # door cards
		_box(inside, Vector3(sx * 0.86, 1.12, -0.08), Vector3(0.08, 0.06, 0.5), Color(0.26, 0.18, 0.12))  # armrests
		_box(inside, Vector3(sx * 0.86, 1.06, 0.2), Vector3(0.06, 0.05, 0.16), TRIM)                     # door handles
		_box(inside, Vector3(sx * 0.86, 1.04, -0.4), Vector3(0.06, 0.08, 0.06), TRIM)                    # window winders
	_box(inside, Vector3(0, 0.7, 0.0), Vector3(0.18, 0.1, 0.5), Color(0.15, 0.14, 0.13))                # gear-stick tunnel hump
	_box(inside, Vector3(0.0, 0.92, -0.1), Vector3(0.04, 0.4, 0.04), Color(0.1, 0.1, 0.1), 0.0, Vector3(-12, 0, 0))
	# ---- headlights
	var lights := Node3D.new()
	lights.name = "Headlights"
	lights.position = Vector3(0, 1.0, -2.5)
	for sx in [-1.0, 1.0]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(sx * 0.66, 0, 0)
		sp.rotation_degrees = Vector3(-4, 0, 0)
		sp.spot_range = 30.0
		sp.spot_angle = 34.0
		sp.light_energy = 2.2
		sp.light_color = Color(1.0, 0.92, 0.72)
		sp.shadow_enabled = false
		lights.add_child(sp)
	root.add_child(lights)
	_flush()
	return {"root": root, "wheels": wheels, "interior": inside, "headlights": lights}

## Where things sit in the cab (truck-local metres): Walt at the wheel (hips on the bench), the passenger's eyes.
const SEAT_WALT := Vector3(-0.45, 0.12, 0.1)
const EYE := Vector3(0.45, 1.6, 0.08)
