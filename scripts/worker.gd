extends CharacterBody3D
class_name QuarryWorker
## One employee in the world. All four professions share this body, rig and animation
## system; only colours, headgear, tool and the task routine differ.
## Production only happens through physical actions at the workplace (strike, pick up,
## load, hand over, sell) after the worker has walked there on the navigation mesh.

enum { MOVING, ARRIVED, BLOCKED }

const RESOURCE_COLORS := {"limestone": Color(0.67, 0.66, 0.56), "coal": Color(0.17, 0.19, 0.21), "iron_ore": Color(0.52, 0.29, 0.23), "crushed_stone": Color(0.75, 0.73, 0.66), "copper_ore": Color(0.36, 0.52, 0.42), "gold_ore": Color(0.78, 0.62, 0.24)}

var game
var business: QuarryBusiness
var employee_id := 0
var profession := ""
var e: Dictionary

# rig
var model: Node3D
var carry_box: MeshInstance3D
var anim := "idle"
var anim_phase := -1.0      ## 0..1 progress of the current physical action (drives the rig)
var anim_t := 0.0
var duration := 1.0
var anim_skip := 0

# navigation
var path := PackedVector3Array()
var path_i := 0
var path_key := ""
var path_version := -1
var unreachable := false
var retry_timer := 0.0
var stuck_anchor := Vector3.ZERO
var stuck_timer := 0.0
var stuck_count := 0
var sidestep := Vector3.ZERO
var sidestep_timer := 0.0
var access_cache := {}
var facing := 0.0

# task
var phase := ""
var mode := "load"
var timer := 0.0
var target_piece: Node3D
var piece_timer := 0.0
var skip_pieces := {}
var mine_dep := ""
var mine_col := -1

func setup(main_node, biz: QuarryBusiness, record: Dictionary) -> void:
	game = main_node
	business = biz
	employee_id = int(record["id"])
	profession = str(record["profession"])
	e = record
	name = "Worker_%d" % employee_id
	collision_layer = 4
	collision_mask = 1 | 8 # world and vehicles (conveyors on layer 16 are stepped over)
	floor_snap_length = 0.3
	set_meta("kind", "worker")
	set_meta("employee", employee_id)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	_build_rig()

# ------------------------------------------------------------------ model

## Phase 4: THE VEIL-pipeline character (assets/characters/CHR_QD_<Profession>.glb, built by
## tools/veil_pipeline/qd_style_cast.py from THE VEIL's hand-made reference) animated by VeilRig.
const CHARACTER := {"miner": "res://assets/characters/CHR_QD_Miner.glb", "operator": "res://assets/characters/CHR_QD_Operator.glb",
	"hauler": "res://assets/characters/CHR_QD_Hauler.glb", "clerk": "res://assets/characters/CHR_QD_Clerk.glb"}
static var _packed := {}
var rig: VeilRig
var speed_now := 0.0

func _build_rig() -> void:
	model = Node3D.new()
	model.name = "Model"
	# The Quarry Days cast is authored facing -Z (see qd_style_cast.py's front_z).
	# The worker body's -Z is its travel direction, so no model flip is needed.
	model.rotation.y = 0.0
	add_child(model)
	var path: String = CHARACTER[profession]
	if not _packed.has(path):
		_packed[path] = load(path)
	var body: Node3D = _packed[path].instantiate()
	model.add_child(body)
	for gi in body.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var found := body.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	rig = VeilRig.new()
	rig.setup(found[0], float(employee_id) * 1.7)
	var up_fwd := Basis(Vector3.RIGHT, 0.0)
	match profession:
		"miner": rig.attach(_tool_pickaxe(), "Right", up_fwd, Vector3.ZERO)
		"operator": rig.attach(_tool_wrench(), "Right", up_fwd, Vector3.ZERO)
		"clerk": rig.attach(_tool_clipboard(), "Left", up_fwd, Vector3.ZERO)
	carry_box = MeshInstance3D.new()
	carry_box.mesh = MeshKit.rock(Vector3(0.42, 0.3, 0.34), 77 + employee_id, 3, 6)
	carry_box.position = Vector3(0, 0.88, -0.36) # in front of the -Z-facing chest
	carry_box.visible = false
	model.add_child(carry_box)

## Tools are small MeshKit models in hand space: handle along +Z (forward from the fist).
func _tool_pickaxe() -> Node3D:
	var n := Node3D.new()
	var s := MeshKit.Soup.new()
	MeshKit.box_into(s, Vector3(0, 0, 0.22), Vector3(0.04, 0.04, 0.78))
	MeshKit.inst(n, s.mesh(), MeshKit.mat(QuarryArt.M_WOOD))
	var h := MeshKit.Soup.new()
	var prof := PackedVector2Array([Vector2(-0.26, -0.01), Vector2(-0.02, 0.03), Vector2(0.02, 0.03), Vector2(0.26, -0.01), Vector2(0.2, -0.04), Vector2(0.0, -0.01), Vector2(-0.2, -0.04)])
	MeshKit.extrude_into(h, prof, 0.045, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0, 0.6)))
	MeshKit.inst(n, h.mesh(), MeshKit.mat("SteelPlate"))
	return n

func _tool_wrench() -> Node3D:
	var n := Node3D.new()
	var s := MeshKit.Soup.new()
	MeshKit.box_into(s, Vector3(0, 0, 0.12), Vector3(0.035, 0.018, 0.3))
	MeshKit.box_into(s, Vector3(0, 0, 0.29), Vector3(0.08, 0.02, 0.06))
	MeshKit.inst(n, s.mesh(), MeshKit.mat("SteelPlate"))
	return n

func _tool_clipboard() -> Node3D:
	var n := Node3D.new()
	var s := MeshKit.Soup.new()
	MeshKit.box_into(s, Vector3(0, 0.02, 0.1), Vector3(0.24, 0.012, 0.32))
	MeshKit.inst(n, s.mesh(), MeshKit.mat(QuarryArt.M_WOOD))
	var p := MeshKit.Soup.new()
	MeshKit.box_into(p, Vector3(0, 0.03, 0.11), Vector3(0.2, 0.004, 0.26))
	MeshKit.inst(n, p.mesh(), MeshKit.flat(Color(0.86, 0.84, 0.76)))
	return n

func _animate(delta: float) -> void:
	# Distant workers animate at a reduced rate (and not at all when far away and off-screen).
	var far: bool = game.player != null and global_position.distance_squared_to(game.player.global_position) > 900.0
	anim_skip += 1
	if far and anim_skip % 4 != 0:
		return
	var dt := delta * (4.0 if far else 1.0)
	var carrying := business.carry_total(e) > 0
	carry_box.visible = carrying and anim in ["idle", "walk", "turn", "unload"]
	if carrying:
		carry_box.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(e["carry"].keys()[0], "RockLimestone"))
	if rig:
		speed_now = Vector2(velocity.x, velocity.z).length()
		rig.pose(dt, anim, speed_now, profession, carrying, anim_phase)

# ------------------------------------------------------------------ navigation

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

## Horizontal velocity eases toward `target` with at most `accel` m/s^2 (no snapping starts/stops).
func _ease_velocity(target: Vector3, accel: float, delta: float) -> void:
	var v := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), accel * delta)
	velocity.x = v.x
	velocity.z = v.y

func _halt(delta: float) -> void:
	_ease_velocity(Vector3.ZERO, 9.0, delta)
	velocity.y -= 22.0 * delta
	move_and_slide()

func _face(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		facing = atan2(-d.x, -d.z)

func _compute_path(goal: Vector3, key: String) -> void:
	path_key = key
	path_version = game.nav_version
	path = NavigationServer3D.map_get_path(game.nav_map, global_position, goal, true)
	path_i = 0
	unreachable = path.is_empty() or _flat(path[path.size() - 1], goal) > 0.8
	if unreachable:
		retry_timer = 3.0
	stuck_anchor = global_position
	stuck_timer = 0.0

## Walks toward `goal` along the navigation mesh. Returns MOVING, ARRIVED or BLOCKED.
func travel(goal: Vector3, key: String, delta: float, arrive := 0.45) -> int:
	if _flat(global_position, goal) <= arrive:
		_halt(delta)
		stuck_count = 0
		return ARRIVED
	if not game.nav_ready():
		_halt(delta)
		return MOVING
	if key != path_key or path_version != game.nav_version:
		_compute_path(goal, key)
	if unreachable:
		retry_timer -= delta
		if retry_timer <= 0.0:
			_compute_path(goal, key)
		_halt(delta)
		return BLOCKED
	while path_i < path.size() and _flat(global_position, path[path_i]) < 0.35:
		path_i += 1
	var target := goal if path_i >= path.size() else path[path_i]
	var dir := Vector3(target.x - global_position.x, 0, target.z - global_position.z).normalized()
	# Simple separation keeps the (max four) workers from walking through each other.
	for other in game.worker_nodes.values():
		if other != self:
			var away: Vector3 = global_position - other.global_position
			away.y = 0
			var dist: float = away.length()
			if dist > 0.01 and dist < 0.9:
				dir += away.normalized() * (0.9 - dist) * 1.6
	if sidestep_timer > 0.0:
		sidestep_timer -= delta
		dir += sidestep
	dir = dir.normalized()
	var speed := business.stat(e, "speed")
	# Phase 5: smooth acceleration; turn toward the path before striding off at full speed.
	var turning := absf(angle_difference(rotation.y, atan2(-dir.x, -dir.z)))
	var want := speed * clampf(1.2 - turning / 1.6, 0.25, 1.0)
	_ease_velocity(dir * want, 7.0, delta)
	velocity.y -= 22.0 * delta
	move_and_slide()
	_face(global_position + dir)
	anim = "walk"
	_check_stuck(delta)
	return MOVING

func _check_stuck(delta: float) -> void:
	stuck_timer += delta
	if stuck_timer < 1.2:
		return
	var moved := _flat(global_position, stuck_anchor)
	stuck_timer = 0.0
	stuck_anchor = global_position
	if moved > 0.35:
		stuck_count = 0
		return
	stuck_count += 1
	sidestep = Vector3(-velocity.z, 0, velocity.x).normalized() * (1.0 if stuck_count % 2 == 0 else -1.0)
	sidestep_timer = 0.6
	path_key = "" # force a fresh path
	if stuck_count >= 4 and path_i < path.size() and not game.is_visible_to_player(global_position):
		# Last-resort recovery, only when the player cannot see it happen.
		global_position = Vector3(path[path_i].x, global_position.y, path[path_i].z)
		stuck_count = 0
	elif stuck_count >= 7:
		e["warning"] = "Route blocked - repathing"

## Reachable standing point around a workplace (cached until the navmesh changes).
func access_point(key: String, info: Dictionary) -> Variant:
	var cached = access_cache.get(key)
	if cached is Dictionary and int(cached["version"]) == game.nav_version and cached["center"] == info["pos"]:
		return cached["point"]
	if not game.nav_ready():
		return null
	var center: Vector3 = info["pos"]
	var face: Vector3 = info.get("face", Vector3.BACK)
	var base_angle := atan2(face.x, face.z)
	var slot: int = maxi(0, business.employees.find(e))
	var result = null
	for k in range(8):
		var offset := (slot % 2) * 0.35 + float([0, 1, -1, 2, -2, 3, -3, 4][k]) * TAU / 8.0
		var angle := base_angle + offset
		var candidate := center + Vector3(sin(angle), 0, cos(angle)) * float(info["radius"])
		candidate.y = center.y
		var p := NavigationServer3D.map_get_path(game.nav_map, global_position, candidate, true)
		if not p.is_empty() and _flat(p[p.size() - 1], candidate) < 0.6:
			result = candidate
			break
	access_cache[key] = {"version": game.nav_version, "center": center, "point": result}
	return result

## Go to an endpoint's workplace. Returns MOVING, ARRIVED or BLOCKED and sets warnings.
func goto_workplace(ep: Dictionary, delta: float) -> int:
	var info: Dictionary = game.workplace(ep)
	if info.is_empty():
		e["warning"] = "Workplace missing"
		_halt(delta)
		return BLOCKED
	var key := JSON.stringify(ep)
	var point = access_point(key, info)
	if point == null:
		if game.nav_ready():
			e["warning"] = "Cannot reach " + business.describe_ep(ep)
			e["task"] = "Blocked: no route"
		retry_timer -= delta
		if retry_timer <= 0.0:
			retry_timer = 3.0
			access_cache.erase(key)
		_halt(delta)
		anim = "idle"
		return BLOCKED
	var r := travel(point, key, delta)
	if r == BLOCKED:
		e["warning"] = "Cannot reach " + business.describe_ep(ep)
		e["task"] = "Blocked: no route"
		access_cache.erase(key)
		anim = "idle"
	elif r == ARRIVED:
		if str(e["warning"]).begins_with("Cannot reach") or str(e["warning"]).begins_with("Route blocked"):
			e["warning"] = ""
		_face(info["pos"])
	return r

# ------------------------------------------------------------------ main loop

func step(delta: float) -> void:
	e = business.employee(employee_id)
	if e.is_empty():
		return
	anim = "idle"
	anim_phase = -1.0
	if not business.can_work(e):
		_off_duty(delta)
	else:
		if str(e["warning"]).begins_with("Unpaid"):
			e["warning"] = ""
		match profession:
			"miner": _miner(delta)
			"operator": _operator(delta)
			"hauler": _hauler(delta)
			"clerk": _clerk(delta)
	# Turn at a natural rate; a large turn while standing plays a stepping-in-place turn.
	var diff := angle_difference(rotation.y, facing)
	rotation.y += clampf(diff, -delta * 5.5, delta * 5.5)
	if absf(diff) > 0.35 and anim == "idle" and Vector2(velocity.x, velocity.z).length() < 0.3:
		anim = "turn"
	_animate(delta)

func _off_duty(delta: float) -> void:
	timer = 0.0
	phase = ""
	if bool(e["suspended"]):
		e["task"] = "Unpaid - waiting for $%.2f" % float(e["owed"])
		e["warning"] = "Unpaid wages: work stopped"
	else:
		e["task"] = "Off shift (%s-%s)" % [game.fmt_time(int(e["shift_start"])), game.fmt_time(int(e["shift_end"]))]
		if str(e["warning"]).begins_with("Unpaid"):
			e["warning"] = ""
	var spot: Vector3 = game.break_spot(business.employees.find(e))
	if travel(spot, "break", delta, 0.6) == ARRIVED:
		_face(spot + Vector3(0, 0, -3)) # toward the bench and the yard
		anim = "rest"
		if str(e["warning"]).begins_with("Route blocked"):
			e["warning"] = ""

const ACTION_ANIM := {"pickup": "pickup", "unload": "unload", "collect": "interact", "start": "interact", "strike": "work", "sell": "work"}

## True once the body faces its work target (actions wait for it: nobody works facing away).
func _aligned() -> bool:
	return absf(angle_difference(rotation.y, facing)) < 0.3

## Shared action timer: returns true once the action finishes. The rig plays the matching action with
## its phase taken from this timer, so the visible motion completes exactly when the work happens.
func _act(delta: float, d: float, label: String) -> bool:
	if phase != label:
		phase = label
		timer = d
		duration = maxf(0.05, d)
	if label == "load":
		anim = "pickup" if profession == "hauler" else "interact"
	else:
		anim = ACTION_ANIM.get(label, "work")
	if not _aligned():
		anim = "turn"
		anim_phase = 0.0
		return false
	timer -= delta
	anim_phase = clampf(1.0 - timer / duration, 0.0, 1.0)
	if timer <= 0.0:
		phase = ""
		return true
	return false

func _wait(delta: float, task: String) -> void:
	e["task"] = task
	phase = ""
	_halt(delta)

# --- shared: picking up loose pieces (miner and hauler) ---
func _collect_pieces(res: String, delta: float) -> bool:
	if target_piece == null or not is_instance_valid(target_piece) or not target_piece.is_inside_tree() or target_piece.is_queued_for_deletion():
		target_piece = game.nearest_piece(res, global_position, skip_pieces)
		if target_piece == null:
			return false
		piece_timer = 0.0
		phase = ""
	var dep_id: String = str(target_piece.get_meta("deposit"))
	e["task"] = "Collecting loose " + res.replace("_", " ")
	var dist := _flat(global_position, target_piece.global_position)
	if dist > 2.6:
		var r := travel(target_piece.global_position, "piece_" + str(target_piece.get_meta("piece_id")), delta, 1.6)
		if r == BLOCKED:
			if not game.is_formation(dep_id):
				r = goto_workplace({"type": "deposit_site", "id": dep_id}, delta)
			if r == BLOCKED:
				skip_pieces[target_piece.get_meta("piece_id")] = true
				target_piece = null
				return true
		if r != ARRIVED:
			return true
	# Close in directly (the rock it came from is gone; collisions still apply).
	if dist > 1.0 and piece_timer < 2.5:
		piece_timer += delta
		var dir := (target_piece.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		_ease_velocity(dir * 1.4, 7.0, delta)
		velocity.y -= 22.0 * delta
		move_and_slide()
		_face(target_piece.global_position)
		anim = "walk"
		return true
	if dist > 1.9:
		skip_pieces[target_piece.get_meta("piece_id")] = true
		target_piece = null
		return true
	_halt(delta)
	_face(target_piece.global_position)
	if _act(delta, business.stat(e, "pickup_seconds") if profession == "miner" else business.stat(e, "handle_seconds"), "pickup"):
		if game.worker_pick_piece(target_piece, e):
			piece_timer = 0.0
		target_piece = null
	return true

func _deliver_to(ep: Dictionary, delta: float, on_unit: Callable) -> void:
	var r := goto_workplace(ep, delta)
	if r != ARRIVED:
		if r == MOVING:
			e["task"] = "Carrying %d to %s" % [business.carry_total(e), business.describe_ep(ep)]
		return
	var res: String = e["carry"].keys()[0]
	if business.ep_space(ep, res) <= 0:
		e["task"] = "Waiting: %s full" % business.describe_ep(ep)
		e["warning"] = business.describe_ep(ep) + " is full"
		phase = ""
		return
	if str(e["warning"]).ends_with(" is full"):
		e["warning"] = ""
	e["task"] = "Unloading at " + business.describe_ep(ep)
	if _act(delta, business.stat(e, "pickup_seconds") if profession == "miner" else business.stat(e, "handle_seconds"), "unload"):
		var n := business.ep_put(ep, res, 1)
		business.carry_take(e, res, n)
		on_unit.call(n)

# --- miner ---
func _miner(delta: float) -> void:
	var res := str(e["assignment"].get("resource", "limestone"))
	var cap := int(business.stat(e, "carry"))
	var carried := business.carry_total(e)
	if carried == 0:
		mode = "load"
	elif carried >= cap:
		mode = "deliver"
	if mode == "deliver":
		_deliver_to({"type": "storage"}, delta, func(n): business.note_mined(e, n))
		return
	if _collect_pieces(res, delta):
		return
	var dep: String = game.nearest_deposit(res, global_position)
	if dep == "":
		if carried > 0:
			mode = "deliver"
		else:
			_wait(delta, "Waiting for %s to regrow" % res.replace("_", " "))
		return
	var ep := {"type": "deposit_site", "id": dep}
	if game.is_formation(dep):
		# Stay on one exposed column until it is gone, so the miner keeps working one face.
		if mine_dep != dep or mine_col < 0 or game.prog.column_units(dep, mine_col) <= 0 or not game.prog.column_exposed(dep, mine_col):
			mine_dep = dep
			mine_col = game.formation_column(dep, global_position)
		if mine_col < 0:
			_wait(delta, "Waiting: no exposed %s face" % res.replace("_", " "))
			return
		ep["col"] = mine_col
	var r := goto_workplace(ep, delta)
	if r == MOVING:
		e["task"] = "Walking to " + res.replace("_", " ") + " deposit"
	elif r == ARRIVED:
		e["task"] = "Mining " + res.replace("_", " ")
		if _act(delta, business.stat(e, "strike_interval"), "strike"):
			game.worker_strike(dep, int(business.stat(e, "hits")), int(business.stat(e, "yield")), self)

# --- hauler ---
func _hauler(delta: float) -> void:
	var src: Dictionary = e["assignment"].get("src", {})
	var dst: Dictionary = e["assignment"].get("dst", {})
	var res := business.route_resource(src, dst)
	if res == "" or not business.ep_valid(src) or not business.ep_valid(dst):
		e["warning"] = "Route needs a valid source and destination"
		_wait(delta, "No valid route")
		return
	if str(e["warning"]).begins_with("Route needs"):
		e["warning"] = ""
	var cap := int(business.stat(e, "carry"))
	var carried := business.carry_total(e)
	if carried == 0:
		mode = "load"
	elif carried >= cap:
		mode = "deliver"
	if mode == "deliver":
		if not e["carry"].has(res):
			# Leftovers from a previous route go back to the storage crate.
			_deliver_to({"type": "storage"}, delta, func(_n): pass)
		else:
			_deliver_to(dst, delta, func(n): business.note_hauled(e, n))
		return
	if str(src["type"]) == "deposit":
		if _collect_pieces(res, delta):
			return
		if carried > 0:
			mode = "deliver"
		else:
			_wait(delta, "Waiting for loose " + res.replace("_", " "))
		return
	var r := goto_workplace(src, delta)
	if r == MOVING:
		e["task"] = "Walking to " + business.describe_ep(src)
	if r != ARRIVED:
		return
	if business.ep_available(src, res) <= 0:
		if carried > 0:
			mode = "deliver"
		else:
			phase = ""
			e["task"] = "Waiting for %s at %s" % [res.replace("_", " "), business.describe_ep(src)]
		return
	e["task"] = "Loading " + res.replace("_", " ")
	if _act(delta, business.stat(e, "handle_seconds"), "load"):
		business.carry_add(e, res, business.ep_take(src, res, 1))

# --- machine operator ---
func _operator(delta: float) -> void:
	var index := int(e["assignment"].get("crusher", -1))
	var ep := {"type": "crusher", "index": index}
	if not business.ep_valid(ep):
		e["warning"] = "Assigned crusher unavailable"
		_wait(delta, "No machine")
		return
	if str(e["warning"]).begins_with("Assigned crusher"):
		e["warning"] = ""
	var r := goto_workplace(ep, delta)
	if r == MOVING:
		e["task"] = "Walking to crusher #%d" % (index + 1)
	if r != ARRIVED:
		return
	var c: Dictionary = game.state.crushers[index]
	var limit: int = game.state.input_limit(index)
	var outlet: int = business.crusher_outputs[index] if index < business.crusher_outputs.size() else -1
	if int(c["output"]) > 0 and outlet >= 0 and business.ep_space({"type": "output", "index": outlet}, "crushed_stone") > 0 and phase in ["", "collect"]:
		e["task"] = "Collecting crushed stone"
		if _act(delta, 1.2 / business.work_multiplier(e), "collect"):
			business.operator_collect(e, index)
		return
	if not bool(c["running"]) and int(c.get("hopper", 0)) > 0 and int(c["input"]) < limit and phase in ["", "load"]:
		e["task"] = "Loading crusher"
		if _act(delta, business.stat(e, "load_seconds"), "load"):
			business.record_units(e, business.hopper_to_input(index))
		return
	if not bool(c["running"]) and int(c["input"]) > 0:
		if business.crusher_output_full(index):
			e["task"] = "Waiting: crusher output full"
			phase = ""
			return
		e["task"] = "Starting crusher"
		if _act(delta, business.stat(e, "downtime"), "start"):
			business.operator_start(e, index)
		return
	phase = ""
	_face(QuarryBusiness.v3(c["position"]))
	if bool(c["running"]):
		anim = "monitor"
		e["task"] = "Monitoring crusher (%.0fs)" % float(c["remaining"])
	elif int(c["output"]) > 0 and outlet < 0:
		e["task"] = "Output waiting for collection"
	else:
		e["task"] = "Waiting for limestone in hopper"

# --- sales clerk ---
func _clerk(delta: float) -> void:
	var ep := {"type": "sell"}
	var r := goto_workplace(ep, delta)
	if r == MOVING:
		e["task"] = "Walking to selling station"
	if r != ARRIVED:
		return
	var any := false
	for res in business.authorized:
		if business.authorized[res] and business.stock(res) > 0:
			any = true
	if not any:
		phase = ""
		anim = "paperwork"
		e["task"] = "No authorized stock to sell"
		return
	e["task"] = "Serving a customer"
	var done := _act(delta, business.stat(e, "sell_interval"), "sell")
	if not done and anim == "work":
		# paperwork while the customer waits; the hand-over plays in the last 1.2 s, ending on the sale
		if timer > 1.2:
			anim = "paperwork"
		else:
			anim_phase = clampf(1.0 - timer / 1.2, 0.0, 1.0)
	if done:
		var sale := business.clerk_sell(e)
		if int(sale["units"]) > 0:
			e["task"] = "Sold %d %s (+$%d)" % [sale["units"], str(sale["resource"]).replace("_", " "), sale["money"]]
			game.worker_sale_feedback(self)
