extends Node3D
## A distant, silent showdown using the real wildlife models. No physics, lights,
## rewards or save state. Emissive geometry works without glow in GL Compatibility.
const CENTRE := Vector3(-148.0, 0.0, -58.0)
const WATCH_SECONDS := 2.0
const DURATION := 36.0                 ## in pose time: the poses run 24 s, then the result (the deer's sad walk, the bunnies carrying the winner off)
const SPEED := 1.3                     ## pose time per real second: a little brisker than the first cut
const COOLDOWN := 18.0
const BLUE := Color(0.16, 0.75, 1.0)
const GOLD := Color(1.0, 0.64, 0.12)

var game
var actors: Array = []
var waves: Array = []
var effects: Node3D
var gaze := 0.0
var elapsed := -1.0
var cooldown := 0.0
var unseen := 0.0
var cinematic := true                  ## the showdown takes over the camera (letterbox, cuts, slow moves) from the moment it starts; SPACE / E skips
var _cam: Camera3D
var _bars: CanvasLayer
var _bar_t: ColorRect
var _bar_b: ColorRect
var _ui_was := true
var _in_cine := false
var _friends: Array = []
var _cloud: Node3D
var _rain: CPUParticles3D
var _confetti: CPUParticles3D
var _burst_done := false
var _music: AudioStreamPlayer
const MUSIC := "res://audio/aura_battle.wav"          ## an original meme-phonk track (tools/make_aura_music.py), timed to the choreography at SPEED
var _caption_nodes: Array = []
var _shades: Array = []
## Where the shades sit on each head (local to the Head hinge; tuned by eye with tools/shot_aura.gd).
const SHADES_AT := [Vector3(0.0, 0.18, -0.36), Vector3(0.0, 0.1, -0.16)]

## Keep just one window between the trees; the surrounding forest stays dense.
static func in_clearing(p: Vector2) -> bool:
	return Rect2(-159.0, -65.0, 31.0, 14.0).has_point(p)

func setup(g) -> void:
	game = g
	name = "ForestAuraBattle"
	position = CENTRE
	for key in ["deer", "rabbit"]:
		var made: Dictionary = WorldModels.animal(key)
		if made.is_empty():
			for actor in actors:
				actor["root"].queue_free()
			actors.clear()
			set_process(false)
			return
		var root: Node3D = made["root"]
		add_child(root)
		root.position = Vector3(0, 0, -2.0 if key == "deer" else 2.0)
		root.rotation.y = PI if key == "deer" else 0.0
		made["home"] = root.position
		made["yaw"] = root.rotation.y
		if key == "rabbit":
			root.scale = Vector3.ONE * 2.0 # readable little challenger at the distant fence
			_split_forepaws(made)
		var rest := {}
		for part_name in made["parts"]:
			rest[part_name] = (made["parts"][part_name] as Node3D).transform
		made["rest"] = rest
		actors.append(made)
	effects = Node3D.new()
	add_child(effects)
	for i in 2:
		var colour := BLUE if i == 0 else GOLD
		var origin: Vector3 = actors[i]["home"]
		var torus := TorusMesh.new()
		torus.inner_radius = 0.90
		torus.outer_radius = 1.0
		torus.rings = 24
		torus.ring_segments = 4
		var wave := _mesh(effects, torus, colour)
		wave.position = origin + Vector3(0, 0.08, 0)
		waves.append(wave)
	for c in CAPTIONS:
		var lb := PixelLabel.new()
		lb.text = str(c[2])
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.font_size = 40
		lb.pixel_size = 0.012
		lb.outline_size = 10
		lb.visible = false
		effects.add_child(lb)
		_caption_nodes.append(lb)
	for i in 2:                                                       # cool-guy shades, worn on the head so they nod with it
		var head: Node3D = actors[i]["parts"]["Head"]
		var shades := Node3D.new()
		shades.name = "Shades"
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.02, 0.02, 0.03)
		dark.metallic = 0.6
		dark.roughness = 0.2
		for sx in [-1.0, 1.0]:
			var lens := MeshInstance3D.new()
			lens.mesh = BoxMesh.new()
			(lens.mesh as BoxMesh).size = Vector3(0.13, 0.08, 0.03) if i == 0 else Vector3(0.09, 0.06, 0.03)
			lens.material_override = dark
			lens.position = Vector3(sx * (0.09 if i == 0 else 0.07), 0.0, 0.0)
			shades.add_child(lens)
		var bridge := MeshInstance3D.new()
		bridge.mesh = BoxMesh.new()
		(bridge.mesh as BoxMesh).size = Vector3(0.1 if i == 0 else 0.07, 0.015, 0.02)
		bridge.material_override = dark
		shades.add_child(bridge)
		shades.position = SHADES_AT[i]
		shades.visible = false
		head.add_child(shades)
		_shades.append(shades)
	for k in 4:                                                       # the winner's friends, waiting in the trees until the result
		var friend: Dictionary = WorldModels.animal("rabbit")
		if friend.is_empty():
			break
		var fr: Node3D = friend["root"]
		fr.scale = Vector3.ONE * 1.6
		fr.visible = false
		add_child(fr)
		var rest := {}
		for part_name in friend["parts"]:
			rest[part_name] = (friend["parts"][part_name] as Node3D).transform
		friend["rest"] = rest
		_friends.append(friend)
	_cloud = Node3D.new()                                             # a small grey rain cloud for the loser
	var grey := StandardMaterial3D.new()
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grey.albedo_color = Color(0.36, 0.38, 0.45)
	for cx in [[-0.5, 0.0, 0.5], [0.0, 0.2, 0.7], [0.55, 0.0, 0.5]]:
		var blob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = cx[2] * 0.7
		sm.height = cx[2] * 1.2
		sm.radial_segments = 8
		sm.rings = 4
		blob.mesh = sm
		blob.material_override = grey
		blob.position = Vector3(cx[0], cx[1], 0)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cloud.add_child(blob)
	_rain = CPUParticles3D.new()
	_rain.amount = 30
	_rain.lifetime = 0.8
	_rain.emitting = false
	_rain.direction = Vector3.DOWN
	_rain.spread = 4.0
	_rain.initial_velocity_min = 2.0
	_rain.initial_velocity_max = 3.0
	_rain.gravity = Vector3(0, -6, 0)
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(0.7, 0.05, 0.4)
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.12, 0.025)
	_rain.mesh = drop
	var blue := StandardMaterial3D.new()
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue.albedo_color = Color(0.45, 0.65, 1.0)
	_rain.material_override = blue
	_cloud.add_child(_rain)
	_rain.position = Vector3(0, -0.2, 0)
	_cloud.visible = false
	effects.add_child(_cloud)
	_confetti = CPUParticles3D.new()
	_confetti.amount = 60
	_confetti.lifetime = 2.2
	_confetti.emitting = false
	_confetti.direction = Vector3.UP
	_confetti.spread = 70.0
	_confetti.initial_velocity_min = 3.0
	_confetti.initial_velocity_max = 5.5
	_confetti.gravity = Vector3(0, -4.5, 0)
	_confetti.angular_velocity_min = -300.0
	_confetti.angular_velocity_max = 300.0
	var chip := BoxMesh.new()
	chip.size = Vector3(0.09, 0.02, 0.06)
	_confetti.mesh = chip
	var conf := StandardMaterial3D.new()
	conf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	conf.vertex_color_use_as_albedo = true
	_confetti.material_override = conf
	_confetti.color_initial_ramp = _confetti_ramp()
	effects.add_child(_confetti)
	effects.visible = false

func _confetti_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.35, 0.35), Color(1.0, 0.85, 0.3), Color(0.4, 0.9, 0.5), Color(0.4, 0.75, 1.0), Color(0.9, 0.5, 1.0)])
	return g

func _mesh(parent: Node3D, mesh: Mesh, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## A broad stretch of the LEFT fence can discover it, but only by looking at the
## clearing. Distance, camera direction and solid occlusion all matter.
func watched() -> bool:
	if game.player == null or game.driving != null or game.menu != "" or game.sleeping or game.player.locked:
		return false
	var p: Vector3 = game.player.global_position
	if p.x < -129.0 or p.x > -106.0 or p.z < -102.0 or p.z > -18.0:
		return false
	var cam: Camera3D = game.player.camera
	var target := global_position + Vector3(0, 1.2, 0)
	var offset := target - cam.global_position
	if offset.length() < 12.0 or offset.length() > 65.0 or not cam.is_position_in_frustum(target):
		return false
	if (-cam.global_basis.z).dot(offset.normalized()) < 0.97:
		return false
	var ray := PhysicsRayQueryParameters3D.create(cam.global_position, target, 1)
	ray.exclude = [game.player.get_rid()]
	# The see-through perimeter fence has a SOLID box collider for movement.
	# Look through that collider, but never through rock, buildings or terrain.
	for attempt in 4:
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			return true
		var body: CollisionObject3D = hit["collider"]
		if not bool(body.get_meta("fence", false)):
			return false
		var excluded := ray.exclude
		excluded.append(body.get_rid())
		ray.exclude = excluded
	return false

func _process(delta: float) -> void:
	if actors.size() != 2:
		return
	# Pause with the game's menus; keep the tableau where it was.
	if game.menu != "" or game.sleeping:
		return
	step(delta, watched())

func step(delta: float, looking: bool) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if elapsed < 0.0:
		gaze = gaze + delta if looking and cooldown <= 0.0 else 0.0
		if gaze >= WATCH_SECONDS:
			elapsed = 0.0
			gaze = 0.0
			unseen = 0.0
			if cinematic:
				_cine_start()
		return
	if _in_cine:
		unseen = 0.0                                            # the camera is ours: nobody can look away
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
			finish()
			return
	else:
		unseen = 0.0 if looking else unseen + delta
	elapsed += delta * SPEED
	# Three seconds' grace lets the player glance away without restarting it.
	if elapsed >= DURATION or unseen >= 3.0:
		finish()
		return
	_pose(elapsed)
	if _in_cine:
		_cine_update(elapsed)

## Split only the Easter egg's instanced rabbit foreleg mesh at its centre.
## The original GLB has both paws in one hinge; no source asset is changed.
func _split_forepaws(made: Dictionary) -> void:
	var pair: Node3D = made["parts"]["LegF"]
	var source: Mesh = (pair.get_child(0) as MeshInstance3D).mesh
	pair.visible = false
	for side in [-1, 1]:
		var paw := Node3D.new()
		paw.transform = pair.transform
		paw.position.x += float(side) * 0.06
		made["root"].add_child(paw)
		var mesh := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices = PackedInt32Array(range(verts.size()))
			var chosen := PackedInt32Array()
			for tri in range(0, indices.size(), 3):
				var x := (verts[indices[tri]].x + verts[indices[tri + 1]].x + verts[indices[tri + 2]].x) / 3.0
				if x * float(side) > 0.0:
					chosen.append_array(indices.slice(tri, tri + 3))
			if chosen.is_empty():
				continue
			for v in verts.size():
				verts[v].x -= float(side) * 0.06
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_INDEX] = chosen
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, source.surface_get_material(surface))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paw.add_child(mi)
		made["parts"]["PawL" if side < 0 else "PawR"] = paw

func pose_name(t: float) -> String:
	if t >= 24.0: return "result"
	if t < 2.0: return "stare"
	if t < 8.0: return "six_seven"
	if t < 15.0: return "boat_roll"
	if t < 20.0: return "crossed"
	if t < 23.0: return "pockets"
	return "settle"

func _pose(t: float) -> void:
	if t >= 24.0:
		_finale(t)
		return
	_set_finale_visible(false)
	var stage := pose_name(t)
	var rise := smoothstep(1.0, 2.5, t) * (1.0 - smoothstep(22.5, 24.0, t))
	effects.visible = rise > 0.01
	_captions(t)
	for sh in _shades:
		(sh as Node3D).visible = t > 2.3 and t < 23.0                 # the shades go on with a flourish once the pose starts
	for i in 2:
		var made: Dictionary = actors[i]
		var actor: Node3D = made["root"]
		var parts: Dictionary = made["parts"]
		for key in parts:
			(parts[key] as Node3D).transform = made["rest"][key]
		var beat := (t - (0.0 if i == 0 else 0.45)) * TAU * 0.9
		var sway := sin(beat) * 0.10 * rise if stage in ["six_seven", "boat_roll"] else 0.0
		actor.position = made["home"] + Vector3(0, absf(sin(beat)) * 0.035 * rise, 0)
		# Quarter-turn toward the viewer makes the forepaw silhouettes legible
		# from the fence, while they still face one another.
		actor.rotation = Vector3(0, float(made["yaw"]) + (0.4 if i == 0 else -0.4) * rise, sway)
		var hip := Vector3(0, 0.8, 0.55) if i == 0 else Vector3(0, 0.13, 0.1)
		var tilt := Basis(Vector3.RIGHT, (0.85 if i == 0 else 0.65) * rise)
		for key in ["Body", "Head", "Antlers", "EarL", "EarR", "Tail", "LegFL", "LegFR", "PawL", "PawR"]:
			if parts.has(key):
				var node: Node3D = parts[key]
				node.position = hip + tilt * (node.position - hip)
				node.basis = tilt * node.basis
		var cur := _arms(stage, t, beat)
		var since := t - _stage_start(stage)
		var left: Vector3 = cur[0]
		var right: Vector3 = cur[1]
		if since < 0.6 and stage != "stare":                      # ease out of the last pose instead of snapping to the next one
			var prev := _arms(pose_name(maxf(0.0, _stage_start(stage) - 0.01)), t, beat)
			var k := smoothstep(0.0, 0.6, since)
			left = (prev[0] as Vector3).lerp(left, k)
			right = (prev[1] as Vector3).lerp(right, k)
		for pair in [["LegFL" if i == 0 else "PawL", left], ["LegFR" if i == 0 else "PawR", right]]:
			var limb: Node3D = parts[pair[0]]
			limb.basis = tilt * Basis.from_euler(pair[1] * rise)
			if i == 1:
				limb.position.y += 0.09 * rise
		var head: Node3D = parts["Head"]
		var nod := (0.08 * sin(beat * 2.0) if stage in ["six_seven", "boat_roll"] else 0.0) * rise
		if stage == "six_seven":
			nod += 0.05 * sin(t * TAU * 1.5) * rise
		var chin := Basis(Vector3.RIGHT, (-0.25 if stage in ["crossed", "pockets"] else -0.10) * rise + nod)
		for key in ["Head", "Antlers", "EarL", "EarR"]:
			if parts.has(key):
				var node: Node3D = parts[key]
				node.position = head.position + chin * (node.position - head.position)
				node.basis = chin * node.basis
		for ear in ["EarL", "EarR"]:
			(parts[ear] as Node3D).rotate_z((0.1 if ear == "EarL" else -0.1) * sin(beat * 0.5) * rise)
		# Brief ground ripples punctuate a pose; nothing covers the animal.
		var phase := fposmod(t - (15.0 if i == 0 else 17.0), 4.0)
		waves[i].visible = t >= 15.0 and t < 20.0 and phase < 0.5
		waves[i].scale = Vector3.ONE * (0.4 + phase * 1.8) * (0.5 if i == 1 else 1.0)

func _stage_start(stage: String) -> float:
	return {"stare": 0.0, "six_seven": 2.0, "boat_roll": 8.0, "crossed": 15.0, "pockets": 20.0, "settle": 23.0}[stage]

## The two forelimbs' (x, y, z) rotations for a stage (the same gestures as before: alternating six-seven, eight right flicks then five left, crossed, pockets).
func _arms(stage: String, t: float, beat: float) -> Array:
	var left := Vector3(0.85, 0.0, -0.2)
	var right := Vector3(0.85, 0.0, 0.2)
	match stage:
		"six_seven":
			# palms out in front, level with the chest, pumping up and down in opposition: one rises while the other drops (the "six, seven" see-saw), a touch faster than the sway
			var pump := sin(t * TAU * 1.5)
			left = Vector3(1.25 + pump * 0.5, 0.1, -0.45 - pump * 0.08)
			right = Vector3(1.25 - pump * 0.5, -0.1, 0.45 + pump * 0.08)
		"boat_roll":
			var local_t := t - 8.0
			var active_right := local_t < 4.0
			var flick := sin(local_t * TAU * 2.0)
			# one paw laid over the other at the middle of the chest; the top one flicks from the "wrist" (small fast turns on every axis) and rolls, the other holds still
			left = Vector3(1.35, -0.1, -0.18)
			right = Vector3(1.45, 0.1, 0.22)
			var wob := Vector3(0.3 * sin(local_t * TAU * 2.0), 0.35 * cos(local_t * TAU * 2.0), 0.3 * sin(local_t * TAU * 2.0 + 1.0))
			if active_right:
				right += wob
			elif local_t < 6.5:
				left += wob * Vector3(1, -1, -1)
		"crossed":
			# crossed over the chest: each paw reaches across to the other side, the left over the right
			left = Vector3(1.05, -0.45, 0.85)
			right = Vector3(1.0, 0.45, -0.7)
		"pockets":
			left = Vector3(-0.2, 0.0, -0.12)
			right = Vector3(-0.2, 0.0, 0.12)
	return [left, right]

## Floating meme captions: [time, actor, text]. Each rises and fades over 1.6 s above that animal.
const CAPTIONS := [[2.6, 0, "+67 AURA"], [3.6, 1, "+67 AURA"], [5.2, 0, "6 7"], [6.2, 1, "6 7"], [8.6, 1, "FLICK x8"], [12.2, 1, "FLICK x5"], [14.0, 0, "+1000 AURA"],
	[16.0, 0, "SIGMA"], [17.4, 1, "SIGMA"], [19.0, 0, "..."], [20.8, 1, "hands in pockets"], [22.0, 0, "-10 AURA (blinked)"],
	[24.4, 0, "-9999 AURA"], [25.0, 1, "WINNER"], [26.6, 1, "+9999 AURA"], [28.4, 0, "sad deer noises"], [30.0, 1, "BUNNY GANG"], [32.2, 1, "CELEBRATE"], [34.0, 0, "..."]]

func _captions(t: float) -> void:
	for k in range(CAPTIONS.size()):
		var c: Array = CAPTIONS[k]
		var lb: Node3D = _caption_nodes[k]
		var age := t - float(c[0])
		if age < 0.0 or age > 1.6:
			lb.visible = false
			continue
		lb.visible = true
		var made: Dictionary = actors[int(c[1])]
		lb.position = (made["root"] as Node3D).position + Vector3(0, (3.0 if int(c[1]) == 0 else 2.6) + age * 0.7, 0)
		lb.modulate = Color(1.0, 0.95, 0.6, clampf(minf(age * 6.0, (1.6 - age) * 2.5), 0.0, 1.0))

func _set_finale_visible(on: bool) -> void:
	for f in _friends:
		(f["root"] as Node3D).visible = on
	if _cloud != null:
		_cloud.visible = on
	if _rain != null:
		_rain.emitting = on
	if not on and _confetti != null:
		_confetti.emitting = false

func _group(parts: Dictionary, keys: Array, pivot: Vector3, b: Basis) -> void:
	for key in keys:
		if parts.has(key):
			var node: Node3D = parts[key]
			node.position = pivot + b * (node.position - pivot)
			node.basis = b * node.basis

## The result (pose time 24 to 36): the deer droops, loses its shades and trudges off under a little rain cloud; the rabbit raises its paws, is joined by four bunnies, and is carried
## into the forest on their shoulders under confetti.
func _finale(t: float) -> void:
	var f := t - 24.0
	effects.visible = true
	for w in waves:
		w.visible = false
	_set_finale_visible(true)
	_captions(t)
	(_shades[0] as Node3D).visible = f < 0.4
	(_shades[1] as Node3D).visible = true
	(_shades[1] as Node3D).position = SHADES_AT[1] + Vector3(0, 0.07, 0.0) * smoothstep(0.3, 1.0, f)          # pushed up onto the forehead
	var west := Vector3(-1, 0, 0)
	# ---- the deer: slumps, turns away, walks off west with its head down
	var dm: Dictionary = actors[0]
	var dr: Node3D = dm["root"]
	var dp: Dictionary = dm["parts"]
	for key in dp:
		(dp[key] as Node3D).transform = dm["rest"][key]
	var walk := smoothstep(1.5, 3.0, f)
	var dist := maxf(0.0, f - 1.8) * 0.85
	var gait := f * TAU * 0.9
	dr.position = (dm["home"] as Vector3) + west * dist + Vector3(0, absf(sin(gait)) * 0.02 * walk, 0)
	dr.rotation = Vector3(0, lerp_angle(float(dm["yaw"]), PI * 0.5, smoothstep(0.8, 2.4, f)), 0)
	var droop := smoothstep(0.0, 1.0, f)
	_group(dp, ["Head", "Antlers", "EarL", "EarR"], (dp["Head"] as Node3D).position, Basis(Vector3.RIGHT, -0.75 * droop - 0.05 * sin(f * 2.2)))
	(dp["EarL"] as Node3D).rotate_z(-0.9 * droop)
	(dp["EarR"] as Node3D).rotate_z(0.9 * droop)
	(dp["Tail"] as Node3D).rotate_x(0.6 * droop)
	for pair in [["LegFL", 0.0], ["LegBR", 0.0], ["LegFR", PI], ["LegBL", PI]]:
		(dp[pair[0]] as Node3D).rotate_x(sin(gait + float(pair[1])) * 0.4 * walk)
	_cloud.position = dr.position + Vector3(0, 3.0, 0)
	_cloud.scale = Vector3.ONE * smoothstep(0.5, 1.5, f)
	# ---- the winner
	var rm: Dictionary = actors[1]
	var rr: Node3D = rm["root"]
	var rp: Dictionary = rm["parts"]
	for key in rp:
		(rp[key] as Node3D).transform = rm["rest"][key]
	var lift := smoothstep(4.6, 5.6, f)
	var march := maxf(0.0, f - 5.2) * 1.5
	var hop := absf(sin(f * TAU * 1.3)) * (0.32 if f < 4.6 else 0.14)
	rr.position = (rm["home"] as Vector3) + west * march + Vector3(0, hop + lift * 1.05, 0)
	rr.rotation = Vector3(0, lerp_angle(float(rm["yaw"]) + 0.4, PI * 0.5 + 0.3, smoothstep(4.6, 5.8, f)), sin(f * 5.0) * 0.08)
	var tilt := Basis(Vector3.RIGHT, 0.55)
	_group(rp, ["Body", "Head", "EarL", "EarR", "Tail", "PawL", "PawR"], Vector3(0, 0.13, 0.1), tilt)
	(rp["PawL"] as Node3D).basis = tilt * Basis.from_euler(Vector3(2.5 + 0.2 * sin(f * 9.0), 0.0, -0.7))
	(rp["PawR"] as Node3D).basis = tilt * Basis.from_euler(Vector3(2.5 - 0.2 * sin(f * 9.0), 0.0, 0.7))
	# ---- the friends: they run in from the trees, jump about, then carry the winner away
	var offsets := [Vector3(-1.4, 0, 0.9), Vector3(1.4, 0, 0.9), Vector3(-0.7, 0, 2.1), Vector3(0.8, 0, 2.3)]
	var starts := [Vector3(-5.0, 0, 8.5), Vector3(1.5, 0, 9.0), Vector3(-3.0, 0, 10.0), Vector3(4.0, 0, 9.5)]
	for i in _friends.size():
		var fm: Dictionary = _friends[i]
		var fr: Node3D = fm["root"]
		var fp: Dictionary = fm["parts"]
		for key in fp:
			(fp[key] as Node3D).transform = fm["rest"][key]
		var base: Vector3 = (rm["home"] as Vector3) + west * march
		var target: Vector3 = base + offsets[i]
		var arrive := smoothstep(1.6 + 0.3 * float(i), 4.8 + 0.2 * float(i), f)
		var pos: Vector3 = (starts[i] as Vector3).lerp(target, arrive)
		var arriving := arrive < 0.98
		var jump := absf(sin(f * TAU * (2.4 if arriving else 1.6) + float(i))) * (0.22 if arriving else 0.3)
		fr.position = pos + Vector3(0, jump, 0)
		fr.visible = f > 1.6 + 0.3 * float(i) - 0.2
		var face := (target - pos) if arriving else (west + Vector3(0, 0, 0.3))
		fr.rotation = Vector3(0, atan2(-face.x, -face.z) if face.length() > 0.01 else 0.0, 0)
		if not arriving:                                                # celebrating: paws up, bouncing, heads turned to the winner
			var up := Basis(Vector3.RIGHT, 0.4)
			_group(fp, ["Body", "Head", "EarL", "EarR", "Tail"], Vector3(0, 0.13, 0.1), up)
			(fp["LegF"] as Node3D).basis = up * Basis.from_euler(Vector3(2.4 + 0.3 * sin(f * 8.0 + float(i)), 0.0, 0.0))
	if f >= 4.8 and not _burst_done:
		_burst_done = true
		_confetti.emitting = true
	if _burst_done:
		_confetti.position = rr.position + Vector3(0, 1.8, 0)

func finish() -> void:
	_cine_end()
	elapsed = -1.0
	cooldown = COOLDOWN
	gaze = 0.0
	unseen = 0.0
	effects.visible = false
	for sh in _shades:
		(sh as Node3D).visible = false
	_set_finale_visible(false)
	_burst_done = false
	for made in actors:
		var actor: Node3D = made["root"]
		actor.position = made["home"]
		actor.rotation = Vector3(0, made["yaw"], 0)
		for key in made["parts"]:
			(made["parts"][key] as Node3D).transform = made["rest"][key]

# ------------------------------------------------------------------ the cinematic

## Shots: [from, to, camera start, camera end, look-at start, look-at end, fov]; positions are relative to the clearing's centre, +x toward the quarry fence.
const SHOTS := [
	[0.0, 2.4, Vector3(10.0, 1.7, 1.0), Vector3(7.2, 1.5, 0.4), Vector3(0, 1.0, 0), Vector3(0, 1.1, 0), 55.0],            # establishing, easing in
	[2.4, 6.0, Vector3(6.0, 1.7, -5.6), Vector3(5.0, 1.8, -4.7), Vector3(0, 1.5, -2.0), Vector3(0, 1.6, -2.0), 45.0],      # the deer, chest up
	[6.0, 8.0, Vector3(5.0, 1.2, 5.4), Vector3(4.2, 1.3, 4.6), Vector3(0, 1.1, 2.0), Vector3(0, 1.2, 2.0), 45.0],          # the rabbit answers
	[8.0, 12.0, Vector3(4.2, 1.1, 0.8), Vector3(3.4, 1.2, 1.1), Vector3(0, 1.2, 2.0), Vector3(0, 1.25, 2.0), 42.0],        # close on the rabbit's flicking paws
	[12.0, 15.0, Vector3(6.5, 1.4, 0.0), Vector3(5.0, 1.3, 3.6), Vector3(0, 1.1, 0), Vector3(0, 1.1, 0.4), 50.0],          # a two-shot drifting round
	[15.0, 20.0, Vector3(8.5, 1.3, 0.0), Vector3(4.6, 1.5, 0.0), Vector3(0, 1.2, 0), Vector3(0, 1.3, 0), 52.0],            # crossed arms: a slow push-in on both
	[20.0, 23.0, Vector3(3.2, 0.45, -4.4), Vector3(2.5, 0.55, -3.6), Vector3(0, 1.7, -2.0), Vector3(0, 1.8, -2.0), 50.0],  # hero shot of the deer from low down
	[23.0, 24.1, Vector3(5.0, 1.4, 0.0), Vector3(9.5, 1.8, 0.0), Vector3(0, 1.1, 0), Vector3(0, 1.1, 0), 55.0],            # pull back
]

func _cine_start() -> void:
	if game == null or game.player == null or not is_inside_tree():
		return
	_in_cine = true
	game.player.locked = true
	if ResourceLoader.exists(MUSIC) and DisplayServer.get_name() != "headless":
		_music = AudioStreamPlayer.new()
		_music.stream = load(MUSIC)
		_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else ("SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master")
		_music.volume_db = -4.0
		add_child(_music)
		_music.play()
	_cam = Camera3D.new()
	_cam.far = 700.0
	add_child(_cam)
	_cam.current = true
	_bars = CanvasLayer.new()
	_bars.layer = 45
	add_child(_bars)
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color(0.02, 0.02, 0.03)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		_bars.add_child(r)
		if top:
			_bar_t = r
		else:
			_bar_b = r
	var ui = game.get("ui")
	if ui != null:
		_ui_was = ui.visible
		ui.visible = false
	_cine_update(0.0)

func _cine_update(t: float) -> void:
	if _cam == null:
		return
	if t >= 24.0:
		_cine_finale(t)
		return
	for sh in SHOTS:
		if t >= float(sh[0]) and t < float(sh[1]) + (0.1 if sh == SHOTS[SHOTS.size() - 1] else 0.0):
			var k := smoothstep(0.0, 1.0, (t - float(sh[0])) / (float(sh[1]) - float(sh[0])))
			_cam.global_position = global_position + (sh[2] as Vector3).lerp(sh[3], k)
			_cam.look_at(global_position + (sh[4] as Vector3).lerp(sh[5], k), Vector3.UP)
			_cam.fov = float(sh[6])
			break
	var h := 70.0 * clampf(t / 0.6, 0.0, 1.0) * clampf((DURATION - t) / 0.6, 0.0, 1.0)
	_bar_t.offset_bottom = h
	_bar_b.offset_top = -h

func _cine_finale(t: float) -> void:
	var f := t - 24.0
	var w: Vector3 = (actors[1]["root"] as Node3D).position
	var d: Vector3 = (actors[0]["root"] as Node3D).position
	var from := Vector3.ZERO
	var look := Vector3.ZERO
	if f < 4.0:                                                       # the winner raised: hop and confetti
		var k := smoothstep(0.0, 1.0, f / 4.0)
		from = global_position + w + Vector3(6.0, 1.6, 2.4).lerp(Vector3(4.2, 1.8, 1.6), k)
		look = global_position + w + Vector3(0, 1.3, 0)
		_cam.fov = 48.0
	elif f < 7.5:                                                     # the sad deer, trudging off under its cloud
		var k := smoothstep(0.0, 1.0, (f - 4.0) / 3.5)
		from = global_position + d + Vector3(4.4, 1.0, -3.2).lerp(Vector3(3.6, 1.4, -2.4), k)
		look = global_position + d + Vector3(0, 1.4, 0)
		_cam.fov = 46.0
	else:                                                             # the parade into the forest
		var k := smoothstep(0.0, 1.0, (f - 7.5) / 4.5)
		from = global_position + w + Vector3(5.5, 1.5, 3.4).lerp(Vector3(4.5, 2.2, 5.5), k)
		look = global_position + w + Vector3(-1.0, 1.4, 0)
		_cam.fov = 52.0
	_cam.global_position = from
	_cam.look_at(look, Vector3.UP)
	var h := 70.0 * clampf((DURATION - t) / 0.6, 0.0, 1.0)
	_bar_t.offset_bottom = h
	_bar_b.offset_top = -h

func _cine_end() -> void:
	if not _in_cine:
		return
	_in_cine = false
	if _music != null and is_instance_valid(_music):
		var m := _music
		_music = null
		var tw := create_tween()
		tw.tween_property(m, "volume_db", -40.0, 0.8)
		tw.tween_callback(m.queue_free)
	if _cam != null and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	if _bars != null and is_instance_valid(_bars):
		_bars.queue_free()
	_bars = null
	var ui = game.get("ui")
	if ui != null:
		ui.visible = _ui_was
	if game.player != null:
		game.player.camera.current = true
		game.player.locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
