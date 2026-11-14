extends Node
class_name QuarryDelivery
## The quarry's service gate and garage door. A tunnel mouth in the south ring road opens onto the back of the
## equipment garage, which has a big roll-up door. New machinery is driven in through it by a delivery driver (an
## NPC) who parks it in its bay, hops out and walks back out; newly hired workers walk in through the same gate.
## The door rolls up by itself only for deliveries and staff coming or going (never for the player), and closes behind them.

const DOOR_X := 0.5
const DOOR_Z := 22.4
const DOOR_W := 5.4
const DOOR_H := 3.7
const GATE := Vector3(0.5, 0.05, 25.4)     ## where drivers and new hires step out of the tunnel mouth
## The blueprint yard: the tunnel comes in from the WEST. Its industrial gate stands at the yard's west edge, the service lane runs east along the
## back of the garage to the garage's open back doorway, and everything else (bays, drivers, new hires) behaves as before.
const WEST_GATE := Vector3(-25.2, 0.05, 25.4)       ## the gate in the mountain face
const WEST_MOUTH := Vector3(-32.0, 0.05, 25.4)      ## where drivers and new hires step out of the tunnel
const WEST_END := Vector3(-45.5, 0.05, 25.4)        ## the machine appears here, inside the tunnel
const VEHICLE_SPEED := 3.6
const WALK_SPEED := 2.4

var west := false                           ## blueprint layout
var gdx := DOOR_X                           ## x of the garage's back doorway / door
var door_c := Vector3(DOOR_X, 0.0, DOOR_Z)  ## the shutter that rolls up for deliveries: the garage door (old yard) or the tunnel gate (blueprint yard)
var mouth := GATE                           ## where people step out
var game
var pivot: Node3D
var body: StaticBody3D
var open_amount := 0.0
var passers: Array = []                     ## other machines coming or going through the gate (Walter's truck)
var jobs: Array = []                        ## active deliveries: {vehicle, driver, slot, stage, wps}
var reserved: Array = []                    ## bays promised to a delivery in progress
var reserved_sizes := {}                    ## bay position -> the footprint of the machine on its way
var delivered := 0                          ## completed deliveries (tests)
var entered := 0                            ## workers who stepped out of the gate (tests)

static func gate_for(bp: bool) -> Vector3:
	return WEST_MOUTH if bp else GATE

func build(main_node) -> void:
	game = main_node
	name = "Delivery"
	game.add_child(self)
	west = game.blueprint
	if west:
		gdx = DOOR_X + game.GARAGE_DX
		door_c = Vector3(WEST_GATE.x, 0.0, WEST_GATE.z)
		mouth = WEST_MOUTH
	# the roll-up door: a pivot at the top of the opening that the shutter scales into
	var dw := DOOR_W
	var dh := DOOR_H
	var px := door_c.x
	if west:
		dw = 6.7                                # the tunnel gate: the shutter fills the portal (posts 8.2 m apart, 1.4 m wide, lintel underside at 4.35 m) ...
		dh = 4.3
		px = WEST_GATE.x - 0.9                  # ... and hangs in the portal's own plane, not 0.9 m in front of it
	pivot = Node3D.new()
	pivot.position = Vector3(px, dh, door_c.z)
	game.world.add_child(pivot)
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(dw, dh, 0.14)
	panel.mesh = bm
	panel.position = Vector3(0, -dh * 0.5, 0)
	panel.material_override = MeshKit.mat("Corrugated")
	pivot.add_child(panel)
	for k in range(5):
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(dw - 0.1, 0.08, 0.2)
		rib.mesh = rm
		rib.position = Vector3(0, -0.4 - (dh / 5.2) * k, 0)
		rib.material_override = MeshKit.flat(Color(0.30, 0.34, 0.32))
		pivot.add_child(rib)
	if west:
		pivot.rotation.y = PI * 0.5            # the gate spans the road: its panel runs north-south
	body = StaticBody3D.new()
	body.name = "Garage door"
	body.position = Vector3(px, dh * 0.5, door_c.z)
	if west:
		body.rotation.y = PI * 0.5
	body.set_meta("nav_skip", true)         # workers path through; the door opens as they come close
	body.set_meta("art", true)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(dw, dh, 0.25)
	cs.shape = bs
	body.add_child(cs)
	game.world.add_child(body)
	if west:
		_build_gate_west()
	else:
		_build_gate()

## The blueprint yard's tunnel: a stone portal in the mountain face at the yard's west edge (the industrial gate hangs in it) and the tunnel
## itself running west into the mountain. The tunnel is built along +z in its own frame and turned to run along -x.
func _build_gate_west() -> void:
	var stone := MeshKit.mat("RockLimestone")
	var gx := WEST_GATE.x - 0.9
	for sz in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.8, 5.6, 1.4)
		post.mesh = pm
		post.position = Vector3(gx, 2.8, WEST_GATE.z + sz * 4.1)
		post.material_override = stone
		game.world.add_child(post)
		var wall := StaticBody3D.new()
		wall.name = "Gate post"
		wall.position = post.position
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = pm.size
		c.shape = b
		wall.add_child(c)
		game.world.add_child(wall)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.8, 1.3, 9.6)
	lintel.mesh = lm
	lintel.position = Vector3(gx, 5.0, WEST_GATE.z)
	lintel.material_override = stone
	game.world.add_child(lintel)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.1, 0.18, 6.8)
	stripe.mesh = sm
	stripe.position = Vector3(gx + 0.92, 4.4, WEST_GATE.z)
	stripe.material_override = MeshKit.mat("Hazard")
	game.world.add_child(stripe)
	_build_tunnel(0.0)

## Tunnel mouth in the ring road: stone portal, dark opening, hazard header, sign and a short haul road.
func _build_gate() -> void:
	var z := GATE.z + 1.2
	var stone := MeshKit.mat("RockLimestone")
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.4, 5.6, 1.8)
		post.mesh = pm
		post.position = Vector3(DOOR_X + sx * 4.1, 2.8, z)
		post.material_override = stone
		game.world.add_child(post)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(9.6, 1.3, 1.8)
	lintel.mesh = lm
	lintel.position = Vector3(DOOR_X, 5.0, z)
	lintel.material_override = stone
	game.world.add_child(lintel)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(6.8, 0.18, 0.1)
	stripe.mesh = sm
	stripe.position = Vector3(DOOR_X, 4.4, z - 0.92)
	stripe.material_override = MeshKit.mat("Hazard")
	game.world.add_child(stripe)
	# keep the portal solid except for the opening (so nobody walks around it onto the embankment)
	for sx in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		wall.name = "Gate post"
		wall.position = Vector3(DOOR_X + sx * 4.1, 2.8, z)
		wall.set_meta("nav_skip", false)
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(1.4, 5.6, 1.8)
		c.shape = b
		wall.add_child(c)
		game.world.add_child(wall)
	_build_tunnel(z + 0.9)

## A real tunnel behind the portal: asphalt road with a dashed centre line, lined walls with ribs, an arched-flat roof, ceiling lamps
## and a bright daylight opening at the far end where the street continues. The road also runs from the garage apron to the portal.
func _build_tunnel(z0: float) -> void:
	var z1 := z0 + 20.0
	var w := 6.8
	var h := 4.4
	var cx := DOOR_X
	var parts := Node3D.new()
	parts.name = "ServiceTunnel"
	game.world.add_child(parts)
	if west:
		# the tunnel's own frame: centre line x 0, running +z from the gate; turned so that +z points west (-x) and its x axis lies along the road's width
		cx = 0.0
		parts.position = Vector3(WEST_GATE.x - 1.8, 0.0, WEST_GATE.z)
		parts.rotation.y = -PI * 0.5
	var box := func(pos: Vector3, size_v: Vector3, m: Material, collide := false, roll := 0.0) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size_v
		mi.mesh = bm
		mi.material_override = m
		mi.position = pos
		mi.rotation.z = roll
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parts.add_child(mi)
		if collide:
			var sb := StaticBody3D.new()
			sb.position = pos
			sb.set_meta("art", true)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = size_v
			cs.shape = bs
			sb.add_child(cs)
			parts.add_child(sb)
	var asphalt: Material = load(QuarryArt.M_ASPHALT)
	var stone := MeshKit.mat("RockLimestone")
	var line := MeshKit.flat(Color(0.92, 0.82, 0.30))
	var rib := MeshKit.flat(Color(0.36, 0.36, 0.38))
	var dark := MeshKit.flat(Color(0.05, 0.05, 0.06))
	# the road: garage apron -> portal -> through the tunnel
	var rz0 := (DOOR_Z + 0.2) if not west else 0.2
	box.call(Vector3(cx, 0.03, (rz0 + z1) * 0.5), Vector3(w, 0.06, z1 - rz0), asphalt, true)
	var d := rz0 + 1.0
	while d < z1 - 1.0:
		box.call(Vector3(cx, 0.07, d), Vector3(0.16, 0.02, 1.2), line)
		d += 2.6
	# walls, roof and the closed end are solid so nobody walks out of the tunnel into the hillside
	for sx in [-1.0, 1.0]:
		box.call(Vector3(cx + sx * (w * 0.5 + 0.3), h * 0.5, (z0 + z1) * 0.5), Vector3(0.6, h, z1 - z0), stone, true)
		box.call(Vector3(cx + sx * (w * 0.5 - 0.02), 0.45, (z0 + z1) * 0.5), Vector3(0.06, 0.9, z1 - z0), MeshKit.flat(Color(0.55, 0.55, 0.5)))   # kerb
	box.call(Vector3(cx, h + 0.3, (z0 + z1) * 0.5), Vector3(w + 1.2, 0.6, z1 - z0), stone, true)
	var lamp := MeshKit.flat(Color(1.0, 0.92, 0.7), 2.2)
	var k := z0 + 2.0
	while k < z1 - 1.0:
		box.call(Vector3(cx, h - 0.05, k), Vector3(w - 0.4, 0.14, 0.18), rib)           # roof rib
		for sx in [-1.0, 1.0]:
			box.call(Vector3(cx + sx * (w * 0.5 - 0.55), h - 0.55, k), Vector3(1.1, 0.14, 0.18), rib, false, -sx * PI * 0.25)    # the corner braces make it an arch
			box.call(Vector3(cx + sx * (w * 0.5 - 0.08), 1.9, k + 1.6), Vector3(0.1, 0.22, 0.5), lamp)                         # wall lights
		box.call(Vector3(cx, h - 0.16, k + 1.6), Vector3(1.4, 0.08, 0.3), lamp)         # ceiling lamp
		k += 3.2
	# the far end: daylight and the street carrying on (sky-coloured glow, road and kerb lines)
	box.call(Vector3(cx, h * 0.5, z1 + 0.15), Vector3(w + 1.2, h + 0.6, 0.3), MeshKit.flat(Color(0.82, 0.90, 1.0), 1.6), true)
	box.call(Vector3(cx, 0.5, z1 - 0.05), Vector3(w, 1.0, 0.1), MeshKit.flat(Color(0.35, 0.37, 0.4), 0.4))
	for sx in [-1.0, 1.0]:
		box.call(Vector3(cx + sx * 1.4, 0.06, z1 - 0.12), Vector3(0.14, 0.02, 0.1), line)
	# the way out: a lit EXIT frame with a green sign, the centre line running right up to it
	box.call(Vector3(cx, h * 0.5, z1 - 0.2), Vector3(w - 0.3, h - 0.3, 0.06), MeshKit.flat(Color(1.0, 0.98, 0.9), 2.6))      # the daylight beyond
	box.call(Vector3(cx, h - 0.45, z1 - 0.5), Vector3(2.4, 0.5, 0.08), MeshKit.flat(Color(0.2, 0.85, 0.4), 2.4))           # EXIT sign
	for sx in [-1.0, 1.0]:
		box.call(Vector3(cx + sx * (w * 0.5 - 0.2), h * 0.5, z1 - 0.4), Vector3(0.3, h - 0.2, 0.3), rib)                  # portal jambs
	# dark inside the portal so the opening reads as depth from the garage
	box.call(Vector3(cx, h + 0.05, z0 - 0.4), Vector3(w + 0.2, 0.12, 0.8), dark)

## Where a newly hired worker steps out (spread a little so several hires do not stack).
func gate_point(k := 0) -> Vector3:
	entered += 1
	if west:
		return mouth + Vector3(-float(k / 3) * 0.9, 0.0, float(k % 3 - 1) * 0.9)
	return GATE + Vector3(float(k % 3 - 1) * 0.9, 0.0, -float(k / 3) * 0.9)

func _near_door(p: Vector3, r := 4.6) -> bool:
	return Vector2(p.x, p.z).distance_to(Vector2(door_c.x, door_c.z)) < r

func _anyone_near() -> bool:
	# the door never opens for the player (on foot or driving): only deliveries and staff arriving or leaving
	for ps in passers:
		if is_instance_valid(ps) and _near_door(ps.global_position, 6.0):
			return true
	for j in jobs:
		if _near_door(j["vehicle"].global_position, 6.0):
			return true
	for ct in crate_jobs:
		if is_instance_valid(ct["node"]) and _near_door(ct["node"].global_position, 6.0):
			return true
	for w in game.worker_nodes.values():
		if w.visible and _near_door(w.global_position):
			return true
	return false

# --------------------------------------------------------------- crate trucks (stationary machinery)

## Crushers, hoppers, belts and the like cannot drive. The order is already paid for and in the construction inventory (that never waits on anything
## here); a flatbed carrying the crate comes through the gate to the drop spot, tips it off and reverses out. Purely visual: it touches no inventory,
## money or save data, never drives through a person (it gives up and vanishes at the gate instead), and `finish_all` clears it.
var crate_jobs: Array = []
const CRATE_COLORS := {"crusher": Color(0.30, 0.38, 0.40), "advanced_crusher": Color(0.26, 0.34, 0.30), "hopper": Color(0.55, 0.45, 0.25), "sorter": Color(0.50, 0.40, 0.28),
	"output": Color(0.30, 0.42, 0.32), "conveyor": Color(0.22, 0.24, 0.26), "conveyor_left": Color(0.22, 0.24, 0.26), "conveyor_right": Color(0.22, 0.24, 0.26)}

func _crate_route() -> Array:
	if west:
		return [WEST_END, Vector3(WEST_MOUTH.x, 0.05, WEST_GATE.z), Vector3(WEST_GATE.x + 1.5, 0.05, WEST_GATE.z), Vector3(WEST_GATE.x + 7.0, 0.05, WEST_GATE.z)]
	return [Vector3(DOOR_X, 0.05, GATE.z), Vector3(DOOR_X, 0.05, 24.2)]

func start_crate(kind: String) -> bool:
	if game == null or crate_jobs.size() >= 2:
		return false
	var route := _crate_route()
	var t := Node3D.new()
	t.name = "CrateTruck"
	var wheels: Array = []
	var steel := MeshKit.flat(Color(0.16, 0.17, 0.19))
	var paint := MeshKit.flat(Color(0.82, 0.55, 0.10))
	var glass := MeshKit.flat(Color(0.30, 0.42, 0.5))
	var tyre := MeshKit.flat(Color(0.07, 0.07, 0.08))
	for part in [[Vector3(0, 0.62, 0.3), Vector3(1.9, 0.28, 5.0), steel], [Vector3(0, 1.45, -1.9), Vector3(1.95, 1.45, 1.35), paint], [Vector3(0, 1.8, -2.5), Vector3(1.7, 0.55, 0.06), glass]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = part[1]
		m.mesh = b
		m.position = part[0]
		m.material_override = part[2]
		t.add_child(m)
	for ax in [-1.9, 1.3, 2.4]:
		for sx in [-1.0, 1.0]:
			var pv := Node3D.new()
			pv.position = Vector3(sx * 1.0, 0.5, ax)
			pv.set_meta("radius", 0.5)
			var wm := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.5
			cy.bottom_radius = 0.5
			cy.height = 0.34
			cy.radial_segments = 10
			wm.mesh = cy
			wm.rotation.z = PI * 0.5
			wm.material_override = tyre
			pv.add_child(wm)
			t.add_child(pv)
			wheels.append(pv)
	var bed := Node3D.new()                        # hinged at the rear: the front of the bed rises to tip the crate off the back
	bed.position = Vector3(0, 0.8, 2.75)
	t.add_child(bed)
	var deck := MeshInstance3D.new()
	var db := BoxMesh.new()
	db.size = Vector3(2.0, 0.12, 4.0)
	deck.mesh = db
	deck.position = Vector3(0, 0, -2.0)
	deck.material_override = steel
	bed.add_child(deck)
	var crate := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(1.6, 1.2, 1.7)
	crate.mesh = cb
	crate.position = Vector3(0, 0.66, -1.3)
	crate.material_override = MeshKit.flat(CRATE_COLORS.get(kind, Color(0.4, 0.4, 0.4)))
	bed.add_child(crate)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.64, 0.14, 1.74)
	band.mesh = bb
	band.position = Vector3(0, 0.66, 0)
	band.material_override = MeshKit.flat(Color(0.85, 0.70, 0.15))
	crate.add_child(band)
	t.position = route[0]
	t.rotation.y = -PI * 0.5 if west else 0.0
	game.world.add_child(t)
	crate_jobs.append({"node": t, "wheels": wheels, "bed": bed, "crate": crate, "route": route.duplicate(), "back": [], "stage": "in", "t": 0.0, "wait": 0.0, "idx": 1})
	return true

func _step_crate(j: Dictionary, delta: float) -> void:
	var t: Node3D = j["node"]
	if not is_instance_valid(t):
		crate_jobs.erase(j)
		return
	match str(j["stage"]):
		"in", "out":
			var route: Array = j["route"]
			var idx: int = j["idx"]
			if _blocked_ahead(t) if j["stage"] == "in" else _blocked_behind(t):
				j["wait"] = float(j["wait"]) + delta
				if float(j["wait"]) > 15.0:
					t.queue_free()                      # never drives through anyone: it gives up (cosmetic only)
					crate_jobs.erase(j)
				return
			j["wait"] = 0.0
			var at_door: bool = (absf(t.global_position.x - door_c.x) < 1.2) if west else (t.global_position.z < DOOR_Z + 1.0 and t.global_position.z > DOOR_Z - 1.0)
			if at_door and open_amount < 0.85:
				return
			var to: Vector3 = route[idx] - t.global_position
			to.y = 0.0
			if to.length() < 0.3:
				if idx >= route.size() - 1:
					if j["stage"] == "in":
						j["stage"] = "tip"
						j["t"] = 0.0
					else:
						t.queue_free()
						crate_jobs.erase(j)
					return
				j["idx"] = idx + 1
				return
			var fwd := -t.global_transform.basis.z
			var step := minf(2.8 * delta, to.length())
			if j["stage"] == "in":
				t.rotation.y = lerp_angle(t.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 3.0))
				t.global_position += fwd * step
				for w in j["wheels"]:
					w.rotate_x(-step / 0.5)
			else:
				# reversing out along the way it came in: the cab still points into the yard
				t.global_position += to.normalized() * step
				for w in j["wheels"]:
					w.rotate_x(step / 0.5)
		"tip":
			j["t"] = float(j["t"]) + delta
			var k := float(j["t"])
			(j["bed"] as Node3D).rotation.x = 0.5 * smoothstep(0.0, 1.4, k) * (1.0 - smoothstep(3.6, 4.6, k))
			var crate: Node3D = j["crate"]
			if k > 1.4 and k < 3.2:
				crate.position.z = lerpf(-1.3, 0.9, smoothstep(1.4, 3.2, k))
				crate.position.y = lerpf(0.66, 0.2, smoothstep(1.4, 3.2, k))
			if k >= 3.2:
				crate.scale = Vector3.ONE * maxf(0.0, 1.0 - (k - 3.2) / 0.6)     # taken into the construction store
				crate.visible = crate.scale.x > 0.02
			if k >= 4.6:
				var r: Array = j["route"].duplicate()
				r.reverse()
				j["route"] = r
				j["idx"] = 1
				j["stage"] = "out"

func _blocked_behind(t: Node3D) -> bool:
	var back := t.global_position + t.global_transform.basis.z * 3.4
	var b2 := Vector2(back.x, back.z)
	if game.player and not game.driving and Vector2(game.player.global_position.x, game.player.global_position.z).distance_to(b2) < 1.9:
		return true
	for w in game.worker_nodes.values():
		if w.visible and Vector2(w.global_position.x, w.global_position.z).distance_to(b2) < 1.9:
			return true
	return false

func is_open() -> bool:
	return open_amount > 0.85

# --------------------------------------------------------------- deliveries

## Called right after fleet.buy: the new machine is put at the tunnel mouth and driven to its bay.
## `fallback` = no bay in the garage was free: the machine drives through the garage and out of its open front to a spot on
## the apron road instead.
func start(vehicle_id: int, slot: Vector3, fallback := false) -> bool:
	var v = game.vehicle_nodes.get(vehicle_id)
	if v == null:
		return false
	reserved.append(slot)
	reserved_sizes[slot] = v.size
	v.set_meta("delivering", true)
	v.collision_layer = 0
	v.collision_mask = 0
	var wps: Array = []
	if west:
		v.global_position = WEST_END
		v.rotation.y = -PI * 0.5                    # heading east out of the tunnel
		wps = [Vector3(WEST_MOUTH.x, 0.05, WEST_GATE.z), Vector3(WEST_GATE.x + 1.5, 0.05, WEST_GATE.z), Vector3(gdx - 3.0, 0.05, WEST_GATE.z), Vector3(gdx, 0.05, 25.0)]
		wps.append(Vector3(gdx, 0.05, 21.0))
	else:
		v.global_position = Vector3(DOOR_X, 0.05, GATE.z)
		v.rotation.y = 0.0
		wps = [Vector3(DOOR_X, 0.05, 24.8), Vector3(DOOR_X, 0.05, 21.0)]
	if fallback:
		wps.append(Vector3(gdx, 0.05, 15.6))
		if absf(slot.x - gdx) > 1.2:
			wps.append(Vector3(slot.x, 0.05, 13.4))
	else:
		if absf(slot.x - gdx) > 1.2:
			wps.append(Vector3(slot.x, 0.05, 21.0))
	wps.append(slot)
	var driver := _make_driver()
	v.add_child(driver)
	driver.position = Vector3(0.0, 1.0, 0.3)
	var job := {"vehicle": v, "driver": driver, "slot": slot, "stage": "drive", "wps": wps, "t": 0.0, "wait": 0.0}
	if not entry_clear():
		# never appear inside someone: the machine waits out of sight at the tunnel mouth until the way is clear
		job["stage"] = "queue"
		v.visible = false
	jobs.append(job)
	return true

## True when nobody (player, worker, another machine) stands where a delivery appears.
func entry_clear() -> bool:
	var at := Vector3(WEST_MOUTH.x if west else DOOR_X, 0.0, WEST_MOUTH.z if west else GATE.z)
	if game.player and not game.driving and Vector2(game.player.global_position.x, game.player.global_position.z).distance_to(Vector2(at.x, at.z)) < 3.4:
		return false
	for w in game.worker_nodes.values():
		if w.visible and Vector2(w.global_position.x, w.global_position.z).distance_to(Vector2(at.x, at.z)) < 3.4:
			return false
	for v in game.vehicle_nodes.values():
		if not v.has_meta("delivering") and Vector2(v.global_position.x, v.global_position.z).distance_to(Vector2(at.x, at.z)) < 4.5:
			return false
	for j in jobs:
		if str(j["stage"]) == "drive" and Vector2(j["vehicle"].global_position.x, j["vehicle"].global_position.z).distance_to(Vector2(at.x, at.z)) < 5.0:
			return false
	return true

## Someone in the way of a delivery truck (pedestrians only: it never drives through people).
func _blocked_ahead(v: Node3D) -> bool:
	var front := v.global_position + (-v.global_transform.basis.z) * 2.6
	var f2 := Vector2(front.x, front.z)
	if game.player and not game.driving and Vector2(game.player.global_position.x, game.player.global_position.z).distance_to(f2) < 1.9:
		return true
	for w in game.worker_nodes.values():
		if w.visible and Vector2(w.global_position.x, w.global_position.z).distance_to(f2) < 1.9:
			return true
	return false

func _make_driver() -> Node3D:
	var d := Node3D.new()
	d.name = "DeliveryDriver"
	var vest := MeshKit.flat(Color(0.95, 0.48, 0.10))
	var pants := MeshKit.flat(Color(0.20, 0.24, 0.32))
	var skin := MeshKit.flat(Color(0.80, 0.62, 0.48))
	var hat := MeshKit.flat(Color(0.95, 0.82, 0.15))
	var parts := [[Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.3), pants], [Vector3(0, 1.1, 0), Vector3(0.52, 0.62, 0.32), vest],
		[Vector3(0, 1.62, 0), Vector3(0.3, 0.3, 0.3), skin], [Vector3(0, 1.84, 0), Vector3(0.36, 0.14, 0.36), hat]]
	for p in parts:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = p[1]
		m.mesh = b
		m.position = p[0]
		m.material_override = p[2]
		d.add_child(m)
	return d

func _physics_process(delta: float) -> void:
	var want := 1.0 if _anyone_near() else 0.0
	if want > 0.5 and open_amount < 0.02:
		game._sfx_at("breaker_hit", Vector3(door_c.x, 1.5, door_c.z), -9.0)   # the shutter starts to roll up
	open_amount = move_toward(open_amount, want, delta * 0.9)
	var e := smoothstep(0.0, 1.0, open_amount)
	pivot.scale.y = lerpf(1.0, 0.06, e)
	body.get_child(0).disabled = open_amount > 0.7
	for j in jobs.duplicate():
		_step_job(j, delta)
	for cj in crate_jobs.duplicate():
		_step_crate(cj, delta)

func _step_job(j: Dictionary, delta: float) -> void:
	var v: QuarryVehicle = j["vehicle"]
	if not is_instance_valid(v):
		jobs.erase(j)
		reserved.erase(j["slot"])
		reserved_sizes.erase(j["slot"])
		return
	match str(j["stage"]):
		"queue":
			if entry_clear():
				v.visible = true
				j["stage"] = "drive"
				game.hud.toast("Delivery arriving", "%s is coming in through the service gate. (K: skip)" % game.fleet.spec(v.vtype)["title"], "info")
		"drive":
			if _blocked_ahead(v) and float(j["wait"]) < 15.0:
				j["wait"] = float(j["wait"]) + delta   # stops for people, up to 15 s
				v.speed = 0.0
				return
			var at_door: bool = (absf(v.global_position.x - door_c.x) < 1.2) if west else (v.global_position.z < DOOR_Z + 1.0 and v.global_position.z > DOOR_Z - 1.0)
			if at_door and open_amount < 0.85:
				v.speed = 0.0                   # waits for the shutter
				return
			var wps: Array = j["wps"]
			var target: Vector3 = wps[0]
			var to: Vector3 = target - v.global_position
			to.y = 0.0
			if to.length() < 0.25:
				wps.pop_front()
				if wps.is_empty():
					v.global_position = j["slot"]
					v.rotation.y = 0.0
					v.speed = 0.0
					_unload_driver(j)
					return
				return
			var want_yaw := atan2(-to.x, -to.z)
			v.rotation.y = lerp_angle(v.rotation.y, want_yaw, minf(1.0, delta * 3.0))
			var turn := absf(angle_difference(v.rotation.y, want_yaw))
			var sp := VEHICLE_SPEED * (0.35 if turn > 0.5 else 1.0)
			v.speed = sp
			v.global_position += to.normalized() * minf(sp * delta, to.length())
		"walk":
			var d: Node3D = j["driver"]
			var wps: Array = j["wps"]
			var target: Vector3 = wps[0]
			var to: Vector3 = target - d.global_position
			to.y = 0.0
			if to.length() < 0.2:
				wps.pop_front()
				if wps.is_empty():
					d.queue_free()
					_finish(j)
				return
			d.rotation.y = atan2(-to.x, -to.z)
			j["t"] = float(j["t"]) + delta
			d.global_position += to.normalized() * minf(WALK_SPEED * delta, to.length())
			d.global_position.y = 0.0 + absf(sin(float(j["t"]) * 7.0)) * 0.05

func _unload_driver(j: Dictionary) -> void:
	var v: QuarryVehicle = j["vehicle"]
	var d: Node3D = j["driver"]
	var from := d.global_position
	v.remove_child(d)
	game.add_child(d)
	d.global_position = v.global_position + Vector3(1.9, 0.0, 0.8)
	# the vehicle is a normal parked machine from here on
	v.remove_meta("delivering")
	v.collision_layer = 8
	v.collision_mask = 1 | 4 | 8 | 16
	v.settled_frames = 0
	v.safe_position = v.global_position
	v.safe_yaw = 0.0
	game.nav_dirty = true
	var slot: Vector3 = j["slot"]
	j["stage"] = "walk"
	if west:
		j["wps"] = [Vector3(minf(slot.x + 2.0, gdx + 13.4), 0, 21.0), Vector3(gdx + 0.8, 0, 21.0), Vector3(gdx + 0.8, 0, 24.8), Vector3(gdx - 3.0, 0, WEST_GATE.z), Vector3(WEST_MOUTH.x, 0, WEST_MOUTH.z)]
	else:
		j["wps"] = [Vector3(minf(slot.x + 2.0, 13.4), 0, 21.0), Vector3(DOOR_X + 0.8, 0, 21.0), Vector3(DOOR_X + 0.8, 0, 24.8), Vector3(DOOR_X, 0, GATE.z)]
	from = from # (kept for clarity: the driver steps out beside the cab)

func _finish(j: Dictionary) -> void:
	reserved.erase(j["slot"])
	reserved_sizes.erase(j["slot"])
	jobs.erase(j)
	delivered += 1

## Completes every running delivery at once (machine on its bay, driver gone). Used by tests and when a save is loaded.
func finish_all() -> void:
	for cj in crate_jobs.duplicate():
		if is_instance_valid(cj["node"]):
			cj["node"].queue_free()
	crate_jobs.clear()
	for j in jobs.duplicate():
		var v: QuarryVehicle = j["vehicle"]
		if is_instance_valid(v):
			v.visible = true
			if str(j["stage"]) == "queue":
				j["stage"] = "drive"
			v.global_position = j["slot"]
			v.rotation.y = 0.0
			v.speed = 0.0
			if str(j["stage"]) == "drive":
				_unload_driver(j)
			if is_instance_valid(j["driver"]):
				j["driver"].queue_free()
		_finish(j)
