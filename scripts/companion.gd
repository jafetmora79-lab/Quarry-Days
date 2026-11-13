extends Node3D
class_name QuarryCompanion
## The dinosaur companion (Phase 7.7, rebuilt in Phase 8.6): a stylised Ankylosaurus. Low and wide, with rows of armour plates
## down its back, spikes along its flanks, a horned head with a beak, four short jointed legs and a long tail ending in a heavy
## club. It follows the player, sleeps on its bed at night and, once it has grown, breaks rock and clears rubble on command
## (key T): it walks up, turns its flank to the target, winds the tail back, and swings it so the club really meets the rock;
## the damage and the dust land at the moment of contact. It has no collider, so it never blocks anyone, and everything it
## breaks goes through the same mining rules as every tool (hardness, exposure, locked levels).

var game
var stage := "hatchling"
var speed := 3.2
var model: Node3D
var body: Node3D            ## shell, plates and belly (rolls and bobs as one)
var head: Node3D
var neck: Node3D
var tail: Node3D            ## base of the tail; the two joints after it follow with a lag
var tail_mid: Node3D
var tail_tip: Node3D
var club: Node3D
var club_tip: Node3D        ## where the club meets the rock
var plates: Node3D
var eyes: Array = []
var hips: Array = []        ## [front-left, front-right, rear-left, rear-right]
var feet: Array = []
var phase := 0.0
var idle_time := 0.0
var resting := false
var _last_player := Vector3.ZERO
var _t := 0.0
var walk_w := 0.0           ## 0..1 how much it is walking (blends the gaits)
var rest_w := 0.0           ## 0..1 how much it is lying down
## smash command
var smash_kind := ""
var smash_col := -1
var smash_left := 0
var debris: Node3D          ## weeds or a rubble heap it was sent to clear
## tail strike: "", "windup", "hold", "strike", "recover"
var strike := ""
var strike_t := 0.0
var strike_hit_done := false
var tail_yaw := 0.0         ## the tail's yaw (about its base), + toward the target side
var hits := 0               ## contacts made (tests)
var _stand: Dictionary = {}
var _stand_key := ""
var last_contact := Vector3.ZERO

const WINDUP := 0.5
const HOLD := 0.12
const STRIKE := 0.16
const RECOVER := 0.32
const WINDUP_YAW := -0.95
const CONTACT_YAW := 1.15
const STRIKE_END_YAW := 1.45
const PIVOT_LOCAL := Vector3(0, 0.8, 0.85)       ## tail base in model space
const TAIL_REACH := 2.0                           ## base to club centre at full stretch, adult scale

var _skin := Color(0.46, 0.40, 0.28)
var _plate_col := Color(0.30, 0.26, 0.19)
var _belly_col := Color(0.76, 0.70, 0.50)
var _bone := Color(0.86, 0.82, 0.68)

func setup(g, stage_name: String) -> void:
	game = g
	name = "Companion"
	_build()
	set_stage(stage_name)

# ------------------------------------------------------------------ model

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(color)
	m.position = pos
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, color, rot)

func _spike(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var p := PrismMesh.new()
	p.size = size
	return _mesh(parent, p, pos, color, rot)

func _build() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	body = Node3D.new()
	body.name = "Body"
	model.add_child(body)
	# belly and shell: a flat, wide barrel
	_box(body, Vector3(1.0, 0.3, 1.75), Vector3(0, 0.55, 0.0), _belly_col)
	_box(body, Vector3(1.24, 0.36, 1.8), Vector3(0, 0.86, 0.0), _skin)
	_box(body, Vector3(1.12, 0.1, 1.7), Vector3(0, 1.07, 0.0), _plate_col)             # armoured crown
	# osteoderms: three columns of plates down the back, the middle ones tallest
	plates = Node3D.new()
	plates.name = "Plates"
	body.add_child(plates)
	for row in range(6):
		var z := -0.72 + float(row) * 0.29
		for col in range(-1, 2):
			var tall := 0.2 if col == 0 else 0.12
			_spike(plates, Vector3(0.28, tall, 0.26), Vector3(float(col) * 0.36, 1.12 + tall * 0.5, z), _plate_col.lightened(0.08 if col == 0 else 0.0), Vector3(0, 0, 0.12 * float(col)))
	# flank spikes, bigger at the shoulder
	for side in [-1.0, 1.0]:
		for k in range(6):
			var big := 1.0 + (0.5 if k < 2 else 0.0)
			_spike(body, Vector3(0.16 * big, 0.26 * big, 0.14 * big), Vector3(side * 0.66, 0.9, -0.7 + float(k) * 0.3), _bone, Vector3(0, 0, -side * deg_to_rad(80)))
	# neck and head
	neck = Node3D.new()
	neck.position = Vector3(0, 0.84, -0.9)
	model.add_child(neck)
	_box(neck, Vector3(0.44, 0.34, 0.4), Vector3(0, 0, -0.1), _skin)
	head = Node3D.new()
	head.position = Vector3(0, -0.02, -0.34)
	neck.add_child(head)
	_box(head, Vector3(0.52, 0.3, 0.5), Vector3(0, 0, -0.14), _skin)                      # skull
	_box(head, Vector3(0.34, 0.16, 0.22), Vector3(0, -0.07, -0.46), _skin.lightened(0.1)) # snout
	_box(head, Vector3(0.22, 0.07, 0.14), Vector3(0, -0.03, -0.62), _bone)                # beak
	_box(head, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.17, -0.12), _plate_col)              # brow armour
	for side in [-1.0, 1.0]:
		_spike(head, Vector3(0.16, 0.24, 0.2), Vector3(side * 0.3, 0.1, 0.06), _bone, Vector3(deg_to_rad(90), 0, -side * deg_to_rad(35)))   # cheek horns
		var eye := _box(head, Vector3(0.09, 0.09, 0.07), Vector3(side * 0.2, 0.07, -0.34), Color(0.06, 0.05, 0.04))
		_box(head, Vector3(0.03, 0.03, 0.02), Vector3(side * 0.2 + side * 0.012, 0.09, -0.375), Color(0.95, 0.95, 0.9))
		eyes.append(eye)
		_box(head, Vector3(0.04, 0.04, 0.03), Vector3(side * 0.07, 0.02, -0.7), Color(0.1, 0.08, 0.07))   # nostril
	# four legs: hip pivot, thigh, shin and a three-toed foot
	for pos in [Vector3(-0.5, 0.62, -0.6), Vector3(0.5, 0.62, -0.6), Vector3(-0.5, 0.62, 0.58), Vector3(0.5, 0.62, 0.58)]:
		var hip := Node3D.new()
		hip.position = pos
		model.add_child(hip)
		_box(hip, Vector3(0.3, 0.32, 0.32), Vector3(0, -0.14, 0), _skin)
		var shin := Node3D.new()
		shin.position = Vector3(0, -0.3, 0)
		hip.add_child(shin)
		_box(shin, Vector3(0.24, 0.3, 0.26), Vector3(0, -0.12, 0.01), _skin.darkened(0.06))
		var foot := Node3D.new()
		foot.position = Vector3(0, -0.28, -0.02)
		shin.add_child(foot)
		_box(foot, Vector3(0.32, 0.09, 0.3), Vector3(0, -0.02, -0.04), _skin.darkened(0.12))
		for tx in [-0.1, 0.0, 0.1]:
			_box(foot, Vector3(0.07, 0.07, 0.1), Vector3(tx, -0.03, -0.22), _bone)
		hips.append(hip)
		feet.append(foot)
	# the tail: three jointed pieces, then the club
	tail = Node3D.new()
	tail.position = PIVOT_LOCAL
	model.add_child(tail)
	_box(tail, Vector3(0.52, 0.34, 0.72), Vector3(0, 0, 0.34), _skin)
	tail_mid = Node3D.new()
	tail_mid.position = Vector3(0, 0, 0.7)
	tail.add_child(tail_mid)
	_box(tail_mid, Vector3(0.38, 0.27, 0.72), Vector3(0, 0, 0.34), _skin)
	_spike(tail_mid, Vector3(0.16, 0.14, 0.4), Vector3(0, 0.18, 0.3), _plate_col)
	tail_tip = Node3D.new()
	tail_tip.position = Vector3(0, 0, 0.7)
	tail_mid.add_child(tail_tip)
	_box(tail_tip, Vector3(0.24, 0.2, 0.5), Vector3(0, 0, 0.22), _skin)
	club = Node3D.new()
	club.position = Vector3(0, 0, 0.68)
	tail_tip.add_child(club)
	var ball := SphereMesh.new()
	ball.radius = 0.3
	ball.height = 0.6
	var knob := _mesh(club, ball, Vector3.ZERO, _bone)
	knob.scale = Vector3(1.35, 0.95, 1.15)
	for side in [-1.0, 1.0]:
		_spike(club, Vector3(0.2, 0.26, 0.22), Vector3(side * 0.4, 0, 0.0), _plate_col, Vector3(0, 0, -side * deg_to_rad(90)))
	club_tip = Node3D.new()
	club_tip.position = Vector3(0, 0, 0.12)
	club.add_child(club_tip)

func set_stage(s: String) -> void:
	stage = s
	var sd: Dictionary = game.prog.companion_cfg().get("stages", {}).get(s, {})
	speed = float(sd.get("speed", 3.2))
	var target := float(sd.get("scale", 0.35))
	if scale.x > 0.01 and absf(scale.x - target) > 0.05 and absf(scale.x - 1.0) > 0.001:
		var tw := create_tween()                    # growing is visible: a quick pop to the new size
		tw.tween_property(self, "scale", Vector3.ONE * target * 1.08, 0.18)
		tw.tween_property(self, "scale", Vector3.ONE * target, 0.2)
	else:
		scale = Vector3.ONE * target
	# proportions: the young are all head, eyes and little armour
	var head_k: float = {"hatchling": 1.5, "juvenile": 1.2, "adult": 1.0}.get(s, 1.0)
	head.scale = Vector3.ONE * head_k
	plates.scale = Vector3(1.0, {"hatchling": 0.5, "juvenile": 0.8, "adult": 1.0}.get(s, 1.0), 1.0)
	club.scale = Vector3.ONE * {"hatchling": 0.55, "juvenile": 0.8, "adult": 1.0}.get(s, 1.0)
	for e in eyes:
		(e as Node3D).scale = Vector3.ONE * ({"hatchling": 1.5, "juvenile": 1.2, "adult": 1.0}.get(s, 1.0))

# ------------------------------------------------------------------ helpers

func ground_y(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.5, 0), p + Vector3(0, -8.0, 0), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else p.y

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.05:
		return
	var target := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(delta * 8.0, 0.0, 1.0))

func _walk_to(goal: Vector3, delta: float, stop: float) -> bool:
	var d := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if d.length() <= stop:
		return true
	var step := minf(speed * delta, d.length() - stop)
	var nx := global_position + d.normalized() * step
	nx.y = lerpf(global_position.y, ground_y(nx), clampf(delta * 10.0, 0.0, 1.0))
	global_position = nx
	_face(d, delta)
	phase += delta * speed * 2.6 / maxf(0.5, scale.x * 1.4)
	return false

## Steady-state lag of the tail joints behind the base yaw (the same numbers the animation uses while striking).
static func joint_lag(base_yaw: float) -> Vector2:
	var mid := -base_yaw * 0.22
	return Vector2(mid, -mid * 0.35 - base_yaw * 0.12)

## Where the club's striking point sits in model space (before scale) when the tail base is turned by `yaw`.
static func club_local(yaw: float) -> Vector3:
	var lag := joint_lag(yaw)
	var b := Basis(Vector3.UP, yaw)
	var m := Basis(Vector3.UP, lag.x)
	var t := Basis(Vector3.UP, lag.y)
	var p := Vector3(0, 0, 0.7) + m * (Vector3(0, 0, 0.7) + t * (Vector3(0, 0, 0.68) + Vector3(0, 0, 0.12)))
	return PIVOT_LOCAL + b * p

## World position of the club's striking point right now.
func club_pos() -> Vector3:
	return club_tip.global_position

## The tail's reach in the world at this size.
func reach() -> float:
	return TAIL_REACH * scale.x

# ------------------------------------------------------------------ commands

func busy() -> bool:
	return smash_left > 0 or (debris != null and is_instance_valid(debris))

func command_debris(node: Node3D) -> String:
	if not game.prog.companion_stage_def(game.prog.current_day).get("smash", false):
		return "%s is still too small to clear rubble." % str(game.prog.companion().get("name", "Your dinosaur"))
	cancel_smash()
	debris = node
	return ""

func command_smash(kind: String, col: int) -> String:
	if not game.prog.companion_stage_def(game.prog.current_day).get("smash", false):
		return "%s is still too small to smash rock." % str(game.prog.companion().get("name", "Your dinosaur"))
	var res := str(game.state.deposits[kind]["resource"])
	if not game.prog.companion_can_break(res, game.prog.current_day):
		return "%s's tail is not strong enough for %s yet." % [str(game.prog.companion().get("name", "Your dinosaur")), game.prog.display(res)]
	smash_kind = kind
	smash_col = col
	smash_left = int(game.prog.companion_cfg().get("smash_hits", 6))
	strike = ""
	return ""

func cancel_smash() -> void:
	_stand_key = ""
	debris = null
	smash_left = 0
	smash_col = -1
	smash_kind = ""
	strike = ""

## Where the rock face is that the tail will hit, in the world: the centre of the column (or debris) and the outward half-size.
func _target_face() -> Dictionary:
	if debris != null and is_instance_valid(debris):
		return {"centre": debris.global_position + Vector3(0, 0.5, 0), "half": 0.5}
	if smash_col >= 0 and smash_kind != "":
		var cell := float(game.prog.fdef(smash_kind).get("cell", 2.0))
		var node: QuarryFormation = game.formation_nodes[smash_kind]
		var top: Vector3 = node.column_top(smash_col)
		return {"centre": Vector3(top.x, minf(top.y, game.prog.column_pos(smash_kind, smash_col).y + 0.7 * scale.x + 0.4), top.z), "half": cell * 0.5}
	return {}

## Body position and heading that put the club's contact point on the face: the target on the dinosaur's right flank (local +x),
## the tail base far enough back that the swing, at its contact angle, ends on the rock.
func _strike_stand(face: Dictionary) -> Dictionary:
	var centre: Vector3 = face["centre"]
	var to := Vector3(centre.x - global_position.x, 0, centre.z - global_position.z)
	if to.length() < 0.01:
		to = Vector3(1, 0, 0)
	var r := to.normalized()
	var theta := atan2(-r.z, r.x)                    # local +x points at the target
	var basis := Basis(Vector3.UP, theta)
	var s := scale.x
	var contact_local := club_local(CONTACT_YAW) * s
	var face_pt := centre - r * float(face["half"])
	var pos := face_pt - basis * contact_local
	return {"pos": Vector3(pos.x, global_position.y, pos.z), "yaw": theta}

# ------------------------------------------------------------------ behaviour

func step(delta: float, player_pos: Vector3, rest_goal := Vector3.INF) -> void:
	_t += delta
	var moving := false
	var working := false
	if debris != null and (not is_instance_valid(debris) or game.prog.cleanup["cleared"].get(str(debris.get_meta("debris_id", "")), false)):
		debris = null
		strike = ""
	if debris == null and smash_left > 0 and (smash_col < 0 or game.prog.column_units(smash_kind, smash_col) <= 0):
		smash_col = game.prog.nearest_column(smash_kind, global_position, true, float(game.prog.companion_cfg().get("reach", 14.0)), "companion")
		if smash_col < 0:
			cancel_smash()
	if busy():
		var face := _target_face()
		if not face.is_empty():
			var stand_key := "%s|%d|%d" % [smash_kind, smash_col, debris.get_instance_id() if debris != null and is_instance_valid(debris) else 0]
			if stand_key != _stand_key:
				_stand = _strike_stand(face)               # chosen once per target, from the side it is approached from
				_stand_key = stand_key
			var stand: Dictionary = _stand
			var goal: Vector3 = stand["pos"]
			var dist := Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
			if dist > 0.25 and strike == "":
				moving = not _walk_to(goal, delta, 0.15)
			else:
				# in place: turn the flank to the target, then wind up and strike
				working = true
				var k_in := clampf(delta * 8.0, 0.0, 1.0)                       # settle exactly onto the chosen spot
				global_position.x = lerpf(global_position.x, goal.x, k_in)
				global_position.z = lerpf(global_position.z, goal.z, k_in)
				rotation.y = lerp_angle(rotation.y, float(stand["yaw"]), clampf(delta * 7.0, 0.0, 1.0))
				if absf(angle_difference(rotation.y, float(stand["yaw"]))) < 0.12 or strike != "":
					_strike_step(delta)
	elif strike != "":
		working = true                         # the last swing finishes before it does anything else
		_strike_step(delta)
	elif rest_goal != Vector3.INF:
		var there := _walk_to(rest_goal, delta, 0.5)
		moving = not there
		resting = there
		if there:
			rotation.y = lerp_angle(rotation.y, 0.0, clampf(delta * 3.0, 0.0, 1.0))
	else:
		var dist2 := Vector2(global_position.x - player_pos.x, global_position.z - player_pos.z).length()
		var moved := (player_pos - _last_player).length()
		_last_player = player_pos
		idle_time = idle_time + delta if moved < 0.01 * maxf(delta * 60.0, 1.0) else 0.0
		resting = idle_time > 6.0 and dist2 < 4.5
		if dist2 > 40.0:
			global_position = player_pos + Vector3(2.0, 0.0, 2.0)
			global_position.y = ground_y(global_position)
		elif dist2 > 3.2 and not resting:
			moving = true
			_walk_to(player_pos, delta, 2.6)
		else:
			_face(player_pos - global_position, delta)
	if busy():
		resting = false
	_animate(delta, moving, working)

## The tail strike: wind back (away from the target), hold a beat, swing through, contact, recover.
func _strike_step(delta: float) -> void:
	if strike == "":
		strike = "windup"
		strike_t = 0.0
		strike_hit_done = false
	strike_t += delta
	match strike:
		"windup":
			var k := smoothstep(0.0, 1.0, clampf(strike_t / WINDUP, 0.0, 1.0))
			tail_yaw = lerpf(0.0, WINDUP_YAW, k)
			if strike_t >= WINDUP:
				strike = "hold"
				strike_t = 0.0
		"hold":
			tail_yaw = WINDUP_YAW + sin(_t * 40.0) * 0.015
			if strike_t >= HOLD:
				strike = "strike"
				strike_t = 0.0
		"strike":
			var k2 := clampf(strike_t / STRIKE, 0.0, 1.0)
			tail_yaw = lerpf(WINDUP_YAW, STRIKE_END_YAW, k2 * k2 * (3.0 - 2.0 * k2) * 0.5 + k2 * 0.5)
			if not strike_hit_done and tail_yaw >= CONTACT_YAW:
				strike_hit_done = true
				tail_yaw = CONTACT_YAW                 # the club is exactly at the rock at the moment of contact
				_apply_tail_pose()
				_contact()
			if strike_t >= STRIKE:
				strike = "recover"
				strike_t = 0.0
		"recover":
			var k3 := smoothstep(0.0, 1.0, clampf(strike_t / RECOVER, 0.0, 1.0))
			tail_yaw = lerpf(STRIKE_END_YAW, 0.0, k3)
			if strike_t >= RECOVER:
				strike = ""
				strike_t = 0.0
				if smash_left <= 0 and debris == null:
					cancel_smash()

## The club has reached the rock: damage and dust happen here, at the club's position.
func _contact() -> void:
	hits += 1
	last_contact = club_pos()
	var dmg: float = float(game.prog.companion_stage_def(game.prog.current_day).get("damage", 0.0))
	if debris != null and is_instance_valid(debris):
		game.hit_debris(debris, dmg, last_contact, true)
		return
	var kind := smash_kind
	var col := smash_col
	smash_left -= 1
	game.companion_strike(kind, col, dmg, self)
	if game.prog.column_units(kind, col) <= 0:
		smash_col = -1

# ------------------------------------------------------------------ animation

## During a blow the joints follow the base exactly: the contact point is worked out from these numbers.
func _apply_tail_pose() -> void:
	tail.rotation.y = tail_yaw
	var lag := joint_lag(tail_yaw)
	tail_mid.rotation.y = lag.x
	tail_tip.rotation.y = lag.y

func _animate(delta: float, moving: bool, working: bool) -> void:
	walk_w = move_toward(walk_w, 1.0 if moving else 0.0, delta * 5.0)
	rest_w = move_toward(rest_w, 1.0 if resting else 0.0, delta * 2.0)
	var s_k := minf(1.0, delta * 10.0)
	# legs: diagonal pairs (front-left with rear-right, front-right with rear-left), feet lift while swinging forward
	for i in range(hips.size()):
		var ph := phase + (0.0 if i == 0 or i == 3 else PI)
		var swing := sin(ph) * 0.55 * walk_w
		var lift := maxf(0.0, cos(ph)) * 0.1 * walk_w
		var fold := 0.85 * rest_w
		var hip: Node3D = hips[i]
		hip.rotation.x = lerpf(hip.rotation.x, swing + fold * (0.7 if i < 2 else -0.7), s_k)
		hip.position.y = lerpf(hip.position.y, 0.62 - 0.26 * rest_w + lift * 0.4, s_k)
		var foot: Node3D = feet[i]
		foot.rotation.x = lerpf(foot.rotation.x, -swing * 0.5 + lift * 2.2, s_k)
	# body: bob and roll while walking, breathing at rest, lower when lying down
	var breathe := sin(_t * (1.4 if resting else 1.9)) * 0.012
	body.position.y = lerpf(body.position.y, absf(sin(phase)) * 0.035 * walk_w - 0.26 * rest_w, s_k)
	body.rotation.z = lerpf(body.rotation.z, sin(phase) * 0.035 * walk_w, s_k)
	body.scale.y = 1.0 + breathe
	# working: the body leans into the swing
	var lean := 0.0
	if working:
		lean = clampf(tail_yaw, -1.0, 1.4) * -0.05
	body.rotation.x = lerpf(body.rotation.x, lean, s_k)
	# neck and head: bob while walking, look around while idle, drop and close the eyes when asleep, watch the target when working
	var look := sin(_t * 0.5) * 0.25 * (1.0 - walk_w) * (1.0 - rest_w)
	neck.rotation.y = lerpf(neck.rotation.y, (-sin(phase) * 0.06 * walk_w) + look * 0.5 + (0.5 if working else 0.0), s_k)
	head.rotation.y = lerpf(head.rotation.y, look * 0.5, s_k)
	head.rotation.x = lerpf(head.rotation.x, sin(phase * 2.0) * 0.04 * walk_w + 0.35 * rest_w, s_k)
	for e in eyes:
		(e as Node3D).scale.y = lerpf((e as Node3D).scale.y, 0.15 if rest_w > 0.5 else 1.0 * head.scale.x, minf(1.0, delta * 8.0))
	# tail: sway while walking and idling; the strike drives it by hand. The joints behind the base follow with a lag.
	var sway := sin(phase * 0.5) * 0.2 * walk_w + sin(_t * 0.9) * 0.1 * (1.0 - walk_w) * (1.0 - rest_w)
	var base_yaw := tail_yaw if strike != "" or absf(tail_yaw) > 0.02 else sway
	if strike == "" and absf(tail_yaw) <= 0.02:
		tail_yaw = 0.0
	if strike != "":
		_apply_tail_pose()
	else:
		tail.rotation.y = lerpf(tail.rotation.y, base_yaw, s_k)
		tail_mid.rotation.y = lerpf(tail_mid.rotation.y, -tail.rotation.y * 0.22 + sin(_t * 1.3) * 0.04, minf(1.0, delta * 14.0))
		tail_tip.rotation.y = lerpf(tail_tip.rotation.y, -tail_mid.rotation.y * 0.35 - tail.rotation.y * 0.12, minf(1.0, delta * 12.0))
	tail.rotation.x = lerpf(tail.rotation.x, 0.0 + (0.25 if rest_w > 0.5 else 0.0), s_k)
