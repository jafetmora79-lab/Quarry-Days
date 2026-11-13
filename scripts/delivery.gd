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
const VEHICLE_SPEED := 3.6
const WALK_SPEED := 2.4

var game
var pivot: Node3D
var body: StaticBody3D
var open_amount := 0.0
var jobs: Array = []                        ## active deliveries: {vehicle, driver, slot, stage, wps}
var reserved: Array = []                    ## bays promised to a delivery in progress
var reserved_sizes := {}                    ## bay position -> the footprint of the machine on its way
var delivered := 0                          ## completed deliveries (tests)
var entered := 0                            ## workers who stepped out of the gate (tests)

func build(main_node) -> void:
	game = main_node
	name = "Delivery"
	game.add_child(self)
	# the roll-up door: a pivot at the top of the opening that the shutter scales into
	pivot = Node3D.new()
	pivot.position = Vector3(DOOR_X, DOOR_H, DOOR_Z)
	game.world.add_child(pivot)
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(DOOR_W, DOOR_H, 0.14)
	panel.mesh = bm
	panel.position = Vector3(0, -DOOR_H * 0.5, 0)
	panel.material_override = MeshKit.mat("Corrugated")
	pivot.add_child(panel)
	for k in range(5):
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(DOOR_W - 0.1, 0.08, 0.2)
		rib.mesh = rm
		rib.position = Vector3(0, -0.4 - 0.7 * k, 0)
		rib.material_override = MeshKit.flat(Color(0.30, 0.34, 0.32))
		pivot.add_child(rib)
	body = StaticBody3D.new()
	body.name = "Garage door"
	body.position = Vector3(DOOR_X, DOOR_H * 0.5, DOOR_Z)
	body.set_meta("nav_skip", true)         # workers path through; the door opens as they come close
	body.set_meta("art", true)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(DOOR_W, DOOR_H, 0.25)
	cs.shape = bs
	body.add_child(cs)
	game.world.add_child(body)
	_build_gate()

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
	var box := func(pos: Vector3, size_v: Vector3, m: Material, collide := false) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size_v
		mi.mesh = bm
		mi.material_override = m
		mi.position = pos
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
	var rz0 := DOOR_Z + 0.2
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
		box.call(Vector3(cx, h - 0.16, k + 1.6), Vector3(1.4, 0.08, 0.3), lamp)         # ceiling lamp
		k += 3.2
	# the far end: daylight and the street carrying on (sky-coloured glow, road and kerb lines)
	box.call(Vector3(cx, h * 0.5, z1 + 0.15), Vector3(w + 1.2, h + 0.6, 0.3), MeshKit.flat(Color(0.82, 0.90, 1.0), 1.6), true)
	box.call(Vector3(cx, 0.5, z1 - 0.05), Vector3(w, 1.0, 0.1), MeshKit.flat(Color(0.35, 0.37, 0.4), 0.4))
	for sx in [-1.0, 1.0]:
		box.call(Vector3(cx + sx * 1.4, 0.06, z1 - 0.12), Vector3(0.14, 0.02, 0.1), line)
	# dark inside the portal so the opening reads as depth from the garage
	box.call(Vector3(cx, h + 0.05, z0 - 0.4), Vector3(w + 0.2, 0.12, 0.8), dark)

## Where a newly hired worker steps out (spread a little so several hires do not stack).
func gate_point(k := 0) -> Vector3:
	entered += 1
	return GATE + Vector3(float(k % 3 - 1) * 0.9, 0.0, -float(k / 3) * 0.9)

func _near_door(p: Vector3, r := 4.6) -> bool:
	return Vector2(p.x, p.z).distance_to(Vector2(DOOR_X, DOOR_Z)) < r

func _anyone_near() -> bool:
	# the door never opens for the player (on foot or driving): only deliveries and staff arriving or leaving
	for j in jobs:
		if _near_door(j["vehicle"].global_position, 6.0):
			return true
	for w in game.worker_nodes.values():
		if w.visible and _near_door(w.global_position):
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
	v.global_position = Vector3(DOOR_X, 0.05, GATE.z)
	v.rotation.y = 0.0
	var wps: Array = [Vector3(DOOR_X, 0.05, 24.8), Vector3(DOOR_X, 0.05, 21.0)]
	if fallback:
		wps.append(Vector3(DOOR_X, 0.05, 15.6))
		if absf(slot.x - DOOR_X) > 1.2:
			wps.append(Vector3(slot.x, 0.05, 13.4))
	else:
		if absf(slot.x - DOOR_X) > 1.2:
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
	var at := Vector3(DOOR_X, 0.0, GATE.z)
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
		game._sfx_at("breaker_hit", Vector3(DOOR_X, 1.5, DOOR_Z), -9.0)   # the shutter starts to roll up
	open_amount = move_toward(open_amount, want, delta * 0.9)
	var e := smoothstep(0.0, 1.0, open_amount)
	pivot.scale.y = lerpf(1.0, 0.06, e)
	body.get_child(0).disabled = open_amount > 0.7
	for j in jobs.duplicate():
		_step_job(j, delta)

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
				game.hud.toast("Delivery arriving", "%s is coming in through the service gate." % game.fleet.spec(v.vtype)["title"], "info")
		"drive":
			if _blocked_ahead(v) and float(j["wait"]) < 15.0:
				j["wait"] = float(j["wait"]) + delta   # stops for people, up to 15 s
				v.speed = 0.0
				return
			if v.global_position.z < DOOR_Z + 1.0 and v.global_position.z > DOOR_Z - 1.0 and open_amount < 0.85:
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
	j["wps"] = [Vector3(minf(slot.x + 2.0, 13.4), 0, 21.0), Vector3(DOOR_X + 0.8, 0, 21.0), Vector3(DOOR_X + 0.8, 0, 24.8), Vector3(DOOR_X, 0, GATE.z)]
	from = from # (kept for clarity: the driver steps out beside the cab)

func _finish(j: Dictionary) -> void:
	reserved.erase(j["slot"])
	reserved_sizes.erase(j["slot"])
	jobs.erase(j)
	delivered += 1

## Completes every running delivery at once (machine on its bay, driver gone). Used by tests and when a save is loaded.
func finish_all() -> void:
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
