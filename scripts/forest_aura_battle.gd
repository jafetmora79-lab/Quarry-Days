extends Node3D
## A distant, silent showdown using the real wildlife models. No physics, lights,
## rewards or save state. Emissive geometry works without glow in GL Compatibility.
const CENTRE := Vector3(-148.0, 0.0, -58.0)
const WATCH_SECONDS := 2.0
const DURATION := 24.0
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
	effects.visible = false

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
		return
	unseen = 0.0 if looking else unseen + delta
	elapsed += delta
	# Three seconds' grace lets the player glance away without restarting it.
	if elapsed >= DURATION or unseen >= 3.0:
		finish()
		return
	_pose(elapsed)

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
	if t < 2.0: return "stare"
	if t < 8.0: return "six_seven"
	if t < 15.0: return "boat_roll"
	if t < 20.0: return "crossed"
	if t < 23.0: return "pockets"
	return "settle"

func _pose(t: float) -> void:
	var stage := pose_name(t)
	var rise := smoothstep(1.0, 2.5, t) * (1.0 - smoothstep(22.5, 24.0, t))
	effects.visible = rise > 0.01
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
		var left := Vector3(0.85, 0.0, -0.2)
		var right := Vector3(0.85, 0.0, 0.2)
		match stage:
			"six_seven":
				# Opposing open-hoof/paw palms, alternating at chest height.
				left = Vector3(1.3 + sin(beat) * 0.22, sin(beat) * 0.25, -0.5)
				right = Vector3(1.3 - sin(beat) * 0.22, sin(beat) * 0.25, 0.5)
			"boat_roll":
				# Eight right flicks followed by five left; each flick lasts .5 s.
				var local_t := t - 8.0
				var active_right := local_t < 4.0
				var flick := sin(local_t * TAU * 2.0)
				left = Vector3(1.2, -0.25, -0.65)
				right = Vector3(1.2, 0.25, 0.65)
				if active_right:
					right += Vector3(0.15 * cos(local_t * TAU), flick * 0.5, flick * 0.25)
				elif local_t < 6.5:
					left += Vector3(0.15 * cos(local_t * TAU), flick * 0.5, flick * 0.25)
			"crossed":
				left = Vector3(0.9, -0.45, -1.1)
				right = Vector3(0.9, 0.45, 1.1)
			"pockets":
				# Paws tucked at the hips, chin up: pockets implied, not added.
				left = Vector3(-0.2, 0.0, -0.12)
				right = Vector3(-0.2, 0.0, 0.12)
		for pair in [["LegFL" if i == 0 else "PawL", left], ["LegFR" if i == 0 else "PawR", right]]:
			var limb: Node3D = parts[pair[0]]
			limb.basis = tilt * Basis.from_euler(pair[1] * rise)
			if i == 1:
				limb.position.y += 0.09 * rise
		var head: Node3D = parts["Head"]
		var chin := Basis(Vector3.RIGHT, (-0.25 if stage in ["crossed", "pockets"] else -0.10) * rise)
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

func finish() -> void:
	elapsed = -1.0
	cooldown = COOLDOWN
	gaze = 0.0
	unseen = 0.0
	effects.visible = false
	for made in actors:
		var actor: Node3D = made["root"]
		actor.position = made["home"]
		actor.rotation = Vector3(0, made["yaw"], 0)
		for key in made["parts"]:
			(made["parts"][key] as Node3D).transform = made["rest"][key]
