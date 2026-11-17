extends Node3D
class_name TerrainArena
## On-foot test arena for the real digging ground (QuarryTerrain): a 64 x 64 m field of the quarry's own strata, a dirt pile and a rubble pile, a collection box.
## Launch:  QuarryDays.exe -- --terrain-arena   (or run res://TerrainArena.tscn).
##
##   WASD move, Shift sprint, mouse look, Space jump
##   1 shovel   2 pickaxe   3 hammer
##   LMB   use the tool where you aim (reach 5 m). The shovel scoops into the shovel (0.09 m3); pick and hammer BREAK hard ground into loose rubble in place.
##   RMB   throw the shovelful where you aim (into the box or onto the ground)
##   R     reset the arena      Esc   quit
## What you hit decides what happens and what you hear: soft ground digs, ground harder than the tool bounces the blow with a chink, and the hint tells you which tool to use.
## Every cubic metre is accounted: ground + shovel + box never changes (shown on screen).

const REACH := 5.0
const BOX_CENTER := Vector3(0, 0, -24.0)
const BOX_HALF := Vector2(1.9, 1.3)
const BOX_CAPACITY := 14.0
const BOX_WALL := 1.3
const TOOLS := ["shovel", "pickaxe", "hammer"]

var geo: QuarryGeology
var terrain: QuarryTerrain
var audio: DigAudio
var player: QuarryPlayer
var tool_id := "shovel"
var carry := {}                       ## material id -> m3 on the shovel
var box := {}                         ## material id -> m3 in the box
var cooldown := 0.0
var label: Label
var hint: Label
var message := ""
var message_t := 0.0
var initial_total := 0.0
var particles_live := 0
var fx_root: Node3D
var box_walls: StaticBody3D
var strikes := 0

func _ready() -> void:
	geo = QuarryGeology.new()
	_build_world()
	_build_player()
	_build_hud()
	initial_total = accounted_total()
	_notify("Dig where you aim. 1 shovel, 2 pickaxe, 3 hammer. Shovel into rock goes 'chink': use the pickaxe.")

func tool_def() -> Dictionary:
	return QuarryGeology.data()["tools"][tool_id]

# ------------------------------------------------------------------ world

func _build_world() -> void:
	terrain = QuarryTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(Rect2(-32, -32, 64, 64), geo)
	terrain.lock_ring(4)
	terrain.add_pile(-9.0, -8.0, 5.0, 2.4, "topsoil", 0.15)
	terrain.add_pile(9.0, -8.0, 4.0, 1.8, "limestone", 0.2)
	terrain.add_pile(0.0, 6.0, 2.5, 0.9, "gravel", 0.1)
	terrain.flush(true)
	audio = DigAudio.new()
	audio.name = "DigAudio"
	add_child(audio)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.58, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.68, 0.72)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.3
	add_child(sun)
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)
	_build_box()

func _build_box() -> void:
	box_walls = StaticBody3D.new()
	box_walls.name = "CollectionBox"
	box_walls.position = BOX_CENTER + Vector3(0, terrain.height_at(BOX_CENTER.x, BOX_CENTER.z), 0)
	box_walls.collision_layer = 1
	add_child(box_walls)
	var w := BOX_HALF
	var specs := [[Vector3(0, BOX_WALL * 0.5, -w.y - 0.1), Vector3(w.x * 2 + 0.4, BOX_WALL, 0.2)], [Vector3(0, BOX_WALL * 0.5, w.y + 0.1), Vector3(w.x * 2 + 0.4, BOX_WALL, 0.2)],
		[Vector3(-w.x - 0.1, BOX_WALL * 0.5, 0), Vector3(0.2, BOX_WALL, w.y * 2)], [Vector3(w.x + 0.1, BOX_WALL * 0.5, 0), Vector3(0.2, BOX_WALL, w.y * 2)]]
	var soup := MeshKit.Soup.new()
	for sp in specs:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sp[1]
		cs.shape = sh
		cs.position = sp[0]
		box_walls.add_child(cs)
		MeshKit.box_into(soup, sp[0], sp[1])
	MeshKit.inst(box_walls, soup.mesh(), MeshKit.mat("SteelGreen"))
	terrain.lock_rect(Rect2(BOX_CENTER.x - BOX_HALF.x, BOX_CENTER.z - BOX_HALF.y, BOX_HALF.x * 2, BOX_HALF.y * 2), 1.5)

func box_inside(p: Vector3) -> bool:
	return absf(p.x - BOX_CENTER.x) < BOX_HALF.x and absf(p.z - BOX_CENTER.z) < BOX_HALF.y

static func total_of(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s

## Every cubic metre: ground + shovel + box. Must never change.
func accounted_total() -> float:
	return terrain.total_volume() + total_of(carry) + total_of(box)

# ------------------------------------------------------------------ player and tools

func _build_player() -> void:
	player = QuarryPlayer.new()
	player.name = "Player"
	player.position = Vector3(0, 0.3, 12.0)
	add_child(player)
	player.collision_mask = 1 | 8
	_equip("shovel")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _equip(id: String) -> void:
	tool_id = id
	var t: String = {"shovel": "shovel", "pickaxe": "repaired_pickaxe", "hammer": "sledgehammer"}[id]
	if player != null and player.tool_view != null:
		player.tool_view.equip(GearModels.tier_of(t), true)

func aim_hit(max_dist := REACH) -> Dictionary:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * max_dist, 1)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

## One strike of the current tool at world point p. Returns the dig result (also drives sound, particles and hints). Called at the visible moment of impact.
func strike(p: Vector3) -> Dictionary:
	var td := tool_def()
	var mode := str(td["mode"])
	var room := float(td["capacity"]) - total_of(carry)
	if mode == "scoop" and room <= 0.0005:
		_notify("The shovel is full: throw it (right click) into the box or onto the ground.")
		return {}
	var budget := room if mode == "scoop" else 0.12
	var res := terrain.dig(p, float(td["radius"]), float(td["depth"]), budget, int(td["max_hardness"]), mode)
	strikes += 1
	var hit_mat := str(res["hit"])
	if str(res["blocked_by"]) != "" and float(res["volume"]) + float(res["broken"]) <= 0.00001:
		audio.play("blocked", str(res["blocked_by"]), p, 1.0)
		_spark(p, QuarryGeology.material_props(str(res["blocked_by"])))
		_notify(_too_hard_text(str(res["blocked_by"])))
		return res
	for id in res["taken"]:
		carry[id] = float(carry.get(id, 0.0)) + float(res["taken"][id])
	if float(res["volume"]) + float(res["broken"]) > 0.0:
		audio.play("dig", hit_mat if mode == "scoop" else str(res["hit"]), p, 0.8 + minf(float(res["volume"]) + float(res["broken"]), 0.2) * 3.0)
		_puff(p, QuarryGeology.material_props(hit_mat))
	if str(res["blocked_by"]) != "":
		audio.play("blocked", str(res["blocked_by"]), p, 0.7)
		_notify(_too_hard_text(str(res["blocked_by"])))
	return res

func _too_hard_text(mat: String) -> String:
	var h := geo.hardness(mat)
	var t: Dictionary = QuarryGeology.data()["tools"]
	if h <= int(t["pickaxe"]["max_hardness"]) and tool_id == "shovel":
		return "Too hard for the shovel - use the pickaxe (2)."
	if h <= int(t["hammer"]["max_hardness"]) and tool_id != "hammer":
		return "Too hard - use the hammer (3)."
	return "Nothing breaks this yet."

func throw_load() -> float:
	var t := total_of(carry)
	if t <= 0.0005:
		return 0.0
	var hit := aim_hit(6.0)
	if hit.is_empty():
		return 0.0
	var p: Vector3 = hit["position"]
	return release_load(p, hit["collider"] == box_walls or box_inside(p))

## Puts the whole shovelful at p: into the box when `over_box` (up to its capacity), else onto the ground as loose material. Returns the volume that left the shovel.
func release_load(p: Vector3, over_box: bool) -> float:
	var t := total_of(carry)
	if t <= 0.0005:
		return 0.0
	var main_mat := ""
	var best := -1.0
	for id in carry:
		if float(carry[id]) > best:
			best = float(carry[id])
			main_mat = str(id)
	if over_box:
		var space := maxf(0.0, BOX_CAPACITY - total_of(box))
		var f := minf(1.0, space / t)
		for id in carry.keys():
			var part := float(carry[id]) * f
			box[id] = float(box.get(id, 0.0)) + part
			carry[id] = float(carry[id]) - part
		audio.play("drop", main_mat, p, 1.0)
	else:
		var left := terrain.deposit(p, 0.9, carry)
		carry = left
		audio.play("pour", main_mat, p, 1.0)
	for id in carry.keys():
		if float(carry[id]) < 0.00001:
			carry.erase(id)
	_puff(p, QuarryGeology.material_props(main_mat))
	return t - total_of(carry)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_1: _equip("shovel")
			KEY_2: _equip("pickaxe")
			KEY_3: _equip("hammer")
			KEY_R: get_tree().reload_current_scene()
			KEY_ESCAPE: get_tree().quit()
	if ev is InputEventMouseButton and ev.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			use_tool()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and cooldown <= 0.0:
			cooldown = 0.35
			throw_load()

## Starts a swing; the dig happens at the visible moment of impact.
func use_tool() -> void:
	if cooldown > 0.0 or player.tool_view == null or player.tool_view.is_busy():
		return
	var hit := aim_hit()
	if hit.is_empty():
		return
	var p: Vector3 = hit["position"]
	cooldown = float(tool_def().get("cooldown", 0.45))
	player.tool_view.swing(0.45, func(): strike(p))

# ------------------------------------------------------------------ cosmetic effects (numbers never ride on them)

func _puff(p: Vector3, mp: Dictionary) -> void:
	_burst(p + Vector3(0, 0.1, 0), Color(mp["particle"][0], mp["particle"][1], mp["particle"][2]), 10, 1.4, 0.07)

func _spark(p: Vector3, mp: Dictionary) -> void:
	_burst(p + Vector3(0, 0.1, 0), Color(1.0, 0.85, 0.45), 8, 2.6, 0.03)
	_burst(p + Vector3(0, 0.1, 0), Color(mp["particle"][0], mp["particle"][1], mp["particle"][2]), 4, 1.0, 0.06)

func _burst(p: Vector3, c: Color, n: int, speed: float, size: float) -> void:
	if particles_live >= 14 or DisplayServer.get_name() == "headless":
		return
	particles_live += 1
	var pr := CPUParticles3D.new()
	pr.emitting = false
	pr.one_shot = true
	pr.amount = n
	pr.lifetime = 0.7
	pr.explosiveness = 1.0
	pr.direction = Vector3.UP
	pr.spread = 55.0
	pr.initial_velocity_min = speed * 0.5
	pr.initial_velocity_max = speed
	pr.gravity = Vector3(0, -9.0, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	pr.mesh = bm
	pr.material_override = MeshKit.flat(c)
	pr.position = p
	fx_root.add_child(pr)
	pr.emitting = true
	get_tree().create_timer(1.0).timeout.connect(func():
		particles_live -= 1
		pr.queue_free())

# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(14, 10)
	label.add_theme_font_size_override("font_size", 16)
	layer.add_child(label)
	hint = Label.new()
	hint.position = Vector2(14, 120)
	hint.add_theme_font_size_override("font_size", 18)
	layer.add_child(hint)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(cross)

func _notify(s: String) -> void:
	message = s
	message_t = 3.0

func status_text() -> String:
	var aim := aim_hit()
	var under := "-"
	if not aim.is_empty():
		var m := terrain.material_at_point(aim["position"])
		under = "%s (hardness %d)" % [QuarryGeology.material_props(m)["title"], geo.hardness(m)]
	var c := []
	for id in carry:
		c.append("%s %.3f" % [id, float(carry[id])])
	return "TOOL %s   AIM %s\nSHOVEL %.3f / %.2f m3 %s\nBOX %.2f / %.0f m3\nACCOUNTED %.3f m3 (start %.3f, never changes)" % [tool_id.to_upper(), under, total_of(carry), float(QuarryGeology.data()["tools"]["shovel"]["capacity"]), str(c), total_of(box), BOX_CAPACITY, accounted_total(), initial_total]

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	message_t = maxf(0.0, message_t - delta)
	if label != null:
		label.text = status_text()
		hint.text = message if message_t > 0.0 else ""
