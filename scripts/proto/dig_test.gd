extends Node3D
## PROTOTYPE test arena for MudRunner-style digging (separate from the real quarry).
## A 40 m x 40 m contained yard: a dirt pile, a rock pile, a collection box and a front loader.
## Launch with DigTest_Prototype.bat (QuarrySimulator.exe -- --dig-test).
##
## On foot: WASD move, Shift sprint, mouse look, LMB shovel (dig where you aim), RMB throw the shovelful
## where you aim (into the box or onto the ground), E enter/exit the loader, R reset the arena, Esc quit.
## Loader: WASD drive, Space brake, hold LMB lower the bucket and drive into the pile to dig,
## release to carry, hold RMB to raise and tip the bucket and pour, E get out, R recover.

const SHOVEL_CAPACITY := 0.09          # m3 per shovelful
const BOX_CENTER := Vector3(0, 0, -14.0)
const BOX_HALF := Vector2(1.9, 1.3)    # interior half size (x, z)
const BOX_CAPACITY := 11.0             # m3
const BOX_WALL := 1.3

var terrain: DigTerrain
var player: QuarryPlayer
var loader: DigLoader
var driving := false
var ui_label: Label
var hint_label: Label
var fx_root: Node3D
var box_dirt := 0.0
var box_rock := 0.0
var box_fill: MeshInstance3D
var box_walls: StaticBody3D
var shovel_dirt := 0.0
var shovel_rock := 0.0
var shovel_node: Node3D
var shovel_load: MeshInstance3D
var shovel_cooldown := 0.0
var shovel_swing := 0.0
var initial_total := 0.0
var message := ""
var message_timer := 0.0
var _stream_timer := 0.0
var _fx_count := 0
var _headless := DisplayServer.get_name() == "headless"

func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	initial_total = accounted_total()
	_notify("Dig test arena. LMB with the shovel to dig. Walk to the loader and press E to drive it.")

# ------------------------------------------------------------------ world

func _build_world() -> void:
	terrain = DigTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(80)
	terrain.add_pile(-8.0, -4.0, 5.5, 2.8, "dirt", 0.18)
	terrain.add_pile(8.0, -4.0, 4.5, 2.2, "rock", 0.22)
	terrain.add_pile(-9.0, 7.0, 2.6, 1.0, "dirt", 0.1)
	terrain.flush(true)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.58, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.68, 0.72)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.6, 0.55)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.3
	add_child(sun)
	_build_box()
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)
	loader = DigLoader.new()
	loader.setup(terrain)
	loader.pour_target = Callable(self, "_pour")
	loader.position = Vector3(8.0, 0.2, 12.0)
	add_child(loader)

func _build_box() -> void:
	box_walls = StaticBody3D.new()
	box_walls.name = "CollectionBox"
	box_walls.position = BOX_CENTER
	box_walls.collision_layer = 1
	add_child(box_walls)
	var w := BOX_HALF
	var specs := [[Vector3(0, BOX_WALL * 0.5, -w.y - 0.1), Vector3(w.x * 2 + 0.4, BOX_WALL, 0.2)], [Vector3(0, BOX_WALL * 0.5, w.y + 0.1), Vector3(w.x * 2 + 0.4, BOX_WALL, 0.2)],
		[Vector3(-w.x - 0.1, BOX_WALL * 0.5, 0), Vector3(0.2, BOX_WALL, w.y * 2)], [Vector3(w.x + 0.1, BOX_WALL * 0.5, 0), Vector3(0.2, BOX_WALL, w.y * 2)]]
	var soup := MeshKit.Soup.new()
	var hz := MeshKit.Soup.new()
	for sp in specs:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sp[1]
		cs.shape = sh
		cs.position = sp[0]
		box_walls.add_child(cs)
		MeshKit.box_into(soup, sp[0], sp[1])
		MeshKit.box_into(hz, sp[0] + Vector3(0, BOX_WALL * 0.5 - 0.06, 0), sp[1] + Vector3(0.02, -BOX_WALL + 0.12, 0.02))
	MeshKit.inst(box_walls, soup.mesh(), MeshKit.mat("SteelGreen"))
	MeshKit.inst(box_walls, hz.mesh(), MeshKit.mat("Hazard"))
	var floor_soup := MeshKit.Soup.new()
	MeshKit.box_into(floor_soup, Vector3(0, 0.03, 0), Vector3(w.x * 2, 0.06, w.y * 2))
	MeshKit.inst(box_walls, floor_soup.mesh(), MeshKit.mat("SteelPlate"))
	box_fill = MeshKit.inst(box_walls, MeshKit.rock(Vector3(w.x * 2 - 0.2, 1.0, w.y * 2 - 0.2), 31, 3, 9), MeshKit.mat("ExcavatedDirt"), Vector3(0, 0.05, 0))
	box_fill.visible = false

func box_inside(p: Vector3) -> bool:
	return absf(p.x - BOX_CENTER.x) < BOX_HALF.x and absf(p.z - BOX_CENTER.z) < BOX_HALF.y

func box_total() -> float:
	return box_dirt + box_rock

## Material that reaches `spot`: into the box when over it, otherwise onto the ground. Returns what was NOT taken.
func _pour(spot: Vector3, amount: float, rock_frac: float) -> float:
	if box_inside(spot):
		var space := maxf(0.0, BOX_CAPACITY - box_total())
		var take := minf(amount, space)
		box_rock += take * rock_frac
		box_dirt += take * (1.0 - rock_frac)
		_update_box_fill()
		return amount - take            # a full box refuses more: it stays with the carrier
	return terrain.deposit(spot, 0.9, amount, rock_frac)

func _update_box_fill() -> void:
	var t := box_total()
	box_fill.visible = t > 0.005
	box_fill.scale = Vector3(1.0, clampf(t / BOX_CAPACITY * 1.6 + 0.05, 0.05, 1.7), 1.0)
	box_fill.material_override = MeshKit.mat("RockLimestone" if box_rock > box_dirt else "ExcavatedDirt")

## Every cubic metre: ground + bucket + shovel + box. Must never change.
func accounted_total() -> float:
	return terrain.total_volume() + loader.load_total() + shovel_dirt + shovel_rock + box_total()

# ------------------------------------------------------------------ player, shovel

func _build_player() -> void:
	player = QuarryPlayer.new()
	player.name = "Player"
	player.position = Vector3(0, 0.3, 13.0)
	add_child(player)
	player.collision_mask = 1 | 8
	player.pickaxe.visible = false
	shovel_node = Node3D.new()
	shovel_node.position = Vector3(0.34, -0.42, -0.65)
	player.camera.add_child(shovel_node)
	var s := MeshKit.Soup.new()
	MeshKit.box_into(s, Vector3(0, 0.0, 0.0), Vector3(0.035, 0.035, 0.95))                              # handle
	MeshKit.box_into(s, Vector3(0, 0.0, 0.55), Vector3(0.09, 0.06, 0.12))                               # grip
	MeshKit.inst(shovel_node, s.mesh(), MeshKit.mat("res://THE_VEIL_ASSETS_V2/Materials_Godot/Furniture/M_Furn_WoodLight.tres"))
	var blade := PackedVector2Array([Vector2(-0.1, 0.0), Vector2(-0.3, -0.07), Vector2(-0.46, 0.0), Vector2(-0.3, 0.05)])
	var b := MeshKit.Soup.new()
	MeshKit.extrude_into(b, blade, 0.24, Transform3D(Basis(), Vector3(0, 0, -0.35)))
	MeshKit.inst(shovel_node, b.mesh(), MeshKit.mat("SteelPlate"))
	shovel_load = MeshKit.inst(shovel_node, MeshKit.rock(Vector3(0.2, 0.12, 0.28), 5, 3, 6), MeshKit.mat("ExcavatedDirt"), Vector3(0, 0.03, -0.62))
	shovel_load.visible = false
	shovel_node.rotation = Vector3(0.18, 0.0, 0.0)

func shovel_total() -> float:
	return shovel_dirt + shovel_rock

func aim_hit(max_dist := 5.0) -> Dictionary:
	var cam: Camera3D = player.camera if not driving else loader.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * max_dist
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func aim_point(max_dist := 5.0) -> Variant:
	var hit := aim_hit(max_dist)
	if hit:
		return hit["position"]
	return null

func shovel_dig() -> float:
	var room := SHOVEL_CAPACITY - shovel_total()
	if room <= 0.0005 or shovel_cooldown > 0.0:
		return 0.0
	var p = aim_point()
	if p == null:
		return 0.0
	var res := terrain.cut_disc(p, 0.55, 0.22, room)
	var got: float = res["dirt"] + res["rock"]
	if got <= 0.0:
		return 0.0
	shovel_dirt += res["dirt"]
	shovel_rock += res["rock"]
	shovel_cooldown = 0.35
	shovel_swing = 1.0
	_spray(p + Vector3(0, 0.1, 0), Vector3.UP, 10, res["rock"] > res["dirt"], 1.4)
	return got

func shovel_throw() -> float:
	var t := shovel_total()
	if t <= 0.0005 or shovel_cooldown > 0.0:
		return 0.0
	var hit := aim_hit(6.0)
	if hit.is_empty():
		return 0.0
	var p: Vector3 = hit["position"]
	if hit["collider"] == box_walls:
		p = BOX_CENTER + Vector3(0, 0.4, 0)       # aiming at the box throws the shovelful over its wall
	var rf := shovel_rock / t
	var left := _pour(p, t, rf)
	var moved := t - left
	shovel_rock = maxf(0.0, shovel_rock - moved * rf)
	shovel_dirt = maxf(0.0, shovel_dirt - moved * (1.0 - rf))
	if shovel_total() < 0.0005:
		shovel_dirt = 0.0
		shovel_rock = 0.0
	shovel_cooldown = 0.35
	shovel_swing = -1.0
	_spray(p + Vector3(0, 0.3, 0), Vector3.UP, 14, rf > 0.5, 2.2)
	return moved

# ------------------------------------------------------------------ vehicle entry

func enter_loader() -> bool:
	if driving or player.global_position.distance_to(loader.global_position) > 4.5:
		return false
	driving = true
	loader.driven = true
	loader.camera.current = true
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true

func exit_loader() -> bool:
	if not driving or absf(loader.speed) > 1.0:
		_notify("Brake to a stop first (Space).")
		return false
	var r := loader.global_transform.basis.x
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.75
	for side in [-1.0, 1.0]:
		var p: Vector3 = loader.global_position + r * side * 2.4
		p.y = terrain.height_at(p.x, p.z) + 0.1
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
		q.collision_mask = 1 | 8
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			driving = false
			loader.driven = false
			loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true, "dig": false, "dump": false}
			player.global_position = p
			player.velocity = Vector3.ZERO
			player.collision_layer = 1
			player.process_mode = Node.PROCESS_MODE_INHERIT
			player.visible = true
			player.camera.current = true
			return true
	_notify("No room to get out here.")
	return false

# ------------------------------------------------------------------ effects (visual only)

func _spray(pos: Vector3, dir: Vector3, amount: int, is_rock: bool, power: float) -> void:
	if _headless or _fx_count >= 14:
		return
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 38.0
	p.initial_velocity_min = power * 0.6
	p.initial_velocity_max = power * 1.4
	p.gravity = Vector3(0, -9.8, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.07, 0.07, 0.07)
	p.mesh = m
	p.material_override = MeshKit.mat("RockLimestone" if is_rock else "ExcavatedDirt")
	p.emitting = true
	fx_root.add_child(p)
	_fx_count += 1
	get_tree().create_timer(1.2).timeout.connect(func():
		_fx_count -= 1
		p.queue_free())
	_dust(pos)

func _dust(pos: Vector3) -> void:
	if _headless or _fx_count >= 14:
		return
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 4
	p.lifetime = 1.1
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, 0.1, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	p.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.57, 0.48, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.material_override = mat
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.emitting = true
	fx_root.add_child(p)
	_fx_count += 1
	get_tree().create_timer(1.4).timeout.connect(func():
		_fx_count -= 1
		p.queue_free())

# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_label = Label.new()
	ui_label.position = Vector2(16, 12)
	ui_label.add_theme_font_size_override("font_size", 15)
	ui_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	layer.add_child(ui_label)
	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left = 16
	hint_label.offset_top = -92
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	layer.add_child(hint_label)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size", 24)
	layer.add_child(cross)

func _notify(s: String) -> void:
	message = s
	message_timer = 5.0

func _fmt(v: float) -> String:
	return "%.2f" % v

func _update_hud() -> void:
	var tv := accounted_total()
	var l := "DIG TEST ARENA (prototype)\n"
	l += "Ground %s m3   Bucket %s/%s m3   Shovel %s/%s m3   Box %s/%s m3\n" % [_fmt(terrain.total_volume()), _fmt(loader.load_total()), _fmt(DigLoader.BUCKET_CAPACITY), _fmt(shovel_total()), _fmt(SHOVEL_CAPACITY), _fmt(box_total()), _fmt(BOX_CAPACITY)]
	l += "All material %s m3 (start %s) - %s" % [_fmt(tv), _fmt(initial_total), "NOTHING LOST OR CREATED" if absf(tv - initial_total) < 0.02 else "MISMATCH"]
	ui_label.text = l
	var h := ""
	if driving:
		h = "LOADER  %.1f m/s   WASD drive  Space brake  hold LMB lower bucket and drive into the pile  release carry  hold RMB raise + tip over the box  R recover  E exit" % absf(loader.speed)
	else:
		h = "WASD move  Shift sprint  LMB shovel dig  RMB throw shovelful  E enter loader (stand close)  R reset arena  Esc quit"
	hint_label.text = h + ("\n" + message if message_timer > 0.0 else "")

# ------------------------------------------------------------------ input and loop

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				if driving:
					exit_loader()
				elif not enter_loader():
					_notify("Stand next to the loader and press E.")
			KEY_R:
				if driving:
					loader.global_position += Vector3(0, 0.3, 0)
					loader.speed = 0.0
					_notify("Loader nudged up.")
				else:
					get_tree().reload_current_scene()
			KEY_ESCAPE:
				get_tree().quit()
	if driving and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		loader.rotate_camera(event.relative)

func _physics_process(delta: float) -> void:
	message_timer = maxf(0.0, message_timer - delta)
	shovel_cooldown = maxf(0.0, shovel_cooldown - delta)
	if driving:
		loader.input = {"throttle": Input.get_axis("move_back", "move_forward"), "steer": Input.get_axis("move_left", "move_right"),
			"brake": Input.is_physical_key_pressed(KEY_SPACE), "dig": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "dump": Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)}
		_loader_fx(delta)
	else:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			shovel_dig()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			shovel_throw()
	# shovel model: load mound and a short swing
	shovel_swing = move_toward(shovel_swing, 0.0, delta * 4.0)
	shovel_node.rotation.x = 0.18 + shovel_swing * 0.6
	shovel_load.visible = shovel_total() > 0.004
	if shovel_load.visible:
		shovel_load.scale = Vector3(1, clampf(shovel_total() / SHOVEL_CAPACITY * 1.4, 0.3, 1.4), 1)
		shovel_load.material_override = MeshKit.mat("RockLimestone" if shovel_rock > shovel_dirt else "ExcavatedDirt")
	_update_hud()

func _loader_fx(delta: float) -> void:
	_stream_timer -= delta
	if _stream_timer > 0.0:
		return
	if loader.cutting:
		_stream_timer = 0.12
		_spray(loader.lip_position() + Vector3(0, 0.15, 0), Vector3.UP, 5, terrain.rock_ratio_at(loader.lip_position().x, loader.lip_position().z) > 0.5, 1.6)
	elif loader.pouring:
		_stream_timer = 0.07
		_spray(loader.lip_position() + Vector3(0, -0.1, 0), Vector3.DOWN, 5, loader.rock_fraction() > 0.5, 0.8)
