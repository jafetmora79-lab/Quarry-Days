extends Node
class_name RepairKit
## The excavator's repair kit as it stands on the machine (Blender: tools/world_models/repair_kit.py -> assets/world/WLD_QD_excavator_kit.glb and WLD_QD_repair_parts.glb).
##
## Kit_Turret is attached to the excavator's Turret node and Kit_Boom to its Boom node with identity transforms, so every marker is the REAL place on the machine whichever way it faces and
## whatever the ground: FuelFiller / FuelPourTarget / FuelCapRest / FuelTether, BatteryTray / BatteryPositive / BatteryNegative / LeadStud*, HoseStart (on the turret) and HoseEnd (on the boom).
## Nothing here uses world coordinates: every pose is computed from marker transforms (kit.m("FuelFiller")), so a rotated turret, a lifted boom or a machine parked on a slope all work.
##
## Three live parts are drawn each frame from the markers, so they stay attached when the boom, stick and bucket move:
##   the hydraulic hose   a rubber tube (swept from a Bezier with sag) between two metal end fittings seated on the two ports; it is rebuilt whenever a port moves
##   the battery leads    two cables from the tray's studs to the terminals (dangling loose until the battery is in)
##   the cap tether       a cord from the filler's lug to the cap, so the cap hangs or lies where its tether allows
## State (battery / hose / fuel) is shown by apply_state().

var vehicle
var rig
var turret_part: Node3D
var boom_part: Node3D
var marks := {}
var cap: Node3D
var cover: Node3D
var battery_node: Node3D
var hose_a: Node3D
var hose_b: Node3D
var hose_mesh: MeshInstance3D
var stub_mesh: MeshInstance3D
var cable_mesh := {}                   ## "pos" / "neg" -> MeshInstance3D
var lugs := {}                         ## "pos" / "neg" -> Node3D (the ring terminal on the loose end)
var tether_mesh: MeshInstance3D
var tether_free := true                ## true: the tether follows the cap wherever it is; false: the cap is screwed on
var hose_slack := 0.06
var state := {"battery": false, "hose": false, "fuel": false}
var hose_live := false                 ## the full hose is drawn (and follows the ports)
var leads_live := true
var _hose_sig := ""
var _mat_rubber: StandardMaterial3D
var _mat_cable := {}

const HOSE_RADIUS := 0.026
const LUG_LOOSE := {"pos": Vector3(0.03, -0.11, -0.05), "neg": Vector3(-0.03, -0.11, -0.05)}      ## where a loose lead hangs, relative to its stud (turret-local)

## Creates the kit on a vehicle with a Blender excavator rig. Returns null for any other machine.
static func attach_to(v) -> RepairKit:
	if v == null or v.rig == null or v.turret == null or v.rig.boom == null:
		return null
	if v.get("repair_kit") != null:
		return v.repair_kit
	var k := RepairKit.new()
	k.name = "RepairKit"
	v.add_child(k)
	if not k._build(v):
		k.queue_free()
		return null
	v.set("repair_kit", k)
	return k

func _build(v) -> bool:
	vehicle = v
	rig = v.rig
	var root: Node3D = WorldModels.dressed("excavator_kit")
	if root == null:
		return false
	turret_part = root.get_node_or_null("Kit_Turret") as Node3D
	boom_part = root.get_node_or_null("Kit_Boom") as Node3D
	if turret_part == null or boom_part == null:
		root.free()
		return false
	root.remove_child(turret_part)
	root.remove_child(boom_part)
	root.free()
	rig.turret.add_child(turret_part)
	rig.boom.add_child(boom_part)
	for part in [turret_part, boom_part]:
		for n in (part as Node).find_children("Marker_*", "Node3D", true, false):
			marks[str(n.name).substr(7)] = n
	cap = turret_part.find_child("Fuel_Cap", true, false) as Node3D
	cover = turret_part.find_child("Battery_Cover", true, false) as Node3D
	_mat_rubber = StandardMaterial3D.new()
	_mat_rubber.albedo_color = Color(0.13, 0.14, 0.17)
	_mat_rubber.roughness = 0.9
	_mat_cable["pos"] = _flat(Color(0.78, 0.12, 0.10))
	_mat_cable["neg"] = _flat(Color(0.07, 0.07, 0.08))
	hose_mesh = _mesh_node("Hose", _mat_rubber)
	stub_mesh = _mesh_node("HoseStub", _mat_rubber)
	tether_mesh = _mesh_node("CapTether", _flat(Color(0.12, 0.12, 0.13)))
	for k in ["pos", "neg"]:
		cable_mesh[k] = _mesh_node("Lead_" + k, _mat_cable[k])
		var lug := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.012, 0.05)
		lug.mesh = bm
		lug.material_override = _flat(Color(0.72, 0.74, 0.76))
		lug.name = "Lug_" + k
		turret_part.add_child(lug)
		lugs[k] = lug
	hose_a = part("hose_fitting")
	hose_b = part("hose_fitting")
	turret_part.add_child(hose_a)
	turret_part.add_child(hose_b)
	battery_node = part("battery")
	turret_part.add_child(battery_node)
	return true

func m(name: String) -> Node3D:
	return marks.get(name) as Node3D

func _flat(c: Color) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = 0.9
	return mt

func _mesh_node(nm: String, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true                      # drawn in world space from world-space points
	add_child(mi)
	return mi

## A loose repair part from the Blender set: "fuel_can", "battery" or "hose_fitting". A fresh copy each call; null if the model is missing.
static func part(id: String) -> Node3D:
	var all: Node3D = WorldModels.dressed("repair_parts")
	if all == null:
		return Node3D.new()
	var n := all.get_node_or_null(id) as Node3D
	if n == null:
		all.free()
		return Node3D.new()
	all.remove_child(n)
	all.free()
	return n

# ------------------------------------------------------------------ state

## Shows what has been repaired. unrepaired: cap off beside the open filler, tray open and empty with loose leads, a torn stub on the hose port.
func apply_state(battery: bool, hose: bool, fuel: bool) -> void:
	state = {"battery": battery, "hose": hose, "fuel": fuel}
	# fuel
	if cap != null:
		cap.global_transform = cap_seated_xf()                     # the cap is on either way (the repair takes it off, pours, and puts it back)
		tether_free = false
	# battery
	if battery_node != null:
		battery_node.visible = battery
		if battery:
			battery_node.global_transform = battery_seated_xf()
	if cover != null:
		cover.rotation.x = 0.0 if battery else 1.75
	leads_live = true
	for k in ["pos", "neg"]:
		lugs[k].visible = true
		if battery:
			lugs[k].global_position = terminal_point(k) + Vector3(0, 0.005, 0)
		else:
			lugs[k].global_position = stud(k) + (turret_part.global_basis * LUG_LOOSE[k])
	# hose
	hose_live = hose
	hose_a.visible = hose
	hose_b.visible = hose
	hose_mesh.visible = hose
	stub_mesh.visible = not hose
	_hose_sig = ""
	_update_geometry()

# ------------------------------------------------------------------ transforms from markers

func stud(k: String) -> Vector3:
	return m("LeadStudPositive" if k == "pos" else "LeadStudNegative").global_position

func terminal_point(k: String) -> Vector3:
	return m("BatteryPositive" if k == "pos" else "BatteryNegative").global_position

## The cap's pose on the filler: its pivot is the mouth, +Y the filler's axis.
func cap_seated_xf() -> Transform3D:
	return m("FuelFiller").global_transform

## The cap lying on the tank top beside the filler (flat), where its tether lets it rest.
func cap_rest_xf() -> Transform3D:
	var f := m("FuelCapRest").global_transform
	return Transform3D(f.basis, f.origin)

func battery_seated_xf() -> Transform3D:
	return m("BatteryTray").global_transform

## The pose of a hose end fitting seated on a port: its +Y axis points into the port, the mouth is at the nipple's base, and `back` pulls it straight back out along the port axis.
func fitting_xf(port: String, back := 0.0, turn := 0.0) -> Transform3D:
	var pm := m(port)
	var d: Vector3 = pm.global_basis.x.normalized()                    # the port's outward axis (the kit's +X)
	var y := -d
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	var b := Basis(x, y, z).rotated(y, turn)
	var mouth := pm.global_position - d * 0.04 + d * back
	return Transform3D(b, mouth + d * 0.07)                           # the fitting's origin sits 0.07 behind its mouth

# ------------------------------------------------------------------ per-frame upkeep

func _process(_delta: float) -> void:
	_update_geometry()

func _update_geometry() -> void:
	if marks.is_empty():
		return
	if hose_live and hose_a != null and hose_a.visible:
		if hose_a.get_meta("follow", true):
			hose_a.global_transform = fitting_xf("HoseStart")
		if hose_b.get_meta("follow", true):
			hose_b.global_transform = fitting_xf("HoseEnd")
	_hose_geometry()
	_leads_geometry()
	_tether_geometry()

func _end_of(fit: Node3D) -> Array:
	var j: Vector3 = fit.to_global(Vector3(0, -0.10, 0))
	var d: Vector3 = (-fit.global_basis.y).normalized()
	return [j, d]

func _hose_geometry() -> void:
	if hose_live and hose_a.visible:
		var ea := _end_of(hose_a)
		var eb := _end_of(hose_b)
		var sig := "%s%s%s%s" % [str((ea[0] as Vector3).snapped(Vector3.ONE * 0.002)), str((ea[1] as Vector3).snapped(Vector3.ONE * 0.02)), str((eb[0] as Vector3).snapped(Vector3.ONE * 0.002)), str((eb[1] as Vector3).snapped(Vector3.ONE * 0.02))]
		if sig != _hose_sig:
			_hose_sig = sig
			hose_mesh.mesh = hose_between(ea[0], ea[1], eb[0], eb[1], hose_slack)
	if stub_mesh.visible:
		var pm := m("HoseStart")
		var d: Vector3 = pm.global_basis.x.normalized()
		var p0 := pm.global_position + d * 0.02
		# a split hose hanging limp from the port: out, then down, ending in a frayed cut
		var pts := PackedVector3Array([p0, p0 + d * 0.06 + Vector3(0, -0.02, 0), p0 + d * 0.11 + Vector3(0, -0.10, 0), p0 + d * 0.13 + Vector3(0, -0.22, 0), p0 + d * 0.13 + Vector3(0, -0.34, 0)])
		stub_mesh.mesh = tube(pts, HOSE_RADIUS)

## A hose between two end fittings: leaves each along its tangent, bows out by `slack`, sags a little. Returns an ArrayMesh in world space.
func hose_between(p0: Vector3, d0: Vector3, p1: Vector3, d1: Vector3, slack: float) -> ArrayMesh:
	var dist := p0.distance_to(p1)
	var k := maxf(0.10, dist * 0.30 + slack)
	var c0 := p0 + d0 * k
	var c1 := p1 + d1 * k
	var pts := PackedVector3Array()
	var n := 20
	for i in range(n + 1):
		var u := float(i) / float(n)
		var a := p0.lerp(c0, u)
		var b := c0.lerp(c1, u)
		var c := c1.lerp(p1, u)
		var p := a.lerp(b, u).lerp(b.lerp(c, u), u)
		p.y -= 0.035 * sin(PI * u)                                       # a little sag
		pts.append(p)
	return tube(pts, HOSE_RADIUS)

## A swept round tube along a polyline (parallel-transport frames), smooth normals, closed ends.
static func tube(pts: PackedVector3Array, radius: float, seg := 7) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := pts.size()
	if n < 2:
		return ArrayMesh.new()
	var prev_n := Vector3.ZERO
	for i in range(n):
		var d: Vector3
		if i == 0:
			d = pts[1] - pts[0]
		elif i == n - 1:
			d = pts[n - 1] - pts[n - 2]
		else:
			d = (pts[i + 1] - pts[i - 1])
		d = d.normalized()
		var nrm: Vector3
		if i == 0:
			var ref := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			nrm = (ref - d * ref.dot(d)).normalized()
		else:
			nrm = (prev_n - d * prev_n.dot(d))
			nrm = nrm.normalized() if nrm.length() > 0.001 else prev_n
		prev_n = nrm
		var bn := d.cross(nrm)
		for s in range(seg):
			var a := TAU * float(s) / float(seg)
			var off := nrm * cos(a) + bn * sin(a)
			verts.append(pts[i] + off * radius)
			norms.append(off)
	for i in range(n - 1):
		for s in range(seg):
			var s2 := (s + 1) % seg
			var a0 := i * seg + s
			var a1 := i * seg + s2
			var b0 := (i + 1) * seg + s
			var b1 := (i + 1) * seg + s2
			idx.append_array([a0, b0, a1, a1, b0, b1])
	# end caps
	for end in [0, n - 1]:
		var c := verts.size()
		verts.append(pts[end])
		var dn := ((pts[1] - pts[0]) if end == 0 else (pts[n - 1] - pts[n - 2])).normalized() * (-1.0 if end == 0 else 1.0)
		norms.append(dn)
		for s in range(seg):
			var s2 := (s + 1) % seg
			if end == 0:
				idx.append_array([c, s2, s])
			else:
				idx.append_array([c, (n - 1) * seg + s, (n - 1) * seg + s2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _leads_geometry() -> void:
	for k in ["pos", "neg"]:
		var a := stud(k)
		var b: Vector3 = (lugs[k] as Node3D).global_position
		var mid := (a + b) * 0.5
		var sag := 0.05 + 0.1 * (1.0 - clampf(a.distance_to(b) / 0.3, 0.0, 1.0))
		var rear: Vector3 = turret_part.global_basis * Vector3(0, 0.03, -0.04)               # the lead leaves the stud, rises a little, then falls toward the lug (all inside the tray)
		var pts := PackedVector3Array()
		for i in range(9):
			var u := float(i) / 8.0
			var p := a.lerp(b, u) + rear * sin(PI * u) * (1.0 - u)
			p.y -= sag * sin(PI * u)
			pts.append(p)
		(cable_mesh[k] as MeshInstance3D).mesh = tube(pts, 0.011, 5)
		(lugs[k] as Node3D).global_basis = turret_part.global_basis

func _tether_geometry() -> void:
	if cap == null:
		return
	var a := m("FuelTether").global_position
	var b: Vector3 = cap.to_global(Vector3(0.066, 0.015, 0.0))
	var dist := a.distance_to(b)
	if not tether_free and dist < 0.02:
		tether_mesh.visible = false
		return
	tether_mesh.visible = true
	var pts := PackedVector3Array()
	var slack := maxf(0.0, 0.30 - dist)                                                  # the tether is 0.30 m long: what the cap does not use hangs as a loop
	for i in range(9):
		var u := float(i) / 8.0
		var p := a.lerp(b, u)
		p.y -= (0.02 + slack * 0.6) * sin(PI * u)
		pts.append(p)
	tether_mesh.mesh = tube(pts, 0.006, 4)
