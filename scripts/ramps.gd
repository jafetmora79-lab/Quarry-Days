extends Node3D
class_name QuarryRamps
## Temporary haul ramps. The ramp tool (hotbar) plans a straight embankment from where you aim, in the direction you face: it rises from the ground at the start to the
## level ground at the far end (the rim of the excavation), and is only accepted when the grade, the width, the headroom and both connections are right. A ramp is a
## solid wedge of fill (graded surface, convex collision) that people and vehicles drive on like any other ground. If the rim is too far or too high for one ramp, a
## STAGE is built instead: a free-standing ramp that ends in a landing, and the next ramp starts from that landing (staged construction). Ramps can be taken away
## again, but never while something stands on them or another ramp rests on their top.
##
## Starter ramps are 3.2 m wide with a grade of at most 30% (16.7 degrees): the starter dump truck, small construction vehicles and the player on foot. (Later,
## heavier machines use the permanent haul roads the survey crew builds.)

const WIDTH := 3.2
const MAX_RISE := 4.2
const MIN_ENCLOSED := 3        # of 16 directions the ground must rise around the start: a hollow, not a hillside or the yard
const STAGE_ENCLOSED := 8      # a free-standing staging ramp needs a deep hole all around
const MAX_SLOPE := 0.30
const STAGE_SLOPE := 0.25
const STAGE_LEN := 12.0
const MIN_LEN := 3.0
const MAX_LEN := 30.0
const MAX_RAMPS := 8
const HEADROOM := 3.4
## A ramp has to climb to the quarry's ground level (the highest ground round its foot, `rim`), or be a stage that a later ramp continues from when the hole is too deep for one.
const EVAL_EVERY_MSEC := 220   ## the plan preview re-evaluates at most this often for the same aim (the check is dozens of ray casts: running it every frame made the game lag)
var _eval_cache := {}

var game
var ramps: Array = []            ## [{"id", "x", "z", "yaw", "y0", "y1", "len", "w", "base", "stage"}]
var bodies := {}                 ## id -> StaticBody3D
var _next_id := 1
var ghost: MeshInstance3D
var ghost_info := {}

func setup(main_node) -> void:
	game = main_node
	name = "Ramps"
	game.add_child(self)

# ------------------------------------------------------------------ geometry helpers

static func dir_of(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

static func right_of(dir: Vector3) -> Vector3:
	return Vector3(-dir.z, 0.0, dir.x)

## Height of the ground at (x, z) looking down from `from_y` (NAN when there is none). Everything solid counts, including other ramps; vehicles and the player do not.
func ground_at(x: float, z: float, from_y: float, ignore_id := -1) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 60.0, z), 1)
	q.exclude = [game.player.get_rid()]
	for id in bodies:
		if int(id) == ignore_id:
			q.exclude.append((bodies[id] as StaticBody3D).get_rid())
	for node in game.vehicle_nodes.values():
		if node is CollisionObject3D:
			q.exclude.append((node as CollisionObject3D).get_rid())
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for attempt in range(8):
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return NAN
		var c = hit["collider"]
		# loose rock, rubble, weeds and survey markers lie ON the ground: they are not the ground (they never stop a ramp being planned, and the ramp is built under them)
		if c is Node and (str((c as Node).get_meta("kind", "")) in ["piece", "debris", "pile", "worker"]):
			q.exclude.append((c as CollisionObject3D).get_rid())
			continue
		return float(hit["position"].y)
	return NAN

## The ramp whose top end (landing) is within `r` of a point: the next stage starts from it.
func landing_near(p: Vector3, r := 2.2) -> Dictionary:
	for rp in ramps:
		var end := Vector3(float(rp["x"]), float(rp["y1"]), float(rp["z"])) + dir_of(float(rp["yaw"])) * float(rp["len"])
		if Vector2(end.x - p.x, end.z - p.z).length() < r:                  # (whatever height you aim at: the ramp's top or the ground at its foot)
			return rp
	return {}

# ------------------------------------------------------------------ validation

## Plans a ramp that starts at `aim` (a point on the ground you are looking at) and runs the way you face (`yaw`).
## Returns {valid, reason, note, x, z, yaw, y0, y1, len, w, base, slope, stage}.
## The live preview: the same check, re-run at most every EVAL_EVERY_MSEC for the same aim (placing still uses `evaluate`, always fresh).
func preview(aim: Vector3, yaw: float) -> Dictionary:
	var ck := "%d|%d|%d|%d|%d" % [roundi(aim.x * 4.0), roundi(aim.y * 4.0), roundi(aim.z * 4.0), roundi(yaw * 20.0), ramps.size()]
	var now := Time.get_ticks_msec()
	if _eval_cache.get("key", "") == ck and now - int(_eval_cache.get("t", -99999)) < EVAL_EVERY_MSEC:
		return (_eval_cache["out"] as Dictionary).duplicate(true)
	var res := evaluate(aim, yaw)
	_eval_cache = {"key": ck, "t": now, "out": res.duplicate(true)}
	return res

func evaluate(aim: Vector3, yaw: float) -> Dictionary:
	var out := {"valid": false, "reason": "", "note": "", "x": aim.x, "z": aim.z, "yaw": yaw, "y0": aim.y, "y1": aim.y, "len": 0.0, "w": WIDTH, "base": aim.y, "slope": 0.0, "stage": false}
	if ramps.size() >= MAX_RAMPS:
		out["reason"] = "Too many ramps (%d). Remove one first." % MAX_RAMPS
		return out
	var dir := dir_of(yaw)
	var right := right_of(dir)
	var start := aim
	var snapped_on := landing_near(aim)
	if not snapped_on.is_empty():                       # staged construction: the next ramp starts exactly at the landing of the last one
		start = Vector3(float(snapped_on["x"]), float(snapped_on["y1"]), float(snapped_on["z"])) + dir_of(float(snapped_on["yaw"])) * float(snapped_on["len"])
		out["x"] = start.x
		out["z"] = start.z
		out["note"] = "Stage %d: continues from the landing" % (ramps.find(snapped_on) + 2)
	var y_s := start.y
	out["y0"] = y_s
	var hw := WIDTH * 0.5 - 0.15
	# the entrance: level enough across its width (a truck needs a flat approach)
	for lat in [-hw, 0.0, hw]:
		var gy := ground_at(start.x + right.x * lat, start.z + right.z * lat, y_s + 3.0)
		if is_nan(gy) or absf(gy - y_s) > 0.4:
			out["reason"] = "The foot of the ramp needs level ground across its width."
			return out
	# a ramp only makes sense in an excavation: the ground must rise around the start (a pit, a basin or a trench), not be open flat country
	var rim := _rim_height(start)
	if rim < 0.8:
		out["reason"] = "Not in an excavation: aim at the floor of a pit or trench."
		return out
	# find the wall: the first place along the centre line where the ground stands 0.7 m above the start
	var wall_l := -1.0
	var l := 0.75
	var steps := int((MAX_LEN + 3.0) / 0.75)
	for i in range(steps):
		var gy := ground_at(start.x + dir.x * l, start.z + dir.z * l, y_s + 12.0)
		if is_nan(gy):
			out["reason"] = "No ground ahead."
			return out
		if gy - y_s > 0.7:
			wall_l = l
			break
		l += 0.75
	var length := 0.0
	var y_e := y_s
	if wall_l > 0.0:
		length = wall_l - 0.375 + 0.25
		var plateau := maxf(ground_at(start.x + dir.x * (wall_l + 0.75), start.z + dir.z * (wall_l + 0.75), y_s + 20.0), ground_at(start.x + dir.x * (wall_l + 1.5), start.z + dir.z * (wall_l + 1.5), y_s + 20.0))
		if is_nan(plateau):
			out["reason"] = "No level ground above the wall."
			return out
		y_e = plateau
		length = maxf(length, 0.5)
		var slope := (y_e - y_s) / length
		out["slope"] = slope
		if length < MIN_LEN:
			out["reason"] = "Too short: the wall is only %.1f m away. Step back and aim again." % length
			return out
		if slope > MAX_SLOPE:
			out["reason"] = "Too steep: %d%% (limit %d%%). Start %.0f m further back, or build it in stages." % [roundi(slope * 100.0), roundi(MAX_SLOPE * 100.0), ceilf((y_e - y_s) / MAX_SLOPE - length)]
			return out
		if slope < 0.02:
			out["reason"] = "Nothing to climb here: the wall is lower than the ramp's start."
			return out
		out["stage"] = false
		if y_e - y_s > MAX_RISE:                       # too high for one ramp: a staging ramp (it needs a deep hole)
			wall_l = -1.0
	if wall_l <= 0.0:
		if rim < 3.0 or _rim_walls < STAGE_ENCLOSED:
			out["reason"] = "Nothing to climb to from here."
			return out
		if rim - 0.8 <= MAX_RISE:
			out["reason"] = "Aim at the wall: the ramp has to climb to the quarry's ground level."
			return out                               # (a free-standing stage is only for a hole too deep to climb out of in one ramp)
		# no wall within reach: a free-standing stage that ends in a landing (the next ramp continues from it)
		length = STAGE_LEN
		y_e = y_s + STAGE_SLOPE * length
		out["slope"] = STAGE_SLOPE
		out["stage"] = true
		out["note"] = (str(out["note"]) + "  " if str(out["note"]) != "" else "") + "Staging ramp: it ends in a landing, build the next stage from there"
	out["len"] = length
	out["y1"] = y_e
	# clearance: the surface must lie above the ground all along (never inside solid terrain), and the head room above it must be free
	var lowest := y_s
	var bad := ""
	var s := 0.0
	while s <= length + 0.01:
		var yy := y_s + (y_e - y_s) * (s / length)
		for lat in [-hw, 0.0, hw]:
			var p: Vector3 = start + dir * s + right * lat
			var gy2 := ground_at(p.x, p.z, yy + 6.0)
			if is_nan(gy2):
				bad = "No ground under the ramp."
				break
			lowest = minf(lowest, gy2)
			var near_end := s > length - 0.8 and not bool(out["stage"])
			if not near_end and s > 0.9 and gy2 > yy - 0.03:                # (the foot itself was checked flat above)
				bad = "Blocked: the ramp would cut into solid ground %.1f m along." % s
				break
		if bad != "":
			break
		# head room above the surface
		var qq := PhysicsRayQueryParameters3D.create(Vector3(start.x + dir.x * s, yy + 0.15, start.z + dir.z * s), Vector3(start.x + dir.x * s, yy + HEADROOM, start.z + dir.z * s), 1)
		qq.exclude = [game.player.get_rid()]
		for node in game.vehicle_nodes.values():
			if node is CollisionObject3D:
				qq.exclude.append((node as CollisionObject3D).get_rid())
		if not game.get_world_3d().direct_space_state.intersect_ray(qq).is_empty():
			bad = "Not enough head room above the ramp %.1f m along." % s
			break
		s += 1.0
	if bad != "":
		out["reason"] = bad
		return out
	# the connection at the top: level ground the whole width (not for a free stage)
	if not bool(out["stage"]):
		for lat in [-hw, 0.0, hw]:
			var p2: Vector3 = start + dir * (length + 0.7) + right * lat
			var gt := ground_at(p2.x, p2.z, y_e + 4.0)
			if is_nan(gt) or absf(gt - y_e) > 0.35:
				out["reason"] = "The top must meet level ground across the full width."
				return out
	# it may not overlap another ramp (apart from the landing it continues from)
	var mine := _footprint(start, dir, length)
	for rp in ramps:
		if rp == snapped_on:
			continue
		var theirs := _footprint(Vector3(float(rp["x"]), 0, float(rp["z"])), dir_of(float(rp["yaw"])), float(rp["len"]))
		if Geometry2D.intersect_polygons(mine, theirs).size() > 0:
			out["reason"] = "It would overlap another ramp."
			return out
	if not bool(out["stage"]) and y_e < y_s + rim - 0.8 and rim - 0.8 <= MAX_RISE:
		out["reason"] = "A ramp has to climb to the quarry's ground level. Aim at the wall that reaches the top edge."
		return out
	out["base"] = lowest - 0.1
	out["valid"] = true
	return out

## How high the ground stands above `start` around it (16 directions out to 16 m); needs at least 3 of the 16 to rise 0.8 m or more, else 0.
var _rim_walls := 0          ## how many of the 16 directions rise (set by _rim_height)

func _rim_height(start: Vector3) -> float:
	var best := 0.0
	var walls := 0
	for d in range(16):
		var a := TAU * float(d) / 16.0
		var up := 0.0
		for r in [3.0, 6.0, 9.0, 12.0, 16.0]:
			var gy := ground_at(start.x + cos(a) * r, start.z + sin(a) * r, start.y + 30.0)
			if not is_nan(gy):
				up = maxf(up, gy - start.y)
		if up >= 0.8:
			walls += 1
			best = maxf(best, up)
	_rim_walls = walls
	return best if walls >= MIN_ENCLOSED else 0.0

## The ground footprint (x, z polygon) of a ramp.
func _footprint(start: Vector3, dir: Vector3, length: float) -> PackedVector2Array:
	var right := right_of(dir)
	var a := start + right * (WIDTH * 0.5)
	var b := start - right * (WIDTH * 0.5)
	var c := b + dir * length
	var d := a + dir * length
	return PackedVector2Array([Vector2(a.x, a.z), Vector2(d.x, d.z), Vector2(c.x, c.z), Vector2(b.x, b.z)])

# ------------------------------------------------------------------ building

func place(plan: Dictionary) -> int:
	if not bool(plan.get("valid", false)):
		return -1
	var rp := {"id": _next_id, "x": plan["x"], "z": plan["z"], "yaw": plan["yaw"], "y0": plan["y0"], "y1": plan["y1"], "len": plan["len"], "w": plan["w"], "base": plan["base"], "stage": plan["stage"]}
	_next_id += 1
	ramps.append(rp)
	_build(rp)
	game.state.ramps = to_save()
	return int(rp["id"])

## Corner points of a ramp's solid wedge, in world space: the four top corners, then the four on the base.
func corners(rp: Dictionary) -> Array:
	var dir := dir_of(float(rp["yaw"]))
	var right := right_of(dir)
	var start := Vector3(float(rp["x"]), 0, float(rp["z"]))
	var hw := float(rp["w"]) * 0.5
	var l := float(rp["len"])
	var y0 := float(rp["y0"])
	var y1 := float(rp["y1"])
	var base := float(rp["base"])
	var s0 := start - right * hw
	var s1 := start + right * hw
	var e0 := start + dir * l - right * hw
	var e1 := start + dir * l + right * hw
	return [Vector3(s0.x, y0, s0.z), Vector3(s1.x, y0, s1.z), Vector3(e1.x, y1, e1.z), Vector3(e0.x, y1, e0.z),
		Vector3(s0.x, base, s0.z), Vector3(s1.x, base, s1.z), Vector3(e1.x, base, e1.z), Vector3(e0.x, base, e0.z)]

func wedge_mesh(rp: Dictionary) -> ArrayMesh:
	var c := corners(rp)
	var top := MeshKit.Soup.new()
	top.quad(c[0], c[3], c[2], c[1])                              # the graded surface (normal up)
	var side := MeshKit.Soup.new()
	side.quad(c[0], c[1], c[5], c[4])                             # the foot
	side.quad(c[1], c[2], c[6], c[5])                             # right side
	side.quad(c[3], c[0], c[4], c[7])                             # left side
	side.quad(c[2], c[3], c[7], c[6])                             # the top end
	var m := ArrayMesh.new()
	for pair in [[top, "RockGravel"], [side, "ExcavatedDirt"]]:
		var so: MeshKit.Soup = pair[0]
		var mm := so.mesh()
		if mm.get_surface_count() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mm.surface_get_arrays(0))
			var mt = MeshKit.mat(str(pair[1]))
			if mt is BaseMaterial3D:
				mt = (mt as BaseMaterial3D).duplicate()
				(mt as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED     # visible from every side whatever the winding
				if str(pair[1]) == "RockGravel":
					(mt as BaseMaterial3D).albedo_color = Color(0.74, 0.62, 0.42)    # a pale packed-gravel surface that stands out from the dark soil
			m.surface_set_material(m.get_surface_count() - 1, mt)
	return m

func _build(rp: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "Ramp_%d" % int(rp["id"])
	body.set_meta("ground", true)
	body.set_meta("ramp_id", int(rp["id"]))
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	sh.points = PackedVector3Array(corners(rp))
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = wedge_mesh(rp)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	add_child(body)
	bodies[int(rp["id"])] = body

# ------------------------------------------------------------------ removing

func ramp_by_id(id: int) -> Dictionary:
	for rp in ramps:
		if int(rp["id"]) == id:
			return rp
	return {}

## Why a ramp cannot be taken away right now ("" when it can): something stands on it, or another ramp starts from its landing.
func removal_block(id: int) -> String:
	var rp := ramp_by_id(id)
	if rp.is_empty():
		return "No such ramp."
	var pts := _footprint(Vector3(float(rp["x"]), 0, float(rp["z"])), dir_of(float(rp["yaw"])), float(rp["len"]))
	var grown := Geometry2D.offset_polygon(pts, 1.0)
	var poly: PackedVector2Array = grown[0] if grown.size() > 0 else pts
	var p: Vector3 = game.player.global_position
	if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), poly):
		return "You are standing on it. Step off first."
	for vn in game.vehicle_nodes.values():
		if is_instance_valid(vn) and vn is Node3D and Geometry2D.is_point_in_polygon(Vector2(vn.global_position.x, vn.global_position.z), poly):
			return "A machine is on the ramp. Drive it off first."
	var end := Vector3(float(rp["x"]), float(rp["y1"]), float(rp["z"])) + dir_of(float(rp["yaw"])) * float(rp["len"])
	for other in ramps:
		if other == rp:
			continue
		if Vector2(float(other["x"]) - end.x, float(other["z"]) - end.z).length() < 0.3:
			return "Another ramp starts from its landing. Remove that one first."
	return ""

func remove(id: int) -> String:
	var why := removal_block(id)
	if why != "":
		return why
	var rp := ramp_by_id(id)
	ramps.erase(rp)
	if bodies.has(id):
		(bodies[id] as Node).queue_free()
		bodies.erase(id)
	game.state.ramps = to_save()
	return ""

## The ramp id under the crosshair ray (or -1).
func ramp_at_look() -> int:
	var t: Node3D = game.last_target
	if t != null and is_instance_valid(t) and t.has_meta("ramp_id"):
		return int(t.get_meta("ramp_id"))
	return -1

# ------------------------------------------------------------------ the ghost (the plan shown in the world)

func show_ghost(plan: Dictionary) -> void:
	if ghost == null:
		ghost = MeshInstance3D.new()
		ghost.name = "RampGhost"
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
	ghost_info = plan
	var shown := plan.duplicate()
	shown["len"] = maxf(float(plan["len"]), 1.0)
	if float(plan["len"]) <= 0.0:
		shown["y1"] = float(plan["y0"]) + 0.3
		shown["len"] = 3.0
	var m := wedge_mesh(shown)
	var col := Color(0.3, 0.95, 0.4, 0.5) if bool(plan["valid"]) else Color(1.0, 0.28, 0.22, 0.5)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = col
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.mesh = m
	ghost.material_override = gm
	ghost.visible = true

func hide_ghost() -> void:
	if ghost != null:
		ghost.visible = false
	ghost_info = {}

# ------------------------------------------------------------------ saving

func to_save() -> Array:
	var out := []
	for rp in ramps:
		out.append(rp.duplicate())
	return out

func restore(saved: Array) -> void:
	for id in bodies.keys():
		(bodies[id] as Node).queue_free()
	bodies.clear()
	ramps.clear()
	_next_id = 1
	for item in saved:
		if not (item is Dictionary) or not (item as Dictionary).has("len"):
			continue
		var rp := {"id": _next_id, "x": float(item["x"]), "z": float(item["z"]), "yaw": float(item["yaw"]), "y0": float(item["y0"]), "y1": float(item["y1"]), "len": float(item["len"]), "w": float(item.get("w", WIDTH)), "base": float(item["base"]), "stage": bool(item.get("stage", false))}
		_next_id += 1
		ramps.append(rp)
		_build(rp)

## For the quarry plan: each ramp's two connection points on the ground.
func plan_segments() -> Array:
	var out := []
	for rp in ramps:
		var dir := dir_of(float(rp["yaw"]))
		var a := Vector2(float(rp["x"]), float(rp["z"]))
		out.append({"from": a, "to": a + Vector2(dir.x, dir.z) * float(rp["len"])})
	return out
