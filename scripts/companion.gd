extends Node3D
class_name QuarryCompanion
## Phase 7.7: the dinosaur companion. A small procedural low-poly dinosaur that follows the player, rests when they stand
## still and, once it is big enough, smashes exposed rock with its tail on command (key T). It never blocks the player
## (no collider) and never mines anything the hardness rule forbids.

var game
var stage := "hatchling"
var speed := 3.2
var model: Node3D
var tail: Node3D
var head: Node3D
var legs := []
var phase := 0.0
var idle_time := 0.0
var resting := false
var _last_player := Vector3.ZERO
## smash command: target column, hits left, timer
var smash_kind := ""
var smash_col := -1
var smash_left := 0
var smash_timer := 0.0
var debris: Node3D          ## weeds or a rubble heap it was sent to clear
var swing := 0.0              ## 0..1 progress of the current tail swing

func setup(g, stage_name: String) -> void:
	game = g
	name = "Companion"
	_build()
	set_stage(stage_name)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _build() -> void:
	# Ankylosaurus-inspired: a low, wide, armoured body, a small head with two horns, four short legs and a heavy tail club.
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	var hide := Color(0.46, 0.40, 0.30)
	var plate := Color(0.33, 0.29, 0.22)
	var belly := Color(0.72, 0.66, 0.48)
	_box(model, Vector3(1.05, 0.55, 1.6), Vector3(0, 0.62, 0), hide)
	_box(model, Vector3(0.9, 0.16, 1.4), Vector3(0, 0.38, 0), belly)
	for row in range(4):                              # armoured plates along the back in two columns
		for sx in [-0.28, 0.28]:
			_box(model, Vector3(0.36, 0.14, 0.3), Vector3(sx, 0.95, -0.55 + float(row) * 0.38), plate)
	for row in range(3):                              # spikes along the flanks
		for sx in [-0.56, 0.56]:
			var sp := _box(model, Vector3(0.1, 0.14, 0.14), Vector3(sx, 0.78, -0.4 + float(row) * 0.42), plate)
			sp.rotation.z = -signf(sx) * 0.5
	head = Node3D.new()
	head.position = Vector3(0, 0.62, -0.95)
	model.add_child(head)
	_box(head, Vector3(0.5, 0.32, 0.5), Vector3(0, 0, -0.18), hide)
	_box(head, Vector3(0.12, 0.12, 0.18), Vector3(0.23, 0.22, -0.2), plate)
	_box(head, Vector3(0.12, 0.12, 0.18), Vector3(-0.23, 0.22, -0.2), plate)
	_box(head, Vector3(0.08, 0.08, 0.06), Vector3(0.14, 0.08, -0.44), Color(0.08, 0.08, 0.06))
	_box(head, Vector3(0.08, 0.08, 0.06), Vector3(-0.14, 0.08, -0.44), Color(0.08, 0.08, 0.06))
	tail = Node3D.new()
	tail.position = Vector3(0, 0.62, 0.78)
	model.add_child(tail)
	_box(tail, Vector3(0.6, 0.34, 0.7), Vector3(0, 0, 0.3), hide)
	var tip := Node3D.new()
	tip.position = Vector3(0, 0, 0.65)
	tail.add_child(tip)
	_box(tip, Vector3(0.38, 0.26, 0.7), Vector3(0, 0, 0.35), hide)
	_box(tip, Vector3(0.62, 0.42, 0.42), Vector3(0, 0, 0.85), Color(0.52, 0.48, 0.4))        # the club
	for lz in [-0.55, 0.55]:
		for sx in [-0.42, 0.42]:
			var leg := Node3D.new()
			leg.position = Vector3(sx, 0.4, lz)
			model.add_child(leg)
			_box(leg, Vector3(0.24, 0.42, 0.28), Vector3(0, -0.2, 0), hide)
			legs.append(leg)

func set_stage(s: String) -> void:
	stage = s
	var sd: Dictionary = game.prog.companion_cfg().get("stages", {}).get(s, {})
	speed = float(sd.get("speed", 3.2))
	scale = Vector3.ONE * float(sd.get("scale", 0.35))

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
	phase += delta * speed * 2.4
	return false

## True while a smash command is running.
func busy() -> bool:
	return smash_left > 0 or (debris != null and is_instance_valid(debris))

## Sends the companion to clear a weed patch or rubble heap (Part 14: designated debris).
func command_debris(node: Node3D) -> String:
	if not game.prog.companion_stage_def(game.prog.current_day).get("smash", false):
		return "%s is still too small to clear rubble." % str(game.prog.companion().get("name", "Your dinosaur"))
	cancel_smash()
	debris = node
	smash_timer = 0.0
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
	smash_timer = 0.0
	swing = 0.0
	return ""

func cancel_smash() -> void:
	debris = null
	smash_left = 0
	smash_col = -1
	smash_kind = ""

func step(delta: float, player_pos: Vector3, rest_goal := Vector3.INF) -> void:
	var moving := false
	if debris != null:
		if not is_instance_valid(debris) or game.prog.cleanup["cleared"].get(str(debris.get_meta("debris_id", "")), false):
			debris = null
		else:
			var arrived_d := _walk_to(debris.global_position, delta, 2.2)
			moving = not arrived_d
			if arrived_d:
				_face(debris.global_position - global_position, delta)
				smash_timer -= delta
				if smash_timer <= 0.0:
					smash_timer = float(game.prog.companion_cfg().get("smash_interval", 1.1))
					swing = 1.0
					var dmg: float = float(game.prog.companion_stage_def(game.prog.current_day).get("damage", 0.0))
					game.hit_debris(debris, dmg, debris.global_position + Vector3(0, 0.3, 0), true)
	elif busy():
		if smash_col < 0 or game.prog.column_units(smash_kind, smash_col) <= 0:
			smash_col = game.prog.nearest_column(smash_kind, global_position, true, float(game.prog.companion_cfg().get("reach", 14.0)))
			if smash_col < 0:
				cancel_smash()
		if busy():
			var at: Vector3 = game.formation_nodes[smash_kind].column_top(smash_col)
			var arrived := _walk_to(at, delta, 2.6)
			moving = not arrived
			if arrived:
				_face(at - global_position, delta)
				smash_timer -= delta
				if smash_timer <= 0.0:
					smash_timer = float(game.prog.companion_cfg().get("smash_interval", 1.1))
					swing = 1.0
					_smash_hit()
	elif rest_goal != Vector3.INF:
		# night or the player asleep: it goes to its bed and lies down
		var there := _walk_to(rest_goal, delta, 0.5)
		moving = not there
		resting = there
		if there:
			rotation.y = lerp_angle(rotation.y, 0.0, clampf(delta * 3.0, 0.0, 1.0))
	else:
		var dist := Vector2(global_position.x - player_pos.x, global_position.z - player_pos.z).length()
		var moved := (player_pos - _last_player).length()
		_last_player = player_pos
		idle_time = idle_time + delta if moved < 0.01 * maxf(delta * 60.0, 1.0) else 0.0
		resting = idle_time > 6.0 and dist < 4.5
		if dist > 40.0:
			global_position = player_pos + Vector3(2.0, 0.0, 2.0)
			global_position.y = ground_y(global_position)
		elif dist > 3.2 and not resting:
			moving = true
			_walk_to(player_pos, delta, 2.6)
		else:
			_face(player_pos - global_position, delta)
	_animate(delta, moving)

func _smash_hit() -> void:
	var kind := smash_kind
	var col := smash_col
	smash_left -= 1
	var dmg: float = float(game.prog.companion_stage_def(game.prog.current_day).get("damage", 0.0))
	game.companion_strike(kind, col, dmg, self)
	if game.prog.column_units(kind, col) <= 0:
		smash_col = -1

func _animate(delta: float, moving: bool) -> void:
	swing = maxf(0.0, swing - delta * 3.0)
	var bob := sin(phase) * 0.04 if moving else 0.0
	model.position.y = bob - (0.2 if resting else 0.0)
	for i in range(legs.size()):
		legs[i].rotation.x = (sin(phase + float(i % 2) * PI) * 0.45) if moving else 0.0
	tail.rotation.y = sin(phase * 0.7) * 0.25 if moving else sin(Time.get_ticks_msec() * 0.002) * 0.12
	if swing > 0.0:
		tail.rotation.y = sin(swing * PI) * (1.0 if int(smash_left) % 2 == 0 else -1.0) * 1.1
	head.rotation.x = (-0.15 if resting else 0.0)
