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
var halos: Array = []
var flames: Array = []
var waves: Array = []
var beams: Array = []
var clash: MeshInstance3D
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
		root.position = Vector3(0, 0, -3.3 if key == "deer" else 3.3)
		root.rotation.y = PI if key == "deer" else 0.0
		made["home"] = root.position
		actors.append(made)
	effects = Node3D.new()
	add_child(effects)
	for i in 2:
		var colour := BLUE if i == 0 else GOLD
		var origin: Vector3 = actors[i]["home"]
		var halo := Node3D.new()
		effects.add_child(halo)
		halo.position = origin
		halos.append(halo)
		var spikes: Array = []
		for k in 10:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.15
			cone.height = 1.0
			cone.radial_segments = 4
			var spike := _mesh(halo, cone, colour)
			var a := TAU * float(k) / 10.0
			spike.position = Vector3(cos(a) * 0.8, 1.0, sin(a) * 0.8)
			spikes.append(spike)
		flames.append(spikes)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.90
		torus.outer_radius = 1.0
		torus.rings = 24
		torus.ring_segments = 4
		var wave := _mesh(effects, torus, colour)
		wave.position = origin + Vector3(0, 0.08, 0)
		waves.append(wave)
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.14
		cylinder.bottom_radius = 0.32
		cylinder.height = 1.0
		cylinder.radial_segments = 6
		beams.append(_mesh(effects, cylinder, colour))
	var ball := SphereMesh.new()
	ball.radius = 0.45
	ball.height = 0.9
	ball.radial_segments = 8
	ball.rings = 4
	clash = _mesh(effects, ball, Color(1.0, 0.96, 0.76))
	clash.position = Vector3(0, 1.2, 0)
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

func _pose(t: float) -> void:
	# Stare-down -> alternating power-ups -> clash -> rabbit's absurd final
	# surge -> both settle, as if nothing happened. Never a camera takeover.
	var charge := smoothstep(2.0, 5.0, t) * (1.0 - smoothstep(21.0, 24.0, t))
	var firing := t >= 10.0 and t < 20.0
	effects.visible = charge > 0.001
	for i in 2:
		var actor: Node3D = actors[i]["root"]
		var parts: Dictionary = actors[i]["parts"]
		var surge := 1.0 + (0.75 if i == 1 and t > 16.0 and t < 20.0 else 0.0)
		var strength := charge * surge * (0.88 + sin(t * 8.0 + i * PI) * 0.12)
		var home: Vector3 = actors[i]["home"]
		actor.position = home + Vector3(0, sin(t * 5.0 + i) * 0.035 * charge, 0)
		actor.rotation.x = -0.12 * charge + sin(t * 13.0) * 0.012 * charge
		for key in ["Head", "Antlers", "EarL", "EarR"]:
			if parts.has(key):
				(parts[key] as Node3D).rotation.x = -0.22 * charge
		halos[i].scale = Vector3.ONE * maxf(0.001, strength)
		halos[i].rotation.y = t * (0.65 if i == 0 else -1.0)
		for k in flames[i].size():
			var spike: MeshInstance3D = flames[i][k]
			var h := 1.2 + 0.7 * sin(t * 7.0 + float(k) * 2.1)
			spike.scale.y = h
			spike.position.y = h * 0.5
		var phase := fposmod(t * 0.7 + i * 0.5, 1.0)
		waves[i].scale = Vector3.ONE * maxf(0.001, (0.5 + phase * 2.2) * charge * surge)
		waves[i].visible = phase < 0.85
		var beam: MeshInstance3D = beams[i]
		beam.visible = firing
		if firing:
			var start := home + Vector3(0, 1.2, 0)
			var meet := Vector3(0, 1.2, -1.3 if t > 16.0 else sin(t * 2.0) * 0.45)
			var span := meet - start
			beam.position = (start + meet) * 0.5
			beam.quaternion = Quaternion(Vector3.UP, span.normalized())
			beam.scale = Vector3(0.7 * strength, span.length(), 0.7 * strength)
	clash.visible = firing
	clash.position.z = -1.3 if t > 16.0 else sin(t * 2.0) * 0.45
	clash.scale = Vector3.ONE * (1.0 + 0.3 * sin(t * 12.0))

func finish() -> void:
	elapsed = -1.0
	cooldown = COOLDOWN
	gaze = 0.0
	unseen = 0.0
	effects.visible = false
	for made in actors:
		var actor: Node3D = made["root"]
		actor.position = made["home"]
		actor.rotation.x = 0.0
		for part in made["parts"].values():
			(part as Node3D).rotation.x = 0.0
