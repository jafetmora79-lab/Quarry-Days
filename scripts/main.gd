extends Node3D

const State = preload("res://scripts/state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const Business = preload("res://scripts/business.gd")
const WorkerScript = preload("res://scripts/worker.gd")
const ManagementScript = preload("res://scripts/management_ui.gd")
const FleetScript = preload("res://scripts/fleet.gd")
const VehicleScript = preload("res://scripts/vehicle.gd")
const SAVE_PATH := "user://quarry_save.json"
const RESOURCE_ORDER := ["limestone", "coal", "iron_ore", "crushed_stone"]
const DEPOSIT_INFO := {"limestone": {"pos": Vector3(-8, 0, -11), "color": Color(0.67, 0.66, 0.56), "pieces": 4, "resource": "limestone"}, "coal": {"pos": Vector3(0, 0, -15), "color": Color(0.17, 0.19, 0.21), "pieces": 3, "resource": "coal"}, "iron_ore": {"pos": Vector3(8, 0, -11), "color": Color(0.52, 0.29, 0.23), "pieces": 2, "resource": "iron_ore"}, "limestone_face": {"pos": Vector3(-12, 0, -18), "color": Color(0.70, 0.68, 0.58), "pieces": 2, "resource": "limestone", "infinite": true, "yaw": -0.65}}
# Phase 2 quarry expansion (east), unlocked by the Automated Business milestone. Same three minerals.
const EXPANSION_DEPOSITS := {"limestone_east": {"pos": Vector3(36, 0, -6), "color": Color(0.67, 0.66, 0.56), "pieces": 4, "resource": "limestone"}, "coal_east": {"pos": Vector3(42, 0, 6), "color": Color(0.17, 0.19, 0.21), "pieces": 3, "resource": "coal"}, "iron_ore_east": {"pos": Vector3(44, 0, -5), "color": Color(0.52, 0.29, 0.23), "pieces": 2, "resource": "iron_ore"}, "limestone_east_2": {"pos": Vector3(35, 0, 6), "color": Color(0.67, 0.66, 0.56), "pieces": 4, "resource": "limestone"}}
var state: QuarryState
var player: QuarryPlayer
var world: Node3D
var ui: Control
var status_label: Label
var action_label: Label
var panel: PanelContainer
var panel_text: Label
var message := "Mine the three deposits. Sell materials to buy a crusher."
var message_timer := 9.0
var menu := ""
var placement := false
var placement_yaw := 0.0
var ghost: Node3D
var ghost_valid := false
var deposit_nodes := {}
var ground_pieces := {}
var crusher_nodes := []
var mining_cooldown := 0.0
var daylight: DirectionalLight3D
var sky_light: WorldEnvironment
var last_target: Node3D
var tutorial_visible := true
var hit_audio: AudioStreamPlayer
var pickup_audio: AudioStreamPlayer
var sell_audio: AudioStreamPlayer
var crusher_audio: AudioStreamPlayer
var material_cache := {}
# Phase 2
var business: QuarryBusiness
var nav_region: NavigationRegion3D
var nav_map: RID
var nav_version := 0
var nav_ready_frame := 0
var nav_dirty := false
var workers_root: Node3D
var worker_nodes := {}
var output_nodes := []
var conveyor_nodes := []
var expansion_gate := []
var management: Control
var milestone_label: Label
var placement_kind := "crusher"
var grid_snap := true
var placement_hint := ""
# Phase 3
var fleet: QuarryFleet
var vehicles_root: Node3D
var vehicle_nodes := {}
var driving: QuarryVehicle
var storage_body: StaticBody3D
var pile_nodes := {}
var construction := false
var relocating := {}
var sell_confirm := ""
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D
var scripted_input := false # tests drive vehicles by setting QuarryVehicle.input directly

func _ready() -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	state = State.new(cfg)
	var bcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))
	business = Business.new(state, bcfg)
	business.milestone_reached.connect(_on_milestone)
	var vcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles.json"))
	fleet = FleetScript.new(business, vcfg)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	_build_quarry()
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0, 0.2, 8)
	add_child(player)
	player.collision_mask = 1 | 2 | 4 | 8 # world, loose pieces, workers, vehicles (conveyors: layer 16, crossable)
	vehicles_root = Node3D.new()
	vehicles_root.name = "Vehicles"
	add_child(vehicles_root)
	workers_root = Node3D.new()
	workers_root.name = "Workers"
	add_child(workers_root)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "QuarryNavigation"
	add_child(nav_region)
	nav_map = get_world_3d().navigation_map
	_setup_ui()
	management = ManagementScript.new()
	management.setup(self)
	ui.add_child(management)
	_rebake_nav()
	hit_audio = _audio("res://audio/pick_hit.wav", -12)
	pickup_audio = _audio("res://audio/pickup.wav", -15)
	sell_audio = _audio("res://audio/sell.wav", -13)
	crusher_audio = _audio("res://audio/crusher_loop.wav", -23)
	var loop_stream: AudioStreamWAV = crusher_audio.stream
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_update_light()

func _audio(path: String, volume: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = volume
	add_child(audio)
	return audio

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if material_cache.has(key):
		return material_cache[key]
	var m := StandardMaterial3D.new()
	var image := Image.create(16,16,false,Image.FORMAT_RGB8)
	for y in range(16):
		for x in range(16):
			var noise := float((x*73+y*151+x*y*19+int(color.r*241))%17)/100.0-0.08
			image.set_pixel(x,y,Color(clampf(color.r+noise,0,1),clampf(color.g+noise,0,1),clampf(color.b+noise,0,1)))
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material_cache[key] = m
	return m

func _solid(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body

func _visual_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.rotation.y = yaw
	mesh.material_override = _mat(color)
	parent.add_child(mesh)
	return mesh

func _build_quarry() -> void:
	_solid(world, "Quarry floor", Vector3(0,-0.25,0), Vector3(58,0.5,58), Color(0.38,0.34,0.28))
	# The lower pit is open toward the office; the stepped rim provides a walkable entrance.
	for i in range(8):
		var angle := (float(i) + 0.5) * TAU / 8.0
		var pos := Vector3(cos(angle)*19, 1.1, -8 + sin(angle)*19)
		if pos.z > 5 and absf(pos.x) < 8:
			continue
		_solid(world, "Excavated rim", pos, Vector3(12,2.2,3.4), Color(0.40,0.36,0.30), -angle-PI/2)
	for i in range(10):
		var angle := float(i)*TAU/10.0
		var cpos := Vector3(cos(angle)*27, 3.0, sin(angle)*27)
		var cliff := _solid(world, "Cliff", cpos, Vector3(10,6,5), Color(0.32+0.025*(i%3),0.32,0.29), -angle-PI/2)
		if i == 0:
			expansion_gate.append(cliff)
	for x in [-20.0,-15.0,15.0,21.0]:
		for z in [-22.0,16.0,22.0]:
			if absf(x) < 19 and z < 0:
				continue
			_solid(world,"Tree trunk",Vector3(x,1.1,z),Vector3(0.5,2.2,0.5),Color(0.24,0.18,0.12))
			_visual_box(world,Vector3(x,2.85,z),Vector3(2.1,2.5,2.1),Color(0.13,0.24,0.16))
	_building("Office", Vector3(-14,0,12), Color(0.48,0.42,0.31))
	_building("Storage shed", Vector3(14,0,12), Color(0.38,0.37,0.31))
	var sell := _solid(world,"Selling station",Vector3(-7,0.85,10),Vector3(2.2,1.7,1.25),Color(0.37,0.26,0.14))
	sell.set_meta("kind","sell")
	var shop := _solid(world,"Upgrade board",Vector3(-14,1.2,8.6),Vector3(2.1,1.4,0.25),Color(0.15,0.26,0.27))
	shop.set_meta("kind","upgrades")
	var storage := _solid(world,"Storage crate",Vector3(10,0.65,10),Vector3(2,1.3,1.6),Color(0.33,0.23,0.13))
	storage.set_meta("kind","storage")
	storage.set_meta("index",0)
	storage_body = storage
	var machine_shop := _solid(world,"Crusher order kiosk",Vector3(-2,0.75,10),Vector3(1.4,1.5,1.0),Color(0.30,0.38,0.42))
	machine_shop.set_meta("kind","shop")
	for kind in DEPOSIT_INFO:
		_build_deposit(kind)
	_build_phase2_area()
	_build_phase3_area()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34,0.47,0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62,0.65,0.70)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sky_light = WorldEnvironment.new()
	sky_light.environment = env
	add_child(sky_light)
	daylight = DirectionalLight3D.new()
	daylight.rotation_degrees = Vector3(-46,-24,0)
	daylight.light_energy = 1.4
	add_child(daylight)

func _building(label: String, pos: Vector3, color: Color) -> void:
	_solid(world,label+" floor",pos+Vector3(0,0.08,0),Vector3(5,0.16,4.8),color)
	_solid(world,label+" left",pos+Vector3(-2.4,1.4,0),Vector3(0.22,2.8,4.8),color)
	_solid(world,label+" right",pos+Vector3(2.4,1.4,0),Vector3(0.22,2.8,4.8),color)
	_solid(world,label+" back",pos+Vector3(0,1.4,2.35),Vector3(5,2.8,0.22),color)
	_solid(world,label+" front left",pos+Vector3(-1.6,1.4,-2.35),Vector3(1.8,2.8,0.22),color)
	_solid(world,label+" front right",pos+Vector3(1.6,1.4,-2.35),Vector3(1.8,2.8,0.22),color)
	_solid(world,label+" roof",pos+Vector3(0,2.92,0),Vector3(5.4,0.27,5.2),Color(0.24,0.25,0.26))

func _deposit_info(kind: String) -> Dictionary:
	if DEPOSIT_INFO.has(kind):
		return DEPOSIT_INFO[kind]
	return EXPANSION_DEPOSITS.get(kind, {})

func _build_deposit(kind: String) -> void:
	var info: Dictionary = _deposit_info(kind)
	state.ensure_deposit(kind, str(info["resource"]), bool(info.get("infinite", false)))
	var face := bool(info.get("infinite", false))
	var body := _solid(world,kind+" deposit",info["pos"]+Vector3(0,1.2 if face else 0.9,0),Vector3(3.6,2.4,1.4) if face else Vector3(2.4,1.8,2.0),info["color"],float(info.get("yaw", 0.4)))
	var status := Label3D.new()
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	status.font_size = 28
	status.pixel_size = 0.006
	status.outline_size = 6
	status.position = Vector3(0, 1.55 if face else 1.35, 0)
	status.visibility_range_end = 16.0
	status.no_depth_test = false
	body.add_child(status)
	body.set_meta("status", status)
	body.set_meta("kind","deposit")
	body.set_meta("resource",info["resource"])
	body.set_meta("deposit",kind)
	deposit_nodes[kind] = body
	_refresh_deposit(kind)

func _refresh_deposit(kind: String) -> void:
	if not deposit_nodes.has(kind):
		return
	var info := _deposit_info(kind)
	var d: Dictionary = state.ensure_deposit(kind, str(info["resource"]), bool(info.get("infinite", false)))
	var body: StaticBody3D = deposit_nodes[kind]
	# Phase 4: deposits never vanish. They shrink with their stock and stay solid; the label says what is left.
	body.visible = true
	body.collision_layer = 1
	var ratio := float(d["stock"]) / float(state.deposit_max(str(d["resource"])))
	var mesh: MeshInstance3D = body.get_child(0)
	mesh.scale = Vector3.ONE * (0.42 + 0.58 * ratio) * (1.0 - float(d["hits"]) * 0.03)
	mesh.position.y = -0.9 * (1.0 - (0.42 + 0.58 * ratio)) if not bool(d.get("infinite", false)) else 0.0
	_update_deposit_label(kind)
	if mesh.get_child_count() > 0:
		for child in mesh.get_children():
			child.queue_free()
	if int(d["hits"]) > 0 and not bool(d["broken"]):
		for n in range(int(d["hits"])):
			_visual_box(mesh,Vector3(-0.5+0.22*n,0.36,1.01),Vector3(0.025,0.35,0.025),Color(0.07,0.07,0.06),0.3*n)

func _spawn_pieces(kind: String, count: int) -> void:
	# Indices beyond the deposit's base count are bonus pieces (miner yield upgrade).
	for i in range(count):
		_spawn_piece(kind, int(state.deposits[kind].get("generation", 0)), i)

func _spawn_piece(kind: String, generation: int, i: int) -> void:
	var info := _deposit_info(kind)
	var count: int = int(info["pieces"])
	var center: Vector3 = info["pos"]
	var angle := TAU * float(i)/float(count) + 0.3
	var radius := 1.85 # Phase 4: pieces land just outside the (still solid) rock
	if i >= count:
		angle = TAU * (float(i - count) + 0.5) / float(count) + 0.3
		radius = 2.3
	if bool(info.get("infinite", false)):
		var fwd := Vector3(sin(float(info["yaw"])), 0, cos(float(info["yaw"])))
		var side := Vector3(fwd.z, 0, -fwd.x)
		center += fwd * 1.5 + side * (0.6 * float(i) - 0.3)
		angle = 0.0
		radius = 0.0
	var body := _solid(world,"Loose "+kind, center+Vector3(cos(angle)*radius,0.27,sin(angle)*radius),Vector3(0.44,0.46,0.42),info["color"],angle)
	body.collision_layer = 2 # walkable for workers; player still collides (mask)
	body.set_meta("kind","piece")
	body.set_meta("resource",info["resource"])
	body.set_meta("deposit",kind)
	body.set_meta("piece_id",kind+"_"+str(generation)+"_"+str(i))
	ground_pieces[str(body.get_meta("piece_id"))] = body

func _strike(kind: String, hits_needed := -1, extra_pieces := 0, by_player := true) -> void:
	var d: Dictionary = state.deposits[kind]
	if bool(d["broken"]):
		if by_player:
			player.swing_pickaxe()
			_notify(_deposit_status(kind))
		return
	if bool(d.get("infinite", false)) and hits_needed < 0:
		hits_needed = int(state.config.get("quarry_face", {}).get("hits", 5))
	d["hits"] = int(d["hits"]) + 1
	var need: int = state.required_hits() if hits_needed < 0 else maxi(1, hits_needed)
	if by_player:
		player.swing_pickaxe()
		hit_audio.play()
	elif player and player.global_position.distance_to(deposit_nodes[kind].global_position) < 16.0:
		hit_audio.play()
	if int(d["hits"]) >= need:
		d["hits"] = 0
		d["generation"] = int(d.get("generation", 0)) + 1
		var n := state.mine_yield(kind, int(_deposit_info(kind)["pieces"]) + maxi(0, extra_pieces))
		_spawn_pieces(kind, n)
		if by_player:
			# Pieces you break are yours for a while; staff will not snatch them from under you.
			for id in ground_pieces:
				if str(id).begins_with(kind + "_" + str(d["generation"]) + "_"):
					ground_pieces[id].set_meta("claim_until", state.clock_minutes + 15.0)
			_notify("%s breaks into %d pieces! Pick them up with E. %s" % [str(_deposit_info(kind)["resource"]).capitalize(), n, _deposit_status(kind)])
	elif by_player:
		_notify("Crack! "+str(need-int(d["hits"]))+" strikes remaining")
	_refresh_deposit(kind)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	status_label = Label.new()
	status_label.position = Vector2(18,13)
	status_label.add_theme_font_size_override("font_size",17)
	ui.add_child(status_label)
	action_label = Label.new()
	action_label.position = Vector2(18,448)
	action_label.add_theme_font_size_override("font_size",17)
	ui.add_child(action_label)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size",26)
	ui.add_child(cross)
	panel = PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(250,80)
	panel.custom_minimum_size = Vector2(470,350)
	ui.add_child(panel)
	panel_text = Label.new()
	panel_text.add_theme_font_size_override("font_size",17)
	panel.add_child(panel_text)
	milestone_label = Label.new()
	milestone_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	milestone_label.offset_left = -330
	milestone_label.offset_right = -14
	milestone_label.offset_top = 12
	milestone_label.offset_bottom = 110
	milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	milestone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	milestone_label.add_theme_font_size_override("font_size",12)
	milestone_label.add_theme_color_override("font_color",Color(0.93,0.88,0.74))
	milestone_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	milestone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(milestone_label)

func _notify(s: String) -> void:
	message = s
	message_timer = 3.0

func _look_target() -> Node3D:
	var start := player.camera.global_position
	var end := start - player.camera.global_transform.basis.z * 4.0
	var query := PhysicsRayQueryParameters3D.create(start,end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit["collider"] is Node3D:
		return hit["collider"]
	return null

func _physics_process(delta: float) -> void:
	if menu != "":
		return
	state.tick(delta)
	business.tick(delta)
	fleet.tick()
	if nav_dirty:
		_rebake_nav()
	for w in worker_nodes.values():
		w.step(delta)
	if driving and not scripted_input:
		driving.input = {"throttle": Input.get_axis("move_back", "move_forward"), "steer": Input.get_axis("move_left", "move_right"), "brake": Input.is_physical_key_pressed(KEY_SPACE)}
	for v in vehicle_nodes.values():
		v.control(delta)
	_update_structures()
	_update_piles()
	mining_cooldown = maxf(0,mining_cooldown-delta)
	message_timer = maxf(0,message_timer-delta)
	_update_light()
	for kind in state.regrow_deposits():
		_refresh_deposit(kind)
	if Engine.get_physics_frames() % 30 == 0:
		for kind in deposit_nodes:
			_update_deposit_label(kind)
	last_target = null if driving else _look_target()
	if placement:
		_update_ghost()
	elif not driving and not construction and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mining_cooldown <= 0:
		mining_cooldown = state.strike_interval()
		if last_target and last_target.get_meta("kind", "") == "deposit":
			_strike(str(last_target.get_meta("deposit")))
		else:
			player.swing_pickaxe()
	var clock := int(state.clock_minutes)
	var items := ""
	for key in RESOURCE_ORDER:
		if int(state.inventory[key]) > 0:
			items += "  "+key.replace("_"," ")+": "+str(state.inventory[key])
	status_label.text = "DAY %d  %02d:%02d     $%d     BAG %d/%d\n%s" % [clock / 1440 + 1, (clock / 60) % 24, clock % 60, state.money, state.total(state.inventory), state.capacity(), items]
	var prompt := ""
	if last_target:
		match str(last_target.get_meta("kind","")):
			"deposit": prompt = "Hold LMB: mine %s  -  %s" % [str(last_target.get_meta("resource")).replace("_", " "), _deposit_status(str(last_target.get_meta("deposit")))]
			"piece": prompt = "E: collect "+str(last_target.get_meta("resource"))
			"crusher": prompt = "E: use crusher"
			"sell": prompt = "E: sell materials"
			"shop": prompt = "E: order machinery"
			"output": prompt = "E: output storage"
			"conveyor": prompt = "Conveyor #%d" % (int(last_target.get_meta("index")) + 1)
			"office": prompt = "E: management office"
			"worker":
				var who := business.employee(int(last_target.get_meta("employee")))
				if not who.is_empty():
					prompt = "%s (%s): %s" % [who["name"], business.profession(who["profession"])["title"], who["task"]]
			"upgrades": prompt = "E: upgrades"
			"storage": prompt = "E: storage"
			"vehicle":
				var vrec := fleet.vehicle(int(last_target.get_meta("vehicle_id")))
				if not vrec.is_empty():
					prompt = "E: drive %s (%d/%d %s)" % [fleet.spec(vrec["type"])["title"], fleet.cargo_total(vrec), fleet.capacity(vrec), "in bucket" if vrec["type"] == "loader" else "in bed"]
			"pile":
				prompt = "%s: %d units - scoop it with a front loader" % [fleet.cfg["piles"][str(last_target.get_meta("pile"))]["title"], int(fleet.piles[str(last_target.get_meta("pile"))]["amount"])]
	if construction and not placement:
		prompt = _construction_prompt()
	if driving:
		prompt = _driving_hud()
	if placement:
		prompt = "PLACE %s: %s | LMB place | R rotate | G grid %s | Esc cancel%s" % [placement_kind.replace("output","output storage").to_upper(), "VALID" if ghost_valid else "BLOCKED", "on" if grid_snap else "off", placement_hint]
	action_label.text = prompt + ("\n"+message if message_timer > 0 else "") + ("\nWASD move  Shift sprint  E interact  M manage  B build mode  F5 save  F9 load  Esc pause" if tutorial_visible and not driving else "")
	_update_milestone_hud()
	for i in range(state.crushers.size()):
		var machine: Dictionary = state.crushers[i]
		if i < crusher_nodes.size():
			crusher_nodes[i].get_child(0).rotation.z = sin(Time.get_ticks_msec()*0.02)*0.025 if bool(machine["running"]) else 0.0
	var any_running := false
	for crusher in state.crushers:
		any_running = any_running or bool(crusher["running"])
	if any_running and not crusher_audio.playing:
		crusher_audio.play()
	elif not any_running and crusher_audio.playing:
		crusher_audio.stop()

func _update_light() -> void:
	var phase := fposmod(state.clock_minutes,1440.0)/1440.0
	var elevation := sin(phase*TAU-PI/2.0)
	var day := clampf((elevation+0.17)*1.5,0.0,1.0)
	daylight.rotation_degrees.x = -25.0-65.0*maxf(0.0,elevation)
	daylight.light_energy = 0.14+day*1.4
	sky_light.environment.background_color = Color(0.025,0.04,0.09).lerp(Color(0.36,0.49,0.62),day)
	sky_light.environment.ambient_light_energy = 0.14+day*0.4

func _unhandled_input(event: InputEvent) -> void:
	if driving and menu == "" and _driving_input(event):
		return
	if event.is_action_pressed("ui_cancel"):
		if placement:
			_cancel_placement()
		elif construction and menu == "":
			construction = false
			_notify("Construction mode off")
		elif menu != "":
			_close_menu()
		else:
			_open_menu("pause")
		get_viewport().set_input_as_handled()
		return
	if menu == "manage":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
			_close_menu()
			get_viewport().set_input_as_handled()
		return
	if menu != "":
		if event is InputEventKey and event.pressed and not event.echo:
			_menu_key(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M and not placement:
		if business.milestones["first_employee"]:
			_open_menu("manage")
		else:
			_notify("Visit the management desk in the office. Remote management unlocks after your first hire.")
		return
	if event.is_action_pressed("save_game"):
		_save()
	if event.is_action_pressed("load_game"):
		_load()
	if placement:
		var step := PI/2.0
		if placement_kind == "conveyor":
			step = PI/4.0 if grid_snap else PI/12.0
		if event.is_action_pressed("rotate_machine"):
			placement_yaw += step
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
			grid_snap = not grid_snap
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				placement_yaw += step
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_place_ghost()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		construction = not construction
		sell_confirm = ""
		_notify("Construction mode: aim at a crusher, conveyor, storage crate or output storage. LMB move, X sell, B exit." if construction else "Construction mode off")
		return
	if construction:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var t := _construction_target()
			if not t.is_empty():
				start_relocation(str(t["kind"]), int(t["index"]))
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X:
			var t := _construction_target()
			if not t.is_empty():
				request_sell(str(t["kind"]), int(t["index"]))
		return
	if event.is_action_pressed("place_machine"):
		_notify("Order machinery at the blue kiosk first.")
	if event.is_action_pressed("interact") and last_target:
		_interact(last_target)

func _interact(target: Node3D) -> void:
	match str(target.get_meta("kind","")):
		"piece":
			var kind := str(target.get_meta("resource"))
			if state.add_item(kind,1) == 1:
				ground_pieces.erase(str(target.get_meta("piece_id")))
				target.queue_free()
				pickup_audio.play()
				_notify("Collected "+kind)
			else:
				_notify("Backpack full")
		"sell", "upgrades", "storage", "crusher", "output", "shop":
			_open_menu(str(target.get_meta("kind")),int(target.get_meta("index",-1)))
		"office":
			_open_menu("manage")
		"vehicle":
			var v = vehicle_nodes.get(int(target.get_meta("vehicle_id")))
			if v:
				enter_vehicle(v)

func _open_menu(kind: String, index := -1) -> void:
	menu = kind
	panel.set_meta("crusher_index",index)
	panel.visible = kind != "manage"
	management.visible = kind == "manage"
	if kind == "manage":
		management.refresh()
	player.locked = true
	if crusher_audio.playing:
		crusher_audio.stream_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_draw_menu()

func _close_menu() -> void:
	menu = ""
	panel.visible = false
	management.visible = false
	player.locked = false
	crusher_audio.stream_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _draw_menu() -> void:
	var text := ""
	match menu:
		"pause": text = "PAUSED\n\nF5 Save     F9 Load\nEsc Resume"
		"sell":
			text = "SELLING STATION   $%d\n\n" % state.money
			for i in range(RESOURCE_ORDER.size()):
				var key: String = RESOURCE_ORDER[i]
				text += "%d  Sell all %s (%d)  $%d each   clerk:%s\n" % [i+1,key.replace("_"," "),state.inventory[key],state.config["prices"][key],"SELLS" if business.authorized[key] else "no"]
			text += "\nShift+1-4 toggle what the sales clerk may sell\nEsc Close"
		"upgrades":
			text = "UPGRADES   $%d\n\n" % state.money
			for i in range(QuarryState.UPGRADE_NAMES.size()):
				var key: String = QuarryState.UPGRADE_NAMES[i]
				text += "%d  %s   %s\n" % [i+1,key.replace("_"," ").capitalize(),"OWNED" if state.upgrades[key] else "$"+str(state.config["upgrades"][key])]
			text += "\nEsc Close"
		"storage":
			text = "STORAGE  %d/%d\n\n" % [state.total(state.storage),state.storage_capacity()]
			for i in range(RESOURCE_ORDER.size()):
				var key: String = RESOURCE_ORDER[i]
				text += "%d  %s  bag:%d  stored:%d\n" % [i+1,key.replace("_"," "),state.inventory[key],state.storage[key]]
			text += "\n1–4 deposit all  |  Shift+1–4 withdraw all\nEsc Close"
		"crusher":
			var index: int = int(panel.get_meta("crusher_index"))
			if index >= 0 and index < state.crushers.size():
				var c: Dictionary = state.crushers[index]
				text = "STONE CRUSHER #%d\n\nHopper (automated feed): %d\nLimestone input: %d  (bag: %d)\nCrushed output: %d\n%s\n\n1 Load all limestone\n2 Start processing\n3 Collect output\n4 Move hopper into input\nEsc Close" % [index+1,c.get("hopper",0),c["input"],state.inventory["limestone"],c["output"],"Running: %.1f sec" % c["remaining"] if c["running"] else "Idle"]
		"output":
			var oi: int = int(panel.get_meta("crusher_index"))
			if oi >= 0 and oi < business.outputs.size():
				var items: Dictionary = business.outputs[oi]["items"]
				text = "OUTPUT STORAGE #%d   %d/%d\n\n" % [oi+1,business.output_total(oi),business.output_capacity()]
				for i in range(RESOURCE_ORDER.size()):
					var key: String = RESOURCE_ORDER[i]
					text += "%d  %s  stored:%d  bag:%d\n" % [i+1,key.replace("_"," "),items[key],state.inventory[key]]
				text += "\n1-4 withdraw all into bag\nShift+4 deposit crushed stone from bag\nEsc Close"
		"shop":
			text = "MACHINERY ORDERS   $%d\n\n" % state.money
			text += "1  Stone crusher      $%d\n" % int(state.config["crusher_price"])
			text += "2  Output storage     $%d\n" % int(business.cfg["output_storage_price"])
			if business.conveyors_unlocked():
				text += "3  Conveyor section   $%d\n" % int(business.cfg["conveyor_price"])
			else:
				text += "3  Conveyor section   LOCKED\n   (Milestone: own a crusher + hire an operator)\n"
			text += "\nPlacement: R rotate, G toggle grid snap, LMB place\nEsc Close"
	panel_text.text = text

func _menu_key(event: InputEventKey) -> void:
	if event.keycode == KEY_F5:
		_save()
	elif event.keycode == KEY_F9:
		_load()
	var digit := int(event.physical_keycode) - KEY_1
	if digit < 0 or digit > 4:
		_draw_menu()
		return
	match menu:
		"sell":
			if digit < RESOURCE_ORDER.size() and event.shift_pressed:
				business.authorized[RESOURCE_ORDER[digit]] = not business.authorized[RESOURCE_ORDER[digit]]
			elif digit < RESOURCE_ORDER.size():
				var sold := state.sell(RESOURCE_ORDER[digit],999)
				if sold > 0:
					sell_audio.play()
				_notify("Sold %d units" % sold)
		"upgrades":
			if state.buy_upgrade(QuarryState.UPGRADE_NAMES[digit]):
				_notify("Upgrade purchased")
			else:
				_notify("Unavailable or insufficient funds")
		"storage":
			if digit < RESOURCE_ORDER.size():
				if event.shift_pressed:
					state.withdraw_item(RESOURCE_ORDER[digit],999)
				else:
					state.deposit_item(RESOURCE_ORDER[digit],999)
		"crusher":
			var index: int = int(panel.get_meta("crusher_index"))
			match digit:
				0: state.load_crusher(index,999)
				1: state.start_crusher(index)
				2: state.collect_crusher(index)
				3:
					while business.hopper_to_input(index) > 0:
						pass
		"output":
			var oi: int = int(panel.get_meta("crusher_index"))
			if digit < RESOURCE_ORDER.size() and oi >= 0 and oi < business.outputs.size():
				var key: String = RESOURCE_ORDER[digit]
				var items: Dictionary = business.outputs[oi]["items"]
				if event.shift_pressed:
					if key == "crushed_stone":
						var moved := mini(int(state.inventory[key]), business.output_capacity() - business.output_total(oi))
						state.inventory[key] -= moved
						items[key] += moved
				else:
					var taken := state.add_item(key, int(items[key]))
					items[key] -= taken
		"shop":
			match digit:
				0: _start_placement("crusher")
				1: _start_placement("output")
				2: _start_placement("conveyor")
			return
	_draw_menu()

func placement_valid(pos: Vector3, yaw: float) -> bool:
	if not in_build_area(pos) or pos.distance_to(Vector3(0,0,8))<2.0 or not _on_ground(pos) or _near_vehicle(pos, 3.0):
		return false
	for body in world.get_children():
		if body == ghost or not body is StaticBody3D or body.name == "Quarry floor" or body.has_meta("ground"):
			continue
		if not body.collision_layer:
			continue
		var d: Vector3 = body.position - pos
		if absf(d.x)<2.1 and absf(d.z)<2.1:
			return false
	for i in range(state.crushers.size()):
		if str(relocating.get("kind", "")) == "crusher" and int(relocating["index"]) == i:
			continue
		var p: Array = state.crushers[i]["position"]
		if Vector2(pos.x,pos.z).distance_to(Vector2(float(p[0]),float(p[2])))<2.5:
			return false
	return true

## Buildable ground: the original quarry floor, plus the east expansion once it is open.
func in_build_area(pos: Vector3, margin := 0.0) -> bool:
	if absf(pos.x) <= 23.5 - margin and absf(pos.z) <= 23.5 - margin and pos.z >= -6.0:
		return true
	return business.expansion_unlocked and pos.x >= 31.0 + margin and pos.x <= 47.5 - margin and absf(pos.z) <= 11.5 - margin

## True when a downward ray at pos lands on open quarry ground (not a structure or slab).
func _on_ground(pos: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 3, 0), pos - Vector3(0, 1, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit:
		return false
	var body: Node = hit["collider"]
	return body.name == "Quarry floor" or body.has_meta("ground")

func _near_vehicle(pos: Vector3, radius: float) -> bool:
	for v in vehicle_nodes.values():
		if Vector2(pos.x, pos.z).distance_to(Vector2(v.global_position.x, v.global_position.z)) < radius:
			return true
	return false

func _update_ghost() -> void:
	var start := player.camera.global_position
	var dir := -player.camera.global_transform.basis.z
	if absf(dir.y)<0.06:
		ghost.visible = false
		ghost_valid = false
		return
	var distance := -start.y/dir.y
	if distance < 0 or distance > 9:
		ghost.visible = false
		ghost_valid = false
		return
	var point := start+dir*distance
	if grid_snap or placement_kind != "conveyor":
		ghost.position = Vector3(snappedf(point.x,0.5),0,snappedf(point.z,0.5))
	else:
		ghost.position = Vector3(point.x,0,point.z)
	ghost.rotation.y = placement_yaw
	ghost.visible = true
	placement_hint = ""
	if placement_kind == "conveyor":
		ghost_valid = conveyor_valid(ghost.position,placement_yaw)
		var link := business.link_for(ghost.position,placement_yaw)
		placement_hint = "\nIN: %s  ->  OUT: %s" % [business.describe_ep(link["src"]), business.describe_ep(link["dst"])]
	else:
		ghost_valid = placement_valid(ghost.position,placement_yaw)
	if ghost_ok_mat == null:
		ghost_ok_mat = StandardMaterial3D.new()
		ghost_ok_mat.albedo_color = Color(0.35, 0.95, 0.4, 0.5)
		ghost_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_ok_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_bad_mat = ghost_ok_mat.duplicate()
		ghost_bad_mat.albedo_color = Color(1.0, 0.25, 0.2, 0.5)
	for child in ghost.get_children():
		if child is MeshInstance3D:
			child.material_override = ghost_ok_mat if ghost_valid else ghost_bad_mat

func _place_ghost() -> void:
	if not ghost_valid:
		_notify("Blocked. Choose clear, level ground.")
		return
	if not relocating.is_empty():
		_finish_relocation()
		return
	match placement_kind:
		"crusher":
			state.new_crusher(ghost.position,placement_yaw)
			_create_crusher(state.crushers.size()-1)
			_notify("Crusher placed! E to load and process limestone.")
		"output":
			_create_output(business.add_output(ghost.position,placement_yaw))
			_notify("Output storage placed. Place it beside a crusher's chute or at a conveyor end.")
		"conveyor":
			_create_conveyor(business.add_conveyor(ghost.position,placement_yaw))
			_notify("Conveyor placed. The yellow arrow shows the direction of travel.")
	business.compute_links()
	business.check_milestones()
	nav_dirty = true
	_cancel_placement(false)

func _placement_price(kind: String) -> int:
	match kind:
		"output": return int(business.cfg["output_storage_price"])
		"conveyor": return int(business.cfg["conveyor_price"])
	return int(state.config["crusher_price"])

func _start_placement(kind: String) -> void:
	if kind == "conveyor" and not business.conveyors_unlocked():
		_notify("Conveyors unlock with the Mechanized Quarry milestone.")
		return
	if not business.buy(_placement_price(kind)):
		_notify("Need $%d" % _placement_price(kind))
		_draw_menu()
		return
	_close_menu()
	placement = true
	placement_kind = kind
	placement_yaw = 0.0
	ghost = Node3D.new()
	world.add_child(ghost)
	match kind:
		"crusher": _crusher_visual(ghost,true)
		"output": _output_visual(ghost,true)
		"conveyor": _conveyor_visual(ghost,true)
	_notify("Choose a clear patch of ground. R rotates, G toggles grid snap, LMB places.")

func _cancel_placement(refund := true) -> void:
	if not relocating.is_empty():
		_restore_relocated() # cancel a move: original spot, no money involved
		refund = false
	if refund:
		state.money += _placement_price(placement_kind)
	placement = false
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func _crusher_visual(parent: Node3D, transparent := false) -> void:
	_visual_box(parent,Vector3(0,0.5,0),Vector3(1.6,1.0,1.4),Color(0.19,0.25,0.27))
	_visual_box(parent,Vector3(0,1.16,0),Vector3(1.1,0.44,1.0),Color(0.44,0.39,0.28))
	_visual_box(parent,Vector3(0,0.15,-0.68),Vector3(1.15,0.24,0.24),Color(0.12,0.13,0.14))
	if transparent:
		for child in parent.get_children():
			child.transparency = 0.45

func _create_crusher(index: int) -> void:
	var data: Dictionary = state.crushers[index]
	var p: Array = data["position"]
	var body := _solid(world,"Stone crusher",Vector3(float(p[0]),0.57,float(p[2])),Vector3(1.8,1.14,1.6),Color(0.22,0.27,0.29),float(data["yaw"]))
	body.set_meta("kind","crusher")
	body.set_meta("index",index)
	_visual_box(body,Vector3(0,0.68,0),Vector3(1.0,0.45,1.0),Color(0.44,0.39,0.28))
	crusher_nodes.append(body)

func _save() -> void:
	if placement:
		_cancel_placement()
	state.player_position = [player.position.x,player.position.y,player.position.z]
	state.player_yaw = player.rotation.y
	var pieces := []
	for id in ground_pieces:
		pieces.append(id)
	for e in business.employees:
		var w = worker_nodes.get(int(e["id"]))
		if w:
			e["position"] = [w.global_position.x, w.global_position.y, w.global_position.z]
			e["yaw"] = w.rotation.y
	for v in vehicle_nodes.values():
		var rec := fleet.vehicle(v.vehicle_id)
		if not rec.is_empty():
			v.save_into(rec)
	fleet.driving_id = driving.vehicle_id if driving else -1
	var data := state.snapshot()
	data["pieces"] = pieces
	data["phase2"] = business.snapshot()
	data["phase3"] = fleet.snapshot()
	var f := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		_notify("Saved quarry progress")
	else:
		_notify("Save failed")

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_notify("No save yet")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or not data.has("pieces") or not state.restore(data):
		_notify("Save could not be read")
		return
	var phase2 = data.get("phase2", {})
	business.restore(phase2 if phase2 is Dictionary else {})
	var phase3 = data.get("phase3", {})
	fleet.restore(phase3 if phase3 is Dictionary else {})
	var resume_driving := fleet.driving_id
	_reset_driving()
	construction = false
	if placement:
		_cancel_placement(false)
	for body in ground_pieces.values():
		body.queue_free()
	ground_pieces.clear()
	for body in crusher_nodes:
		body.queue_free()
	crusher_nodes.clear()
	for body in output_nodes + conveyor_nodes:
		body.queue_free()
	output_nodes.clear()
	conveyor_nodes.clear()
	for w in worker_nodes.values():
		w.queue_free()
	worker_nodes.clear()
	_set_expansion(business.expansion_unlocked)
	for kind in deposit_nodes:
		_refresh_deposit(kind)
	var ids := {}
	for id in data["pieces"]:
		ids[str(id)] = true
	for id in ids:
		var parts: PackedStringArray = str(id).split("_")
		if parts.size() >= 3:
			var kind := "_".join(parts.slice(0,parts.size()-2))
			if deposit_nodes.has(kind):
				_spawn_piece(kind,int(parts[parts.size()-2]),int(parts[parts.size()-1]))
	for i in range(state.crushers.size()):
		_create_crusher(i)
	for i in range(business.outputs.size()):
		_create_output(i)
	for i in range(business.conveyors.size()):
		_create_conveyor(i)
	_place_storage_body()
	business.compute_links()
	_sync_workers()
	_sync_vehicles(true)
	_rebake_nav()
	var p: Array = state.player_position
	player.position = Vector3(float(p[0]),maxf(0.05,float(p[1])),float(p[2]))
	player.rotation.y = state.player_yaw
	player.velocity = Vector3.ZERO
	_update_light()
	if menu != "":
		_close_menu()
	if resume_driving >= 0 and vehicle_nodes.has(resume_driving):
		enter_vehicle(vehicle_nodes[resume_driving])
	_notify("Loaded quarry progress")

# ===================================================================== Phase 2

func _on_milestone(id: String) -> void:
	match id:
		"first_employee": _notify("Milestone: First Employee - remote management (M) and +5% productivity unlocked")
		"mechanized": _notify("Milestone: Mechanized Quarry - conveyor belts unlocked at the kiosk")
		"automated":
			_notify("Milestone: Automated Business - the east quarry expansion is open!")
			_set_expansion(true)

func fmt_time(minutes: int) -> String:
	return "%02d:%02d" % [posmod(minutes, 1440) / 60, posmod(minutes, 60)]

func _build_phase2_area() -> void:
	var floor_body := _solid(world, "Expansion floor", Vector3(39,-0.25,0), Vector3(20,0.5,26), Color(0.36,0.33,0.27))
	floor_body.set_meta("ground", true)
	_solid(world, "Expansion cliff", Vector3(39,3,-14), Vector3(22,6,2), Color(0.33,0.32,0.29))
	_solid(world, "Expansion cliff", Vector3(39,3,14), Vector3(22,6,2), Color(0.34,0.32,0.29))
	_solid(world, "Expansion cliff", Vector3(50,3,0), Vector3(2,6,30), Color(0.32,0.31,0.28))
	var barrier := _solid(world, "Rockfall barrier", Vector3(29.6,2.0,0), Vector3(1.2,4.0,26), Color(0.42,0.37,0.31))
	expansion_gate.append(barrier)
	var desk := _solid(world, "Management desk", Vector3(-14,0.5,13.4), Vector3(1.8,1.0,0.8), Color(0.30,0.20,0.12))
	desk.set_meta("kind", "office")
	_visual_box(desk, Vector3(-0.4,0.62,0), Vector3(0.5,0.24,0.06), Color(0.12,0.2,0.16))
	_solid(world, "Break bench", Vector3(-9.6,0.25,15.3), Vector3(2.6,0.5,0.6), Color(0.33,0.22,0.12))

## Shows or hides the east expansion. Locked: barrier + cliff in place, no deposits there.
func _set_expansion(unlocked: bool) -> void:
	for body in expansion_gate:
		body.visible = not unlocked
		body.collision_layer = 0 if unlocked else 1
		body.set_meta("nav_skip", unlocked)
	for kind in EXPANSION_DEPOSITS:
		if unlocked and not deposit_nodes.has(kind):
			_build_deposit(kind)
		elif not unlocked and deposit_nodes.has(kind):
			deposit_nodes[kind].queue_free()
			deposit_nodes.erase(kind)
			for id in ground_pieces.keys():
				if str(ground_pieces[id].get_meta("deposit")) == kind:
					ground_pieces[id].queue_free()
					ground_pieces.erase(id)
	_refresh_pile_presence()
	nav_dirty = true

# --------------------------------------------------------------- navigation

func _box_faces(size: Vector3) -> PackedVector3Array:
	var h := size * 0.5
	var c := [Vector3(-h.x,-h.y,-h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(-h.x,-h.y,h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)]
	var out := PackedVector3Array()
	for q in [[3,2,6,7],[4,5,1,0],[7,6,5,4],[0,1,2,3],[3,7,4,0],[6,2,1,5]]:
		for i in [q[0],q[1],q[2],q[0],q[2],q[3]]:
			out.append(c[i])
	return out

## Rebuilds the walkable navigation mesh from the actual static geometry (machines, walls,
## deposits, conveyors). Called on start, load and after every placement / expansion.
func _rebake_nav() -> void:
	nav_dirty = false
	var source := NavigationMeshSourceGeometryData3D.new()
	for body in world.get_children():
		if not body is StaticBody3D or not body.is_inside_tree():
			continue
		var kind := str(body.get_meta("kind", ""))
		if kind in ["piece", "conveyor"] or bool(body.get_meta("nav_skip", false)) or body.is_queued_for_deletion():
			continue # loose pieces and low conveyor belts can be stepped over
		if body.collision_layer == 0 and kind != "deposit":
			continue
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				source.add_faces(_box_faces(child.shape.size), body.global_transform * child.transform)
	for v in vehicle_nodes.values():
		if v != driving and not v.is_queued_for_deletion():
			for child in v.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D:
					source.add_faces(_box_faces(child.shape.size), v.global_transform * child.transform)
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.filter_baking_aabb = AABB(Vector3(-30,-1,-30), Vector3(82,9,60))
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	nav_region.navigation_mesh = mesh
	nav_version += 1
	nav_ready_frame = Engine.get_physics_frames() + 2

func nav_ready() -> bool:
	return Engine.get_physics_frames() >= nav_ready_frame and NavigationServer3D.map_get_iteration_id(nav_map) > 0

func is_visible_to_player(pos: Vector3) -> bool:
	if player == null or player.camera == null:
		return false
	return pos.distance_to(player.global_position) < 45.0 and player.camera.is_position_in_frustum(pos + Vector3(0,1,0))

# --------------------------------------------------------------- worker services

func break_spot(slot: int) -> Vector3:
	return Vector3(-10.9 + 0.85 * clampi(slot, 0, 3), 0, 16.4)

## Standing area for a workplace endpoint: centre, radius of reachable ring, preferred side.
func workplace(ep: Dictionary) -> Dictionary:
	match str(ep.get("type", "")):
		"storage": return {"pos": business.storage_pos, "radius": 2.1, "face": Vector3(-0.3,0,-1)}
		"sell": return {"pos": Vector3(-7,0,10), "radius": 2.0, "face": Vector3(0,0,1)}
		"crusher":
			var i := int(ep.get("index", -1))
			if i < 0 or i >= state.crushers.size():
				return {}
			var c: Dictionary = state.crushers[i]
			return {"pos": Business.v3(c["position"]) * Vector3(1,0,1), "radius": 2.0, "face": -Business.forward(float(c["yaw"]))}
		"output":
			var i := int(ep.get("index", -1))
			if i < 0 or i >= business.outputs.size():
				return {}
			return {"pos": Business.v3(business.outputs[i]["position"]) * Vector3(1,0,1), "radius": 1.7, "face": Vector3(0,0,1)}
		"deposit_site":
			var id := str(ep.get("id", ""))
			if not deposit_nodes.has(id):
				return {}
			var p: Vector3 = _deposit_info(id)["pos"]
			var toward := (Vector3(0,0,8) - p) if not EXPANSION_DEPOSITS.has(id) else (Vector3(30,0,0) - p)
			return {"pos": p, "radius": 2.4, "face": toward.normalized()}
	return {}

func nearest_piece(res: String, from: Vector3, skip := {}) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for id in ground_pieces:
		var body: Node3D = ground_pieces[id]
		if str(body.get_meta("resource")) != res or skip.has(id) or body.is_queued_for_deletion():
			continue
		if float(body.get_meta("claim_until", -1.0)) > state.clock_minutes:
			continue # freshly broken by the player
		var d := body.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = body
	return best

func nearest_deposit(res: String, from: Vector3) -> String:
	var best := ""
	var best_d := INF
	for kind in deposit_nodes:
		if str(_deposit_info(kind)["resource"]) != res or bool(state.deposits[kind]["broken"]) or bool(_deposit_info(kind).get("infinite", false)):
			continue # the quarry face is reserved for hand mining
		var d: float = deposit_nodes[kind].global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = kind
	return best

func worker_strike(kind: String, hits: int, extra: int, _worker: Node3D) -> void:
	if deposit_nodes.has(kind):
		_strike(kind, hits, extra, false)

## A worker physically picks up one loose piece next to it. Returns false if it cannot.
func worker_pick_piece(piece: Node3D, e: Dictionary) -> bool:
	if piece == null or not is_instance_valid(piece) or piece.is_queued_for_deletion():
		return false
	var id := str(piece.get_meta("piece_id"))
	if not ground_pieces.has(id) or business.carry_total(e) >= int(business.stat(e, "carry")):
		return false
	ground_pieces.erase(id)
	business.carry_add(e, str(piece.get_meta("resource")), 1)
	piece.queue_free()
	return true

func worker_sale_feedback(w: Node3D) -> void:
	if player and w.global_position.distance_to(player.global_position) < 14.0:
		sell_audio.play()

func _sync_workers() -> void:
	for id in worker_nodes.keys():
		if business.employee(id).is_empty():
			worker_nodes[id].queue_free()
			worker_nodes.erase(id)
	for e in business.employees:
		var id := int(e["id"])
		if worker_nodes.has(id):
			continue
		var w = WorkerScript.new()
		w.setup(self, business, e)
		var p: Array = e.get("position", [])
		if p.size() == 3:
			w.position = Vector3(float(p[0]), maxf(0.05, float(p[1])), float(p[2]))
			w.rotation.y = float(e.get("yaw", 0.0))
		else:
			w.position = break_spot(business.employees.find(e)) + Vector3(0, 0.05, 0)
		workers_root.add_child(w)
		worker_nodes[id] = w

# --------------------------------------------------------------- management actions (UI)

func ui_hire(candidate_id: String) -> String:
	var reason := business.hire_block_reason(candidate_id)
	if reason != "":
		return reason
	var e := business.hire(candidate_id)
	_sync_workers()
	return "Hired %s. They will head to the break area, then to work during their shift." % e["name"]

func ui_fire(id: int) -> String:
	var e := business.employee(id)
	if e.is_empty() or not business.fire(id):
		return "Nobody to dismiss"
	_sync_workers()
	return "%s left the company. Final wages settled%s." % [e["name"], "" if business.outstanding_debt <= 0.0 else " (remaining wages are owed)"]

func ui_assign(id: int, a: Dictionary) -> String:
	if business.assign(id, a):
		var w = worker_nodes.get(id)
		if w:
			w.access_cache.clear()
			w.path_key = ""
			w.phase = ""
		return "Assignment updated"
	return "That workplace is not compatible"

func ui_shift(id: int, start_minute: int, end_minute: int) -> String:
	return "Shift updated" if business.set_shift(id, start_minute, end_minute) else "Shift must be at least 30 minutes"

func ui_upgrade(id: int) -> String:
	var e := business.employee(id)
	var info := business.upgrade_info(e)
	if info.is_empty():
		return "Fully trained"
	if business.buy_upgrade(id):
		return "%s trained: %s" % [e["name"], info["name"]]
	return "Need $%d" % int(info["cost"])

# --------------------------------------------------------------- structures

func _output_visual(parent: Node3D, transparent := false) -> void:
	_visual_box(parent,Vector3(0,0.55,0),Vector3(1.4,1.1,1.4),Color(0.24,0.30,0.22))
	_visual_box(parent,Vector3(0,1.12,0),Vector3(1.5,0.08,1.5),Color(0.40,0.36,0.22))
	if transparent:
		for child in parent.get_children():
			child.transparency = 0.45

func _conveyor_visual(parent: Node3D, transparent := false) -> void:
	_visual_box(parent,Vector3(0,0.13,0),Vector3(0.9,0.26,2.0),Color(0.16,0.17,0.18))
	_visual_box(parent,Vector3(0,0.27,0),Vector3(0.7,0.04,2.0),Color(0.07,0.07,0.07))
	_visual_box(parent,Vector3(0,0.30,-0.75),Vector3(0.2,0.02,0.32),Color(0.85,0.70,0.15))
	if transparent:
		for child in parent.get_children():
			child.transparency = 0.45

func _create_output(index: int) -> void:
	var data: Dictionary = business.outputs[index]
	var p := Business.v3(data["position"])
	var body := _solid(world,"Output storage",Vector3(p.x,0.55,p.z),Vector3(1.4,1.1,1.4),Color(0.24,0.30,0.22),float(data["yaw"]))
	body.set_meta("kind","output")
	body.set_meta("index",index)
	_visual_box(body,Vector3(0,0.57,0),Vector3(1.5,0.08,1.5),Color(0.40,0.36,0.22))
	var fill := _visual_box(body,Vector3(0,0.3,0),Vector3(1.2,0.5,1.2),Color(0.75,0.73,0.66))
	body.set_meta("fill", fill)
	output_nodes.append(body)

func _create_conveyor(index: int) -> void:
	var data: Dictionary = business.conveyors[index]
	var p := Business.v3(data["position"])
	# Phase 3: a low belt on its own collision layer (16). People step over it; vehicles,
	# placement and interaction still see it. Small supports mark the crossing points.
	var body := _solid(world,"Conveyor",Vector3(p.x,0.13,p.z),Vector3(0.9,0.26,2.0),Color(0.16,0.17,0.18),float(data["yaw"]))
	body.collision_layer = 16
	body.set_meta("kind","conveyor")
	body.set_meta("index",index)
	_visual_box(body,Vector3(0,0.14,0),Vector3(0.7,0.04,2.0),Color(0.07,0.07,0.07))
	_visual_box(body,Vector3(0,0.17,-0.75),Vector3(0.2,0.02,0.32),Color(0.85,0.70,0.15))
	for z in [-0.95, 0.95]:
		_visual_box(body,Vector3(0,-0.02,z),Vector3(1.05,0.24,0.1),Color(0.85,0.70,0.15))
	var items := []
	for i in range(int(business.cfg.get("conveyor_capacity", 3))):
		var item := _visual_box(body,Vector3(0,0.28,0),Vector3(0.26,0.26,0.26),Color(0.67,0.66,0.56))
		item.visible = false
		items.append(item)
	body.set_meta("items", items)
	conveyor_nodes.append(body)

## Cheap per-frame visuals: belt items slide along, output storages show their fill level.
func _update_structures() -> void:
	for i in range(mini(conveyor_nodes.size(), business.conveyors.size())):
		var c: Dictionary = business.conveyors[i]
		var items: Array = conveyor_nodes[i].get_meta("items")
		var n := int(c["items"])
		for k in range(items.size()):
			var item: MeshInstance3D = items[k]
			item.visible = k < n
			if item.visible:
				item.position.z = minf(0.75, 0.75 - 1.5 * float(c["progress"]) + 0.55 * k)
				item.material_override = _mat(WorkerScript.RESOURCE_COLORS.get(str(c["resource"]), Color.GRAY))
	for i in range(mini(output_nodes.size(), business.outputs.size())):
		var fill: MeshInstance3D = output_nodes[i].get_meta("fill")
		var ratio := float(business.output_total(i)) / float(business.output_capacity())
		fill.visible = ratio > 0.0
		fill.scale.y = maxf(0.05, ratio)
		fill.position.y = -0.5 + 0.5 * maxf(0.05, ratio) + 0.08

func conveyor_valid(pos: Vector3, yaw: float) -> bool:
	if not in_build_area(pos) or not _on_ground(pos) or _near_vehicle(pos, 2.6):
		return false
	if player and Vector2(pos.x,pos.z).distance_to(Vector2(player.global_position.x,player.global_position.z)) < 1.3:
		return false
	var fwd := Business.forward(yaw)
	var side := Vector3(fwd.z, 0, -fwd.x)
	var points := [pos, pos + fwd * 0.85, pos - fwd * 0.85, pos + side * 0.4, pos - side * 0.4]
	for body in world.get_children():
		if body == ghost or not body is StaticBody3D or (body.collision_layer & (1 | 16)) == 0 or body.has_meta("ground") or body.name == "Quarry floor":
			continue
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var h: Vector3 = child.shape.size * 0.5
				var inv: Transform3D = (body.global_transform * child.transform).affine_inverse()
				for p in points:
					var l: Vector3 = inv * (p + Vector3(0, 0.2, 0))
					if absf(l.x) <= h.x + 0.12 and absf(l.z) <= h.z + 0.12 and absf(l.y) <= h.y + 0.3:
						return false
	return true

# --------------------------------------------------------------- HUD

func _update_milestone_hud() -> void:
	var done := 0
	var next := ""
	var names := {"first_employee": "First Employee: hire a worker", "mechanized": "Mechanized Quarry: crusher + operator", "automated": "Automated Business: run a full production chain"}
	for id in Business.MILESTONES:
		if business.milestones[id]:
			done += 1
		elif next == "":
			next = names[id]
	var text := "MILESTONES %d/3%s" % [done, ("\nNext: " + next) if next != "" else "\nAll complete"]
	var alerts := 0
	for e in business.employees:
		if str(e["warning"]) != "":
			alerts += 1
			if alerts <= 2:
				text += "\n! %s: %s" % [str(e["name"]).split(" ")[0], e["warning"]]
	if alerts > 2:
		text += "\n! +%d more (M)" % (alerts - 2)
	milestone_label.text = text

# ===================================================================== Phase 3

func _build_phase3_area() -> void:
	var road := Color(0.27,0.26,0.24)
	_visual_box(world, Vector3(5.5,0.012,13.2), Vector3(3.6,0.024,11.0), road)    # parking -> yard
	_visual_box(world, Vector3(20.0,0.014,7.5), Vector3(20.0,0.028,3.6), road)    # yard -> east expansion
	_visual_box(world, Vector3(5.0,0.01,18.5), Vector3(19.0,0.02,4.6), Color(0.30,0.29,0.26)) # parking apron
	for slot in fleet.cfg.get("parking", []):
		for side in [-1.4, 1.4]:
			_visual_box(world, Vector3(float(slot[0]) + side,0.03,float(slot[2])), Vector3(0.12,0.02,4.2), Color(0.85,0.75,0.2))
	var sign := _solid(world, "Equipment parking sign", Vector3(-4.5,1.0,18.5), Vector3(0.2,2.0,1.4), Color(0.85,0.62,0.12))
	sign.set_meta("kind", "parking_sign")
	for id in fleet.cfg.get("piles", {}):
		var info: Dictionary = fleet.cfg["piles"][id]
		var pos := Business.v3(info["pos"])
		var color: Color = WorkerScript.RESOURCE_COLORS.get(str(info["resource"]), Color.GRAY)
		var body := _solid(world, "Rubble pile", pos + Vector3(0,0.3,0), Vector3(1.4,0.6,1.4), color.darkened(0.15))
		body.set_meta("kind", "pile")
		body.set_meta("pile", id)
		var mound := Node3D.new()
		mound.position.y = -0.3
		body.add_child(mound)
		_visual_box(mound, Vector3(0,0.45,0), Vector3(2.5,0.9,2.2), color, 0.2)
		_visual_box(mound, Vector3(0.2,1.05,-0.1), Vector3(1.5,0.5,1.4), color.lightened(0.08), 0.9)
		body.set_meta("mound", mound)
		pile_nodes[id] = body
	_refresh_pile_presence()

func _refresh_pile_presence() -> void:
	for id in pile_nodes:
		var active := fleet.pile_active(id)
		var body: StaticBody3D = pile_nodes[id]
		body.visible = active
		body.collision_layer = 1 if active else 0
		body.set_meta("nav_skip", not active)

func _update_piles() -> void:
	var cap := float(fleet.cfg.get("pile_max", 30))
	for id in pile_nodes:
		var body: StaticBody3D = pile_nodes[id]
		if body.visible:
			var mound: Node3D = body.get_meta("mound")
			mound.scale = Vector3(1, clampf(float(fleet.piles[id]["amount"]) / cap, 0.08, 1.0), 1)

# --------------------------------------------------------------- vehicles

func _sync_vehicles(rebuild := false) -> void:
	if rebuild:
		for v in vehicle_nodes.values():
			v.queue_free()
		vehicle_nodes.clear()
	for rec in fleet.vehicles:
		var id := int(rec["id"])
		if vehicle_nodes.has(id):
			continue
		var v = VehicleScript.new()
		v.setup(self, fleet, rec)
		vehicles_root.add_child(v)
		vehicle_nodes[id] = v

## First equipment parking slot with nothing on it (vehicles, people, objects).
func free_parking_slot() -> Variant:
	for slot in fleet.cfg.get("parking", []):
		var pos := Vector3(float(slot[0]), 0.05, float(slot[2]))
		if _near_vehicle(pos, 3.5):
			continue
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.6, 1.8, 4.8)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), pos + Vector3(0, 1.1, 0))
		q.collision_mask = 1 | 4 | 8 | 16
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			return pos
	return null

func enter_vehicle(v: QuarryVehicle) -> void:
	if driving or v == null:
		return
	driving = v
	v.driven = true
	v.settled_frames = 0
	fleet.driving_id = v.vehicle_id
	v.camera.current = true
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	player.velocity = Vector3.ZERO
	construction = false
	nav_dirty = true
	_notify("Driving the %s. E to exit." % fleet.spec(v.vtype)["title"])

## Safe exit beside the vehicle; refuses when moving or boxed in.
func exit_vehicle() -> bool:
	if driving == null:
		return false
	if absf(driving.speed) > 1.2:
		_notify("Brake to a stop before getting out (Space).")
		return false
	var spot = _exit_spot(driving)
	if spot == null:
		_notify("No room to get out here - move the vehicle.")
		return false
	var v := driving
	_reset_driving()
	player.global_position = spot
	player.rotation.y = v.rotation.y
	return true

## Returns control to the on-foot player without moving them (used by exit and load).
func _reset_driving() -> void:
	if driving:
		driving.driven = false
		driving.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	driving = null
	fleet.driving_id = -1
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.collision_layer = 1
	player.velocity = Vector3.ZERO
	player.camera.current = true
	nav_dirty = true # parked vehicle becomes an obstacle for workers

func _exit_spot(v: QuarryVehicle) -> Variant:
	var hx := v.size.x * 0.5 + 0.8
	var hz := v.size.z * 0.5 + 0.9
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.75
	for local in [Vector3(-hx,0,0), Vector3(hx,0,0), Vector3(0,0,hz), Vector3(0,0,-hz)]:
		var p: Vector3 = v.global_transform * local
		p.y = v.global_position.y + 0.05
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.98, 0))
		q.collision_mask = 1 | 4 | 8 | 16
		q.exclude = [v.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			continue
		var ray := PhysicsRayQueryParameters3D.create(p + Vector3(0,1,0), p - Vector3(0,1.5,0), 1)
		if get_world_3d().direct_space_state.intersect_ray(ray):
			return p
	return null

func _driving_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		driving.rotate_camera(event.relative)
		return true
	if event.is_action_pressed("interact"):
		exit_vehicle()
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if driving.vtype == "loader":
				loader_primary(driving)
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			vehicle_dump(driving)
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			driving.recover()
			_notify("Vehicle recovered to its last clear position")
			return true
		if event.physical_keycode == KEY_B:
			return true
	return false

func _nearest_pile(point: Vector3, radius: float) -> String:
	var best := ""
	var best_d := radius
	for id in pile_nodes:
		if not fleet.pile_active(id):
			continue
		var d := Vector2(point.x, point.z).distance_to(Vector2(pile_nodes[id].global_position.x, pile_nodes[id].global_position.z))
		if d < best_d:
			best_d = d
			best = id
	return best

## Contextual LMB: a lowered bucket scoops (pile first, then loose pieces) and lifts;
## a raised bucket lowers.
func loader_primary(v: QuarryVehicle) -> int:
	var rec := fleet.vehicle(v.vehicle_id)
	if v.bucket_target > 0.5:
		v.bucket_target = 0.0
		_notify("Bucket lowered - drive into a rubble pile and press LMB to scoop.")
		return 0
	var point := v.work_point()
	var got := 0
	var source := ""
	var pile := _nearest_pile(point, 3.0)
	if pile != "" and int(fleet.piles[pile]["amount"]) > 0:
		got = fleet.scoop_pile(rec, pile)
		source = str(fleet.cfg["piles"][pile]["title"]).to_lower()
	if fleet.space(rec) > 0:
		var near := []
		for id in ground_pieces:
			var body: Node3D = ground_pieces[id]
			if not body.is_queued_for_deletion() and Vector2(point.x, point.z).distance_to(Vector2(body.global_position.x, body.global_position.z)) < 2.6:
				near.append(id)
		for id in near:
			if fleet.space(rec) <= 0:
				break
			var body: Node3D = ground_pieces[id]
			if fleet.add_cargo(rec, str(body.get_meta("resource")), 1) == 1:
				ground_pieces.erase(id)
				body.queue_free()
				got += 1
				source = "loose rock" if source == "" else source + " and loose rock"
	v.bucket_target = 1.0
	if got > 0:
		pickup_audio.play()
		_notify("Scooped %d from %s. Bucket %d/%d." % [got, source, fleet.cargo_total(rec), fleet.capacity(rec)])
	elif fleet.space(rec) <= 0:
		_notify("Bucket is full - dump it into a truck, crusher hopper or the storage crate (RMB).")
	else:
		_notify("Nothing to scoop here. Lower the bucket at a rubble pile or loose rock.")
	return got

## Nearest place a vehicle can deliver to around `point`.
func dump_target(point: Vector3, radius: float, from: QuarryVehicle) -> Dictionary:
	var best := {}
	var best_d := radius
	var candidates := [[{"type": "storage"}, business.storage_pos]]
	for i in range(state.crushers.size()):
		candidates.append([{"type": "crusher", "index": i}, Business.v3(state.crushers[i]["position"])])
	for i in range(business.outputs.size()):
		candidates.append([{"type": "output", "index": i}, Business.v3(business.outputs[i]["position"])])
	for c in candidates:
		var d := Vector2(point.x, point.z).distance_to(Vector2(c[1].x, c[1].z))
		if d < best_d:
			best_d = d
			best = {"ep": c[0]}
	if from.vtype == "loader":
		for other in vehicle_nodes.values():
			if other != from and other.vtype == "truck":
				var c: Vector3 = other.bed_center()
				var d := Vector2(point.x, point.z).distance_to(Vector2(c.x, c.z))
				if d < maxf(best_d, 3.2):
					best_d = d
					best = {"truck": other}
	return best

func _target_name(t: Dictionary) -> String:
	if t.has("truck"):
		return "the dump truck"
	return business.describe_ep(t["ep"])

## RMB: loader dumps its bucket; truck raises its bed and unloads.
func vehicle_dump(v: QuarryVehicle) -> int:
	var rec := fleet.vehicle(v.vehicle_id)
	if fleet.cargo_total(rec) <= 0:
		_notify("Nothing to unload.")
		return 0
	var t := dump_target(v.work_point(), 3.0, v)
	if t.is_empty():
		_notify("Nothing to unload into here. Get close to a storage crate, crusher, output storage%s." % (" or truck" if v.vtype == "loader" else ""))
		return 0
	if v.vtype == "truck":
		if v.unload_timer > 0.0:
			return 0
		v.start_unload(t)
		_notify("Raising the bed over %s..." % _target_name(t))
		return 0
	var moved := 0
	if t.has("truck"):
		moved = fleet.transfer(rec, fleet.vehicle(t["truck"].vehicle_id))
	else:
		moved = fleet.dump_to(rec, t["ep"])
	v.dump_timer = 1.0
	_notify("Dumped %d into %s.%s" % [moved, _target_name(t), (" %d left in the bucket (target full or wrong material)." % fleet.cargo_total(rec)) if fleet.cargo_total(rec) > 0 else ""])
	return moved

func truck_finish_unload(v: QuarryVehicle, t: Dictionary) -> int:
	var rec := fleet.vehicle(v.vehicle_id)
	if rec.is_empty() or not t.has("ep") or not business.ep_valid(t["ep"]):
		return 0
	var moved := fleet.dump_to(rec, t["ep"])
	_notify("Unloaded %d into %s.%s" % [moved, _target_name(t), (" %d stays on the truck (target full or wrong material)." % fleet.cargo_total(rec)) if fleet.cargo_total(rec) > 0 else ""])
	return moved

func _driving_hud() -> String:
	var rec := fleet.vehicle(driving.vehicle_id)
	var cargo := ""
	for k in rec["cargo"]:
		cargo += " %s %d" % [str(k).replace("_", " "), rec["cargo"][k]]
	var hint := ""
	var point := driving.work_point()
	if driving.vtype == "loader":
		var pile := _nearest_pile(point, 3.0)
		if driving.bucket_target < 0.5 and pile != "":
			hint = "  >> LMB scoop %s (%d)" % [fleet.cfg["piles"][pile]["title"], fleet.piles[pile]["amount"]]
	if fleet.cargo_total(rec) > 0:
		var t := dump_target(point, 3.0, driving)
		if not t.is_empty():
			hint = "  >> RMB unload into " + _target_name(t)
	var load_label := "BUCKET" if driving.vtype == "loader" else "BED"
	var controls := "WASD drive  Mouse look  %sRMB %s  Space brake  R recover  E exit" % ["LMB bucket %s  " % ("down" if driving.bucket_target > 0.5 else "up/scoop") if driving.vtype == "loader" else "", "dump bucket" if driving.vtype == "loader" else "raise bed / unload"]
	return "%s  %.1f m/s   %s %d/%d%s%s\n%s" % [fleet.spec(driving.vtype)["title"].to_upper(), absf(driving.speed), load_label, fleet.cargo_total(rec), fleet.capacity(rec), cargo, hint, controls]

func ui_buy_vehicle(type: String) -> String:
	var reason := fleet.buy_block_reason(type)
	if reason != "":
		return reason
	var slot = free_parking_slot()
	if slot == null:
		return "Equipment parking is blocked - clear a parking bay south of the yard"
	fleet.buy(type, slot, 0.0)
	_sync_vehicles()
	nav_dirty = true
	return "%s delivered to the equipment parking area." % fleet.spec(type)["title"]

func ui_vehicle_upgrade(key: String) -> String:
	var reason := fleet.upgrade_block_reason(key)
	if reason != "":
		return reason
	fleet.buy_upgrade(key)
	return "%s installed." % fleet.cfg["upgrades"][key]["title"]

# --------------------------------------------------------------- construction management

func _structure_node(kind: String, index: int) -> Node3D:
	match kind:
		"crusher": return crusher_nodes[index] if index >= 0 and index < crusher_nodes.size() else null
		"output": return output_nodes[index] if index >= 0 and index < output_nodes.size() else null
		"conveyor": return conveyor_nodes[index] if index >= 0 and index < conveyor_nodes.size() else null
		"storage": return storage_body
	return null

func _construction_target() -> Dictionary:
	if last_target == null or not is_instance_valid(last_target):
		return {}
	var k := str(last_target.get_meta("kind", ""))
	if k in ["crusher", "output", "conveyor", "storage"]:
		return {"kind": k, "index": int(last_target.get_meta("index", 0))}
	return {}

func _structure_name(kind: String, index: int) -> String:
	return "Storage crate" if kind == "storage" else business.describe_ep({"type": kind, "index": index})

func _construction_prompt() -> String:
	var t := _construction_target()
	if t.is_empty():
		return "CONSTRUCTION MODE: aim at a crusher, conveyor, storage crate or output storage  |  B / Esc exit"
	var kind := str(t["kind"])
	var index := int(t["index"])
	if kind == "storage":
		return "Storage crate  |  LMB move  (the main crate cannot be sold)  |  B exit"
	var n := business.contents_total(business.structure_contents(kind, index))
	return "%s%s  |  LMB move  |  X sell (+$%d refund)  |  B exit" % [_structure_name(kind, index), (" holding %d items" % n) if n > 0 else "", business.refund_value(kind)]

func start_relocation(kind: String, index: int) -> bool:
	var node := _structure_node(kind, index)
	if node == null or placement:
		return false
	relocating = {"kind": kind, "index": index, "layer": node.collision_layer}
	node.visible = false
	node.collision_layer = 0
	placement = true
	placement_kind = kind
	placement_yaw = node.rotation.y
	ghost = Node3D.new()
	world.add_child(ghost)
	match kind:
		"crusher": _crusher_visual(ghost, true)
		"output": _output_visual(ghost, true)
		"conveyor": _conveyor_visual(ghost, true)
		"storage": _visual_box(ghost, Vector3(0,0.65,0), Vector3(2,1.3,1.6), Color(0.33,0.23,0.13))
	_notify("Moving %s. LMB confirm, R rotate, Esc cancel (stays where it was)." % _structure_name(kind, index))
	return true

func _finish_relocation() -> void:
	var kind := str(relocating["kind"])
	var index := int(relocating["index"])
	var node := _structure_node(kind, index)
	business.move_structure(kind, index, ghost.position, placement_yaw)
	node.position = Vector3(ghost.position.x, node.position.y, ghost.position.z)
	node.rotation.y = 0.0 if kind == "storage" else placement_yaw
	node.collision_layer = int(relocating["layer"])
	node.visible = true
	relocating = {}
	business.compute_links()
	nav_dirty = true
	_cancel_placement(false)
	_notify("%s moved. Connections and worker routes updated." % _structure_name(kind, index))

func _restore_relocated() -> void:
	var node := _structure_node(str(relocating["kind"]), int(relocating["index"]))
	if node:
		node.collision_layer = int(relocating["layer"])
		node.visible = true
	relocating = {}

## X in construction mode. Structures holding material need a second press to confirm.
func request_sell(kind: String, index: int, confirmed := false) -> int:
	var reason := business.sell_block_reason(kind, index)
	if reason != "":
		_notify(reason)
		return -1
	var key := "%s:%d" % [kind, index]
	var n := business.contents_total(business.structure_contents(kind, index))
	if n > 0 and not confirmed and sell_confirm != key:
		sell_confirm = key
		_notify("%s holds %d items. Press X again to sell; contents go to the storage crate, output storage or your bag." % [_structure_name(kind, index), n])
		return -1
	sell_confirm = ""
	var label := _structure_name(kind, index)
	var refund := business.sell_structure(kind, index)
	_rebuild_structures(kind)
	nav_dirty = true
	_notify("%s sold for $%d.%s" % [label, refund, " Contents returned to storage." if n > 0 else ""])
	return refund

func _rebuild_structures(kind: String) -> void:
	match kind:
		"crusher":
			for b in crusher_nodes:
				b.queue_free()
			crusher_nodes.clear()
			for i in range(state.crushers.size()):
				_create_crusher(i)
		"output":
			for b in output_nodes:
				b.queue_free()
			output_nodes.clear()
			for i in range(business.outputs.size()):
				_create_output(i)
		"conveyor":
			for b in conveyor_nodes:
				b.queue_free()
			conveyor_nodes.clear()
			for i in range(business.conveyors.size()):
				_create_conveyor(i)
	business.compute_links()

func _place_storage_body() -> void:
	storage_body.position = Vector3(business.storage_pos.x, 0.65, business.storage_pos.z)
	storage_body.rotation.y = 0.0

# ===================================================================== Phase 4: deposit status

func _deposit_status(kind: String) -> String:
	var d: Dictionary = state.deposits.get(kind, {})
	if d.is_empty():
		return ""
	if bool(d.get("infinite", false)):
		return "Quarry face: never runs out (slow hand mining, %d hits)" % int(state.config.get("quarry_face", {}).get("hits", 5))
	var res := str(d["resource"])
	var every := state.deposit_regrow(res)
	if int(d["stock"]) <= 0:
		return "Depleted - regrows 1 unit every %d min (next in %d min)" % [int(every), int(ceil(state.regrow_eta(kind)))]
	return "%d/%d left, +1 every %d min" % [int(d["stock"]), state.deposit_max(res), int(every)]

func _update_deposit_label(kind: String) -> void:
	if not deposit_nodes.has(kind):
		return
	var label: Label3D = deposit_nodes[kind].get_meta("status")
	var d: Dictionary = state.deposits[kind]
	var name_text := "QUARRY FACE" if bool(d.get("infinite", false)) else str(d["resource"]).replace("_", " ").to_upper()
	if bool(d.get("infinite", false)):
		label.text = name_text + "\nalways workable"
		label.modulate = Color(0.85, 0.95, 0.8)
	elif int(d["stock"]) <= 0:
		label.text = "%s DEPLETED\nregrows in %d min" % [name_text, int(ceil(state.regrow_eta(kind)))]
		label.modulate = Color(1.0, 0.6, 0.45)
	else:
		label.text = "%s %d/%d" % [name_text, int(d["stock"]), state.deposit_max(str(d["resource"]))]
		label.modulate = Color(0.95, 0.9, 0.75)
