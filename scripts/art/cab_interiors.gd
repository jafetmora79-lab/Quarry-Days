extends RefCounted
class_name CabInterior
## Real cabs for the machines: a seat with a backrest and headrest, a dashboard with gauges and warning lamps, a steering wheel or
## the two joystick consoles, pedals, an ignition with a key, a floor mat, a grab rail and foot steps outside, and a hinged door.
## Everything is built in the cab's own space (the excavator's turret, or the vehicle model) facing -Z, and the pieces that move
## are returned in a dictionary the vehicle keeps as the meta "cab":
##   ref     the node the positions are in          eye   where the driver's eyes are        door   the hinged door (rotation.y opens it)
##   door_c  the door's sill centre, outer face      key   the ignition key (rotates)         lamps  the dashboard lamp materials
##   open    door rotation when open                 step  the top foot step (cab space)      side   -1 = door on the left

const SEAT := Color(0.16, 0.15, 0.14)
const TRIM := Color(0.1, 0.1, 0.11)
const MAT := Color(0.08, 0.075, 0.07)

## A rotation about the point `c` (box_into applies its transform after adding the corner offsets to the centre).
static func _rot(c: Vector3, ang: float) -> Transform3D:
	var b := Basis(Vector3.RIGHT, ang)
	return Transform3D(b, c - b * c)

static func _inst(parent: Node3D, soup: MeshKit.Soup, mat: Material) -> MeshInstance3D:
	var mi := MeshKit.inst(parent, soup.mesh(), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## The seat: a post, a cushion, a reclined backrest and a headrest.
static func seat(s: MeshKit.Soup, at: Vector3, floor_y: float, w := 0.38) -> void:
	var post_h := maxf(0.05, at.y - floor_y)
	MeshKit.box_into(s, Vector3(at.x, floor_y + post_h * 0.5, at.z + 0.02), Vector3(0.12, post_h, 0.14))
	MeshKit.box_into(s, at, Vector3(w, 0.08, 0.36))
	MeshKit.box_into(s, at + Vector3(0, 0.25, 0.2), Vector3(w, 0.46, 0.07), Vector2.ONE, _rot(at + Vector3(0, 0.25, 0.2), 0.14))
	MeshKit.box_into(s, at + Vector3(0, 0.56, 0.236), Vector3(w * 0.5, 0.14, 0.06))
	for sx in [-1.0, 1.0]:
		MeshKit.box_into(s, at + Vector3(sx * (w * 0.5 + 0.02), 0.14, 0.04), Vector3(0.04, 0.04, 0.26))     # armrests

## A steering wheel on a raked column: a ring, three spokes and a hub.
static func wheel(trim: MeshKit.Soup, steel: MeshKit.Soup, at: Vector3, radius := 0.15) -> void:
	var rake := Basis(Vector3.RIGHT, -1.0)                                         # the wheel faces the driver, tilted back
	var xf := Transform3D(rake, at)
	var ring := []
	for k in range(0, 13):
		var a := TAU * float(k) / 12.0
		ring.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	MeshKit.tube_into(trim, ring, 0.02, 5, xf)
	for k in range(3):
		var a2 := TAU * float(k) / 3.0 + PI * 0.5
		MeshKit.tube_into(trim, [Vector3.ZERO, Vector3(cos(a2) * radius, 0.0, sin(a2) * radius)], 0.012, 4, xf)
	MeshKit.frustum_into(steel, Vector3.ZERO, 0.03, 0.03, 0.04, 6, xf)
	MeshKit.tube_into(steel, [Vector3.ZERO, Vector3(0, -0.3, -0.12)], 0.024, 5, xf)        # the column, down into the dash

## A joystick console beside the seat: a block, a gaiter and a stick with a knob.
static func stick(trim: MeshKit.Soup, steel: MeshKit.Soup, at: Vector3, floor_y: float) -> void:
	var h := maxf(0.1, at.y - floor_y)
	MeshKit.box_into(trim, Vector3(at.x, floor_y + h * 0.5, at.z), Vector3(0.1, h, 0.34))
	MeshKit.frustum_into(trim, at + Vector3(0, 0.0, -0.02), 0.035, 0.02, 0.07, 6)
	MeshKit.frustum_into(steel, at + Vector3(0, 0.05, -0.02), 0.012, 0.012, 0.2, 5)
	MeshKit.box_into(trim, at + Vector3(0, 0.27, -0.02), Vector3(0.05, 0.05, 0.06))

## Build the interior. `p`: floor_y, seat (cushion centre), dash (centre of the dash top), width, depth, kind ("wheel" or "sticks"), key_at (on the dash).
static func build(parent: Node3D, p: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.name = "Interior"
	parent.add_child(n)
	var seat_s := MeshKit.Soup.new()
	var trim := MeshKit.Soup.new()
	var steel := MeshKit.Soup.new()
	var mat := MeshKit.Soup.new()
	var fy: float = p["floor_y"]
	var w: float = p["width"]
	var d: float = p["depth"]
	var c: Vector3 = p["center"]                                       # floor centre (x, floor top y, z)
	MeshKit.box_into(mat, Vector3(c.x, fy + 0.012, c.z), Vector3(w * 0.92, 0.024, d * 0.92))
	var seats: Array = p["seats"]
	for s_at in seats:
		seat(seat_s, s_at, fy)
	var dash: Vector3 = p["dash"]
	MeshKit.box_into(trim, dash + Vector3(0, -0.1, 0), Vector3(w * 0.9, 0.3, 0.16), Vector2(1.0, 0.8))          # the dash, sloping toward the driver
	MeshKit.box_into(trim, dash + Vector3(0, 0.1, 0.02), Vector3(w * 0.9, 0.04, 0.2))                           # its hood over the gauges
	var kind: String = p["kind"]
	if kind == "wheel":
		var wheel_at: Vector3 = p["wheel"]
		wheel(trim, steel, wheel_at)
		for px in [-0.09, 0.0, 0.09]:
			var pc := Vector3(wheel_at.x + px, fy + 0.07, dash.z + 0.34)
			MeshKit.box_into(trim, pc, Vector3(0.07, 0.03, 0.12), Vector2.ONE, _rot(pc, -0.5))   # pedals
		var shift: Vector3 = p.get("shift", Vector3.ZERO)
		if shift != Vector3.ZERO:
			MeshKit.frustum_into(steel, shift, 0.015, 0.012, 0.3, 5)
			MeshKit.box_into(trim, shift + Vector3(0, 0.32, 0), Vector3(0.05, 0.05, 0.05))
	else:
		for sx in [-1.0, 1.0]:
			stick(trim, steel, Vector3(p["seats"][0].x + sx * 0.24, fy + 0.3, p["seats"][0].z - 0.06), fy)
		for lx in [-0.09, 0.09]:
			var lever_x: float = p["seats"][0].x + lx
			MeshKit.frustum_into(steel, Vector3.ZERO, 0.014, 0.014, 0.32, 5, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(lever_x, fy, dash.z + 0.3)))   # travel levers
	_inst(n, seat_s, MeshKit.flat(SEAT))
	_inst(n, trim, MeshKit.flat(TRIM))
	_inst(n, steel, MeshKit.mat("SteelPlate"))
	_inst(n, mat, MeshKit.flat(MAT))
	# gauges and lamps on the dash: dark until the key is turned, then lit
	var lamps := []
	var gx: float = dash.x - w * 0.3
	var colors := [Color(0.9, 0.2, 0.15), Color(1.0, 0.7, 0.15), Color(0.3, 0.9, 0.35), Color(0.7, 0.9, 1.0), Color(0.7, 0.9, 1.0)]
	for k in range(5):
		var gm := MeshKit.flat(colors[k] * 0.25)
		var gs := MeshKit.Soup.new()
		var size := Vector3(0.07, 0.07, 0.02) if k >= 3 else Vector3(0.045, 0.03, 0.02)
		MeshKit.box_into(gs, Vector3(gx + float(k) * w * 0.16, dash.y + 0.04, dash.z + 0.075), size)
		_inst(n, gs, gm)
		lamps.append({"mat": gm, "color": colors[k]})
	# the ignition: a switch plate on the dash and a key that turns
	var ik: Vector3 = p["key_at"]
	var plate := MeshKit.Soup.new()
	MeshKit.box_into(plate, ik, Vector3(0.06, 0.06, 0.02))
	_inst(n, plate, MeshKit.mat("SteelPlate"))
	var key := Node3D.new()
	key.name = "Key"
	key.position = ik + Vector3(0, 0, 0.02)
	n.add_child(key)
	var ks := MeshKit.Soup.new()
	MeshKit.box_into(ks, Vector3(0, 0.03, 0.015), Vector3(0.018, 0.05, 0.012))
	MeshKit.box_into(ks, Vector3(0, 0.0, 0.0), Vector3(0.024, 0.024, 0.02))
	_inst(key, ks, MeshKit.flat(Color(0.85, 0.7, 0.2)))
	return {"node": n, "key": key, "lamps": lamps}

## A door hinged on its front edge (the hinge is at the pivot; the door extends toward +Z from it): a frame, a glass pane (and a painted lower
## panel when `lower` > 0) and a handle. `side` -1 = left of the cab. Returns the pivot; rotation.y = `open_angle(side)` opens it outward.
static func door(parent: Node3D, hinge: Vector3, depth: float, height: float, lower: float, paint_key: String, side: float, glass_path: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Door"
	pivot.position = hinge
	parent.add_child(pivot)
	var frame := MeshKit.Soup.new()
	var paint := MeshKit.Soup.new()
	var t := 0.045
	MeshKit.box_into(frame, Vector3(0, height * 0.5, 0.02), Vector3(t, height, 0.05))                   # hinge stile
	MeshKit.box_into(frame, Vector3(0, height * 0.5, depth - 0.02), Vector3(t, height, 0.05))           # latch stile
	MeshKit.box_into(frame, Vector3(0, height - 0.025, depth * 0.5), Vector3(t, 0.05, depth))           # top rail
	MeshKit.box_into(frame, Vector3(0, lower + 0.01, depth * 0.5), Vector3(t, 0.05, depth))             # belt rail
	if lower > 0.0:
		MeshKit.box_into(paint, Vector3(0, lower * 0.5, depth * 0.5), Vector3(t, lower, depth))
	MeshKit.box_into(frame, Vector3(-side * 0.04, lower + 0.18, depth - 0.1), Vector3(0.03, 0.035, 0.13))   # the handle, on the outside
	var fm := MeshKit.mat("SteelPlate")
	_inst(pivot, frame, fm)
	if lower > 0.0:
		_inst(pivot, paint, MeshKit.mat(paint_key))
	var gs := MeshKit.Soup.new()
	MeshKit.box_into(gs, Vector3(0, lower + (height - lower) * 0.5, depth * 0.5), Vector3(0.012, height - lower - 0.06, depth - 0.1))
	MeshKit.inst(pivot, gs.mesh(), MeshKit.mat(glass_path))
	return pivot

static func open_angle(side: float) -> float:
	return 1.45 * side            # a left door (side -1) swings out to the left, a right door to the right

## Foot steps and a vertical grab rail on the outside of the cab, under the door. `at`: the point on the cab's outer face at sill height, with z = where
## the person steps; `base_y` the ground (or the track top) the lowest step rises from.
static func steps(parent: Node3D, at: Vector3, base_y: float, side: float) -> void:
	var s := MeshKit.Soup.new()
	var rise := at.y - base_y
	var count := 2 if rise > 0.5 else 1
	for k in range(count):
		var y := base_y + rise * float(k + 1) / float(count + 1) - 0.02
		MeshKit.box_into(s, Vector3(at.x + side * 0.12, y, at.z), Vector3(0.26, 0.035, 0.34))
		MeshKit.box_into(s, Vector3(at.x + side * 0.015, y - 0.08, at.z), Vector3(0.03, 0.15, 0.3))     # the bracket that holds it
	var rail_h := rise + 0.55
	MeshKit.box_into(s, Vector3(at.x + side * 0.05, base_y + rail_h * 0.5 + 0.1, at.z + 0.17), Vector3(0.035, rail_h, 0.035))   # the grab rail
	MeshKit.box_into(s, Vector3(at.x + side * 0.025, base_y + rail_h + 0.09, at.z + 0.17), Vector3(0.07, 0.035, 0.035))
	_inst(parent, s, MeshKit.mat("SteelPlate"))
