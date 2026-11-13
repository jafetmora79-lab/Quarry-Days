extends RefCounted
class_name VehicleModels
## PSX-style industrial vehicle models for QuarryVehicle (front loader, dump truck). Built from extruded
## side profiles, beveled panels, faceted wheels with tread texture, hydraulic rams and glass, using the
## Quarry Days / THE VEIL pixel materials. Vehicles face -Z. Only visuals: collision stays one box.

const GLASS := "res://assets/materials/M_QD_Glass.tres"

static func _soups(keys: Array) -> Dictionary:
	var d := {}
	for k in keys:
		d[k] = MeshKit.Soup.new()
	return d

static func _emit(parent: Node3D, parts: Dictionary) -> void:
	MeshKit.repair(parts)
	for key in parts:
		var s: MeshKit.Soup = parts[key]
		if s.verts.size() > 0:
			MeshKit.inst(parent, s.mesh(), MeshKit.mat(key))

static func _xf(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)

## Wheel: tread drum + rim + hub cap; returns the spinning pivot (rotate about local X).
static func wheel(parent: Node3D, pos: Vector3, radius: float, width: float, rim_key: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.set_meta("radius", radius)          # the vehicle spins it by the distance it has really travelled
	parent.add_child(pivot)
	var tire := MeshKit.Soup.new()
	MeshKit.drum_into(tire, Vector3.ZERO, radius, width, 12)
	MeshKit.inst(pivot, tire.mesh(), MeshKit.mat("Tire"))
	var rim := MeshKit.Soup.new()
	var side := signf(pos.x) if pos.x != 0.0 else 1.0
	MeshKit.drum_into(rim, Vector3(side * 0.02, 0, 0), radius * 0.55, width + 0.02, 8)
	MeshKit.drum_into(rim, Vector3(side * (width * 0.5 + 0.03), 0, 0), radius * 0.22, 0.06, 6)
	MeshKit.inst(pivot, rim.mesh(), MeshKit.mat(rim_key))
	return pivot

## A solid steel roller on a pivot (rotates about local X) registered with the vehicle's spinning wheels.
static func _roller(v, pos: Vector3, radius: float, width: float, seg: int) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.set_meta("radius", radius)
	v.model_root.add_child(pivot)
	var d := MeshKit.Soup.new()
	MeshKit.drum_into(d, Vector3.ZERO, radius, width, seg)
	MeshKit.box_into(d, Vector3.ZERO, Vector3(width + 0.02, radius * 0.5, radius * 0.25))          # a spoke, so the rolling is visible
	MeshKit.inst(pivot, d.mesh(), MeshKit.mat("SteelPlate"))
	v.wheels.append(pivot)

## Hydraulic ram between two points (barrel + chrome rod). Returns the node so it can be re-aimed.
static func ram(parent: Node3D, a: Vector3, b: Vector3, r := 0.06) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var barrel := MeshKit.Soup.new()
	MeshKit.frustum_into(barrel, Vector3.ZERO, r, r, 0.55, 6)
	MeshKit.inst(n, barrel.mesh(), MeshKit.mat("SteelGreen"))
	var rod := MeshKit.Soup.new()
	MeshKit.frustum_into(rod, Vector3(0, 0.5, 0), r * 0.5, r * 0.5, 0.5, 6)
	MeshKit.inst(n, rod.mesh(), MeshKit.mat(QuarryArt.M_BRUSHED))
	aim(n, a, b)
	return n

static func aim(n: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := maxf(0.05, d.length())
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	n.transform = Transform3D(Basis(x, y * (len / 1.0), z), a)

# ------------------------------------------------------------------ front loader (2.0 x 1.5 x 3.0)

static func loader(v) -> void:
	var p := _soups(["PaintYellow", "SteelPlate", "Hazard"])
	# rear engine body: hooded side profile (z, y), rounded tail
	var body := PackedVector2Array([Vector2(-0.25, 0.55), Vector2(1.5, 0.55), Vector2(1.55, 0.75), Vector2(1.5, 1.2), Vector2(1.35, 1.32), Vector2(0.45, 1.32), Vector2(0.4, 1.0), Vector2(-0.25, 1.0)])
	MeshKit.extrude_into(p["PaintYellow"], body, 1.5)
	MeshKit.box_into(p["SteelPlate"], Vector3(0, 0.82, 1.56), Vector3(1.6, 0.42, 0.18))          # counterweight
	MeshKit.box_into(p["Hazard"], Vector3(0, 0.82, 1.66), Vector3(1.5, 0.12, 0.02))
	for z in [0.8, 1.1]:
		MeshKit.box_into(p["SteelPlate"], Vector3(0, 1.335, z), Vector3(1.0, 0.02, 0.08))            # engine louvres
	MeshKit.box_into(p["SteelPlate"], Vector3(0, 0.75, -0.75), Vector3(1.05, 0.42, 1.1))         # front frame / articulation
	MeshKit.box_into(p["SteelPlate"], Vector3(0, 0.52, -0.2), Vector3(0.5, 0.3, 0.5))            # pivot joint
	MeshKit.frustum_into(p["SteelPlate"], Vector3(0.52, 1.3, 1.2), 0.07, 0.06, 0.75, 6)           # exhaust stack
	# cab: posts, roof, glass
	for x in [-0.6, 0.6]:
		for z in [-0.55, 0.35]:
			MeshKit.box_into(p["SteelPlate"], Vector3(x, 1.62, z), Vector3(0.07, 1.25, 0.07))
	MeshKit.box_into(p["PaintYellow"], Vector3(0, 2.28, -0.1), Vector3(1.4, 0.12, 1.2), Vector2(0.94, 0.92))
	MeshKit.box_into(p["SteelPlate"], Vector3(0, 1.02, -0.1), Vector3(1.3, 0.06, 0.95))           # cab floor
	# fenders over the wheels
	for x in [-0.98, 0.98]:
		for z in [-0.85, 0.95]:
			MeshKit.box_into(p["PaintYellow"], Vector3(x, 1.12, z), Vector3(0.48, 0.06, 1.15), Vector2(1.0, 0.85))
	_emit(v.model_root, p)
	var glass := MeshKit.Soup.new()
	MeshKit.box_into(glass, Vector3(0, 1.62, -0.56), Vector3(1.15, 1.1, 0.02))
	MeshKit.box_into(glass, Vector3(0, 1.72, 0.36), Vector3(1.15, 0.9, 0.02))
	for x in [-0.6, 0.6]:
		MeshKit.box_into(glass, Vector3(x, 1.72, -0.1), Vector3(0.02, 0.9, 0.85))
	MeshKit.inst(v.model_root, glass.mesh(), MeshKit.mat(GLASS))
	var lamps := MeshKit.Soup.new()
	for x in [-0.5, 0.5]:
		MeshKit.box_into(lamps, Vector3(x, 2.2, -0.72), Vector3(0.16, 0.1, 0.06))
	MeshKit.inst(v.model_root, lamps.mesh(), MeshKit.flat(Color(1.0, 0.92, 0.7), 0.8))
	for x in [-0.98, 0.98]:
		for z in [-0.85, 0.95]:
			v.wheels.append(wheel(v.model_root, Vector3(x, 0.55, z), 0.55, 0.42, "PaintYellow"))
	# lift arms + bucket (animated nodes used by QuarryVehicle)
	v.arm = Node3D.new()
	v.arm.position = Vector3(0, 1.15, -0.45)
	v.model_root.add_child(v.arm)
	var a := _soups(["PaintYellow", "SteelPlate"])
	for x in [-0.66, 0.66]:
		var beam := PackedVector2Array([Vector2(0.15, -0.08), Vector2(-1.55, -0.32), Vector2(-1.6, -0.12), Vector2(-0.6, 0.06), Vector2(0.15, 0.1)])
		MeshKit.extrude_into(a["PaintYellow"], beam, 0.16, _xf(Vector3(x, 0, 0)))
	MeshKit.drum_into(a["SteelPlate"], Vector3(0, -0.12, -0.95), 0.07, 1.3, 6)                   # cross tube
	_emit(v.arm, a)
	for x in [-0.42, 0.42]:
		ram(v.arm, Vector3(x, -0.45, 0.2), Vector3(x, -0.12, -0.9), 0.07)                        # lift cylinders
	v.bucket = Node3D.new()
	v.bucket.position = Vector3(0, -0.2, -1.55)
	v.arm.add_child(v.bucket)
	var b := _soups(["SteelPlate", "Hazard"])
	# curved scoop shell (C-profile): back plate sweeping into the floor and a cutting edge
	var shell := PackedVector2Array([Vector2(0.28, 0.42), Vector2(0.22, 0.12), Vector2(0.08, -0.08), Vector2(-0.15, -0.16), Vector2(-0.62, -0.16),
		Vector2(-0.64, -0.11), Vector2(-0.16, -0.10), Vector2(0.03, -0.03), Vector2(0.16, 0.14), Vector2(0.22, 0.42)])
	MeshKit.extrude_into(b["SteelPlate"], shell, 2.1)
	for x in [-1.05, 1.05]:
		var plate := PackedVector2Array([Vector2(0.28, 0.42), Vector2(0.1, -0.12), Vector2(-0.64, -0.16), Vector2(-0.5, 0.0)])
		MeshKit.extrude_into(b["SteelPlate"], plate, 0.04, _xf(Vector3(x, 0, 0)))
	for k in range(6):
		MeshKit.box_into(b["SteelPlate"], Vector3(-0.9 + k * 0.36, -0.15, -0.7), Vector3(0.09, 0.05, 0.16), Vector2(0.6, 0.6))   # teeth
	MeshKit.box_into(b["Hazard"], Vector3(0, 0.4, 0.26), Vector3(2.0, 0.05, 0.04))
	_emit(v.bucket, b)
	v.bucket_load = MeshKit.inst(v.bucket, MeshKit.rock(Vector3(1.8, 0.4, 0.6), 41, 3, 7), MeshKit.mat("RockLimestone"), Vector3(0, -0.12, -0.22))
	v.bucket_load.visible = false

# ------------------------------------------------------------------ dump truck (2.2 x 1.8 x 4.6)

static func truck(v) -> void:
	var cab_paint: String = v.paint_cab
	var bed_paint: String = v.paint_bed
	var p := _soups([cab_paint, "SteelPlate", "Hazard"])
	for x in [-0.55, 0.55]:
		MeshKit.box_into(p["SteelPlate"], Vector3(x, 0.62, 0.1), Vector3(0.16, 0.24, 4.4))          # chassis rails
	# cab side profile: bumper, hood, sloped windscreen, roof, cab back
	var cab := PackedVector2Array([Vector2(-2.32, 0.55), Vector2(-0.95, 0.55), Vector2(-0.95, 2.25), Vector2(-1.55, 2.25), Vector2(-1.82, 1.6), Vector2(-2.3, 1.42)])
	MeshKit.extrude_into(p[cab_paint], cab, 2.0)
	MeshKit.box_into(p["SteelPlate"], Vector3(0, 0.62, -2.36), Vector3(2.1, 0.22, 0.14))         # bumper
	MeshKit.box_into(p["SteelPlate"], Vector3(0, 1.02, -2.33), Vector3(1.1, 0.5, 0.04))          # grille
	for y in [0.86, 0.98, 1.1, 1.22]:
		MeshKit.box_into(p[cab_paint], Vector3(0, y, -2.36), Vector3(1.0, 0.03, 0.02))
	MeshKit.frustum_into(p["SteelPlate"], Vector3(0.9, 1.4, -1.0), 0.07, 0.06, 1.1, 6)            # exhaust
	for x in [-1.08, 1.08]:
		MeshKit.box_into(p["SteelPlate"], Vector3(x, 1.85, -1.75), Vector3(0.04, 0.22, 0.14))      # mirrors
		MeshKit.box_into(p["SteelPlate"], Vector3(x * 0.975, 1.85, -1.75), Vector3(0.1, 0.03, 0.03))   # and the arm that holds each one to the cab
	for z in [-1.6, 1.3]:
		for x in [-1.0, 1.0]:
			MeshKit.box_into(p[cab_paint if z < 0 else "SteelPlate"], Vector3(x, 1.12, z), Vector3(0.52, 0.06, 1.15 if z < 0 else 1.9), Vector2(1.0, 0.85))
	MeshKit.box_into(p["SteelPlate"], Vector3(0, 0.95, 2.28), Vector3(0.6, 0.08, 0.08))           # rear hinge bar
	_emit(v.model_root, p)
	var glass := MeshKit.Soup.new()
	var ws := PackedVector2Array([Vector2(-1.8, 1.62), Vector2(-1.57, 2.2), Vector2(-1.55, 2.2), Vector2(-1.78, 1.62)])
	MeshKit.extrude_into(glass, ws, 1.8, _xf(Vector3(0, 0, -0.012)))
	for x in [-1.012, 1.012]:
		MeshKit.box_into(glass, Vector3(x, 1.88, -1.25), Vector3(0.01, 0.55, 0.5))      # side windows sit just outside the cab skin, not in its plane
	MeshKit.inst(v.model_root, glass.mesh(), MeshKit.mat(GLASS))
	var lamps := MeshKit.Soup.new()
	for x in [-0.78, 0.78]:
		MeshKit.box_into(lamps, Vector3(x, 1.05, -2.34), Vector3(0.2, 0.14, 0.04))
	MeshKit.inst(v.model_root, lamps.mesh(), MeshKit.flat(Color(1.0, 0.92, 0.7), 0.8))
	var tail := MeshKit.Soup.new()
	for x in [-0.95, 0.95]:
		MeshKit.box_into(tail, Vector3(x, 0.75, 2.3), Vector3(0.16, 0.1, 0.04))
	MeshKit.inst(v.model_root, tail.mesh(), MeshKit.flat(Color(0.8, 0.12, 0.08), 0.6))
	for x in [-0.95, 0.95]:
		for z in [-1.6, 0.9, 1.7]:
			v.wheels.append(wheel(v.model_root, Vector3(x, 0.47, z), 0.47, 0.4 if z < 0 else 0.48, "SteelPlate"))
	# tipping body: hinge at the rear axle line, front headboard with cab guard, ribbed tapered sides
	v.bed = Node3D.new()
	v.bed.position = Vector3(0, 0.75, 2.15)
	v.model_root.add_child(v.bed)
	var b := _soups([bed_paint, "SteelPlate", "Hazard"])
	MeshKit.box_into(b[bed_paint], Vector3(0, 0.06, -1.4), Vector3(2.1, 0.12, 2.95))
	var side := PackedVector2Array([Vector2(0.05, 0.1), Vector2(-2.85, 0.1), Vector2(-2.85, 0.95), Vector2(-0.3, 0.85), Vector2(0.05, 0.6)])
	for x in [-1.03, 1.03]:
		MeshKit.extrude_into(b[bed_paint], side, 0.08, _xf(Vector3(x, 0, 0)))
		for z in [-0.6, -1.3, -2.0]:
			MeshKit.box_into(b["SteelPlate"], Vector3(x * 1.04, 0.5, z), Vector3(0.05, 0.75, 0.08))    # side ribs
	MeshKit.box_into(b[bed_paint], Vector3(0, 0.62, -2.86), Vector3(2.1, 1.1, 0.1))          # headboard
	MeshKit.box_into(b[bed_paint], Vector3(0, 1.17, -2.8), Vector3(1.96, 0.06, 0.5))          # cab guard: stands on the headboard and stays clear of the cab roof
	MeshKit.box_into(b["Hazard"], Vector3(0, 0.95, -0.02), Vector3(2.1, 0.08, 0.03))
	for x in [-0.4, 0.4]:
		MeshKit.drum_into(b["SteelPlate"], Vector3(x, 0.0, 0.0), 0.09, 0.22, 6)                   # rear hinges
	_emit(v.bed, b)
	v.bed_load = MeshKit.inst(v.bed, MeshKit.rock(Vector3(1.9, 0.6, 2.6), 42, 3, 8), MeshKit.mat("RockLimestone"), Vector3(0, 0.1, -1.4))
	v.bed_load.visible = false
	v.set_meta("ram", ram(v.model_root, Vector3(0, 0.72, 0.0), Vector3(0, 0.82, 0.05), 0.08))

## Keep the tipping ram connected between the chassis and the underside of the bed.
static func update_truck_ram(v) -> void:
	if not v.has_meta("ram"):
		return
	var anchor := Vector3(0, 0.72, 0.0)
	var top: Vector3 = v.bed.transform * Vector3(0, 0.0, -2.2)
	var n: Node3D = v.get_meta("ram")
	n.visible = v.bed_tilt > 0.02
	if n.visible:
		aim(n, anchor, top)

# ------------------------------------------------------------------ excavator (2.0 x 2.2 x 3.4; the heavy one is the same model, larger)

static func excavator(v) -> void:
	var paint: String = v.paint_main
	var p := _soups([paint, "SteelPlate", "Tire", "Hazard"])
	var u := _soups([paint, "SteelPlate", "Hazard"])      # the upper body: it swings on the slewing ring (v.turret)
	# crawler tracks: the tread is its own mesh with its own material, whose texture scrolls with the distance travelled; the idlers and
	# road wheels are pivots that roll (QuarryVehicle._animate)
	v.track_mats = []
	for x in [-0.8, 0.8]:
		var tread := MeshKit.Soup.new()
		MeshKit.box_into(tread, Vector3(x, 0.32, 0.0), Vector3(0.46, 0.6, 3.3), Vector2(1.0, 0.9))
		var tmat: StandardMaterial3D = (MeshKit.mat("Tire") as StandardMaterial3D).duplicate()
		MeshKit.inst(v.model_root, tread.mesh(), tmat)
		tmat.set_meta("scroll_sign", 1.0 if x < 0.0 else -1.0)       # the two outer faces run their u axis in opposite directions
		v.track_mats.append(tmat)
		for z in [-1.45, 1.45]:
			_roller(v, Vector3(x, 0.33, z), 0.3, 0.5, 8)                                                            # idlers
		for z in [-1.0, -0.33, 0.33, 1.0]:
			_roller(v, Vector3(x, 0.2, z), 0.14, 0.52, 6)                                                           # road wheels
	MeshKit.box_into(p[paint], Vector3(0, 0.68, 0.0), Vector3(1.7, 0.2, 2.6))                                       # undercarriage
	MeshKit.drum_into(p["SteelPlate"], Vector3(0, 0.84, 0.0), 0.72, 0.18, 12)                                      # slewing ring
	# upper body: engine hood and counterweight at the back, boom foot at the front
	MeshKit.box_into(u[paint], Vector3(0.1, 1.2, 0.45), Vector3(1.7, 0.7, 1.7), Vector2(0.96, 0.9))
	MeshKit.box_into(u["SteelPlate"], Vector3(0.1, 1.4, 1.45), Vector3(1.7, 0.78, 0.45))                           # counterweight
	MeshKit.box_into(u[paint], Vector3(0.55, 0.98, -0.5), Vector3(0.62, 0.5, 0.4))                                   # boom pedestal: the boom's foot is hinged to the body here
	MeshKit.drum_into(u["SteelPlate"], Vector3(0.55, 1.05, -0.5), 0.1, 0.7, 8)                                      # boom foot pin
	MeshKit.box_into(u["Hazard"], Vector3(0.1, 1.05, 1.69), Vector3(1.6, 0.1, 0.02))
	MeshKit.frustum_into(u["SteelPlate"], Vector3(0.6, 1.62, 0.85), 0.07, 0.06, 0.65, 6)                           # exhaust
	for z in [0.2, 0.55, 0.9]:
		MeshKit.box_into(u["SteelPlate"], Vector3(0.1, 1.56, z), Vector3(1.1, 0.02, 0.08))                         # louvres
	# cab on the left, glazed on three sides
	for x in [-0.78, -0.12]:
		for z in [-0.6, 0.15]:
			MeshKit.box_into(u["SteelPlate"], Vector3(x, 1.9, z), Vector3(0.06, 0.95, 0.06))
	MeshKit.box_into(u[paint], Vector3(-0.45, 2.4, -0.22), Vector3(0.82, 0.1, 0.9), Vector2(0.94, 0.92))
	MeshKit.box_into(u["SteelPlate"], Vector3(-0.45, 1.55, -0.22), Vector3(0.8, 0.06, 0.8))
	_emit(v.model_root, p)
	v.turret = Node3D.new()
	v.turret.name = "Turret"
	v.model_root.add_child(v.turret)
	_emit(v.turret, u)
	var glass := MeshKit.Soup.new()
	MeshKit.box_into(glass, Vector3(-0.45, 1.95, -0.642), Vector3(0.7, 0.8, 0.02))
	MeshKit.box_into(glass, Vector3(-0.802, 1.95, -0.22), Vector3(0.02, 0.8, 0.68))
	MeshKit.box_into(glass, Vector3(-0.098, 1.95, -0.22), Vector3(0.02, 0.8, 0.68))
	MeshKit.inst(v.turret, glass.mesh(), MeshKit.mat(GLASS))
	var lamps := MeshKit.Soup.new()
	MeshKit.box_into(lamps, Vector3(-0.45, 2.34, -0.66), Vector3(0.4, 0.07, 0.05))
	MeshKit.inst(v.turret, lamps.mesh(), MeshKit.flat(Color(1.0, 0.92, 0.7), 0.8))
	# boom, stick and bucket: v.arm swings the whole assembly, v.bucket curls (QuarryVehicle animates both)
	v.arm = Node3D.new()
	v.arm.position = Vector3(0.55, 1.05, -0.5)
	v.turret.add_child(v.arm)
	var a := _soups([paint, "SteelPlate"])
	var boom := PackedVector2Array([Vector2(0.1, -0.15), Vector2(-0.9, 0.25), Vector2(-1.9, 0.0), Vector2(-1.95, -0.2), Vector2(-0.9, 0.05), Vector2(0.1, -0.4)])
	MeshKit.extrude_into(a[paint], boom, 0.3)
	MeshKit.drum_into(a["SteelPlate"], Vector3(0, -0.1, -1.95), 0.1, 0.34, 6)                                       # elbow pin
	MeshKit.drum_into(a["SteelPlate"], Vector3(0, 0.0, 0.0), 0.11, 0.36, 8)                                         # boom foot hub: always overlaps the pedestal, whatever the angle
	_emit(v.arm, a)
	ram(v.arm, Vector3(0, -0.45, 0.4), Vector3(0, 0.1, -0.85), 0.08)                                                # boom cylinder
	# the stick hangs from the elbow (v.stick) and the bucket from the stick's tip (v.bucket): three joints, all independent
	v.stick = Node3D.new()
	v.stick.position = Vector3(0, -0.1, -1.95)
	v.arm.add_child(v.stick)
	v.bucket = Node3D.new()
	v.bucket.position = Vector3(0, -0.7, 0.0)
	v.stick.add_child(v.bucket)
	var sk := _soups(["SteelPlate"])
	var stick := PackedVector2Array([Vector2(0.08, 0.1), Vector2(-0.1, -0.7), Vector2(0.0, -0.75), Vector2(0.18, 0.1)])
	MeshKit.extrude_into(sk["SteelPlate"], stick, 0.2)
	MeshKit.drum_into(sk["SteelPlate"], Vector3(0.0, 0.0, 0.0), 0.09, 0.3, 8)                                       # stick-to-boom pin at the elbow
	MeshKit.drum_into(sk["SteelPlate"], Vector3(-0.02, -0.7, 0.0), 0.08, 0.3, 8)                                    # bucket pin at the stick's tip
	_emit(v.stick, sk)
	var b := _soups(["SteelPlate", "Hazard"])
	var shell := PackedVector2Array([Vector2(0.18, -0.55 + 0.7), Vector2(0.05, -0.8 + 0.7), Vector2(-0.3, -0.95 + 0.7), Vector2(-0.62, -0.78 + 0.7), Vector2(-0.64, -0.7 + 0.7), Vector2(-0.32, -0.8 + 0.7), Vector2(0.0, -0.66 + 0.7), Vector2(0.18, -0.45 + 0.7)])
	MeshKit.extrude_into(b["SteelPlate"], shell, 0.8)
	for k in range(4):
		MeshKit.box_into(b["SteelPlate"], Vector3(-0.3 + k * 0.2, -0.96 + 0.7, -0.62 + 0.0), Vector3(0.08, 0.1, 0.14), Vector2(0.6, 0.6))       # teeth
	MeshKit.drum_into(b["SteelPlate"], Vector3(0.0, 0.0, 0.0), 0.075, 0.32, 8)                                      # bucket pivot pin: rotates in place with the bucket
	MeshKit.box_into(b["SteelPlate"], Vector3(0.0, 0.07, -0.08), Vector3(0.26, 0.2, 0.2))                           # bucket ears the pin goes through
	_emit(v.bucket, b)
	v.bucket_load = MeshKit.inst(v.bucket, MeshKit.rock(Vector3(0.7, 0.35, 0.5), 43, 3, 6), MeshKit.mat("RockLimestone"), Vector3(-0.28, -0.68 + 0.7, -0.58))
	v.bucket_load.visible = false

