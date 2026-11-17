extends Node3D
class_name QuarryWildlife
## A little peaceful wildlife for atmosphere: two deer and four rabbits that now and then appear at the forest edges, graze, look about, wander a few metres, and slip away
## when the player or a machine comes near. Not a simulation: no hunger, breeding, combat, inventory or pathfinding. Each animal is a small state machine moving on the flat
## ground in the forest strips (never on the yard, a road, the tunnel approach, the quarry or the east extension: Landscape.forest_blocked), animated by rotating the model's
## named hinge nodes (WorldModels.animal). At most two deer and four rabbits exist; an animal is only placed when the player is not near that spot, so nothing pops up in front
## of you, and it keeps away from machines (it flees from any vehicle that is moving or close). Nothing here is saved or touches the economy.

var game
var aura_battle: Node3D
var animals: Array = []
var t := 0.0
var enabled := true
const DEER_FLEE := 17.0
const RABBIT_FLEE := 7.0
const MACHINE_FLEE := 13.0

class Beast:
	var kind := "deer"
	var root: Node3D
	var parts := {}
	var state := "away"
	var timer := 30.0
	var life := 0.0
	var anchor := Vector3.ZERO
	var heading := Vector3(0, 0, -1)
	var speed := 0.0
	var phase := 0.0
	var head_pitch := 0.0
	var head_yaw := 0.0
	var head_goal_pitch := 0.0
	var head_goal_yaw := 0.0
	var ear_t := 2.0
	var hop_t := -1.0
	var hop_from := Vector3.ZERO
	var hop_to := Vector3.ZERO
	var alert := 0.0
	var spooked := false

func setup(g) -> void:
	game = g
	name = "Wildlife"
	game.add_child(self)
	if not game.blueprint or game.landscape == null:
		enabled = false
		return
	aura_battle = preload("res://scripts/forest_aura_battle.gd").new()
	add_child(aura_battle)
	aura_battle.setup(game)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var picked: Array = []
	var want := [["deer", 62.0], ["deer", 62.0], ["rabbit", 48.0], ["rabbit", 48.0], ["rabbit", 48.0], ["rabbit", 48.0]]
	for w in want:
		var spot := _pick_anchor(rng, picked, float(w[1]))
		picked.append(spot)
		var b := Beast.new()
		b.kind = str(w[0])
		var made: Dictionary = WorldModels.animal(b.kind)
		if made.is_empty():
			continue
		b.root = made["root"]
		b.parts = made["parts"]
		b.root.visible = false
		add_child(b.root)
		b.anchor = spot
		b.timer = rng.randf_range(8.0, 45.0) + float(animals.size()) * 6.0
		animals.append(b)

## A spot in the forest strips, clear of everything, at least `from_yard` metres from the working yard and away from the other animals' spots.
func _pick_anchor(rng: RandomNumberGenerator, taken: Array, from_yard: float) -> Vector3:
	var ls = game.landscape
	var zones := [[-185.0, -100.0, -140.0, 60.0], [140.0, -100.0, 185.0, 60.0], [-110.0, 50.0, 110.0, 72.0]]
	for tries in 2500:
		var z: Array = zones[rng.randi() % zones.size()]
		var p := Vector2(rng.randf_range(float(z[0]), float(z[2])), rng.randf_range(float(z[1]), float(z[3])))
		if ls.forest_blocked(p) or p.distance_to(Vector2(0, 12)) < from_yard or _tree_near(p, 4.5 if from_yard > 55.0 else 3.0):
			continue                                    # an open patch of ground, so the animal can be seen and has room
		var ok := true
		for o in taken:
			if Vector2((o as Vector3).x, (o as Vector3).z).distance_to(p) < 35.0:
				ok = false
		if ok:
			return Vector3(p.x, 0.0, p.y)
	return Vector3(150.0, 0.0, -30.0)

func _tree_near(p: Vector2, r: float) -> bool:
	var ls = game.landscape
	for arr in [ls.tree_positions, ls.young_positions]:
		for q in arr:
			if absf(q.x - p.x) < r and absf(q.z - p.y) < r and Vector2(q.x, q.z).distance_to(p) < r:
				return true
	return false

func _process(delta: float) -> void:
	if enabled:
		step(minf(delta, 0.1))

## One tick of every animal (also called by tests with a fixed delta).
func step(delta: float) -> void:
	t += delta
	var threats := _threats()
	for b in animals:
		_tick(b, delta, threats)

## Positions an animal should keep away from: the player, and every machine that is moving or close.
func _threats() -> Array:
	var out := []
	if game.player != null and is_instance_valid(game.player):
		out.append([game.player.global_position, 1.0])
	for v in game.vehicle_nodes.values():
		if is_instance_valid(v):
			out.append([(v as Node3D).global_position, 1.0 if absf(float(v.speed)) > 0.4 or v.driven else 0.55])
	return out

func _nearest_threat(b: Beast, threats: Array) -> Array:
	var best := 1e9
	var at := Vector3.ZERO
	var scale := 1.0
	for th in threats:
		var d: float = Vector2(b.root.global_position.x - th[0].x, b.root.global_position.z - th[0].z).length() / float(th[1])
		if d < best:
			best = d
			at = th[0]
			scale = float(th[1])
	return [best, at]

func _tick(b: Beast, delta: float, threats: Array) -> void:
	var pos := b.root.global_position
	if b.state == "away":
		b.timer -= delta
		if b.timer <= 0.0:
			var th := _nearest_threat_to(b.anchor, threats)
			if th > 40.0:
				_appear(b)
			else:
				b.timer = 15.0                           # someone is working near the spot: try again later
		return
	var near := _nearest_threat(b, threats)
	var limit := DEER_FLEE if b.kind == "deer" else RABBIT_FLEE
	if b.state != "flee" and b.state != "leave" and float(near[0]) < limit:
		b.state = "flee"
		b.timer = 3.4 if b.kind == "deer" else 2.4
		var away := Vector3(pos.x - near[1].x, 0.0, pos.z - near[1].z)
		b.heading = (away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)).rotated(Vector3.UP, randf_range(-0.4, 0.4))
		b.spooked = true
	b.life += delta
	if b.life > (110.0 if b.kind == "deer" else 90.0) and b.state in ["idle", "graze", "look", "walk", "hop"]:
		b.state = "leave"
		b.timer = 7.0
		var out := Vector3(pos.x, 0.0, pos.z - 12.0).normalized()
		b.heading = Vector3(pos.x, 0.0, pos.z - 12.0).normalized()
	if b.kind == "deer":
		_deer(b, delta)
	else:
		_rabbit(b, delta)

func _nearest_threat_to(p: Vector3, threats: Array) -> float:
	var best := 1e9
	for th in threats:
		best = minf(best, Vector2(p.x - th[0].x, p.z - th[0].z).length())
	return best

func _appear(b: Beast) -> void:
	b.root.global_position = b.anchor
	b.root.visible = true
	b.state = "idle"
	b.timer = randf_range(2.0, 6.0)
	b.life = 0.0
	b.spooked = false
	b.head_pitch = 0.0
	_face(b, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))

func _hide(b: Beast) -> void:
	b.root.visible = false
	b.state = "away"
	b.timer = randf_range(70.0, 210.0) if b.kind == "deer" else randf_range(50.0, 140.0)
	b.speed = 0.0

func _face(b: Beast, h: Vector3) -> void:
	if h.length() < 0.01:
		return
	b.heading = h.normalized()
	b.root.rotation.y = atan2(-b.heading.x, -b.heading.z)           # the models face -Z

## Moves along the heading; turns around instead of stepping onto ground that is not the animal's (yard, road, quarry ...).
func _move(b: Beast, dist: float) -> void:
	var p := b.root.global_position
	var q := p + b.heading * dist
	var ls = game.landscape
	var off := Vector2(q.x - b.anchor.x, q.z - b.anchor.z).length()
	if b.state in ["walk", "hop"] and off > (9.0 if b.kind == "deer" else 5.0):
		_face(b, Vector3(b.anchor.x - p.x, 0, b.anchor.z - p.z))      # back toward its patch
		q = p + b.heading * dist
	if ls.forest_blocked(Vector2(q.x, q.z)) or absf(q.x) > 205.0 or q.z < -130.0 or q.z > 78.0:
		var tries := 0
		while tries < 8:
			tries += 1
			var h2 := b.heading.rotated(Vector3.UP, 0.8 * float(tries) * (1.0 if tries % 2 == 0 else -1.0))
			var q2 := p + h2 * dist
			if not ls.forest_blocked(Vector2(q2.x, q2.z)) and absf(q2.x) <= 205.0 and q2.z > -130.0 and q2.z < 78.0:
				_face(b, h2)
				b.root.global_position = q2
				return
		return                                                  # boxed in: stand still
	b.root.global_position = q

func _deer(b: Beast, delta: float) -> void:
	var p: Dictionary = b.parts
	var gait := 0.0
	var amp := 0.0
	var sp := 0.0
	b.timer -= delta
	match b.state:
		"idle":
			b.head_goal_pitch = 0.0
			b.head_goal_yaw = sin(t * 0.4 + b.anchor.x) * 0.25
			if b.timer <= 0.0:
				var r := randf()
				if r < 0.5:
					b.state = "graze"
					b.timer = randf_range(6.0, 14.0)
				elif r < 0.7:
					b.state = "look"
					b.timer = randf_range(2.0, 4.0)
					b.head_goal_yaw = randf_range(-0.8, 0.8)
				elif r < 0.95:
					b.state = "walk"
					b.timer = randf_range(3.0, 8.0)
					_face(b, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
				else:
					b.timer = randf_range(2.0, 5.0)
		"graze":
			var lift := fmod(t + b.anchor.z, 5.0) < 0.9          # now and then the head comes up to listen
			b.head_goal_pitch = 0.0 if lift else -0.95
			b.head_goal_yaw = 0.0
			if b.timer <= 0.0:
				b.state = "idle"
				b.timer = randf_range(2.0, 6.0)
		"look":
			b.head_goal_pitch = 0.05
			if b.timer <= 0.0:
				b.state = "idle"
				b.timer = randf_range(2.0, 5.0)
		"walk":
			sp = 0.9
			gait = 1.0
			amp = 0.45
			b.head_goal_pitch = -0.1 + 0.08 * sin(t * 3.0)
			b.head_goal_yaw = 0.0
			if b.timer <= 0.0:
				b.state = "idle"
				b.timer = randf_range(2.0, 5.0)
		"flee":
			sp = 7.0
			gait = 2.6
			amp = 0.85
			b.head_goal_pitch = 0.1
			b.head_goal_yaw = 0.0
			if b.timer <= 0.0:
				b.state = "leave"
				b.timer = 4.0
		"leave":
			sp = 2.5 if not b.spooked else 5.0
			gait = 1.6 if not b.spooked else 2.2
			amp = 0.6 if not b.spooked else 0.75
			b.head_goal_pitch = -0.05
			if b.timer <= 0.0:
				_hide(b)
				return
	if sp > 0.0:
		_move(b, sp * delta)
		_face(b, b.heading)
	b.phase += delta * gait * 6.0
	b.head_pitch = lerpf(b.head_pitch, b.head_goal_pitch, 1.0 - exp(-4.0 * delta))
	b.head_yaw = lerpf(b.head_yaw, b.head_goal_yaw, 1.0 - exp(-3.0 * delta))
	# animation: legs swing in diagonal pairs, the body bobs, the head follows its goals, breathing, ear and tail flicks
	var ph := b.phase
	(p["LegFL"] as Node3D).rotation.x = sin(ph) * amp
	(p["LegBR"] as Node3D).rotation.x = sin(ph) * amp
	(p["LegFR"] as Node3D).rotation.x = -sin(ph) * amp
	(p["LegBL"] as Node3D).rotation.x = -sin(ph) * amp
	var breath := 1.0 + 0.012 * sin(t * 1.9 + b.anchor.x)
	(p["Body"] as Node3D).scale = Vector3(1.0, breath, 1.0)
	(p["Body"] as Node3D).position.y = (absf(sin(ph)) * 0.05 * amp * 2.0) if gait > 0.0 else 0.0
	(p["Head"] as Node3D).rotation = Vector3(b.head_pitch, b.head_yaw, 0.0)
	(p["Antlers"] as Node3D).rotation = (p["Head"] as Node3D).rotation
	b.ear_t -= delta
	var flick := 0.0
	if b.ear_t < 0.0:
		flick = 1.0
		if b.ear_t < -0.25:
			b.ear_t = randf_range(2.0, 6.0)
	(p["EarL"] as Node3D).rotation = Vector3(b.head_pitch, b.head_yaw, flick * 0.5)
	(p["EarR"] as Node3D).rotation = Vector3(b.head_pitch, b.head_yaw, -flick * 0.2)
	(p["Tail"] as Node3D).rotation.x = (-0.5 if b.state == "flee" else 0.1 * sin(t * 2.2))

func _rabbit(b: Beast, delta: float) -> void:
	var p: Dictionary = b.parts
	b.timer -= delta
	var arc := 0.0
	match b.state:
		"idle":
			b.head_goal_pitch = -0.1 + 0.12 * sin(t * 6.0 + b.anchor.x)          # the nose twitches
			if b.timer <= 0.0:
				if randf() < 0.65:
					b.state = "hop"
					b.hop_t = 0.0
					_face(b, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
					_start_hop(b, 0.7)
					b.timer = randf_range(2.0, 4.0) if randf() < 0.5 else 0.0
				else:
					b.timer = randf_range(1.5, 4.0)
		"hop":
			arc = _hop_step(b, delta, 0.4)
			if b.hop_t < 0.0:
				if b.timer > 0.0:
					b.state = "idle"
				else:
					b.state = "idle"
					b.timer = randf_range(1.5, 4.0)
		"flee":
			if b.hop_t < 0.0:
				_start_hop(b, 1.3)
			arc = _hop_step(b, delta, 0.26)
			if b.timer <= 0.0 and b.hop_t < 0.0:
				b.state = "leave"
				b.timer = 3.0
		"leave":
			if b.hop_t < 0.0:
				_start_hop(b, 0.9)
			arc = _hop_step(b, delta, 0.3)
			if b.timer <= 0.0 and b.hop_t < 0.0:
				_hide(b)
				return
	b.head_pitch = lerpf(b.head_pitch, b.head_goal_pitch, 1.0 - exp(-8.0 * delta))
	var root_y := arc * 0.22
	var pos := b.root.global_position
	b.root.global_position = Vector3(pos.x, root_y, pos.z)
	(p["Head"] as Node3D).rotation.x = b.head_pitch + (-0.3 * arc if arc > 0.0 else 0.0)
	(p["LegB"] as Node3D).rotation.x = -0.9 * arc
	(p["LegF"] as Node3D).rotation.x = 0.7 * arc
	b.ear_t -= delta
	var flick := 0.0
	if b.ear_t < 0.0:
		flick = sin(clampf(-b.ear_t, 0.0, 0.3) / 0.3 * PI)
		if b.ear_t < -0.3:
			b.ear_t = randf_range(1.5, 5.0)
	(p["EarL"] as Node3D).rotation = Vector3(0.25 * arc + b.head_pitch * 0.5, 0.0, flick * 0.4)
	(p["EarR"] as Node3D).rotation = Vector3(0.25 * arc + b.head_pitch * 0.5, 0.0, -flick * 0.2)
	(p["Tail"] as Node3D).rotation.x = 0.3 * arc

func _start_hop(b: Beast, dist: float) -> void:
	b.hop_t = 0.0
	b.hop_from = b.root.global_position
	b.hop_to = b.hop_from + b.heading * dist
	var ls = game.landscape
	if ls.forest_blocked(Vector2(b.hop_to.x, b.hop_to.z)) or absf(b.hop_to.x) > 205.0 or b.hop_to.z < -130.0 or b.hop_to.z > 78.0:
		b.hop_to = b.hop_from                                  # nowhere to go that way: a hop on the spot
		_face(b, b.heading.rotated(Vector3.UP, PI * 0.7))

## Advances a hop (duration `dur`); returns its arc 0..1 (the jump height factor), or 0 when none is under way.
func _hop_step(b: Beast, delta: float, dur: float) -> float:
	if b.hop_t < 0.0:
		return 0.0
	b.hop_t += delta / dur
	var k := clampf(b.hop_t, 0.0, 1.0)
	var flat := b.hop_from.lerp(b.hop_to, k)
	b.root.global_position = Vector3(flat.x, 0.0, flat.z)
	_face(b, b.heading)
	if b.hop_t >= 1.0:
		b.hop_t = -1.0
		return 0.0
	return sin(k * PI)

## Number of animals currently out (visible).
func active_count() -> int:
	var n := 0
	for b in animals:
		if b.root != null and b.root.visible:
			n += 1
	return n
