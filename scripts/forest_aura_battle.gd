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
var cinematic := true                  ## the showdown takes over the camera (letterbox, cuts, slow moves) from the moment it starts; SPACE / E skips
var _cam: Camera3D
var _bars: CanvasLayer
var _bar_t: ColorRect
var _bar_b: ColorRect
var _ui_was := true
var _in_cine := false
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
	elapsed += delta
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
	[16.0, 0, "SIGMA"], [17.4, 1, "SIGMA"], [19.0, 0, "..."], [20.8, 1, "hands in pockets"], [22.0, 0, "-10 AURA (blinked)"]]

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
		lb.position = (made["home"] as Vector3) + Vector3(0, (3.0 if int(c[1]) == 0 else 2.2) + age * 0.7, 0)
		lb.modulate = Color(1.0, 0.95, 0.6, clampf(minf(age * 6.0, (1.6 - age) * 2.5), 0.0, 1.0))

func finish() -> void:
	_cine_end()
	elapsed = -1.0
	cooldown = COOLDOWN
	gaze = 0.0
	unseen = 0.0
	effects.visible = false
	for sh in _shades:
		(sh as Node3D).visible = false
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

func _cine_end() -> void:
	if not _in_cine:
		return
	_in_cine = false
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
