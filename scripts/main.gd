extends Node3D

const State = preload("res://scripts/state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const SAVE_PATH := "user://quarry_save.json"
const RESOURCE_ORDER := ["limestone", "coal", "iron_ore", "crushed_stone"]
const DEPOSIT_INFO := {"limestone": {"pos": Vector3(-8, 0, -11), "color": Color(0.67, 0.66, 0.56), "pieces": 4}, "coal": {"pos": Vector3(0, 0, -15), "color": Color(0.17, 0.19, 0.21), "pieces": 3}, "iron_ore": {"pos": Vector3(8, 0, -11), "color": Color(0.52, 0.29, 0.23), "pieces": 2}}
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

func _ready() -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	state = State.new(cfg)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	_build_quarry()
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0, 0.2, 8)
	add_child(player)
	_setup_ui()
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
		_solid(world, "Cliff", cpos, Vector3(10,6,5), Color(0.32+0.025*(i%3),0.32,0.29), -angle-PI/2)
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
	var machine_shop := _solid(world,"Crusher order kiosk",Vector3(-2,0.75,10),Vector3(1.4,1.5,1.0),Color(0.30,0.38,0.42))
	machine_shop.set_meta("kind","shop")
	for kind in DEPOSIT_INFO:
		_build_deposit(kind)
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

func _build_deposit(kind: String) -> void:
	var info: Dictionary = DEPOSIT_INFO[kind]
	if not state.deposits.has(kind):
		state.deposits[kind] = {"hits": 0, "ready_at": 0.0, "broken": false}
	var body := _solid(world,kind+" deposit",info["pos"]+Vector3(0,0.9,0),Vector3(2.4,1.8,2.0),info["color"],0.4)
	body.set_meta("kind","deposit")
	body.set_meta("resource",kind)
	deposit_nodes[kind] = body
	_refresh_deposit(kind)

func _refresh_deposit(kind: String) -> void:
	var body: StaticBody3D = deposit_nodes[kind]
	var d: Dictionary = state.deposits[kind]
	body.visible = not bool(d["broken"])
	body.collision_layer = 1 if body.visible else 0
	var mesh: MeshInstance3D = body.get_child(0)
	mesh.scale = Vector3.ONE * (1.0 - float(d["hits"]) * 0.07)
	if mesh.get_child_count() > 0:
		for child in mesh.get_children():
			child.queue_free()
	if int(d["hits"]) > 0 and body.visible:
		for n in range(int(d["hits"])):
			_visual_box(mesh,Vector3(-0.5+0.22*n,0.36,1.01),Vector3(0.025,0.35,0.025),Color(0.07,0.07,0.06),0.3*n)

func _spawn_pieces(kind: String, count: int) -> void:
	for i in range(count):
		_spawn_piece(kind, int(state.deposits[kind].get("generation", 0)), i)

func _spawn_piece(kind: String, generation: int, i: int) -> void:
	var count: int = int(DEPOSIT_INFO[kind]["pieces"])
	var center: Vector3 = DEPOSIT_INFO[kind]["pos"]
	var angle := TAU * float(i)/float(count)
	var body := _solid(world,"Loose "+kind, center+Vector3(cos(angle)*1.0,0.27,sin(angle)*1.0),Vector3(0.44,0.46,0.42),DEPOSIT_INFO[kind]["color"],angle)
	body.set_meta("kind","piece")
	body.set_meta("resource",kind)
	body.set_meta("piece_id",kind+"_"+str(generation)+"_"+str(i))
	ground_pieces[str(body.get_meta("piece_id"))] = body

func _strike(kind: String) -> void:
	var d: Dictionary = state.deposits[kind]
	if bool(d["broken"]):
		return
	d["hits"] = int(d["hits"]) + 1
	player.swing_pickaxe()
	hit_audio.play()
	if int(d["hits"]) >= state.required_hits():
		d["hits"] = 0
		d["generation"] = int(d.get("generation", 0)) + 1
		d["broken"] = true
		d["ready_at"] = state.clock_minutes + float(state.config["deposit_regen_minutes"])
		_spawn_pieces(kind,int(DEPOSIT_INFO[kind]["pieces"]))
		_notify(kind.capitalize()+" breaks! Pick up the pieces with E.")
	else:
		_notify("Crack! "+str(state.required_hits()-int(d["hits"]))+" strikes remaining")
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
	mining_cooldown = maxf(0,mining_cooldown-delta)
	message_timer = maxf(0,message_timer-delta)
	_update_light()
	for kind in state.deposits:
		var dep: Dictionary = state.deposits[kind]
		if bool(dep["broken"]) and state.clock_minutes >= float(dep["ready_at"]):
			dep["broken"] = false
			dep["hits"] = 0
			_refresh_deposit(kind)
	last_target = _look_target()
	if placement:
		_update_ghost()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mining_cooldown <= 0:
		mining_cooldown = state.strike_interval()
		if last_target and last_target.get_meta("kind", "") == "deposit":
			_strike(str(last_target.get_meta("resource")))
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
			"deposit": prompt = "Hold LMB: mine "+str(last_target.get_meta("resource"))
			"piece": prompt = "E: collect "+str(last_target.get_meta("resource"))
			"crusher": prompt = "E: use crusher"
			"sell": prompt = "E: sell materials"
			"shop": prompt = "E: buy crusher ($%d)" % int(state.config["crusher_price"])
			"upgrades": prompt = "E: upgrades"
			"storage": prompt = "E: storage"
	if placement:
		prompt = "PLACE CRUSHER: %s | LMB place | R rotate | Esc cancel" % ("VALID" if ghost_valid else "BLOCKED")
	action_label.text = prompt + ("\n"+message if message_timer > 0 else "") + ("\nWASD move  Shift sprint  E interact  P place  F5 save  F9 load  Esc pause" if tutorial_visible else "")
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
	if event.is_action_pressed("ui_cancel"):
		if placement:
			_cancel_placement()
		elif menu != "":
			_close_menu()
		else:
			_open_menu("pause")
		get_viewport().set_input_as_handled()
		return
	if menu != "":
		if event is InputEventKey and event.pressed and not event.echo:
			_menu_key(event)
		return
	if event.is_action_pressed("save_game"):
		_save()
	if event.is_action_pressed("load_game"):
		_load()
	if placement:
		if event.is_action_pressed("rotate_machine"):
			placement_yaw += PI/2.0
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				placement_yaw += PI/2.0
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_place_ghost()
		return
	if event.is_action_pressed("place_machine"):
		_notify("Buy a crusher at the blue kiosk first.")
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
		"sell", "upgrades", "storage", "crusher":
			_open_menu(str(target.get_meta("kind")),int(target.get_meta("index",-1)))
		"shop":
			if state.buy_crusher():
				placement = true
				ghost = Node3D.new()
				world.add_child(ghost)
				_crusher_visual(ghost,true)
				_notify("Choose a clear patch of ground. R rotates, LMB places.")
			else:
				_notify("Need $"+str(state.config["crusher_price"]))

func _open_menu(kind: String, index := -1) -> void:
	menu = kind
	panel.set_meta("crusher_index",index)
	panel.visible = true
	player.locked = true
	if crusher_audio.playing:
		crusher_audio.stream_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_draw_menu()

func _close_menu() -> void:
	menu = ""
	panel.visible = false
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
				text += "%d  Sell all %s (%d)  $%d each\n" % [i+1,key.replace("_"," "),state.inventory[key],state.config["prices"][key]]
			text += "\nEsc Close"
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
				text = "STONE CRUSHER\n\nLimestone input: %d  (bag: %d)\nCrushed output: %d\n%s\n\n1 Load all limestone\n2 Start processing\n3 Collect output\nEsc Close" % [c["input"],state.inventory["limestone"],c["output"],"Running: %.1f sec" % c["remaining"] if c["running"] else "Idle"]
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
			if digit < RESOURCE_ORDER.size():
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
	_draw_menu()

func placement_valid(pos: Vector3, yaw: float) -> bool:
	if absf(pos.x)>23.5 or absf(pos.z)>23.5 or pos.z < -6.0 or pos.distance_to(Vector3(0,0,8))<2.0:
		return false
	for body in world.get_children():
		if body == ghost or not body is StaticBody3D or body.name == "Quarry floor":
			continue
		if not body.collision_layer:
			continue
		var d: Vector3 = body.position - pos
		if absf(d.x)<2.1 and absf(d.z)<2.1:
			return false
	for c in state.crushers:
		var p: Array = c["position"]
		if Vector2(pos.x,pos.z).distance_to(Vector2(float(p[0]),float(p[2])))<2.5:
			return false
	return true

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
	ghost.position = Vector3(snappedf(point.x,0.5),0,snappedf(point.z,0.5))
	ghost.rotation.y = placement_yaw
	ghost.visible = true
	ghost_valid = placement_valid(ghost.position,placement_yaw)
	for child in ghost.get_children():
		if child is MeshInstance3D:
			child.transparency = 0.42 if ghost_valid else 0.65

func _place_ghost() -> void:
	if not ghost_valid:
		_notify("Blocked. Choose clear, level ground.")
		return
	state.new_crusher(ghost.position,placement_yaw)
	_create_crusher(state.crushers.size()-1)
	_cancel_placement(false)
	_notify("Crusher placed! E to load and process limestone.")

func _cancel_placement(refund := true) -> void:
	if refund:
		state.money += int(state.config["crusher_price"])
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
	var data := state.snapshot()
	data["pieces"] = pieces
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
	if placement:
		_cancel_placement(false)
	for body in ground_pieces.values():
		body.queue_free()
	ground_pieces.clear()
	for body in crusher_nodes:
		body.queue_free()
	crusher_nodes.clear()
	for kind in DEPOSIT_INFO:
		_refresh_deposit(kind)
	var ids := {}
	for id in data["pieces"]:
		ids[str(id)] = true
	for id in ids:
		var parts: PackedStringArray = str(id).split("_")
		if parts.size() >= 3:
			var kind := "_".join(parts.slice(0,parts.size()-2))
			if DEPOSIT_INFO.has(kind):
				_spawn_piece(kind,int(parts[parts.size()-2]),int(parts[parts.size()-1]))
	for i in range(state.crushers.size()):
		_create_crusher(i)
	var p: Array = state.player_position
	player.position = Vector3(float(p[0]),maxf(0.05,float(p[1])),float(p[2]))
	player.rotation.y = state.player_yaw
	player.velocity = Vector3.ZERO
	_update_light()
	if menu != "":
		_close_menu()
	_notify("Loaded quarry progress")
