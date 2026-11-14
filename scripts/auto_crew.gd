extends RefCounted
class_name AutoCrew
## Automatic excavator + truck loop. A bought excavator or dump truck can be put on "auto crew" (J). Nothing here creates
## material or production: every step goes through the same game functions a player uses (excavator_target / _excavator_dig,
## fleet.add_cargo, vehicle_dump / fleet.transfer / fleet.dump_to). The crew only presses the controls.
##
## Excavator (stays where it is parked; its reach is its dig_reach): seek rock or soil in reach -> swing the cab -> dig until the
## bucket is full -> raise -> swing to a truck / crusher / output / storage / spoil heap in reach -> dump -> swing back.
## Truck: waits at its home spot to be loaded -> when full (or loaded and idle) drives the nav route to a destination, turns round,
## backs up to it, tips -> drives home. Each completed load / trip costs the machine's `auto_cost` (a visible operating cost).

const REACH_STEPS := 16
const CYCLE_IDLE := 25.0          ## a loaded truck that nobody has added to for this long leaves anyway
const STAND_OFF := 8.5
const TIP := 3.0                  ## how close the bed's work point must be to the destination

var game
var rt := {}                      ## vehicle id -> runtime state (never saved: derived again from the record)

func _init(main_node) -> void:
	game = main_node

static func yaw_of(v: Vector3) -> float:
	return atan2(-v.x, -v.z)

func is_auto(rec: Dictionary) -> bool:
	return bool(rec.get("auto", false))

func eligible(v: QuarryVehicle) -> String:
	if v == null or v.vtype == "starter_excavator":
		return "Grandpa's mini excavator is a hand machine."
	if v.vkind not in ["excavator", "truck"]:
		return "Only excavators and dump trucks can run an auto crew."
	return ""

## Switch a machine's auto crew on or off. Returns the new state.
func toggle(v: QuarryVehicle) -> bool:
	var why := eligible(v)
	if why != "":
		game._notify(why)
		return false
	var rec: Dictionary = game.fleet.vehicle(v.vehicle_id)
	if rec.is_empty():
		return false
	var on := not bool(rec.get("auto", false))
	if on and v.driven:
		if not game.exit_vehicle():
			return false
	rec["auto"] = on
	rt.erase(v.vehicle_id)
	if on:
		rec["auto_home"] = [v.global_position.x, v.global_position.y, v.global_position.z]
		game._notify("%s: auto crew ON. It costs $%d per %s." % [str(rec["name"]), cost(v), "bucket" if v.vkind == "excavator" else "trip"])
	else:
		release(v)
		game._notify("%s: auto crew off." % str(rec["name"]))
	return on

func release(v: QuarryVehicle) -> void:
	v.digging = false
	v.auto_drive = false
	v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	var lbl: Label3D = v.get_meta("crew_label", null)
	if lbl:
		lbl.visible = false

func cost(v: QuarryVehicle) -> int:
	return int(game.fleet.spec(v.vtype).get("auto_cost", 3 if v.vkind == "excavator" else 4))

func _state(v: QuarryVehicle) -> Dictionary:
	if not rt.has(v.vehicle_id):
		rt[v.vehicle_id] = {"phase": "seek" if v.vkind == "excavator" else "wait", "t": 0.0, "stall": 0.0, "idle": 0.0, "last": -1, "status": "",
			"moved": 0, "path": PackedVector3Array(), "pi": 0, "stuck_t": 0.0, "stuck_pos": v.global_position, "fails": 0, "dest": {}, "phase_t": 0.0}
	return rt[v.vehicle_id]

func status_of(v: QuarryVehicle) -> String:
	return str(rt[v.vehicle_id].get("status", "")) if rt.has(v.vehicle_id) else ""

func phase_of(v: QuarryVehicle) -> String:
	return str(rt[v.vehicle_id].get("phase", "")) if rt.has(v.vehicle_id) else ""

## Called every physics frame for each vehicle before its own control().
func step(v: QuarryVehicle, delta: float) -> void:
	var rec: Dictionary = game.fleet.vehicle(v.vehicle_id)
	if rec.is_empty():
		return
	if not is_auto(rec) or v.driven or v.has_meta("delivering") or game.driving == v:
		if rt.has(v.vehicle_id):
			rt.erase(v.vehicle_id)
			release(v)
		return
	var r: Dictionary = _state(v)
	if v.vkind == "excavator":
		_step_excavator(v, rec, r, delta)
	else:
		_step_truck(v, rec, r, delta)
	_label(v, rec, r)

func _label(v: QuarryVehicle, rec: Dictionary, r: Dictionary) -> void:
	var lbl: Label3D = v.get_meta("crew_label", null)
	if lbl == null:
		lbl = Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.pixel_size = 0.006
		lbl.font_size = 30
		lbl.outline_size = 8
		lbl.position = Vector3(0, v.size.y + 1.4, 0)
		lbl.visibility_range_end = 30.0
		v.add_child(lbl)
		v.set_meta("crew_label", lbl)
	lbl.visible = true
	var st := str(r["status"])
	lbl.text = "AUTO  %d/%d\n%s" % [game.fleet.cargo_total(rec), game.fleet.capacity(rec), st]
	lbl.modulate = Color(1.0, 0.75, 0.3) if st.begins_with("NO ") or st.contains("FULL") or st.contains("STUCK") else Color(0.6, 0.95, 0.6)

func _pay(v: QuarryVehicle, rec: Dictionary) -> bool:
	var c := cost(v)
	if game.state.money < c:
		rec["auto"] = false
		release(v)
		rt.erase(v.vehicle_id)
		game._notify("%s: auto crew stopped - you cannot pay the $%d running cost." % [str(rec["name"]), c])
		return false
	game.state.money -= c
	return true

# ------------------------------------------------------------------ excavator

func _hardness_ok(v: QuarryVehicle, t: Dictionary) -> bool:
	var s: Dictionary = game.fleet.spec(v.vtype)
	if int(game.prog.material(str(t["res"])).get("hardness", 1)) > int(s.get("dig_hardness", 1)):
		return false
	return game.prog.extraction_block(str(t["kind"]), int(t["col"]), "excavator", int(s.get("dig_hardness", 1))) == ""

## The cab angle (relative to the tracks) at which the bucket reaches rock or soil it can really dig, nearest to where the cab points.
func dig_angle(v: QuarryVehicle) -> Variant:
	var keep := v.swing
	var best = null
	var best_d := 99.0
	for i in range(REACH_STEPS):
		var a := -PI + TAU * float(i) / float(REACH_STEPS)
		v.swing = a
		var ok := false
		var t: Dictionary = game.excavator_target(v)
		if not t.is_empty():
			ok = _hardness_ok(v, t)
		elif game.soil_target(v) >= 0:
			ok = true
		if ok:
			var d := absf(angle_difference(a, v.turret_yaw))
			if d < best_d:
				best_d = d
				best = a
	v.swing = keep
	return best

func _cargo_res(rec: Dictionary) -> String:
	var best := ""
	var n := 0
	for k in rec["cargo"]:
		if int(rec["cargo"][k]) > n:
			n = int(rec["cargo"][k])
			best = str(k)
	return best

func _accepts(v: QuarryVehicle, rec: Dictionary, t: Dictionary) -> bool:
	if t.is_empty():
		return false
	if t.has("spoil"):
		return int(rec["cargo"].get("soil", 0)) > 0
	if t.has("truck"):
		var tv: QuarryVehicle = t["truck"]
		var trec: Dictionary = game.fleet.vehicle(tv.vehicle_id)
		return not trec.is_empty() and game.fleet.space(trec) > 0 and absf(tv.speed) < 0.3 and tv.unload_timer <= 0.0 and truck_ready(tv)
	if t.has("ep"):
		return game.business.ep_space(t["ep"], _cargo_res(rec)) > 0
	return false

## A truck can be loaded while it is parked and not on a trip.
func truck_ready(tv: QuarryVehicle) -> bool:
	if not rt.has(tv.vehicle_id):
		return true
	return str(rt[tv.vehicle_id]["phase"]) == "wait"

func dump_angle(v: QuarryVehicle, rec: Dictionary) -> Variant:
	var keep := v.swing
	var best = null
	var best_score := 1e9
	for i in range(REACH_STEPS):
		var a := -PI + TAU * float(i) / float(REACH_STEPS)
		v.swing = a
		var t: Dictionary = game.dump_target(v.work_point(), TIP, v)
		if _accepts(v, rec, t):
			var score := absf(angle_difference(a, v.turret_yaw)) + (0.0 if t.has("truck") else 0.5)    # trucks first, then the nearest swing
			if score < best_score:
				best_score = score
				best = a
	v.swing = keep
	return best

func _aligned(v: QuarryVehicle) -> bool:
	return absf(angle_difference(v.turret_yaw, v.swing)) < 0.08

func _step_excavator(v: QuarryVehicle, rec: Dictionary, r: Dictionary, delta: float) -> void:
	var cargo: int = game.fleet.cargo_total(rec)
	match str(r["phase"]):
		"seek":
			v.digging = false
			v.bucket_target = 0.0
			if cargo > 0:
				r["phase"] = "haul"
				r["t"] = 0.0
				return
			r["t"] = float(r["t"]) - delta
			if float(r["t"]) > 0.0:
				return
			r["t"] = 1.0
			if game.state.money < cost(v):
				r["status"] = "NO MONEY FOR CREW"
				return
			var a = dig_angle(v)
			if a == null:
				r["status"] = "NO ROCK IN REACH"
				return
			v.swing = a
			r["phase"] = "turn_dig"
			r["status"] = "SWINGING TO ROCK"
		"turn_dig":
			if _aligned(v):
				r["phase"] = "dig"
				r["stall"] = 0.0
				r["last"] = cargo
		"dig":
			r["status"] = "DIGGING"
			v.bucket_target = 0.0
			if game.fleet.space(rec) <= 0:
				v.digging = false
				r["phase"] = "haul"
				r["t"] = 0.0
				return
			v.digging = true
			game._excavator_dig(v, delta)
			var now: int = game.fleet.cargo_total(rec)
			if now > int(r["last"]):
				r["last"] = now
				r["stall"] = 0.0
			else:
				r["stall"] = float(r["stall"]) + delta
			if not v.digging or float(r["stall"]) > 6.0:
				v.digging = false
				r["phase"] = "haul" if now > 0 else "seek"
				r["t"] = 0.0 if now > 0 else 2.0
		"haul":
			v.digging = false
			v.bucket_target = 1.0                       # loaded bucket raised while it swings
			r["t"] = float(r["t"]) - delta
			if float(r["t"]) > 0.0:
				return
			r["t"] = 1.0
			var a = dump_angle(v, rec)
			if a == null:
				r["status"] = "NO TRUCK OR STORAGE IN REACH"
				return
			v.swing = a
			r["phase"] = "turn_dump"
			r["status"] = "SWINGING TO DUMP"
		"turn_dump":
			if _aligned(v):
				r["phase"] = "dump"
				r["t"] = 0.4
		"dump":
			r["t"] = float(r["t"]) - delta
			if float(r["t"]) > 0.0:
				return
			var before: int = game.fleet.cargo_total(rec)
			var t: Dictionary = game.dump_target(v.work_point(), TIP, v)
			if _accepts(v, rec, t):
				game.vehicle_dump(v, true)
			var moved: int = before - game.fleet.cargo_total(rec)
			if moved > 0 and not _pay(v, rec):
				return
			r["status"] = "DUMPED %d" % moved if moved > 0 else "DESTINATION FULL"
			r["phase"] = "after_dump"
			r["t"] = 1.4
		"after_dump":
			v.bucket_target = 1.0
			r["t"] = float(r["t"]) - delta
			if float(r["t"]) <= 0.0:
				var left: int = game.fleet.cargo_total(rec)
				r["phase"] = "haul" if left > 0 else "seek"
				r["t"] = 2.5 if left > 0 else 0.0

# ------------------------------------------------------------------ truck

func _drive(v: QuarryVehicle, target_speed: float, steer: float) -> void:
	var throttle := 0.0
	var brake := false
	if target_speed > 0.0:
		if v.speed < target_speed - 0.15:
			throttle = 1.0
		elif v.speed > target_speed + 0.3:
			brake = true
	elif target_speed < 0.0:
		if v.speed > target_speed + 0.15:
			throttle = -1.0
		elif v.speed < target_speed - 0.3:
			brake = true
	else:
		brake = true
	v.input = {"throttle": throttle, "steer": clampf(steer, -1.0, 1.0), "brake": brake}

# ------------------------------------------------------------------ routing around the soil field

const SOIL_BLOCK := 0.3          ## soil at least this deep stops a truck (it is a solid ledge to the hull)

func _soil_blocked(p: Vector3) -> bool:
	var soil = game.soil
	if soil == null or not is_instance_valid(soil):
		return false
	var i: int = soil.cell_at(Vector3(p.x, 0.0, p.z))
	return i >= 0 and soil.height(i) >= SOIL_BLOCK

func _path_hits_soil(path: PackedVector3Array) -> bool:
	for k in range(path.size() - 1):
		var a := path[k]
		var b := path[k + 1]
		var n := int(ceil(a.distance_to(b) / 1.0))
		for j in range(n + 1):
			if _soil_blocked(a.lerp(b, float(j) / float(maxi(1, n)))):
				return true
	return false

## A* over a grid of the soil's own cell size covering both ends, soil cells (and the ring around them, a truck is wide) blocked, the surroundings of the
## two ends cleared so a machine standing against the field can still get out. Returns waypoints, or an empty array when there is no way round.
func soil_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var soil = game.soil
	if soil == null:
		return PackedVector3Array()
	var cell: float = float(soil.cell)
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) - Vector2(14.0, 14.0)
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + Vector2(14.0, 14.0)
	var cols := int(ceil((hi.x - lo.x) / cell))
	var rows := int(ceil((hi.y - lo.y) / cell))
	if cols * rows > 9000 or cols < 2 or rows < 2:
		return PackedVector3Array()
	var f2 := Vector2(from.x, from.z)
	var t2 := Vector2(to.x, to.z)
	var raw := PackedByteArray()
	raw.resize(cols * rows)
	for j in range(rows):
		for i in range(cols):
			var c := lo + Vector2((float(i) + 0.5) * cell, (float(j) + 0.5) * cell)
			raw[j * cols + i] = 1 if _soil_blocked(Vector3(c.x, 0.0, c.y)) else 0
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	for j in range(rows):
		for i in range(cols):
			var c := lo + Vector2((float(i) + 0.5) * cell, (float(j) + 0.5) * cell)
			var b := 0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := i + di
					var jj := j + dj
					if ii >= 0 and jj >= 0 and ii < cols and jj < rows and raw[jj * cols + ii] == 1:
						b = 1
			if c.distance_to(f2) < 3.6 or c.distance_to(t2) < 3.6:
				b = 0
			blocked[j * cols + i] = b
	var si := clampi(int((f2.x - lo.x) / cell), 0, cols - 1)
	var sj := clampi(int((f2.y - lo.y) / cell), 0, rows - 1)
	var gi := clampi(int((t2.x - lo.x) / cell), 0, cols - 1)
	var gj := clampi(int((t2.y - lo.y) / cell), 0, rows - 1)
	var dist := {}
	var prev := {}
	var open: Array = [[0.0, si, sj]]
	dist[sj * cols + si] = 0.0
	var found := false
	while not open.is_empty():
		open.sort_custom(func(a, b): return a[0] < b[0])
		var cur: Array = open.pop_front()
		var ci: int = cur[1]
		var cj: int = cur[2]
		if ci == gi and cj == gj:
			found = true
			break
		var cd: float = float(dist.get(cj * cols + ci, 1e9))
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if di == 0 and dj == 0:
					continue
				var ni := ci + di
				var nj := cj + dj
				if ni < 0 or nj < 0 or ni >= cols or nj >= rows or blocked[nj * cols + ni] == 1:
					continue
				if di != 0 and dj != 0 and (blocked[cj * cols + ni] == 1 or blocked[nj * cols + ci] == 1):
					continue                          # no cutting a corner of the field
				var nd := cd + (1.4142 if di != 0 and dj != 0 else 1.0)
				var key := nj * cols + ni
				if nd < float(dist.get(key, 1e9)):
					dist[key] = nd
					prev[key] = cj * cols + ci
					var h := Vector2(float(ni - gi), float(nj - gj)).length()
					open.append([nd + h, ni, nj])
	if not found:
		return PackedVector3Array()
	var cells: Array = []
	var k := gj * cols + gi
	while true:
		cells.push_front(k)
		if k == sj * cols + si:
			break
		k = int(prev[k])
	# string-pull: keep only the corners, so the truck drives straight lines where the way is clear
	var pts: Array = []
	for ck in cells:
		pts.append(Vector3(lo.x + (float(int(ck) % cols) + 0.5) * cell, from.y, lo.y + (float(int(ck) / cols) + 0.5) * cell))
	var out := PackedVector3Array([from])
	var anchor := 0
	while anchor < pts.size() - 1:
		var far := anchor + 1
		for m in range(pts.size() - 1, anchor, -1):
			if _line_clear(pts[anchor] if anchor > 0 else from, pts[m], blocked, lo, cell, cols, rows):
				far = m
				break
		out.append(pts[far])
		anchor = far
	out.append(to)
	return out

func _line_clear(a: Vector3, b: Vector3, blocked: PackedByteArray, lo: Vector2, cell: float, cols: int, rows: int) -> bool:
	var n := int(ceil(a.distance_to(b) / (cell * 0.5)))
	for j in range(n + 1):
		var p := a.lerp(b, float(j) / float(maxi(1, n)))
		var i := int((p.x - lo.x) / cell)
		var jj := int((p.z - lo.y) / cell)
		if i < 0 or jj < 0 or i >= cols or jj >= rows or blocked[jj * cols + i] == 1:
			return false
	return true

func _stop(v: QuarryVehicle) -> void:
	v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}

func _plan(v: QuarryVehicle, goal: Vector3, r: Dictionary) -> void:
	var path := PackedVector3Array()
	if game.nav_ready():
		var g: Vector3 = NavigationServer3D.map_get_closest_point(game.nav_map, goal)
		path = NavigationServer3D.map_get_path(game.nav_map, v.global_position, g, true)
	if path.size() < 2:
		path = PackedVector3Array([v.global_position, goal])
	# the nav mesh does not know the soil field: when the route would run into standing soil, re-plan around it on the soil grid
	if _path_hits_soil(path):
		var detour := soil_route(v.global_position, goal)
		if detour.size() >= 2:
			path = detour
	r["path"] = path
	r["pi"] = 1 if path.size() > 1 else 0
	r["stuck_t"] = 0.0
	r["stuck_pos"] = v.global_position

## Pure pursuit along the planned route. Returns true once the last point is reached. Backs up and re-plans when stuck.
func _follow(v: QuarryVehicle, r: Dictionary, final_goal: Vector3, delta: float, slow_end := true) -> bool:
	var goal := final_goal
	if r.has("via"):
		# after getting stuck the truck first drives to a side-step point, then plans to the real goal again
		goal = r["via"]
		r["via_t"] = float(r.get("via_t", 0.0)) + delta
		if (v.global_position * Vector3(1, 0, 1)).distance_to(goal * Vector3(1, 0, 1)) < 2.5 or float(r["via_t"]) > 9.0:
			r.erase("via")
			r["path"] = PackedVector3Array()
			r["stuck_t"] = 0.0
			goal = final_goal
	var path: PackedVector3Array = r["path"]
	if path.is_empty():
		_plan(v, goal, r)
		path = r["path"]
	var pi: int = r["pi"]
	var flat := v.global_position * Vector3(1, 0, 1)
	while pi < path.size() - 1 and flat.distance_to(path[pi] * Vector3(1, 0, 1)) < 1.8:
		pi += 1
	r["pi"] = pi
	var wp: Vector3 = path[mini(pi, path.size() - 1)] * Vector3(1, 0, 1)
	var dist_end := flat.distance_to(goal * Vector3(1, 0, 1))
	if dist_end < 2.6 and not r.has("via"):
		_stop(v)
		return true
	var dir := wp - flat
	var dy := angle_difference(v.global_rotation.y, yaw_of(dir))
	var cruise := clampf(float(game.fleet.max_speed(game.fleet.vehicle(v.vehicle_id))) * 0.5, 2.5, 6.0)     # an auto crew drives at about half throttle
	var spd := cruise if absf(dy) < 0.7 else cruise * 0.45
	var steer_cmd := -dy * 2.0
	# local avoidance: the nav route only knows the baked walkable surface, not soil, vehicles or loose obstacles
	var av := _probe(v)
	var near_goal := dist_end < 9.0          # close to the loading spot a neighbour (the excavator) is expected: only a head-on obstacle matters
	if float(av["c"]) < (2.4 if near_goal else 5.0) or (not near_goal and (float(av["l"]) < 3.2 or float(av["r"]) < 3.2)):
		var open_left: bool = float(av["l"]) > float(av["r"])
		var amount := 1.0 if float(av["c"]) < 3.5 else 0.6
		steer_cmd = (-amount if open_left else amount)
		spd = minf(spd, 1.6 if float(av["c"]) > 2.0 else 0.9)
	if slow_end:
		spd = minf(spd, maxf(1.0, dist_end * 0.5))
	# stuck: barely moved in 3 s while asked to move
	r["stuck_t"] = float(r["stuck_t"]) + delta
	if float(r["stuck_t"]) > 2.0:
		if flat.distance_to((r["stuck_pos"] as Vector3) * Vector3(1, 0, 1)) < 0.5:
			r["fails"] = int(r["fails"]) + 1
			r["back_t"] = 1.8
			var avp := _probe(v)
			var fw := v.forward()
			fw.y = 0.0
			var left := fw.rotated(Vector3.UP, PI * 0.5)
			var side_dir := left if float(avp["l"]) >= float(avp["r"]) else -left
			if int(r["fails"]) % 2 == 0:
				side_dir = -side_dir                       # alternate sides on repeated failures
			r["via"] = v.global_position + side_dir * 6.5 - fw * 1.5
			r["via_t"] = 0.0
			_plan(v, r["via"], r)
		r["stuck_t"] = 0.0
		r["stuck_pos"] = v.global_position
	if float(r.get("back_t", 0.0)) > 0.0:
		r["back_t"] = float(r["back_t"]) - delta
		_drive(v, -1.5, -signf(dy) * 0.8)
		r["status"] = "BACKING OUT"
		return false
	_drive(v, spd, steer_cmd)
	return false

## Free distance ahead (centre) and ahead-left / ahead-right of the truck, up to 6 m, from rays at bumper height.
func _probe(v: QuarryVehicle) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = v.get_world_3d().direct_space_state
	var out := {"c": 6.0, "l": 6.0, "r": 6.0}
	var f := v.forward()
	f.y = 0.0
	f = f.normalized()
	var origin := v.global_position + Vector3(0, 0.25, 0) + f * (v.size.z * 0.5)
	var dirs := {"c": f, "l": f.rotated(Vector3.UP, 0.55), "r": f.rotated(Vector3.UP, -0.55)}
	for k in dirs:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + (dirs[k] as Vector3) * 6.0)
		q.exclude = [v.get_rid()]
		q.collision_mask = 1 | 4 | 8 | 16
		var h := space.intersect_ray(q)
		if not h.is_empty():
			out[k] = origin.distance_to(h["position"])
	return out

func _truck_dest(rec: Dictionary) -> Dictionary:
	var res := _cargo_res(rec)
	if res == "":
		return {}
	var biz: QuarryBusiness = game.business
	if res == "soil":
		if game.spoil_node and is_instance_valid(game.spoil_node):
			return {"ep": {"spoil": true}, "pos": game.spoil_node.global_position}
		return {}
	if res == "limestone":
		for i in range(game.state.crushers.size()):
			var ep := {"type": "crusher", "index": i}
			if biz.ep_space(ep, res) > 0:
				return {"ep": ep, "pos": QuarryBusiness.v3(game.state.crushers[i]["position"])}
	for i in range(biz.outputs.size()):
		var ep2 := {"type": "output", "index": i}
		if biz.ep_space(ep2, res) > 0:
			return {"ep": ep2, "pos": QuarryBusiness.v3(biz.outputs[i]["position"])}
	var ep3 := {"type": "storage"}
	if biz.ep_space(ep3, res) > 0:
		return {"ep": ep3, "pos": biz.storage_pos}
	return {}

func _tip_ok(v: QuarryVehicle, rec: Dictionary) -> bool:
	var t: Dictionary = game.dump_target(v.work_point(), TIP, v)
	if t.is_empty() or t.has("truck"):
		return false
	if t.has("spoil"):
		return int(rec["cargo"].get("soil", 0)) > 0
	return game.business.ep_space(t["ep"], _cargo_res(rec)) > 0

func _home(rec: Dictionary, v: QuarryVehicle) -> Vector3:
	var h: Array = rec.get("auto_home", [])
	if h.size() == 3:
		return Vector3(float(h[0]), float(h[1]), float(h[2]))
	return v.global_position

func _step_truck(v: QuarryVehicle, rec: Dictionary, r: Dictionary, delta: float) -> void:
	v.auto_drive = true
	var cargo: int = game.fleet.cargo_total(rec)
	match str(r["phase"]):
		"wait":
			_stop(v)
			r["status"] = "WAITING FOR LOAD" if cargo < game.fleet.capacity(rec) else "FULL"
			if cargo != int(r["last"]):
				r["last"] = cargo
				r["idle"] = 0.0
			else:
				r["idle"] = float(r["idle"]) + delta
			var full: bool = game.fleet.space(rec) <= 0
			if cargo > 0 and (full or float(r["idle"]) > CYCLE_IDLE) and absf(v.speed) < 0.3:
				var d: Dictionary = _truck_dest(rec)
				if d.is_empty():
					r["status"] = "NO DESTINATION WITH ROOM"
					r["idle"] = 0.0
					return
				r["dest"] = d
				r["fails"] = 0
				var dpos: Vector3 = d["pos"]
				var away := (v.global_position - dpos) * Vector3(1, 0, 1)
				r["away"] = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
				r["goal"] = dpos * Vector3(1, 0, 1) + (r["away"] as Vector3) * STAND_OFF + Vector3(0, v.global_position.y, 0)
				r["path"] = PackedVector3Array()
				r["phase"] = "go_dest"
		"go_dest":
			r["status"] = "HAULING"
			if _follow(v, r, r["goal"], delta):
				r["phase"] = "turn_away"
				r["phase_t"] = 0.0
			elif int(r["fails"]) >= 4:
				_give_up(v, r)
		"turn_away":
			# a wide U-turn so the tail points at the destination
			r["status"] = "TURNING"
			r["phase_t"] = float(r["phase_t"]) + delta
			var want := yaw_of(r["away"])
			var dy := angle_difference(v.global_rotation.y, want)
			if absf(dy) < 0.25 or float(r["phase_t"]) > 14.0:
				r["phase"] = "reverse"
				r["phase_t"] = 0.0
			else:
				_drive(v, 1.5, -signf(dy))
		"reverse":
			r["status"] = "BACKING UP"
			r["phase_t"] = float(r["phase_t"]) + delta
			if _tip_ok(v, rec):
				_stop(v)
				r["phase"] = "tip"
				r["phase_t"] = 0.0
				return
			if float(r["phase_t"]) > 25.0:
				_give_up(v, r)
				return
			var dpos: Vector3 = r["dest"]["pos"]
			var to := (dpos - v.global_position) * Vector3(1, 0, 1)
			var rear_want := yaw_of(to) + PI
			var dy2 := angle_difference(v.global_rotation.y, rear_want)
			_drive(v, -1.4, clampf(dy2 * 2.5, -1.0, 1.0))      # reversing inverts the steering, so the sign differs from driving forward
		"tip":
			r["status"] = "TIPPING"
			_stop(v)
			r["phase_t"] = float(r["phase_t"]) + delta
			if v.unload_timer <= 0.0 and float(r["phase_t"]) < 0.2:
				var before: int = game.fleet.cargo_total(rec)
				game.vehicle_dump(v, true)
				r["before"] = before
			elif v.unload_timer <= 0.0 and float(r["phase_t"]) > 0.4:
				var moved: int = int(r.get("before", cargo)) - game.fleet.cargo_total(rec)
				if moved > 0 and not _pay(v, rec):
					return
				r["phase"] = "go_home"
				r["path"] = PackedVector3Array()
				r["fails"] = 0
		"go_home":
			r["status"] = "RETURNING"
			var home := _home(rec, v)
			if _follow(v, r, home, delta):
				r["phase"] = "wait"
				r["last"] = -1
				r["idle"] = 0.0
			elif int(r["fails"]) >= 4:
				_give_up(v, r)

func _give_up(v: QuarryVehicle, r: Dictionary) -> void:
	# the cargo stays on board (nothing is lost): the truck stops where it is and tries again from "wait"
	_stop(v)
	r["status"] = "STUCK - RETRYING"
	r["phase"] = "go_home" if str(r["phase"]) != "go_home" else "wait"
	r["path"] = PackedVector3Array()
	r["fails"] = 0
	r["idle"] = 0.0
	r["last"] = -1
