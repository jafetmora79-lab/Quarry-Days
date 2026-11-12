extends Node3D

const State = preload("res://scripts/state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const Business = preload("res://scripts/business.gd")
const WorkerScript = preload("res://scripts/worker.gd")
const ManagementScript = preload("res://scripts/management_ui.gd")
const FleetScript = preload("res://scripts/fleet.gd")
const VehicleScript = preload("res://scripts/vehicle.gd")
const ArtScript = preload("res://scripts/art/quarry_art.gd")
const ProgressionScript = preload("res://scripts/progression.gd")
const FormationScript = preload("res://scripts/formation.gd")
const FXScript = preload("res://scripts/fx.gd")
const HUDScript = preload("res://scripts/hud.gd")
const PitZoneScript = preload("res://scripts/pit_zone.gd")
const LandscapeScript = preload("res://scripts/art/landscape.gd")
const ArcFormationScript = preload("res://scripts/arc_formation.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const ExcavationScript = preload("res://scripts/excavation.gd")
const RigScript = preload("res://scripts/rig.gd")
const MINE_REACH := 2.6 # tools reach a little past the visual lunge (QuarryToolView.REACH_MAX)
const HILLSIDE_ID := "hillside_face_01"
const HOME_POS := Vector3(-7.3, 0, 19.6)
const SAVE_PATH := "user://quarry_save.json"
const RESOURCE_ORDER := ["limestone", "coal", "iron_ore", "crushed_stone", "copper_ore", "gold_ore"]
# Phase 5: the three small starting rocks are replaced by enormous finite formations (data/progression.json).
# The quarry face stays as the never-empty hand-mining fallback.
const DEPOSIT_INFO := {"limestone_face": {"pos": Vector3(-12.6, 0, -17.6), "color": Color(0.70, 0.68, 0.58), "pieces": 2, "resource": "limestone", "infinite": true, "yaw": -0.65}}
const UPGRADE_MENU := ["larger_backpack", "faster_mining", "hauling_harness", "efficient_crusher", "expanded_storage"]
const LEGACY_DEPOSITS := {"limestone": "stone_mountain", "coal": "coal_mountain", "iron_ore": "iron_mountain"}
# Phase 2 quarry expansion (east), unlocked by the Automated Business milestone. Same three minerals.
const EXPANSION_DEPOSITS := {"limestone_east": {"pos": Vector3(36, 0, -6), "color": Color(0.67, 0.66, 0.56), "pieces": 4, "resource": "limestone"}, "coal_east": {"pos": Vector3(42, 0, 6), "color": Color(0.17, 0.19, 0.21), "pieces": 3, "resource": "coal"}, "iron_ore_east": {"pos": Vector3(44, 0, -5), "color": Color(0.52, 0.29, 0.23), "pieces": 2, "resource": "iron_ore"}, "limestone_east_2": {"pos": Vector3(35, 0, 6), "color": Color(0.67, 0.66, 0.56), "pieces": 4, "resource": "limestone"}}
var state: QuarryState
var player: QuarryPlayer
var world: Node3D
var ui: Control
var status_label: Label
var action_label: Label
var panel: PanelContainer # QuarryStationUI
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
var sleeping := false
var sleep_timer := 0.0
var _late_day := -1             # day on which the "go home to sleep" hint was shown
var landscape: QuarryLandscape  # sky, clouds, distant mountains and forest (no collision)
var doors: Array = []            # QuarryDoor: the office and home doors (E to open / close)
var delivery: QuarryDelivery    # service gate, garage door, delivery drivers and walk-in hires
var pit_zone: QuarryPitZone     # Phase 6.3a: the new pit area behind the north-east gate
var pit_retired: Array = []     # ring pieces retired to make the gate (for tests)
var cleanup_nodes := {}      # Phase 6.2: weed clumps and rubble heaps still on the site (id -> body)
var debris_dmg := {}         # id -> damage dealt so far
var _weed_mesh: ArrayMesh
var _heap_mesh: ArrayMesh
var touch_mode := false      # on-screen controls (Android / --touch)
var touch_mine := false      # MINE button held
var hillside_retired: Array = [] # rim / cliff bodies the hillside replaced (for tests)
var nav_rebakes := 0 # number of navigation rebuilds (measured while excavating)
var _click_ms := {}
var _tx_anchor := Vector2.INF # where money pop-ups rise from while a menu button is being handled
const CLICK_GUARD_MS := 150
var mine_normal := Vector3.UP # surface normal at the last mining hit (dust direction)
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D
var scripted_input := false
var art: QuarryArt # Phase 4 visual layer (THE VEIL style); gameplay never depends on it # tests drive vehicles by setting QuarryVehicle.input directly
# Phase 5
var prog: QuarryProgression
var fx: QuarryFX
var hud: QuarryHUD
var formation_nodes := {}
var sfx := {}
var power_audio: AudioStreamPlayer
var power_feedback_t := 0.0
var small_power_t := 0.0
var too_hard_t := 0.0
var bag_full_t := 0.0
var hud_refresh_t := 0.0
var discovery_nodes := {}
var excavation: Node3D
var rig_nodes: Array = []
var rig_pick_type := ""

func _ready() -> void:
	touch_mode = OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	state = State.new(cfg)
	var bcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))
	business = Business.new(state, bcfg)
	business.milestone_reached.connect(_on_milestone)
	var vcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles.json"))
	fleet = FleetScript.new(business, vcfg)
	var pcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	prog = ProgressionScript.new(state, business, pcfg)
	business.prog = prog
	state.money = int(pcfg.get("new_game_money", state.money))
	state.money_earned.connect(_on_income)
	prog.stage_reached.connect(_on_stage)
	prog.formation_cleared.connect(_on_formation_cleared)
	prog.site_cleared.connect(_on_site_cleared)
	fx = FXScript.new()
	add_child(fx)
	fx.game_audio_break = func(at: Vector3): _sfx_at("rock_break", at, -6.0)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	_build_quarry()
	art = ArtScript.new()
	art.build_environment(self)
	_carve_hillside_site()
	_build_pit_zone()
	for spec in [["Office door", Vector3(-14, 0, 12 - 2.35), -1.0], ["Home door", HOME_POS + Vector3(0, 0, -2.35), 1.0]]:
		var dr := QuarryDoor.new()
		dr.build(self, spec[1], spec[2], spec[0])
		doors.append(dr)
	delivery = QuarryDelivery.new()
	delivery.build(self)
	landscape = LandscapeScript.new()
	landscape.build(self)
	_spawn_cleanup()
	art.dress_storage(storage_body)
	for kind in deposit_nodes:
		_dress_deposit(kind)
	for id in pile_nodes:
		art.dress_pile(pile_nodes[id], str(fleet.cfg["piles"][id]["resource"]), 400 + id.length())
	excavation = ExcavationScript.new()
	add_child(excavation)
	excavation.setup(self)
	excavation.set_open(prog.level_unlocked >= 2)
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
	for key in ["hit_hammer", "hit_pick", "hit_reinforced", "rock_break", "ui_pop", "coin", "unlock", "breaker_hit"]:
		sfx[key] = _audio("res://audio/%s.wav" % key, -9.0)
	power_audio = _audio("res://audio/drill_loop.wav", -14.0)
	for key in ["drill_loop", "jackhammer_loop", "rig_loop"]:
		var ls: AudioStreamWAV = load("res://audio/%s.wav" % key)
		ls.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ls.loop_end = ls.data.size() / 2
	player.tool_view.equip(state.tool_tier, true)
	hit_audio = _audio("res://audio/pick_hit.wav", -12)
	pickup_audio = _audio("res://audio/pickup.wav", -15)
	sell_audio = _audio("res://audio/sell.wav", -13)
	crusher_audio = _audio("res://audio/crusher_loop.wav", -23)
	var loop_stream: AudioStreamWAV = crusher_audio.stream
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_update_light()
	_refresh_stage_hud()
	if not prog.story["intro_seen"]:
		call_deferred("_show_intro")

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
	# Phase 5: the floor is split around the future excavation pit; thick pieces form solid pit walls.
	var pit: Array = prog.cfg["excavation"]["pit"]
	var x0 := float(pit[0])
	var z0 := float(pit[1])
	var x1 := float(pit[2])
	var z1 := float(pit[3])
	_solid(world, "Quarry floor", Vector3(0, -0.25, (z1 + 29.0) * 0.5), Vector3(58, 0.5, 29.0 - z1), Color(0.38,0.34,0.28))
	_floor_piece("Quarry floor north", Vector3(0, -2.75, (z0 - 29.0) * 0.5), Vector3(58, 5.5, z0 + 29.0))
	_floor_piece("Quarry floor west", Vector3((x0 - 29.0) * 0.5, -2.75, (z0 + z1) * 0.5), Vector3(x0 + 29.0, 5.5, z1 - z0))
	_floor_piece("Quarry floor east", Vector3((x1 + 29.0) * 0.5, -2.75, (z0 + z1) * 0.5), Vector3(29.0 - x1, 5.5, z1 - z0))
	_floor_piece("Quarry floor south wall", Vector3((x0 + x1) * 0.5, -3.0, z1 + 0.25), Vector3(x1 - x0, 5.0, 0.5))
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
			if in_hillside_zone(Vector3(x, 0, z), 1.5):
				continue # the hillside replaces this corner of the rim
			_solid(world,"Tree trunk",Vector3(x,1.1,z),Vector3(0.5,2.2,0.5),Color(0.24,0.18,0.12))
			_visual_box(world,Vector3(x,2.85,z),Vector3(2.1,2.5,2.1),Color(0.13,0.24,0.16))
	_building("Office", Vector3(-14,0,12), Color(0.48,0.42,0.31))
	_building("Storage shed", Vector3(14,0,12), Color(0.38,0.37,0.31))
	_building("Home", HOME_POS, Color(0.46,0.38,0.28))
	var bed := _solid(world, "Bed", HOME_POS + Vector3(-1.3, 0.35, 1.3), Vector3(1.0, 0.7, 2.0), Color(0.45,0.3,0.22))
	bed.set_meta("kind", "bed")
	var sell := _solid(world,"Selling station",Vector3(-7,0.85,10),Vector3(2.2,1.7,1.25),Color(0.37,0.26,0.14))
	sell.set_meta("kind","sell")
	var shop := _solid(world,"Upgrade board",Vector3(-14,1.2,7.8),Vector3(2.1,1.4,0.25),Color(0.15,0.26,0.27))
	shop.set_meta("kind","upgrades")
	var storage := _solid(world,"Storage crate",Vector3(10,0.65,10),Vector3(2,1.3,1.6),Color(0.33,0.23,0.13))
	storage.set_meta("kind","storage")
	storage.set_meta("index",0)
	storage_body = storage
	var machine_shop := _solid(world,"Crusher order kiosk",Vector3(-2,0.75,10),Vector3(1.4,1.5,1.0),Color(0.30,0.38,0.42))
	machine_shop.set_meta("kind","shop")
	for kind in DEPOSIT_INFO:
		_build_deposit(kind)
	for id in prog.formation_ids():
		if prog.formation_active(id):
			_build_formation(id)
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

## Invisible walkable ground block (the art layer draws the surface).
func _floor_piece(label: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	world.add_child(body)
	return body

func _building(label: String, pos: Vector3, color: Color) -> void:
	_solid(world,label+" floor",pos+Vector3(0,0.08,0),Vector3(5,0.16,4.8),color)
	# A shallow physical approach bridges the 16 cm foundation. The controller has
	# no step-up or jump, so a bare threshold otherwise blocks both entrances.
	var approach := _solid(world, label+" entrance ramp", pos+Vector3(0,0.04,-2.95), Vector3(1.42,0.08,1.0),color)
	approach.rotation.x = -atan(0.16)
	_solid(world,label+" left",pos+Vector3(-2.4,1.4,0),Vector3(0.22,2.8,4.8),color)
	_solid(world,label+" right",pos+Vector3(2.4,1.4,0),Vector3(0.22,2.8,4.8),color)
	_solid(world,label+" back",pos+Vector3(0,1.4,2.35),Vector3(5,2.8,0.22),color)
	_solid(world,label+" front left",pos+Vector3(-1.6,1.4,-2.35),Vector3(1.8,2.8,0.22),color)
	_solid(world,label+" front right",pos+Vector3(1.6,1.4,-2.35),Vector3(1.8,2.8,0.22),color)
	_solid(world,label+" roof",pos+Vector3(0,2.92,0),Vector3(5.4,0.27,5.2),Color(0.24,0.25,0.26))

# ------------------------------------------------------------------ home and sleep

func _sleep_tick(delta: float) -> void:
	if sleeping:
		sleep_timer -= delta
		if sleep_timer <= 0.0:
			if hud.fade_alpha() >= 0.99:
				sleep_now()
				hud.fade_to(0.0, 0.9)
				sleep_timer = 1.0
			else:
				sleeping = false
				player.locked = false
		return
	# one gentle hint per evening
	var h := _hour()
	var day := int(state.clock_minutes / 1440.0)
	if h >= 20.0 and _late_day != day and menu == "" and not placement:
		_late_day = day
		hud.toast("It's getting late", "Your bed is in the little house by the garage (E).", "info")

func _hour() -> float:
	return fposmod(state.clock_minutes, 1440.0) / 60.0

## Beds are for the evening and the small hours: from `sleep_from_hour` until `wake_hour`.
func can_sleep() -> bool:
	var h := _hour()
	return h >= float(prog.cfg.get("home", {}).get("sleep_from_hour", 17.0)) or h < float(prog.cfg.get("home", {}).get("wake_hour", 7.0)) - 1.0

func try_sleep() -> void:
	if sleeping:
		return
	if not can_sleep():
		_notify("You are not tired yet. Rest after %02d:00." % int(prog.cfg.get("home", {}).get("sleep_from_hour", 17.0)))
		return
	sleeping = true
	player.locked = true
	hud.fade_to(1.0, 0.9)
	sleep_timer = 1.1

## Advances the clock to the next wake-up time and saves. Money, staff, machines and every excavated section stay as
## they are: wages are settled minute by minute by the business, machines simply rest, and rock never grows back.
func sleep_now() -> void:
	var wake := float(prog.cfg.get("home", {}).get("wake_hour", 7.0)) * 60.0
	var day_start := floorf(state.clock_minutes / 1440.0) * 1440.0
	var target := day_start + wake
	if target <= state.clock_minutes:
		target += 1440.0
	state.clock_minutes = target
	business.tick(0.0) # settle wages up to the new time
	_update_light()
	_late_day = -1
	_save()
	hud.toast("Good morning", "Day %d. The game was saved." % (int(state.clock_minutes / 1440.0) + 1), "milestone")

# ------------------------------------------------------------------ Phase 6.2: clean up Grandpa's site

func _debris_meshes() -> void:
	if _weed_mesh != null:
		return
	var w := MeshKit.Soup.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 62
	for k in range(9):
		var a := TAU * float(k) / 9.0 + rng.randf_range(-0.3, 0.3)
		var h := rng.randf_range(0.5, 0.95)
		var tilt := rng.randf_range(0.15, 0.5)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, tilt)
		MeshKit.box_into(w, Vector3(0, h * 0.5, 0), Vector3(0.07, h, 0.045), Vector2(0.15, 0.4), Transform3D(basis, Vector3(cos(a) * 0.12, 0, sin(a) * 0.12)))
	_weed_mesh = w.mesh()
	_weed_mesh.surface_set_material(0, MeshKit.flat(Color(0.36, 0.52, 0.2)))
	var r := MeshKit.Soup.new()
	MeshKit.rock_into(r, Vector3(0, 0, 0), Vector3(1.3, 0.8, 1.2), 621, 3, 6)
	MeshKit.rock_into(r, Vector3(0.55, 0, 0.3), Vector3(0.8, 0.55, 0.8), 622, 3, 6)
	MeshKit.rock_into(r, Vector3(-0.5, 0, 0.35), Vector3(0.7, 0.5, 0.7), 623, 3, 6)
	MeshKit.rock_into(r, Vector3(0.1, 0, -0.5), Vector3(0.8, 0.6, 0.7), 624, 3, 6)
	MeshKit.rock_into(r, Vector3(0.15, 0.55, 0.0), Vector3(0.7, 0.45, 0.65), 625, 3, 6)
	_heap_mesh = r.mesh()
	_heap_mesh.surface_set_material(0, MeshKit.mat("RockLimestone"))

## (Re)builds the weeds and rubble heaps still on the site (none once it is clean).
func _spawn_cleanup() -> void:
	for n in cleanup_nodes.values():
		if is_instance_valid(n):
			n.queue_free()
	cleanup_nodes.clear()
	_sync_pit_gate()
	if not prog.cleanup_active():
		return
	_debris_meshes()
	for id in prog.cleanup_ids():
		if prog.cleanup["cleared"].get(id, false):
			continue
		var weed: bool = str(id).begins_with("w")
		var p2: Vector2 = prog.cleanup_pos(str(id))
		var body := StaticBody3D.new()
		body.name = "Debris_" + str(id)
		body.position = Vector3(p2.x, 0.0, p2.y)
		body.rotation.y = float(hash(str(id)) % 628) / 100.0
		body.set_meta("kind", "debris")
		body.set_meta("debris_id", str(id))
		body.set_meta("nav_skip", true)
		body.collision_layer = 32 # only mining rays and look-at see it: people and vehicles walk and drive through
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 0.9, 0.9) if weed else Vector3(1.5, 0.95, 1.4)
		cs.shape = box
		cs.position.y = box.size.y * 0.5
		body.add_child(cs)
		var vis := MeshKit.inst(body, _weed_mesh if weed else _heap_mesh, null)
		vis.material_override = null
		vis.name = "Visual"
		if not weed:
			var left: int = prog.heap_units_left(str(id))
			vis.scale = Vector3.ONE * lerpf(0.5, 1.0, float(left) / float(maxi(1, int(prog.cleanup_cfg().get("heap_units", 5)))))
		world.add_child(body)
		cleanup_nodes[id] = body

## One strike on a weed clump or rubble heap. Weeds fall after `weed_hp` damage; a heap gives one stone (into the
## bag) per `heap_unit_hp` damage and is gone when its stone is used up. Nothing is lost when the bag is full.
func hit_debris(node: Node3D, damage: float, point: Vector3, continuous := false) -> void:
	var id := str(node.get_meta("debris_id", ""))
	if id == "" or prog.cleanup["cleared"].get(id, false):
		return
	var cfg: Dictionary = prog.cleanup_cfg()
	var weed := id.begins_with("w")
	if not continuous:
		_play_tool_hit()
		player.impact_feedback(0.4)
		fx.impact(point, "copper_ore" if weed else "limestone", 0.8, mine_normal)
	elif power_feedback_t <= 0.0:
		power_feedback_t = 0.12
		fx.impact(point, "copper_ore" if weed else "limestone", 0.6, mine_normal)
	debris_dmg[id] = float(debris_dmg.get(id, 0.0)) + damage
	var vis: Node3D = node.get_node_or_null("Visual")
	if weed:
		if float(debris_dmg[id]) >= float(cfg.get("weed_hp", 6.0)):
			_finish_debris(id, node, "weeds")
		elif vis:
			vis.scale = Vector3.ONE * lerpf(1.0, 0.55, float(debris_dmg[id]) / float(cfg.get("weed_hp", 6.0)))
		return
	var unit_hp := float(cfg.get("heap_unit_hp", 10.0))
	while float(debris_dmg[id]) >= unit_hp and prog.heap_units_left(id) > 0:
		if state.total(state.inventory) >= state.capacity():
			debris_dmg[id] = unit_hp * 0.999
			_bag_full_notice()
			break
		state.add_item("limestone", 1)
		prog.cleanup["units"][id] = prog.heap_units_left(id) - 1
		debris_dmg[id] = float(debris_dmg[id]) - unit_hp
		_reward_popup("limestone", 1)
	var total := float(maxi(1, int(cfg.get("heap_units", 5))))
	if prog.heap_units_left(id) <= 0:
		_finish_debris(id, node, "rubble")
	elif vis:
		vis.scale = Vector3.ONE * lerpf(0.5, 1.0, float(prog.heap_units_left(id)) / total)

func _finish_debris(id: String, node: Node3D, what: String) -> void:
	node.collision_layer = 0
	for c in node.get_children():
		if c is CollisionShape3D:
			c.disabled = true
	cleanup_nodes.erase(id)
	debris_dmg.erase(id)
	var tw := create_tween()
	var vis: Node3D = node.get_node_or_null("Visual")
	if vis:
		tw.tween_property(vis, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(node.queue_free)
	if what == "weeds" and hud:
		hud.popup_resource("copper_ore", 1, "Weeds cut")
	var last := prog.clear_cleanup_item(id)
	if not last:
		_notify("Site cleanup: %d left." % prog.cleanup_left())

## The whole site is clean: Walt's letter arrives with money, and the hillside opens.
func _on_site_cleared() -> void:
	var cu: Dictionary = prog.cleanup_cfg()
	var gift := int(cu.get("gift", 0))
	state.money += gift
	if hud:
		hud.popup_money(gift)
		hud.toast("Site cleared!", "The hillside and the north gate are open. Walt sent $%d." % gift, "milestone")
		player.locked = true
		hud.show_card(str(cu.get("gift_title", "A LETTER")), str(cu.get("gift_text", "")), func(): player.locked = false)
	_sfx_unlock()
	if formation_nodes.has(HILLSIDE_ID):
		formation_nodes[HILLSIDE_ID].update_label()
	_sync_pit_gate()
	_notify("Walt's gift: $%d. The hillside and the north gate are open." % gift)

# ------------------------------------------------------------------ Phase 6.3a: the pit area behind the north-east gate

func pit_gate_xf() -> Transform3D:
	return PitZoneScript.gate_transform(prog.cfg.get("pit_zone", {}))

## True near the access corridor (world builders use it to keep scenery out of the way).
func in_pit_corridor(p: Vector3, margin := 0.0) -> bool:
	var c: Dictionary = prog.cfg.get("pit_zone", {})
	if c.is_empty():
		return false
	var l := pit_gate_xf().affine_inverse() * p
	return absf(l.x) <= float(c.get("corridor_width", 8.0)) * 0.5 + margin and l.z <= 12.0 and l.z >= -(float(c.get("corridor_length", 30.0)) + 3.0)

## Retires the ring pieces in the gate's mouth (low rim walls, the cliff filler) and builds the zone behind it.
func _build_pit_zone() -> void:
	if prog.cfg.get("pit_zone", {}).is_empty():
		return
	var inv := pit_gate_xf().affine_inverse()
	for body in world.get_children():
		if not body is StaticBody3D or body.has_meta("ground") or body.collision_layer != 1:
			continue
		var l: Vector3 = inv * body.global_position
		if absf(l.x) > 7.0 or l.z > 9.0 or l.z < -3.0 or body.position.y < 0.9:
			continue
		var h := 0.0
		for c in body.get_children():
			if c is CollisionShape3D and c.shape is BoxShape3D:
				h = maxf(h, (c.shape as BoxShape3D).size.y)
		if absf(h - 2.2) < 0.05 or absf(h - 6.0) < 0.05 or absf(h - 6.4) < 0.05:
			body.visible = false
			body.collision_layer = 0
			body.set_meta("nav_skip", true)
			pit_retired.append(str(body.name))
	if art:
		for m in art.root.get_children():
			if m.has_meta("filler_xz"):
				var fp: Vector2 = m.get_meta("filler_xz")
				var fl: Vector3 = inv * Vector3(fp.x, 0, fp.y)
				if absf(fl.x) <= 7.0 and fl.z <= 9.0 and fl.z >= -3.0:
					m.visible = false
	pit_zone = PitZoneScript.new()
	if not pit_zone.setup(self):
		pit_zone.free()
		pit_zone = null
		return
	for id in prog.formation_ids():
		if prog.formation_active(id) and str(prog.fdef(id).get("frame", "")) == "pit":
			_build_formation(id)

## The gate opens with the cleanup tutorial (saves from before it are already open).
func _sync_pit_gate() -> void:
	if pit_zone:
		pit_zone.set_open(not prog.cleanup_active())

## Footprint of the Phase 6.1 hillside (world xz), from its formation data. Empty rect when the data has none.
func hillside_rect() -> Rect2:
	var f: Dictionary = prog.fdef(HILLSIDE_ID)
	if f.is_empty():
		return Rect2()
	var d := prog.dims(HILLSIDE_ID)
	var cell := float(f["cell"])
	var c: Array = f["center"]
	var size := Vector2(float(d.x) * cell, float(d.y) * cell)
	return Rect2(Vector2(float(c[0]), float(c[2])) - size * 0.5, size)

func in_hillside_zone(p: Vector3, margin := 0.0) -> bool:
	var r := hillside_rect()
	return r.size != Vector2.ZERO and r.grow(margin).has_point(Vector2(p.x, p.z))

## The hillside takes over the west rim: the low "Excavated rim" walls and the one cliff block that stood in its
## working area are retired (hidden, no collision, ignored by navigation). Cliffs behind the back wall stay as the
## taller hill above it, so the ring of rock around the quarry stays closed with no gaps.
func _carve_hillside_site() -> void:
	var r := hillside_rect()
	if r.size == Vector2.ZERO:
		return
	var zone := Rect2(Vector2(r.position.x + 4.0, r.position.y - 0.4), Vector2(r.size.x - 4.0 + 2.6, r.size.y + 0.8)) # x: front 7 m of the grid + the strip in front of it
	for body in world.get_children():
		if not body is StaticBody3D or body.has_meta("ground") or body.collision_layer != 1:
			continue
		if not zone.has_point(Vector2(body.position.x, body.position.z)):
			continue
		var h := 0.0
		for c in body.get_children():
			if c is CollisionShape3D and c.shape is BoxShape3D:
				h = maxf(h, (c.shape as BoxShape3D).size.y)
		if (absf(h - 2.2) < 0.05 or absf(h - 6.0) < 0.05) and not str(body.get_meta("kind", "")) in ["deposit", "sell", "storage"]:
			body.visible = false
			body.collision_layer = 0
			body.set_meta("nav_skip", true)
			hillside_retired.append(str(body.name))
	# Plain placeholder boxes of the remaining ring pieces behind the hill would show as flat dark slabs: hide their
	# visuals (colliders stay) and give the hill a proper stratified backdrop instead.
	var back := r.grow(5.0)
	for body in world.get_children():
		if body is StaticBody3D and body.collision_layer == 1 and not body.has_meta("ground") and back.has_point(Vector2(body.position.x, body.position.z)) and body.position.y > 2.5:
			for c in body.get_children():
				if c is MeshInstance3D and not c.has_meta("art"):
					c.visible = false
	_build_hillside_backdrop(r)

## Taller stratified hill behind and at the north end of the cut (visual), with a collider on the north wall so it
## cannot be walked through. Reuses MeshKit.cliff_into and the cut-limestone material.
func _build_hillside_backdrop(r: Rect2) -> void:
	var s := MeshKit.Soup.new()
	var depth := 2.6
	var west_len := r.size.y + 4.0
	var west_c := Vector3(r.position.x - depth * 0.5, 0, r.position.y + r.size.y * 0.5 - 0.5)
	MeshKit.cliff_into(s, west_len, 8.6, depth, 611, 4, Transform3D(Basis(Vector3.UP, -PI * 0.5), west_c))
	var north_len := r.size.x + 4.0
	var north_c := Vector3(r.position.x + r.size.x * 0.5 + 1.0, 0, r.position.y - depth * 0.5)
	MeshKit.cliff_into(s, north_len, 7.0, depth, 612, 3, Transform3D(Basis(Vector3.UP, PI), north_c))
	var mi := MeshKit.inst(world, s.mesh(), MeshKit.mat("CutLimestone"))
	mi.name = "HillsideBackdrop"
	var wall := StaticBody3D.new()
	wall.name = "Hillside north wall"
	wall.position = north_c + Vector3(0, 3.5, 0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(north_len, 7.0, depth)
	cs.shape = box
	wall.add_child(cs)
	world.add_child(wall)

func _deposit_info(kind: String) -> Dictionary:
	if DEPOSIT_INFO.has(kind):
		return DEPOSIT_INFO[kind]
	if prog and prog.is_formation(kind):
		return {"pos": prog.formation_origin_world(kind), "resource": str(prog.fdef(kind)["resource"]), "pieces": 0, "formation": true, "color": WorkerScript.RESOURCE_COLORS.get(str(prog.fdef(kind)["resource"]), Color.GRAY)}
	return EXPANSION_DEPOSITS.get(kind, {})

func is_formation(kind: String) -> bool:
	return formation_nodes.has(kind)

## Phase 5: one enormous chunked formation (see scripts/formation.gd).
func _build_formation(id: String) -> void:
	if formation_nodes.has(id):
		return
	var pit_frame := str(prog.fdef(id).get("frame", "")) == "pit"
	if pit_frame and pit_zone == null:
		return # built once the pit zone exists (see _build_pit_zone)
	prog.init_formation(id)
	var node = (ArcFormationScript if prog.is_arc(id) else FormationScript).new()
	node.setup(self, prog, id)
	world.add_child(node)
	if pit_frame:
		pit_zone.formations.append(node)
	formation_nodes[id] = node
	deposit_nodes[id] = node

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
	_dress_deposit(kind)
	_refresh_deposit(kind)

func _refresh_deposit(kind: String) -> void:
	if not deposit_nodes.has(kind):
		return
	if formation_nodes.has(kind):
		formation_nodes[kind].refresh(true)
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
	if bool(info.get("formation", false)):
		_place_formation_piece(kind, generation, i)
		return
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
	if art:
		art.dress_piece(body, str(info["resource"]), i + generation)
	ground_pieces[str(body.get_meta("piece_id"))] = body

func _place_formation_piece(kind: String, generation: int, i: int) -> void:
	var col := posmod(generation, 100)
	if col >= prog.column_count(kind):
		col = 0
	var cell := float(prog.fdef(kind)["cell"])
	var base := prog.column_pos(kind, col)
	var out := prog.column_open_dir(kind, col, player.global_position if player else base + Vector3(0, 0, 5))
	var side := Vector3(out.z, 0, -out.x)
	var h := float(abs(hash(str(generation) + "_" + str(i))) % 1000) / 1000.0
	var p := base + out * (cell * 0.5 + 0.5 + 0.45 * float(i / 3) + h * 0.2) + side * ((float(i % 3) - 1.0) * 0.5 + (h - 0.5) * 0.2)
	var body := _solid(world, "Loose " + kind, p + Vector3(0, 0.27, 0), Vector3(0.44, 0.46, 0.42), info_color(kind), h * TAU)
	body.collision_layer = 2
	body.set_meta("kind", "piece")
	body.set_meta("resource", str(prog.fdef(kind)["resource"]))
	body.set_meta("deposit", kind)
	body.set_meta("piece_id", "%s_%d_%d" % [kind, generation, i])
	if art:
		art.dress_piece(body, str(prog.fdef(kind)["resource"]), i + generation)
	ground_pieces[str(body.get_meta("piece_id"))] = body

func info_color(kind: String) -> Color:
	return _deposit_info(kind).get("color", Color.GRAY)

func _strike(kind: String, hits_needed := -1, extra_pieces := 0, by_player := true) -> void:
	if formation_nodes.has(kind):
		# Phase 5 formations take damage, not hits (the old signature stays for staff and tests).
		if by_player:
			player_mine(kind, -1, prog.tool_power() if not prog.is_continuous() else prog.tool_dps() * 0.25)
		else:
			worker_strike(kind, maxi(1, hits_needed), extra_pieces, null)
		return
	var d: Dictionary = state.deposits[kind]
	if by_player and not prog.can_mine(str(d["resource"])):
		_too_hard(str(d["resource"]))
		return
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
		_play_tool_hit()
		player.impact_feedback(0.6)
	elif player and player.global_position.distance_to(deposit_nodes[kind].global_position) < 16.0:
		hit_audio.play()
	if fx and deposit_nodes.has(kind):
		fx.impact(deposit_nodes[kind].global_position + Vector3(0, 1.0, 0), str(d["resource"]), 0.6)
	if int(d["hits"]) >= need:
		d["hits"] = 0
		d["generation"] = int(d.get("generation", 0)) + 1
		var n := state.mine_yield(kind, int(_deposit_info(kind)["pieces"]) + maxi(0, extra_pieces))
		if by_player:
			# Phase 5: what you break goes straight into the bag; only an overflow drops as loose pieces.
			var res := str(_deposit_info(kind)["resource"])
			var put := state.add_item(res, n)
			if put > 0:
				_reward_popup(res, put)
				prog.stats["hand"] = int(prog.stats["hand"]) + put
			if n - put > 0:
				for i in range(put, n):
					_spawn_piece(kind, int(d["generation"]), i)
				for id in ground_pieces:
					if str(id).begins_with(kind + "_" + str(d["generation"]) + "_"):
						ground_pieces[id].set_meta("claim_until", state.clock_minutes + 15.0)
				_bag_full_notice()
			fx.chunk_break(deposit_nodes[kind].global_position + Vector3(0, 0.9, 0), res)
		else:
			_spawn_pieces(kind, n)
	elif by_player:
		hud.show_mining("%s  %d more strikes" % [prog.display(str(d["resource"])).to_upper(), need - int(d["hits"])], 1.0 - float(d["hits"]) / float(need))
	_refresh_deposit(kind)

# ------------------------------------------------------------------ Phase 5: player mining

func _play_tool_hit() -> void:
	var t := prog.tool()
	var key := str(t.get("sound", "hit_pick"))
	var a: AudioStreamPlayer = sfx.get(key, hit_audio)
	a.pitch_scale = randf_range(0.93, 1.07)
	a.play()

func _sfx_at(key: String, at: Vector3, db := 0.0) -> void:
	if not sfx.has(key):
		return
	var d := player.global_position.distance_to(at) if player else 0.0
	if d > 30.0:
		return
	var a: AudioStreamPlayer = sfx[key]
	a.volume_db = -9.0 + db - d * 0.4
	a.pitch_scale = randf_range(0.92, 1.08)
	a.play()

func _reward_popup(res: String, n: int) -> void:
	if hud:
		hud.popup_resource(res, n, prog.display(res))
	var a: AudioStreamPlayer = sfx.get("ui_pop")
	if a:
		a.pitch_scale = randf_range(1.0, 1.15)
		a.play()

func _too_hard(res: String) -> void:
	player.tool_view.deflect()
	if too_hard_t <= 0.0:
		too_hard_t = 1.2
		var a: AudioStreamPlayer = sfx["hit_reinforced"]
		a.pitch_scale = 1.6
		a.play()
		_notify("Too hard for the %s - %s needs the %s." % [str(prog.tool()["title"]), prog.display(res), str(prog.tool_for(res)["title"])])

func _bag_full_notice() -> void:
	if bag_full_t <= 0.0:
		bag_full_t = 2.5
		_notify("Bag full! Sell at the booth or store at the crate. Extra rock drops beside the formation.")

## Ray from the camera: {"node", "column", "point"} for whatever the crosshair is on.
func _mining_ray() -> Dictionary:
	player.tool_view.target_dist = 1.3
	var start := player.camera.global_position
	var end := start - player.camera.global_transform.basis.z * MINE_REACH
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit["collider"] is Node3D:
		return {}
	var node: Node3D = hit["collider"]
	var col := -1
	if node is QuarryFormation:
		col = node.column_from_shape(int(hit["shape"]))
	mine_normal = hit["normal"]
	player.tool_view.target_dist = player.camera.global_position.distance_to(hit["position"])
	return {"node": node, "column": col, "point": hit["position"], "normal": hit["normal"]}

func loose_count(kind: String) -> int:
	var n := 0
	for id in ground_pieces:
		if str(ground_pieces[id].get_meta("deposit", "")) == kind:
			n += 1
	return n

## Applies player mining damage to a formation column. Units go to the bag, overflow drops as loose
## pieces (up to a cap); with no room at all nothing is extracted. Returns units mined.
func player_mine(kind: String, col: int, damage: float, point := Vector3.INF, continuous := false) -> int:
	if not formation_nodes.has(kind):
		return 0
	if prog.formation_locked(kind) != "":
		_notify(prog.formation_locked(kind))
		return 0
	var node: QuarryFormation = formation_nodes[kind]
	var res := str(state.deposits[kind]["resource"])
	if not prog.can_mine(res):
		_too_hard(res)
		return 0
	var strict := bool(prog.fdef(kind).get("strict", false))
	if col < 0 or prog.column_units(kind, col) <= 0 or (strict and not prog.column_minable(kind, col)):
		if strict:
			# hillside: only exposed rock near the strike point can be cut, never a section behind solid rock
			col = prog.nearest_column(kind, player.global_position if point == Vector3.INF else point, true, 2.6)
			if col < 0:
				if prog.units_left(kind) > 0:
					_notify("Nothing to cut here. Mine the exposed face in front of you.")
				else:
					_notify("%s is cleared." % str(prog.fdef(kind)["title"]))
				return 0
		else:
			col = prog.nearest_column(kind, player.global_position if point == Vector3.INF else point, false)
	if col < 0:
		_notify("%s is cleared." % str(prog.fdef(kind)["title"]))
		return 0
	var bag_room := state.capacity() - state.total(state.inventory)
	var drop_room := maxi(0, int(prog.cfg.get("loose_piece_cap", 36)) - loose_count(kind))
	var ex := prog.extract(kind, col, damage, bag_room + drop_room, "hand")
	var n := int(ex["units"])
	var at := node.column_top(col) if point == Vector3.INF else point
	if not continuous:
		_play_tool_hit()
		player.impact_feedback(0.5 + 0.25 * float(state.tool_tier))
		fx.impact(at, res, 1.0, mine_normal)
	elif power_feedback_t <= 0.0:
		power_feedback_t = 0.12
		fx.impact(at, res, 0.7, mine_normal)
		player.impact_feedback(0.25)
	node.hit(col)
	if n > 0:
		var put := state.add_item(res, n)
		if put > 0:
			_reward_popup(res, put)
		for i in range(n - put):
			_spawn_formation_piece(kind, col, i)
		if n - put > 0:
			_bag_full_notice()
	elif bag_room + drop_room <= 0:
		_bag_full_notice()
	if int(ex["chunks"]) > 0:
		node.refresh()
	else:
		node.update_label()
	var left := prog.column_units(kind, col)
	hud.show_mining("%s  %d LEFT" % [prog.display(res).to_upper(), prog.units_left(kind)], 1.0 - prog.top_chunk_damage(kind, col) if left > 0 else 0.0)
	return n

## Loose piece beside a formation column (deterministic spot, so saved pieces reload in place).
func _spawn_formation_piece(kind: String, col: int, i: int) -> void:
	var d: Dictionary = state.deposits[kind]
	d["generation"] = int(d.get("generation", 0)) + 1
	_spawn_piece(kind, int(d["generation"]) * 100 + col, i)

func _player_mining(delta: float) -> void:
	var tv: QuarryToolView = player.tool_view
	tv.equip(state.tool_tier)
	power_feedback_t = maxf(0.0, power_feedback_t - delta)
	too_hard_t = maxf(0.0, too_hard_t - delta)
	bag_full_t = maxf(0.0, bag_full_t - delta)
	var lmb := (touch_mine if touch_mode else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and not driving and not construction and not placement and not hud.card_open()
	if prog.is_continuous():
		tv.operating = lmb
		if lmb:
			var want := "res://audio/%s.wav" % str(prog.tool()["sound"])
			if power_audio.stream == null or power_audio.stream.resource_path != want:
				power_audio.stream = load(want)
			if not power_audio.playing:
				power_audio.play()
			var hit := _mining_ray()
			if not hit.is_empty() and str(hit["node"].get_meta("kind", "")) == "debris":
				hit_debris(hit["node"], prog.tool_dps() * delta, hit["point"], true)
			elif not hit.is_empty() and str(hit["node"].get_meta("kind", "")) == "deposit":
				var kind := str(hit["node"].get_meta("deposit"))
				if formation_nodes.has(kind):
					player_mine(kind, int(hit["column"]), prog.tool_dps() * delta, hit["point"], true)
				else:
					small_power_t += delta
					if small_power_t >= 0.22:
						small_power_t = 0.0
						_strike(kind)
		elif power_audio.playing:
			power_audio.stop()
		return
	tv.operating = false
	if power_audio.playing:
		power_audio.stop()
	if lmb and not tv.is_busy() and mining_cooldown <= 0.0:
		mining_cooldown = prog.tool_interval()
		_mining_ray() # sets how far the head must lunge to meet the rock under the crosshair
		tv.swing(prog.tool_interval(), _on_swing_impact)

## Swing tools apply damage at the visible moment of impact, against whatever is under the crosshair then.
func _on_swing_impact() -> void:
	var hit := _mining_ray()
	if hit.is_empty():
		return
	var node: Node3D = hit["node"]
	if str(node.get_meta("kind", "")) == "debris":
		hit_debris(node, prog.tool_power(), hit["point"])
		return
	if str(node.get_meta("kind", "")) != "deposit":
		return
	var kind := str(node.get_meta("deposit"))
	if formation_nodes.has(kind):
		player_mine(kind, int(hit["column"]), prog.tool_power(), hit["point"])
	else:
		_strike(kind)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = QuarryTheme.theme()
	layer.add_child(ui)
	hud = HUDScript.new()
	ui.add_child(hud)
	hud.setup(self)
	if touch_mode:
		hud.tutorial = false # keyboard hints make no sense on a touchscreen
		var touch := TouchScript.new()
		ui.add_child(touch)
		touch.setup(self)
	# Station menus (selling booth, upgrade board, storage, machines): one cozy clickable panel.
	panel = QuarryStationUI.new()
	ui.add_child(panel)
	(panel as QuarryStationUI).setup(self)

func _notify(s: String) -> void:
	message = s
	message_timer = 3.0
	if hud:
		hud.set_message(s, 3.2)

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
	_sleep_tick(delta)
	if sleeping:
		return
	if art and art.garage_roof:
		# the chase camera would sit inside the roof: take the roof off while a vehicle is driven under it
		var inside := driving != null and driving.global_position.x > -6.5 and driving.global_position.x < 16.0 and driving.global_position.z > 12.5 and driving.global_position.z < 24.0
		art.garage_roof.visible = not inside
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
	_player_mining(delta)
	_phase5_tick(delta)
	var prompt := ""
	if last_target:
		match str(last_target.get_meta("kind","")):
			"deposit": prompt = "%s %s  -  %s" % ["Hold LMB: drill" if prog.is_continuous() else "LMB: mine", prog.display(str(last_target.get_meta("resource"))), _deposit_status(str(last_target.get_meta("deposit")))]
			"debris":
				var did := str(last_target.get_meta("debris_id", ""))
				prompt = "LMB: cut the weeds" if did.begins_with("w") else "LMB: break the rubble heap (%d stone left)" % prog.heap_units_left(did)
			"door":
				var dn := str(last_target.get_meta("door"))
				prompt = "E: use the door"
				for dr in doors:
					if str(dr.name) == dn:
						prompt = "E: close the %s" % dn.to_lower() if dr.want_open else "E: open the %s" % dn.to_lower()
			"bed": prompt = "E: sleep until morning" if can_sleep() else "Too early to sleep (rest after %02d:00)" % int(prog.cfg.get("home", {}).get("sleep_from_hour", 17.0))
			"discovery": prompt = "E: open the old lockbox"
			"rig":
				var ri := int(last_target.get_meta("index"))
				if ri < prog.rigs.size():
					var rr: Dictionary = prog.rigs[ri]
					prompt = "E: %s  -  %s  (bin %d/%d)" % [str(prog.machine(str(rr["type"]))["title"]), str(rr["status"]), prog.rig_bin_total(rr), prog.rig_bin_cap(rr)]
			"piece": prompt = "E: collect "+str(last_target.get_meta("resource"))
			"crusher": prompt = "E: use crusher"
			"sell": prompt = "E: sell materials"
			"shop": prompt = "E: order machinery"
			"output": prompt = "E: output storage"
			"conveyor":
				var ci := int(last_target.get_meta("index"))
				var link: Dictionary = business.links[ci] if ci < business.links.size() else {}
				prompt = "Conveyor #%d: %s -> %s | B to move" % [ci + 1, business.describe_ep(link.get("src", {})), business.describe_ep(link.get("dst", {}))]
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
	hud.set_prompt(prompt)
	hud.tutorial = tutorial_visible and not driving
	hud_refresh_t -= delta
	if hud_refresh_t <= 0.0:
		hud_refresh_t = 0.2
		hud.refresh_panels()
	_update_machines(delta)

func _update_light() -> void:
	var phase := fposmod(state.clock_minutes,1440.0)/1440.0
	var elevation := sin(phase*TAU-PI/2.0)
	var day := clampf((elevation+0.17)*1.5,0.0,1.0)
	daylight.rotation_degrees.x = -25.0-65.0*maxf(0.0,elevation)
	daylight.light_energy = 0.14+day*1.4
	sky_light.environment.background_color = Color(0.025,0.04,0.09).lerp(Color(0.36,0.49,0.62),day)
	sky_light.environment.ambient_light_energy = 0.14+day*0.4
	if art:
		art.set_night(1.0 - day)
	if landscape:
		landscape.set_day(day)

func _unhandled_input(event: InputEvent) -> void:
	if hud and hud.card_open():
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
			hud.close_card()
			if menu == "":
				player.locked = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if touch_mode and menu == "" and event is InputEventMouseButton and not event.has_meta("touch_ok"):
		return # screen taps / drags are emulated mouse clicks: only the on-screen buttons act in the world
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
		"bed":
			try_sleep()
		"door":
			for dr in doors:
				if str(dr.name) == str(target.get_meta("door")):
					dr.toggle()
		"discovery":
			_read_discovery(str(target.get_meta("discovery")))
		"rig":
			_open_menu("rig", int(target.get_meta("index")))
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

## Every menu button goes through here: rapid repeat clicks on the same button inside 150 ms are ignored (no
## doubled transactions), the action runs once, and a money drop shows a red "-$n" at the button. Gains arrive
## through state.money_earned (_on_income) and use the same anchor, so "+$n" also rises from the button.
func ui_click(key: String, action: Callable, btn: Control = null) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_click_ms.get(key, -100000)) < CLICK_GUARD_MS:
		return
	_click_ms[key] = now
	_tx_anchor = _button_anchor(btn)
	var before := state.money
	action.call()
	if state.money < before and hud:
		hud.popup_spend(before - state.money, _tx_anchor)
	_tx_anchor = Vector2.INF
	if menu != "" and menu != "manage":
		_draw_menu()
	elif menu == "manage":
		management.refresh()

func _button_anchor(btn: Control) -> Vector2:
	if btn == null or not is_instance_valid(btn) or not btn.is_inside_tree():
		return Vector2.INF
	var r := btn.get_global_rect()
	return Vector2(r.position.x + r.size.x * 0.5, r.position.y)

func _draw_menu() -> void:
	if menu == "" or menu == "manage":
		return
	var p: QuarryStationUI = panel
	var m := state.money
	var idx := int(panel.get_meta("crusher_index", -1))
	p.fit(520.0 if menu == "pause" else 700.0, 165.0 if menu == "pause" else 470.0)
	match menu:
		"pause":
			p.begin("PAUSED", -1, "Optional keys:  F5 save   F9 load   Esc resume")
			p.text("The quarry waits for you. Save with the button or F5.", QuarryTheme.DIM, true)
			p.button_bar([["resume", "RESUME", true, func(): _close_menu()], ["save", "SAVE GAME", true, func(): _save()], ["load", "LOAD GAME", true, func(): _load()]])
		"sell": _draw_sell(p)
		"upgrades": _draw_upgrades(p)
		"storage":
			p.begin("STORAGE   %d / %d" % [state.total(state.storage), state.storage_capacity()], -1, "Optional keys: 1-6 store all, Shift+1-6 take all")
			for i in range(RESOURCE_ORDER.size()):
				var key: String = RESOURCE_ORDER[i]
				p.row([[prog.display(key), QuarryTheme.INK, 150], ["bag %d" % int(state.inventory[key]), QuarryTheme.DIM, 90], ["stored %d" % int(state.storage[key]), QuarryTheme.DIM, 110]],
					[["store_" + key, "STORE ALL", int(state.inventory[key]) > 0, func(): menu_act("storage", i, false)], ["take_" + key, "TAKE ALL", int(state.storage[key]) > 0, func(): menu_act("storage", i, true)]], QuarryTheme.RES_COLORS.get(key, Color.WHITE))
		"crusher":
			if idx >= 0 and idx < state.crushers.size():
				var c: Dictionary = state.crushers[idx]
				p.begin("STONE CRUSHER #%d" % (idx + 1), m, "Optional keys: 1 load, 2 start, 3 collect, 4 hopper")
				p.text("Hopper (automated feed): %d      Limestone input: %d      Crushed output: %d" % [c.get("hopper", 0), c["input"], c["output"]], QuarryTheme.INK)
				p.text("Limestone in your bag: %d      %s" % [state.inventory["limestone"], ("Running: %.1f sec left" % c["remaining"]) if c["running"] else "Idle"])
				p.button_bar([["load", "LOAD LIMESTONE", int(state.inventory["limestone"]) > 0, func(): menu_act("crusher", 0, false)], ["start", "START", not bool(c["running"]) and int(c["input"]) > 0, func(): menu_act("crusher", 1, false)]])
				p.button_bar([["collect", "COLLECT OUTPUT", int(c["output"]) > 0, func(): menu_act("crusher", 2, false)], ["hopper", "HOPPER > INPUT", int(c.get("hopper", 0)) > 0, func(): menu_act("crusher", 3, false)]])
		"output":
			if idx >= 0 and idx < business.outputs.size():
				var items: Dictionary = business.outputs[idx]["items"]
				p.begin("OUTPUT STORAGE #%d   %d / %d" % [idx + 1, business.output_total(idx), business.output_capacity()], -1, "Optional keys: 1-6 withdraw, Shift+4 deposit gravel")
				for i in range(RESOURCE_ORDER.size()):
					var key: String = RESOURCE_ORDER[i]
					p.row([[prog.display(key), QuarryTheme.INK, 150], ["stored %d" % int(items[key]), QuarryTheme.DIM, 110], ["bag %d" % int(state.inventory[key]), QuarryTheme.DIM, 90]],
						[["take_" + key, "WITHDRAW", int(items[key]) > 0, func(): menu_act("output", i, false)]], QuarryTheme.RES_COLORS.get(key, Color.WHITE))
				p.button_bar([["deposit_gravel", "DEPOSIT GRAVEL FROM BAG", int(state.inventory["crushed_stone"]) > 0, func(): menu_act("output", 3, true)], ])
		"shop": _draw_shop(p)
		"rig_pick":
			var m_rig := prog.machine(rig_pick_type)
			p.begin("INSTALL %s" % str(m_rig["title"]).to_upper(), m, "Choose the formation it will work.")
			var ids := _rig_formations()
			for i in range(ids.size()):
				var why := prog.rig_block_reason(rig_pick_type, ids[i])
				p.item("pick_" + ids[i], str(prog.fdef(ids[i])["title"]), "%d %s left" % [prog.units_left(ids[i]), prog.display(str(prog.fdef(ids[i])["resource"]))],
					int(m_rig["price"]), "free pad" if why == "" else "", "INSTALL", why == "", func(): install_rig(rig_pick_type, ids[i]), why if why != "" and not why.begins_with("Need $") else "")
			p.button_bar([["back", "BACK TO ORDERS", true, func(): menu = "shop"]])
		"rig":
			if idx >= 0 and idx < prog.rigs.size():
				var r: Dictionary = prog.rigs[idx]
				var mm := prog.machine(str(r["type"]))
				var up := prog.rig_upgrade_info(r)
				p.begin("%s #%d   LEVEL %d" % [str(mm["title"]).to_upper(), idx + 1, int(r["level"]) + 1], m, "Optional keys: 1 collect, 2 on/off, 3 upgrade")
				p.text(str(prog.fdef(str(r["formation"]))["title"]), QuarryTheme.ACCENT)
				p.text("Status: %s      Rate: %.0f %s per in-game hour" % [str(r["status"]), prog.rig_rate_per_hour(r), prog.display(str(prog.fdef(str(r["formation"]))["resource"]))], QuarryTheme.INK)
				p.text("Running cost: $%.1f per in-game minute      Output bin: %d / %d" % [float(mm["cost_per_min"]), prog.rig_bin_total(r), prog.rig_bin_cap(r)], QuarryTheme.INK)
				p.button_bar([["collect", "COLLECT BIN", prog.rig_bin_total(r) > 0, func(): menu_act("rig", 0, false)], ["power", "SWITCH %s" % ("OFF" if bool(r["on"]) else "ON"), true, func(): menu_act("rig", 1, false)]])
				if not up.is_empty():
					p.item("upgrade", "Upgrade", str(up["effect"]), int(up["cost"]), "Level %d" % (int(r["level"]) + 1), "UPGRADE", true, func(): menu_act("rig", 2, false))
				else:
					p.text("Fully upgraded.", QuarryTheme.GOOD)

func _draw_sell(p: QuarryStationUI) -> void:
	var bag_value := 0
	for key in RESOURCE_ORDER:
		bag_value += int(state.inventory[key]) * int(state.config["prices"][key])
	p.begin("SALES BOOTH", state.money, "Optional keys: 1-6 sell, 7 sell all, Shift+1-6 clerk on/off")
	var R := HORIZONTAL_ALIGNMENT_RIGHT
	p.row([["MATERIAL", QuarryTheme.DIM, 120], ["IN BAG", QuarryTheme.DIM, 60, R], ["PRICE EACH", QuarryTheme.DIM, 90, R], ["SALE VALUE", QuarryTheme.DIM, 100, R]], [], Color(0, 0, 0, 0), true)
	for i in range(RESOURCE_ORDER.size()):
		var key: String = RESOURCE_ORDER[i]
		var n := int(state.inventory[key])
		var price := int(state.config["prices"][key])
		var ok: bool = business.authorized[key]
		p.row([[prog.display(key), QuarryTheme.INK, 120, HORIZONTAL_ALIGNMENT_LEFT, true], [str(n), QuarryTheme.INK if n > 0 else QuarryTheme.DIM, 60, R], ["$%d" % price, QuarryTheme.DIM, 90, R], [QuarryTheme.money_text(n * price), QuarryTheme.MONEY if n > 0 else QuarryTheme.DIM, 100, R, true]],
			[["clerk_" + key, "Clerk: " + ("on" if ok else "off"), true, func(): menu_act("sell", i, true), 84, "toggle"], ["sell_" + key, "SELL", n > 0, func(): menu_act("sell", i, false), 80, "primary"]], QuarryTheme.RES_COLORS.get(key, Color.WHITE))
	p.button_bar([["sell_all", "SELL ALL   %s" % QuarryTheme.money_text(bag_value), bag_value > 0, func(): menu_act("sell", 6, false), 260, "primary"]])
	p.text("'Clerk' chooses what the sales clerk may sell for you. It never stops you selling by hand.")

func _draw_upgrades(p: QuarryStationUI) -> void:
	p.begin("UPGRADE BOARD", state.money, "Optional keys: 1 next tool, 2-6 upgrades")
	var nt := prog.next_tool()
	var tools_total := prog.tools().size()
	if nt.is_empty():
		p.text("TOOL: %s - the best tool is yours." % str(prog.tool()["title"]), QuarryTheme.GOOD)
	else:
		p.item("tool", str(nt["title"]), "%s  (MINING POWER +%d%%)" % [str(nt.get("desc", "")), prog.tool_gain_percent(state.tool_tier, state.tool_tier + 1)], int(nt["cost"]),
			"Tool %d / %d" % [state.tool_tier + 1, tools_total], "BUY", true, func(): menu_act("upgrades", 0, false))
	for i in range(UPGRADE_MENU.size()):
		var key: String = UPGRADE_MENU[i]
		var info: Dictionary = prog.cfg.get("player_upgrades", {}).get(key, {})
		var owned: bool = state.upgrades[key]
		p.item("up_" + key, str(info.get("title", key)), str(info.get("effect", "")), int(state.config["upgrades"][key]),
			"OWNED" if owned else "Level 0 / 1", "OWNED" if owned else "BUY", not owned, func(): menu_act("upgrades", i + 1, false))

func _draw_shop(p: QuarryStationUI) -> void:
	p.begin("MACHINERY ORDERS", state.money, "Optional keys: 1-7 order. Placement: R rotate, G grid snap, LMB place, Esc refund.")
	var machines_ok := prog.unlocked("crusher")
	var stage_note := "Unlocks at the %s stage" % prog.feature_stage_title("crusher")
	p.item("shop_crusher", "Stone crusher", "Turns limestone into gravel. Place it on clear ground.", int(state.config["crusher_price"]), "Owned: %d" % state.crushers.size(), "ORDER", machines_ok, func(): menu_act("shop", 0, false), "" if machines_ok else stage_note)
	p.item("shop_output", "Output storage", "Holds crushed stone from a crusher chute.", int(business.cfg["output_storage_price"]), "Owned: %d" % business.outputs.size(), "ORDER", machines_ok, func(): menu_act("shop", 1, false), "" if machines_ok else stage_note)
	var conv_ok := business.conveyors_unlocked()
	p.item("shop_conveyor", "Conveyor section", "Carries material between machines.", int(business.cfg["conveyor_price"]), "Owned: %d" % business.conveyors.size(), "ORDER", conv_ok, func(): menu_act("shop", 2, false), "" if conv_ok else "Needs a crusher + operator")
	var adv_ok := prog.unlocked("advanced_crusher")
	p.item("shop_advanced", "Advanced crusher", "2x batch size and 2x speed.", int(prog.machine("advanced_crusher")["price"]), "", "ORDER", adv_ok, func(): menu_act("shop", 3, false), "" if adv_ok else "Unlocks at the %s stage" % prog.feature_stage_title("advanced_crusher"))
	for pair in [["drill_rig", "Drilling rig", "Works stone, coal, iron and copper from a fixed pad.", 4], ["rock_breaker", "Rock breaker", "Breaks any rock, gold too.", 5]]:
		var t: String = pair[0]
		var owned := 0
		for r in prog.rigs:
			if str(r["type"]) == t:
				owned += 1
		var ok := prog.unlocked(t)
		p.item("shop_" + t, str(pair[1]), str(pair[2]), int(prog.machine(t)["price"]), "Owned: %d" % owned, "ORDER", ok, func(): menu_act("shop", int(pair[3]), false), "" if ok else "Unlocks at the %s stage" % prog.feature_stage_title(t))
	if prog.level_unlocked >= 2:
		p.item("shop_permit", "Excavation permit", "The lower level is open.", 0, "OWNED", "OWNED", false, func(): pass)
	else:
		var pok := prog.unlocked("permit")
		p.item("shop_permit", "Excavation permit", "Opens a 3.5 m lower level with copper and gold.", prog.permit_cost(), "", "BUY", pok, func(): menu_act("shop", 6, false), "" if pok else "Unlocks at the %s stage" % prog.feature_stage_title("permit"))
	p.text("Rigs work a formation from a drilling pad and fill their own output bin: collect it (E), send a hauler, a belt or the loader.")

func _menu_key(event: InputEventKey) -> void:
	if event.keycode == KEY_F5:
		_save()
	elif event.keycode == KEY_F9:
		_load()
	var digit := int(event.physical_keycode) - KEY_1
	if digit < 0 or digit > 8:
		_draw_menu()
		return
	menu_act(menu, digit, event.shift_pressed)
	_draw_menu()

## One menu action. Buttons and the optional number keys both end up here (digit = 0-based slot).
func menu_act(kind: String, digit: int, shift: bool) -> void:
	match kind:
		"sell":
			if digit < RESOURCE_ORDER.size() and shift:
				business.authorized[RESOURCE_ORDER[digit]] = not business.authorized[RESOURCE_ORDER[digit]]
			elif digit < RESOURCE_ORDER.size():
				sell_from_bag([RESOURCE_ORDER[digit]])
			elif digit == 6:
				sell_from_bag(RESOURCE_ORDER)
		"upgrades":
			if digit == 0:
				buy_next_tool()
			elif digit - 1 < UPGRADE_MENU.size():
				buy_player_upgrade(UPGRADE_MENU[digit - 1])
		"storage":
			if digit < RESOURCE_ORDER.size():
				if shift:
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
				if shift:
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
				3: _start_placement("advanced_crusher")
				4, 5:
					var t := "drill_rig" if digit == 4 else "rock_breaker"
					if not prog.unlocked(t):
						_notify("The %s unlocks at the %s stage." % [str(prog.machine(t)["title"]), prog.feature_stage_title(t)])
					else:
						rig_pick_type = t
						menu = "rig_pick"
				6: buy_permit()
		"rig_pick":
			var ids := _rig_formations()
			if digit < ids.size():
				install_rig(rig_pick_type, ids[digit])
		"rig":
			var ri := int(panel.get_meta("crusher_index"))
			if ri >= 0 and ri < prog.rigs.size():
				var r: Dictionary = prog.rigs[ri]
				match digit:
					0:
						var res := prog.rig_resource(r)
						var n := state.add_item(res, int(r["bin"].get(res, 0)))
						prog.rig_take(r, res, n)
						if n > 0:
							_reward_popup(res, n)
						else:
							_notify("Nothing to collect, or your bag is full.")
					1:
						r["on"] = not bool(r["on"])
					2:
						var up := prog.rig_upgrade_info(r)
						if not up.is_empty() and prog.upgrade_rig(r):
							hud.toast(str(prog.machine(str(r["type"]))["title"]) + " upgraded", str(up["effect"]), "unlock")
							_sfx_unlock()
						elif not up.is_empty():
							_notify("Need $%d" % int(up["cost"]))

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
	if excavation and excavation.lower_build_ok(pos):
		return true
	if pit_zone and pit_zone.build_ok(pos, margin):
		return true
	if pos.y < -0.5:
		return false
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
	# Phase 5: aim at the actual ground (upper floor or the lower excavation level)
	var gq := PhysicsRayQueryParameters3D.create(start, start + dir * 12.0, 1)
	gq.exclude = [player.get_rid()]
	var gh := get_world_3d().direct_space_state.intersect_ray(gq)
	if gh and (str(gh["collider"].name) == "Quarry floor" or gh["collider"].has_meta("ground")) and start.distance_to(gh["position"]) < 12.0:
		point = gh["position"]
	if grid_snap or placement_kind != "conveyor":
		ghost.position = Vector3(snappedf(point.x,0.5),point.y if point.y < -1.0 else 0.0,snappedf(point.z,0.5))
	else:
		ghost.position = Vector3(point.x,point.y if point.y < -1.0 else 0.0,point.z)
	if placement_kind == "conveyor" and grid_snap:
		var snap := conveyor_snap(ghost.position)
		if not snap.is_empty():
			ghost.position = Vector3(snap["pos"].x, ghost.position.y, snap["pos"].z)
			placement_yaw = float(snap["yaw"])
	ghost.rotation.y = placement_yaw
	ghost.visible = true
	placement_hint = ""
	if placement_kind == "conveyor":
		ghost_valid = conveyor_valid(ghost.position,placement_yaw)
		var link := business.link_for(ghost.position,placement_yaw)
		placement_hint = "\nIN: %s  ->  OUT: %s%s" % [business.describe_ep(link["src"]), business.describe_ep(link["dst"]), "  |  CONNECTED" if not link["src"].is_empty() and not link["dst"].is_empty() else "  |  align both ends"]
	else:
		ghost_valid = placement_valid(ghost.position,placement_yaw)
	if ghost_ok_mat == null:
		ghost_ok_mat = StandardMaterial3D.new()
		ghost_ok_mat.albedo_color = Color(0.35, 0.95, 0.4, 0.5)
		ghost_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_ok_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_bad_mat = ghost_ok_mat.duplicate()
		ghost_bad_mat.albedo_color = Color(1.0, 0.25, 0.2, 0.5)
	for child in ghost.find_children("*", "MeshInstance3D", true, false):
		child.material_override = ghost_ok_mat if ghost_valid else ghost_bad_mat

func _place_ghost() -> void:
	if not ghost_valid:
		_notify("Blocked. Choose clear, level ground.")
		return
	if not relocating.is_empty():
		_finish_relocation()
		return
	match placement_kind:
		"crusher", "advanced_crusher":
			state.new_crusher(ghost.position,placement_yaw, 2 if placement_kind == "advanced_crusher" else 1)
			_create_crusher(state.crushers.size()-1)
			_notify("Crusher placed! E to load and process limestone.")
			prog.check_stages()
		"output":
			_create_output(business.add_output(ghost.position,placement_yaw))
			_notify("Output storage placed. Place it beside a crusher's chute or at a conveyor end.")
		"conveyor":
			_create_conveyor(business.add_conveyor(ghost.position,placement_yaw))
			var link: Dictionary = business.links.back()
			_notify("Conveyor: %s -> %s. B then LMB to move it if disconnected." % [business.describe_ep(link["src"]), business.describe_ep(link["dst"])])
	business.compute_links()
	business.check_milestones()
	nav_dirty = true
	_cancel_placement(false)

func _placement_price(kind: String) -> int:
	match kind:
		"advanced_crusher": return int(prog.machine("advanced_crusher")["price"])
		"output": return int(business.cfg["output_storage_price"])
		"conveyor": return int(business.cfg["conveyor_price"])
	return int(state.config["crusher_price"])

func _start_placement(kind: String) -> void:
	if kind in ["crusher", "output", "advanced_crusher"] and not prog.unlocked("crusher"):
		_notify("Machinery unlocks at the %s stage." % prog.feature_stage_title("crusher"))
		return
	if kind == "advanced_crusher" and not prog.unlocked("advanced_crusher"):
		_notify("The advanced crusher unlocks at the %s stage." % prog.feature_stage_title("advanced_crusher"))
		return
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
		"advanced_crusher": _crusher_visual(ghost,true,2)
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

func _crusher_visual(parent: Node3D, transparent := false, tier := 1) -> void:
	if art:
		art.crusher_model(parent, 0.0, tier)
		return
	_visual_box(parent,Vector3(0,0.5,0),Vector3(1.6,1.0,1.4),Color(0.19,0.25,0.27))
	_visual_box(parent,Vector3(0,1.16,0),Vector3(1.1,0.44,1.0),Color(0.44,0.39,0.28))
	_visual_box(parent,Vector3(0,0.15,-0.68),Vector3(1.15,0.24,0.24),Color(0.12,0.13,0.14))
	if transparent:
		for child in parent.get_children():
			child.transparency = 0.45

func _create_crusher(index: int) -> void:
	var data: Dictionary = state.crushers[index]
	var p: Array = data["position"]
	var tier := int(data.get("tier", 1))
	var body := _solid(world,"Stone crusher" if tier < 2 else "Advanced crusher",Vector3(float(p[0]),float(p[1])+0.57,float(p[2])),Vector3(1.8,1.14,1.6) if tier < 2 else Vector3(2.0,1.14,1.9),Color(0.22,0.27,0.29),float(data["yaw"]))
	body.set_meta("kind","crusher")
	body.set_meta("index",index)
	body.set_meta("ground_y", float(p[1]))
	_visual_box(body,Vector3(0,0.68,0),Vector3(1.0,0.45,1.0),Color(0.44,0.39,0.28))
	if art:
		art.dress_crusher(body, tier)
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	lbl.font_size = 26
	lbl.pixel_size = 0.006
	lbl.outline_size = 7
	lbl.position = Vector3(0, 1.75, 0)
	lbl.visibility_range_end = 14.0
	body.add_child(lbl)
	body.set_meta("label", lbl)
	body.set_meta("spin", 0.0)
	body.set_meta("last_output", int(data["output"]))
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
	data["phase5"] = prog.snapshot()
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
	var phase5 = data.get("phase5", {})
	var vtypes := []
	for v in fleet.vehicles:
		vtypes.append(str(v["type"]))
	prog.restore(phase5 if phase5 is Dictionary else {}, vtypes)
	debris_dmg.clear()
	_spawn_cleanup()
	if not data.has("phase5") and not data.has("earned"):
		# Phase 1-4 save: count what the business has already sold toward the stages.
		var rev := 0
		for day in business.daily:
			rev += int(business.daily[day].get("revenue", 0))
		state.earned = maxi(state.earned, rev + state.money)
		prog.check_stages()
	var legacy := _migrate_legacy_deposits()
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
	excavation.set_open(prog.level_unlocked >= 2)
	_sync_formations()
	_sync_rigs()
	for kind in deposit_nodes:
		_refresh_deposit(kind)
	var ids := {}
	for id in data["pieces"]:
		ids[str(id)] = true
	var legacy_pieces := {}
	for id in ids:
		var parts: PackedStringArray = str(id).split("_")
		if parts.size() >= 3:
			var kind := "_".join(parts.slice(0,parts.size()-2))
			if deposit_nodes.has(kind):
				_spawn_piece(kind,int(parts[parts.size()-2]),int(parts[parts.size()-1]))
			elif LEGACY_DEPOSITS.has(kind):
				legacy_pieces[kind] = int(legacy_pieces.get(kind, 0)) + 1
	_restore_legacy_pieces(legacy_pieces)
	for did in discovery_nodes.keys():
		discovery_nodes[did].queue_free()
	discovery_nodes.clear()
	for did in prog.story["found"]:
		if not prog.story["read"].get(did, false):
			_spawn_discovery(did, str(prog.story.get("found_at", prog.cfg.get("starting_formations", ["stone_mountain"])[0])))
	player.tool_view.equip(state.tool_tier, true)
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
	_notify("Loaded quarry progress" + (" - your old quarry has grown: three huge formations replace the small rocks." if legacy else ""))
	if hud:
		hud.shown_money = float(state.money)
		hud.refresh_panels()

# ===================================================================== Phase 2

func _on_milestone(id: String) -> void:
	if hud:
		var titles := {"first_employee": ["Milestone: First Employee", "Remote management (M) and +5% staff productivity"], "mechanized": ["Milestone: Mechanized Quarry", "Conveyor belts and the front loader unlocked"], "automated": ["Milestone: Automated Business", "The east expansion is open"]}
		var t: Array = titles.get(id, [id, ""])
		hud.toast(str(t[0]), str(t[1]), "milestone")
		_sfx_unlock()
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
	nav_rebakes += 1
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
				if body is QuarryFormation and child.has_meta("column") and bool(prog.fdef(body.fid).get("strict", false)) and not prog.column_exposed(body.fid, int(child.get_meta("column"))):
					continue # buried hillside columns are not part of any walkable surface or obstacle edge
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
	mesh.filter_baking_aabb = AABB(Vector3(-30,-6,-30), Vector3(82,14,60))
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
			return {"pos": Business.v3(c["position"]), "radius": 2.0 if int(c.get("tier", 1)) < 2 else 2.3, "face": -Business.forward(float(c["yaw"]))}
		"output":
			var i := int(ep.get("index", -1))
			if i < 0 or i >= business.outputs.size():
				return {}
			return {"pos": Business.v3(business.outputs[i]["position"]), "radius": 1.7, "face": Vector3(0,0,1)}
		"rig":
			var ri := int(ep.get("index", -1))
			if ri < 0 or ri >= prog.rigs.size():
				return {}
			var bp := prog.rig_bin_pos(prog.rigs[ri])
			var pd := prog.pad(str(prog.rigs[ri]["formation"]), int(prog.rigs[ri]["pad"]))
			return {"pos": bp, "radius": 1.25, "face": Basis(Vector3.UP, float(pd["yaw"])) * Vector3(1, 0, 0)}
		"deposit_site":
			var id := str(ep.get("id", ""))
			if not deposit_nodes.has(id):
				return {}
			if formation_nodes.has(id):
				var col := int(ep.get("col", -1))
				if col < 0 or col >= prog.column_count(id) or prog.column_units(id, col) <= 0:
					return {}
				var cp := prog.column_pos(id, col)
				var cell := float(prog.fdef(id)["cell"])
				return {"pos": cp, "radius": cell * 0.5 + 0.95, "face": prog.column_open_dir(id, col, cp + Vector3(0, 0, 9))}
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
		if not prog.can_mine(res) or prog.formation_locked(kind) != "":
			continue # staff carry company tools: nothing harder than the best owned tool; locked faces stay closed
		var p: Vector3 = deposit_nodes[kind].global_position
		if formation_nodes.has(kind):
			var col := prog.nearest_column(kind, from, true)
			if col < 0:
				continue
			p = prog.column_pos(kind, col)
		var d: float = p.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = kind
	return best

func worker_strike(kind: String, hits: int, extra: int, worker: Node3D) -> void:
	if formation_nodes.has(kind):
		_crew_strike_formation(kind, hits, extra, worker)
	elif deposit_nodes.has(kind):
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
			w.position = delivery.gate_point(business.employees.find(e)) if delivery else break_spot(business.employees.find(e)) + Vector3(0, 0.05, 0)
		workers_root.add_child(w)
		worker_nodes[id] = w

# --------------------------------------------------------------- management actions (UI)

func ui_hire(candidate_id: String) -> String:
	if not prog.unlocked("hire"):
		return "Hiring opens at the %s stage. Keep mining and selling!" % prog.feature_stage_title("hire")
	var reason := business.hire_block_reason(candidate_id)
	if reason != "":
		return reason
	var e := business.hire(candidate_id)
	_sync_workers()
	prog.check_stages()
	if business.employees.size() == 1:
		hud.toast("First employee: " + str(e["name"]), "They'll mine right beside you.", "milestone")
		_sfx_unlock()
	return "Hired %s. They walk in through the service gate, then head to work during their shift." % e["name"]

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
	if art:
		art.output_model(parent, 0.0)
		return
	_visual_box(parent,Vector3(0,0.55,0),Vector3(1.4,1.1,1.4),Color(0.24,0.30,0.22))
	_visual_box(parent,Vector3(0,1.12,0),Vector3(1.5,0.08,1.5),Color(0.40,0.36,0.22))
	if transparent:
		for child in parent.get_children():
			child.transparency = 0.45

func _conveyor_visual(parent: Node3D, transparent := false) -> void:
	if art:
		art.conveyor_model(parent, 0.0)
		return
	_visual_box(parent,Vector3(0,0.13,0),Vector3(0.9,0.26,2.0),Color(0.16,0.17,0.18))
	_visual_box(parent,Vector3(0,0.27,0),Vector3(0.7,0.04,2.0),Color(0.07,0.07,0.07))
	_visual_box(parent,Vector3(0,0.30,-0.75),Vector3(0.2,0.02,0.32),Color(0.85,0.70,0.15))
	if transparent:
		for child in parent.get_children():
			child.transparency = 0.45

func _create_output(index: int) -> void:
	var data: Dictionary = business.outputs[index]
	var p := Business.v3(data["position"])
	var body := _solid(world,"Output storage",Vector3(p.x,p.y+0.55,p.z),Vector3(1.4,1.1,1.4),Color(0.24,0.30,0.22),float(data["yaw"]))
	body.set_meta("ground_y", p.y)
	body.set_meta("kind","output")
	body.set_meta("index",index)
	_visual_box(body,Vector3(0,0.57,0),Vector3(1.5,0.08,1.5),Color(0.40,0.36,0.22))
	var fill := _visual_box(body,Vector3(0,0.3,0),Vector3(1.2,0.5,1.2),Color(0.75,0.73,0.66))
	body.set_meta("fill", fill)
	if art:
		art.dress_output(body)
	output_nodes.append(body)

func _create_conveyor(index: int) -> void:
	var data: Dictionary = business.conveyors[index]
	var p := Business.v3(data["position"])
	# Phase 3: a low belt on its own collision layer (16). People step over it; vehicles,
	# placement and interaction still see it. Small supports mark the crossing points.
	var body := _solid(world,"Conveyor",Vector3(p.x,p.y+0.13,p.z),Vector3(0.9,0.26,2.0),Color(0.16,0.17,0.18),float(data["yaw"]))
	body.set_meta("ground_y", p.y)
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
	if art:
		art.dress_conveyor(body)
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
	if storage_body.has_meta("fill"):
		var sf: MeshInstance3D = storage_body.get_meta("fill")
		var sratio := float(state.total(state.storage)) / float(maxi(1, state.storage_capacity()))
		sf.visible = sratio > 0.0
		sf.scale.y = maxf(0.08, sratio)
		sf.position.y = -0.55 + 0.6 * maxf(0.08, sratio) * 0.5
	for i in range(mini(output_nodes.size(), business.outputs.size())):
		var fill: MeshInstance3D = output_nodes[i].get_meta("fill")
		var ratio := float(business.output_total(i)) / float(business.output_capacity())
		fill.visible = ratio > 0.0
		fill.scale.y = maxf(0.05, ratio)
		fill.position.y = -0.5 + 0.5 * maxf(0.05, ratio) + 0.08

## Magnetic placement for belts (grid snap on): within 2.6 m of a machine port or the end of another belt, the
## ghost jumps to the spot where its end touches the machine and faces along the flow, so it links with no
## fiddling. Returns {"pos", "yaw"} or {} when nothing is near. Press G to place freely.
func conveyor_snap(at: Vector3) -> Dictionary:
	var best := {}
	var best_d := 2.6
	var cands := []
	for i in range(state.crushers.size()):
		var c: Vector3 = Business.v3(state.crushers[i]["position"]) * Vector3(1, 0, 1)
		var yc := float(state.crushers[i]["yaw"])
		var f := Business.forward(yc)
		var adv := int(state.crushers[i].get("tier", 1)) >= 2
		cands.append({"pos": c - f * (2.0 if adv else 1.8), "yaw": yc})   # feeds the input (back) side
		cands.append({"pos": c + f * (2.2 if adv else 2.0), "yaw": yc})   # carries away from the discharge chute
	for o in business.outputs:
		var op: Vector3 = Business.v3(o["position"]) * Vector3(1, 0, 1)
		for k in range(4):
			var yk := float(k) * PI * 0.5
			cands.append({"pos": op - Business.forward(yk) * 1.75, "yaw": yk})
	for j in range(business.conveyors.size()):
		var cp: Vector3 = Business.v3(business.conveyors[j]["position"]) * Vector3(1, 0, 1)
		var yj := float(business.conveyors[j]["yaw"])
		cands.append({"pos": cp + Business.forward(yj) * 2.0, "yaw": yj})
		cands.append({"pos": cp - Business.forward(yj) * 2.0, "yaw": yj})
	for cd in cands:
		var d := Vector2(at.x, at.z).distance_to(Vector2(cd["pos"].x, cd["pos"].z))
		if d < best_d and conveyor_valid(Vector3(cd["pos"].x, at.y, cd["pos"].z), float(cd["yaw"])):
			best_d = d
			best = cd
	return best

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
		if _near_vehicle(pos, 3.5) or (delivery and delivery.reserved.has(pos)):
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
	if driving or v == null or v.has_meta("delivering"):
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not touch_mode:
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
	for ri in range(prog.rigs.size()):
		var r: Dictionary = prog.rigs[ri]
		var bp := prog.rig_bin_pos(r)
		if fleet.space(rec) > 0 and got == 0 and prog.rig_bin_total(r) > 0 and Vector2(point.x, point.z).distance_to(Vector2(bp.x, bp.z)) < 2.6:
			var res := prog.rig_resource(r)
			var n := fleet.add_cargo(rec, res, prog.rig_bin_total(r))
			prog.rig_take(r, res, n)
			got += n
			source = "the rig's output bin"
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
		v.curl_timer = 0.6
		fx.impact(point + Vector3(0, 0.5, 0), str(rec["cargo"].keys()[0]) if not rec["cargo"].is_empty() else "limestone", 1.0)
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
	if moved > 0:
		fx.chunk_break(v.work_point() + Vector3(0, 1.0, 0), "limestone")
	_notify("Dumped %d into %s.%s" % [moved, _target_name(t), (" %d left in the bucket (target full or wrong material)." % fleet.cargo_total(rec)) if fleet.cargo_total(rec) > 0 else ""])
	return moved

func truck_finish_unload(v: QuarryVehicle, t: Dictionary) -> int:
	var rec := fleet.vehicle(v.vehicle_id)
	if rec.is_empty() or not t.has("ep") or not business.ep_valid(t["ep"]):
		return 0
	var moved := fleet.dump_to(rec, t["ep"])
	if moved > 0:
		fx.chunk_break(v.work_point() + Vector3(0, 0.8, 0), "limestone")
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
	if not prog.unlocked(type):
		return "The %s unlocks at the %s stage" % [fleet.spec(type)["title"], prog.feature_stage_title(type)]
	var reason := fleet.buy_block_reason(type)
	if reason != "":
		return reason
	var slot = free_parking_slot()
	if slot == null:
		return "Equipment parking is blocked - clear a parking bay south of the yard"
	var rec := fleet.buy(type, slot, 0.0)
	_sync_vehicles()
	nav_dirty = true
	if delivery and not rec.is_empty() and delivery.start(int(rec["id"]), slot):
		return "%s is being driven in through the service door to the equipment parking area." % fleet.spec(type)["title"]
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
	return "%s%s  |  LMB move  |  X sell (+$%d refund)  |  B exit" % [_structure_name(kind, index), (" holding %d items" % n) if n > 0 else "", business.refund_value(kind, index)]

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
		"crusher": _crusher_visual(ghost, true, int(state.crushers[index].get("tier", 1)))
		"output": _output_visual(ghost, true)
		"conveyor": _conveyor_visual(ghost, true)
		"storage":
			if art:
				art.storage_model(ghost, 0.0)
			else:
				_visual_box(ghost, Vector3(0,0.65,0), Vector3(2,1.3,1.6), Color(0.33,0.23,0.13))
	_notify("Moving %s. LMB confirm, R rotate, Esc cancel (stays where it was)." % _structure_name(kind, index))
	return true

func _finish_relocation() -> void:
	var kind := str(relocating["kind"])
	var index := int(relocating["index"])
	var node := _structure_node(kind, index)
	business.move_structure(kind, index, ghost.position, placement_yaw)
	var lift := node.position.y - float(node.get_meta("ground_y", 0.0))
	node.position = ghost.position + Vector3(0, lift, 0)
	node.set_meta("ground_y", ghost.position.y)
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
	if formation_nodes.has(kind):
		var res := str(d["resource"])
		if not prog.can_mine(res):
			return "too hard: needs the %s" % str(prog.tool_for(res)["title"])
		return "%s  %d / %d left" % [str(prog.fdef(kind)["title"]), prog.units_left(kind), prog.max_units(kind)]
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
	if formation_nodes.has(kind):
		formation_nodes[kind].update_label()
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

func _dress_deposit(kind: String) -> void:
	if art == null or not deposit_nodes.has(kind) or formation_nodes.has(kind):
		return
	var info := _deposit_info(kind)
	var face := bool(info.get("infinite", false))
	art.dress_deposit(deposit_nodes[kind], info, Vector3(3.6, 2.4, 1.4) if face else Vector3(2.4, 1.8, 2.0))

# ===================================================================== Phase 5: progression glue

func _phase5_tick(delta: float) -> void:
	prog.check_stages()
	for ev in prog.tick_rigs(delta):
		var id := str(ev["formation"])
		if formation_nodes.has(id):
			formation_nodes[id].hit(int(ev["column"]))
			if int(ev["chunks"]) > 0:
				formation_nodes[id].refresh()
			else:
				formation_nodes[id].update_label()

func _on_income(amount: int, source: String) -> void:
	if hud:
		hud.on_income(amount, source, _tx_anchor)

func _refresh_stage_hud() -> void:
	if hud:
		hud.refresh_panels()

func _on_stage(index: int) -> void:
	var info := prog.stage_info(index)
	if hud:
		hud.toast("Stage %d: %s" % [index + 1, str(info["title"])], str(info["goal"]), "unlock")
	_sfx_unlock()
	_refresh_stage_hud()

func _sfx_unlock() -> void:
	if sfx.has("unlock"):
		sfx["unlock"].play()

func _show_intro() -> void:
	var st: Dictionary = prog.cfg.get("story", {})
	if hud and not prog.story["intro_seen"]:
		player.locked = true
		# two cards: Grandpa's letter, then a short "how to start" so the first day is clear
		hud.show_card(str(st.get("intro_title", "")), str(st.get("intro", "")), func():
			if str(st.get("intro2", "")) != "":
				hud.show_card(str(st.get("intro2_title", "YOUR FIRST DAY")), str(st.get("intro2", "")), func(): prog.story["intro_seen"] = true; player.locked = false)
			else:
				prog.story["intro_seen"] = true
				player.locked = false)

## First formation fully cleared: grandpa's lockbox appears where the rock stood.
func _on_formation_cleared(id: String) -> void:
	nav_dirty = true
	if hud:
		hud.toast("%s cleared!" % str(prog.fdef(id)["title"]), "Every last chunk of it. Look at the space you've opened up.", "milestone")
	_sfx_unlock()
	if id in prog.cfg.get("starting_formations", []) and not prog.story["found"].get("first_clear", false):
		prog.mark_found("first_clear")
		prog.story["found_at"] = id
		_spawn_discovery("first_clear", id)
		if hud:
			hud.toast("Something under the rock...", "An old lockbox is lying where the formation stood.", "unlock")

func _spawn_discovery(did: String, formation: String) -> void:
	if discovery_nodes.has(did) or not prog.is_formation(formation):
		return
	var c: Vector3 = prog.formation_origin_world(formation)
	var body := _solid(world, "Lockbox", Vector3(c.x, c.y + 0.25, c.z), Vector3(0.7, 0.5, 0.45), Color(0.32, 0.22, 0.14), 0.4)
	body.set_meta("kind", "discovery")
	body.set_meta("discovery", did)
	var mi: MeshInstance3D = body.get_child(0)
	mi.mesh = MeshKit.box(Vector3(0.7, 0.5, 0.45), Vector2(0.96, 0.96))
	mi.material_override = MeshKit.mat("SteelGreen")
	MeshKit.inst(body, MeshKit.box(Vector3(0.74, 0.08, 0.49)), MeshKit.mat("SteelPlate"), Vector3(0, 0.2, 0))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.55)
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.8, 0)
	body.add_child(glow)
	discovery_nodes[did] = body

func _read_discovery(did: String) -> void:
	var info := prog.discovery(did)
	var reward := prog.read_discovery(did)
	if discovery_nodes.has(did):
		discovery_nodes[did].queue_free()
		discovery_nodes.erase(did)
	nav_dirty = true
	var body := str(info.get("text", ""))
	if reward > 0:
		body += "\n\n(+%s)" % QuarryTheme.money_text(reward)
	_close_menu()
	hud.show_card(str(info.get("title", "DISCOVERY")), body)
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## One line per production fact for the HUD (only what is really happening).
func hud_status_text() -> String:
	var lines := []
	if prog.cleanup_active():
		lines.append("Site cleanup %d/%d" % [prog.cleanup_total() - prog.cleanup_left(), prog.cleanup_total()])
	var done := 0
	for id in Business.MILESTONES:
		if business.milestones[id]:
			done += 1
	lines.append("Milestones %d/3" % done)
	var running := 0
	for c in state.crushers:
		if bool(c["running"]):
			running += 1
	if state.crushers.size() > 0:
		lines.append("Crushers %d/%d running" % [running, state.crushers.size()])
	if prog.rigs.size() > 0:
		var working := 0
		for r in prog.rigs:
			if bool(r["working"]):
				working += 1
		lines.append("Rigs %d/%d drilling" % [working, prog.rigs.size()])
	if business.employees.size() > 0:
		var on := 0
		for e in business.employees:
			if business.can_work(e):
				on += 1
		lines.append("Staff %d/%d on shift" % [on, business.employees.size()])
	var alerts := 0
	for e in business.employees:
		if str(e["warning"]) != "":
			alerts += 1
			if alerts <= 2:
				lines.append("! %s: %s" % [str(e["name"]).split(" ")[0], e["warning"]])
	if alerts > 2:
		lines.append("! +%d more (M)" % (alerts - 2))
	return "\n".join(lines)

# ------------------------------------------------------------------ staff mining a formation

## Nearest column a staff miner can reach (exposed) on a formation, or -1.
func formation_column(kind: String, from: Vector3) -> int:
	if not formation_nodes.has(kind):
		return -1
	return prog.nearest_column(kind, from, true)

func _crew_strike_formation(kind: String, hits: int, extra: int, w: Node3D) -> void:
	var node: QuarryFormation = formation_nodes[kind]
	var col: int = int(w.mine_col) if w and "mine_col" in w else -1
	if col < 0 or prog.column_units(kind, col) <= 0:
		col = prog.nearest_column(kind, w.global_position if w else node.global_position, true)
	if col < 0:
		return
	var room := maxi(0, int(prog.cfg.get("loose_piece_cap", 36)) - loose_count(kind))
	var ex := prog.extract(kind, col, prog.crew_damage(float(hits), float(extra)), room, "crew")
	var res := str(state.deposits[kind]["resource"])
	for i in range(int(ex["units"])):
		_spawn_formation_piece(kind, col, i)
	node.hit(col)
	if int(ex["chunks"]) > 0:
		node.refresh()
	else:
		node.update_label()
	var at := node.column_top(col)
	if player and player.global_position.distance_to(at) < 22.0:
		fx.impact(at, res, 0.7)
		_sfx_at("hit_pick", at, -4.0)

# ------------------------------------------------------------------ Phase 5: selling and buying

## Sells the listed materials from the bag with one combined confirmation. Returns money earned.
func sell_from_bag(keys: Array) -> int:
	var total := 0
	var parts := []
	for key in keys:
		var n := int(state.inventory[key])
		if n <= 0:
			continue
		var before := state.money
		state.sell(key, n)
		total += state.money - before
		parts.append("%d %s" % [n, prog.display(key).to_upper()])
	if total > 0:
		sfx["coin"].play()
		hud.toast("Sold " + ", ".join(parts), "+" + QuarryTheme.money_text(total), "sale")
		_notify("Sold %s for %s" % [", ".join(parts), QuarryTheme.money_text(total)])
	else:
		_notify("Nothing of that in your bag.")
	return total

func buy_next_tool() -> bool:
	var from := state.tool_tier
	var nt := prog.next_tool()
	if nt.is_empty():
		_notify("You already own the best tool.")
		return false
	if not prog.buy_next_tool():
		_notify("The %s costs %s." % [str(nt["title"]), QuarryTheme.money_text(int(nt["cost"]))])
		return false
	player.tool_view.equip(state.tool_tier)
	hud.toast("New tool: " + str(nt["title"]), "MINING POWER +%d%%" % prog.tool_gain_percent(from, state.tool_tier), "unlock")
	_sfx_unlock()
	_notify(str(nt.get("desc", "")))
	return true

func buy_player_upgrade(key: String) -> bool:
	var info: Dictionary = prog.cfg.get("player_upgrades", {}).get(key, {})
	if not state.buy_upgrade(key):
		_notify("Already owned" if state.upgrades.get(key, false) else "Need $%d" % int(state.config["upgrades"].get(key, 0)))
		return false
	hud.toast(str(info.get("title", key)), str(info.get("effect", "")), "unlock")
	_sfx_unlock()
	return true

# ------------------------------------------------------------------ Phase 5: save migration

## Phase 1-4 saves recorded three small deposits (limestone / coal / iron_ore). They are replaced by the
## formations, which start full; the old records are dropped. Returns true if anything was migrated.
func _migrate_legacy_deposits() -> bool:
	var found := false
	for k in LEGACY_DEPOSITS:
		if state.deposits.has(k) and not bool(state.deposits[k].get("formation", false)):
			state.deposits.erase(k)
			found = true
	return found

## Loose pieces of the old small deposits go back to the player: storage crate, then bag, then as
## loose pieces beside the matching new formation. Nothing is lost or duplicated.
func _restore_legacy_pieces(counts: Dictionary) -> void:
	for kind in counts:
		var res := str(kind)
		var n := int(counts[kind])
		var room := state.storage_capacity() - state.total(state.storage)
		var a := mini(n, maxi(0, room))
		state.storage[res] = int(state.storage[res]) + a
		n -= a
		n -= state.add_item(res, n)
		var f := str(LEGACY_DEPOSITS[kind])
		for i in range(n):
			if formation_nodes.has(f):
				_spawn_formation_piece(f, maxi(0, prog.nearest_column(f, Vector3(0, 0, 8), false)), i)

## Builds or removes formation nodes to match the unlocked level, then re-reads every column.
func _sync_formations() -> void:
	for id in prog.formation_ids():
		if prog.formation_active(id):
			if not formation_nodes.has(id):
				_build_formation(id)
			prog.init_formation(id)
			formation_nodes[id].refresh(true)
		elif formation_nodes.has(id):
			formation_nodes[id].queue_free()
			formation_nodes.erase(id)
			deposit_nodes.erase(id)

# ------------------------------------------------------------------ Phase 5: machinery that shows what it does

var belt_mat_moving: StandardMaterial3D
var _belt_scroll := 0.0

## Crushers: flywheels/mantle spin up and down smoothly, the jaw cycles only while really crushing,
## the hopper shows its real contents, the output pile grows when a run completes, and a small label
## shows run progress. Conveyors: the belt texture scrolls only while the belt carries material.
func _update_machines(delta: float) -> void:
	var any_running := false
	var t := Time.get_ticks_msec() * 0.001
	for i in range(mini(state.crushers.size(), crusher_nodes.size())):
		var c: Dictionary = state.crushers[i]
		var body: Node3D = crusher_nodes[i]
		var running := bool(c["running"])
		any_running = any_running or running
		var spin := move_toward(float(body.get_meta("spin", 0.0)), 1.0 if running else 0.0, delta * (0.8 if running else 0.45))
		body.set_meta("spin", spin)
		var ease := spin * spin * (3.0 - 2.0 * spin)
		var axis_y := str(body.get_meta("spin_axis", "x")) == "y"
		for fw in body.get_meta("flywheels", []):
			if axis_y:
				fw.rotation.y += delta * 9.0 * ease
				fw.rotation.x = sin(t * 9.0) * 0.05 * ease # gyrating mantle
			else:
				fw.rotation.x += delta * 8.0 * ease
		if body.has_meta("jaw") and not axis_y:
			body.get_meta("jaw").rotation.x = sin(t * 7.5) * 0.16 * ease
		var tier := int(c.get("tier", 1))
		var hop: MeshInstance3D = body.get_meta("hopper_fill", null)
		if hop:
			var cap := float(int(business.cfg.get("crusher_hopper_capacity", 24)) * (2 if tier >= 2 else 1) + state.input_limit(i))
			var amount := float(int(c.get("hopper", 0)) + int(c["input"]))
			hop.visible = amount > 0.0
			hop.scale = Vector3(1, clampf(amount / cap, 0.15, 1.0), 1)
		var pile: MeshInstance3D = body.get_meta("output_pile", null)
		if pile:
			var outn := int(c["output"])
			pile.visible = outn > 0
			pile.scale = Vector3.ONE * clampf(0.4 + float(outn) / 24.0, 0.4, 1.3)
		var last := int(body.get_meta("last_output", 0))
		if int(c["output"]) > last:
			# a run just finished: short completion feedback at the chute
			var chute: Vector3 = body.global_transform * Vector3(0, 0.3, -1.3)
			fx.chunk_break(chute, "crushed_stone")
			if player and player.global_position.distance_to(body.global_position) < 18.0:
				sfx["ui_pop"].play()
				_notify("Crusher #%d finished: +%d gravel" % [i + 1, int(c["output"]) - last])
		body.set_meta("last_output", int(c["output"]))
		var lbl: Label3D = body.get_meta("label", null)
		if lbl:
			if running:
				var dur := maxf(0.01, float(c.get("duration", state.process_seconds(i))))
				lbl.text = "CRUSHING %d%%\n%d stone -> gravel" % [int(100.0 * (1.0 - float(c["remaining"]) / dur)), int(c["input"])]
				lbl.modulate = Color(1.0, 0.85, 0.45)
			elif int(c["output"]) > 0:
				lbl.text = "%d GRAVEL READY" % int(c["output"])
				lbl.modulate = Color(0.7, 0.95, 0.6)
			elif int(c.get("hopper", 0)) + int(c["input"]) > 0:
				lbl.text = "WAITING TO START\n%d stone loaded" % (int(c.get("hopper", 0)) + int(c["input"]))
				lbl.modulate = Color(0.95, 0.9, 0.75)
			else:
				lbl.text = "IDLE - EMPTY"
				lbl.modulate = Color(0.75, 0.72, 0.65)
	if belt_mat_moving == null:
		belt_mat_moving = (MeshKit.mat("Belt") as StandardMaterial3D).duplicate()
	_belt_scroll = fposmod(_belt_scroll + delta * float(business.cfg.get("conveyor_rate", 0.5)) * 1.5, 1.0)
	belt_mat_moving.uv1_offset = Vector3(0, _belt_scroll, 0)
	for i in range(mini(conveyor_nodes.size(), business.conveyors.size())):
		var cnode: Node3D = conveyor_nodes[i]
		var belt: MeshInstance3D = cnode.get_meta("belt", null)
		if belt:
			var moving := int(business.conveyors[i]["items"]) > 0 or float(business.conveyors[i]["pull"]) > 0.0
			belt.material_override = belt_mat_moving if moving else MeshKit.mat("Belt")
	if any_running and not crusher_audio.playing:
		crusher_audio.play()
	elif not any_running and crusher_audio.playing:
		crusher_audio.stop()

# ------------------------------------------------------------------ Phase 5: rigs and the lower level

## Formations a rig can be sent to (active, with rock left).
func _rig_formations() -> Array:
	var out := []
	for id in prog.formation_ids():
		if prog.formation_active(id) and prog.units_left(id) > 0:
			out.append(id)
	return out

func install_rig(type: String, formation: String) -> bool:
	var why := prog.rig_block_reason(type, formation)
	if why != "":
		_notify(why)
		return false
	var r := prog.buy_rig(type, formation)
	_sync_rigs()
	nav_dirty = true
	hud.toast("%s installed" % str(prog.machine(type)["title"]), "Working the %s from its drilling pad." % str(prog.fdef(formation)["title"]), "unlock")
	_sfx_unlock()
	_close_menu()
	return not r.is_empty()

func _sync_rigs() -> void:
	for n in rig_nodes:
		n.queue_free()
	rig_nodes.clear()
	for i in range(prog.rigs.size()):
		var node = RigScript.new()
		node.setup(self, prog, i)
		world.add_child(node)
		rig_nodes.append(node)
	business.compute_links()

func buy_permit() -> bool:
	var why := prog.permit_block_reason()
	if why != "":
		_notify(why)
		return false
	prog.buy_permit()
	_open_lower_level()
	return true

func _open_lower_level() -> void:
	excavation.set_open(true)
	_sync_formations()
	hud.toast("Lower level open!", "A ramp leads 3.5 m down to copper and gold.", "milestone")
	_sfx_unlock()
	_notify("Copper needs the Power Drill; gold needs the Heavy Jackhammer (or a rock breaker).")
