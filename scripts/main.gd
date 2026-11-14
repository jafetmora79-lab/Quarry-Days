extends Node3D

const State = preload("res://scripts/state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const Business = preload("res://scripts/business.gd")
const WorkerScript = preload("res://scripts/worker.gd")
const PadScript = preload("res://scripts/gamepad.gd")
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
## Where the yard's buildings stand. The blueprint world (new games) lays the yard out as drawn: tool shed top-left, office top-right,
## storage beside the tool shed, house bottom-right, garage along the bottom with the tunnel coming in from the west (see _init_layout).
var HOME_POS := Vector3(-8.6, 0, 18.9)
var OFFICE_POS := Vector3(-15.5, 0, 12)
var SHED_POS := Vector3(15.5, 0, 12)
var TOOLSHED_POS := Vector3(-7.6, 0, 10.0)         ## the tool upgrade shed (it used to be a corner of the office)
var SELL_ANCHOR := Vector3(-12.3, 0.85, 9.0)       ## where carts and the sales clerk deal: just outside the office door (there is no sales stand any more)
var STORAGE_POS := Vector3(10, 0.65, 10)           ## the storage crate
var GARAGE_DX := 0.0                               ## the garage row's shift along x (blueprint: it sits further west)
var EXP_DZ := 0.0                                  ## the east extension's shift along z (blueprint: south of the quarry fence)
var blueprint := false                             ## true in the blueprint world (the new game)
const SAVE_PATH := "user://quarry_save.json"
const SAVE_BACKUP := "user://quarry_save.bak"
const AUTOSAVE_SECONDS := 60.0
const RESOURCE_ORDER := ["limestone", "coal", "iron_ore", "crushed_stone", "copper_ore", "gold_ore", "topsoil", "gravel"]
# Phase 5: the three small starting rocks are replaced by enormous finite formations (data/progression.json).
# The quarry face stays as the never-empty hand-mining fallback.
const DEPOSIT_INFO := {"limestone_face": {"pos": Vector3(-12.6, 0, -17.6), "color": Color(0.70, 0.68, 0.58), "pieces": 2, "resource": "limestone", "infinite": true, "yaw": -0.65}}
# Phase 10.1: two small natural ore outcrops stand where the big piles used to be (finite and slow to regrow, like the east rocks)
const OUTCROP_INFO := {"coal_outcrop": {"pos": Vector3(2.0, 0, -14.0), "color": Color(0.17, 0.19, 0.21), "pieces": 3, "resource": "coal", "yaw": 0.5},
	"iron_boulder": {"pos": Vector3(11.5, 0, -11.0), "color": Color(0.52, 0.29, 0.23), "pieces": 2, "resource": "iron_ore", "yaw": -0.4}}
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
var placement_from_inventory := false
var placement_belt := "straight"   ## straight | left | right while a belt is being placed
var grid_snap := true
var placement_hint := ""
# Phase 3
var fleet: QuarryFleet
var vehicles_root: Node3D
var vehicle_nodes := {}
var driving: QuarryVehicle
var storage_body: StaticBody3D
var sell_body: StaticBody3D
var pile_nodes := {}
var construction := false
var relocating := {}
var sell_confirm := ""
var sleeping := false
var sleep_timer := 0.0
var _late_day := -1             # day on which the "go home to sleep" hint was shown
var landscape: QuarryLandscape  # sky, clouds, distant mountains and forest (no collision)
var curfew_enabled := true                      ## tests switch it off when they run the clock past the curfew
var introductions_enabled := DisplayServer.get_name() != "headless"   ## headless tests hire workers without the conversation
var autosave_enabled := DisplayServer.get_name() != "headless"   ## tests run headless and never touch the player's save
var autosave_t := 0.0
var _confirm_new := false
var title_enabled := DisplayServer.get_name() != "headless"      ## the main menu opens on launch (tests run headless and skip it)
var title: QuarryTitleMenu
var music: QuarryMusic
var survey: QuarrySurvey
var dialog: QuarryIntroDialog         # the introduction with a new employee, while it is open
var dialog_worker: Node3D
var _forced_sleep := false
var doors: Array = []            # QuarryDoor: the office and home doors (E to open / close)
var delivery: QuarryDelivery    # service gate, garage door, delivery drivers and walk-in hires
var safety: QuarrySafety
var pit_zone: QuarryPitZone     # Phase 6.3a: the new pit area behind the north-east gate
var pit_retired: Array = []     # ring pieces retired to make the gate (for tests)
var cleanup_nodes := {}      # Phase 6.2: weed clumps and rubble heaps still on the site (id -> body)
var debris_dmg := {}         # id -> damage dealt so far
var _weed_mesh: ArrayMesh
var _heap_mesh: ArrayMesh
var gamepad: QuarryGamepad                 # joypad support (see scripts/gamepad.gd)
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
	prog.natural_start_enabled = natural_start_enabled
	_peek_save_layout()
	_init_layout()
	prog.protect = Callable(self, "_column_has_player")
	business.prog = prog
	state.money = int(pcfg.get("new_game_money", state.money))
	state.money_earned.connect(_on_income)
	prog.stage_reached.connect(_on_stage)
	prog.formation_cleared.connect(_on_formation_cleared)
	prog.site_cleared.connect(_on_site_cleared)
	prog.area_completed.connect(_on_area_completed)
	prog.quarry_level_reached.connect(_on_quarry_level)
	prog.road_built_signal.connect(_on_road_built)
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
	for spec in [["Office door", OFFICE_POS + Vector3(0, 0, -2.35), -1.0], ["Home door", HOME_POS + Vector3(0, 0, -2.35), 1.0], ["Tool shed door", TOOLSHED_POS + Vector3(0, 0, -2.35), -1.0]]:
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
	safety = QuarrySafety.new()
	player.name = "Player"
	player.position = Vector3(0, 0.2, 8)
	add_child(player)
	add_child(safety)
	safety.setup(self)
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
	_build_truck()                                   # before the first bake, so routes go around it
	_rebake_nav()
	for key in ["hit_hammer", "hit_pick", "hit_reinforced", "rock_break", "ui_pop", "coin", "unlock", "breaker_hit"]:
		sfx[key] = _audio("res://audio/%s.wav" % key, -9.0)
	power_audio = _audio("res://audio/drill_loop.wav", -14.0)
	for key in ["drill_loop", "jackhammer_loop", "rig_loop"]:
		var ls: AudioStreamWAV = load("res://audio/%s.wav" % key)
		ls.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ls.loop_end = ls.data.size() / 2
	player.tool_view.equip(prog.model_tier(), true)
	hit_audio = _audio("res://audio/pick_hit.wav", -12)
	pickup_audio = _audio("res://audio/pickup.wav", -15)
	sell_audio = _audio("res://audio/sell.wav", -13)
	crusher_audio = _audio("res://audio/crusher_loop.wav", -23)
	var loop_stream: AudioStreamWAV = crusher_audio.stream
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music = QuarryMusic.new()
	add_child(music)
	music.setup(self)
	survey = QuarrySurvey.new()
	survey.setup(self)
	_update_light()
	_refresh_stage_hud()
	if autosave_enabled and FileAccess.file_exists(SAVE_PATH):
		_load(true)                                  # continue where you left off: a launch never starts from scratch over a save
	_ensure_opening()
	if title_enabled and not Engine.has_meta("qd_skip_title"):
		call_deferred("_show_title")
	elif not prog.story["intro_seen"]:
		call_deferred("_show_intro")
	Engine.remove_meta("qd_skip_title") if Engine.has_meta("qd_skip_title") else null

## A save from before Phase 10 (or the legacy start) lives in the old world: say so before the world is built, so its geometry matches.
func _peek_save_layout() -> void:
	if not autosave_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var data = _read_save()
	if data == null or not data is Dictionary:
		return
	var p5 = data.get("phase5", {})
	var st = p5.get("story", {}) if p5 is Dictionary else {}
	var legacy := true
	if st is Dictionary and st.get("excavator", null) is Dictionary:
		legacy = bool((st["excavator"] as Dictionary).get("legacy", false))
	if legacy:
		prog.story["excavator"]["legacy"] = true

func _init_layout() -> void:
	blueprint = prog.filled_world()
	if not blueprint:
		return
	TOOLSHED_POS = Vector3(-17.125, 0, 3.5)     # x on a nav cell centre: the 1.4 m doorway keeps a walkable lane after the agent-radius erosion
	SHED_POS = Vector3(-8.875, 0, 3.5)
	OFFICE_POS = Vector3(13.125, 0, 3.5)
	HOME_POS = Vector3(17.625, 0, 17.5)
	SELL_ANCHOR = Vector3(13.125, 0.85, 0.2)         # carts and the sales clerk deal just outside the office door
	STORAGE_POS = Vector3(9.0, 0.65, -13.5)          # the storage bin stands INSIDE the quarry, just past the central gate
	business.storage_pos = Vector3(STORAGE_POS.x, 0.0, STORAGE_POS.z)
	GARAGE_DX = -8.0
	PARK_X_MIN = -4.4 + GARAGE_DX
	PARK_X_MAX = 14.0 + GARAGE_DX
	EXP_DZ = 12.0
	for slot in fleet.cfg.get("parking", []):
		slot[0] = float(slot[0]) + GARAGE_DX

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
	if blueprint:
		_build_blueprint_ground()
	else:
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
		for i in range(8 if not natural_start_enabled else 0):       # the old pit's rim slabs belong to the legacy layout; in the new one they stood inside the hangar
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
	_building("Office", OFFICE_POS, Color(0.48,0.42,0.31))
	_building("Storage shed", SHED_POS, Color(0.38,0.37,0.31))
	_building("Home", HOME_POS, Color(0.46,0.38,0.28))
	_building("Tool shed", TOOLSHED_POS, Color(0.40,0.36,0.30))
	var bed := _solid(world, "Bed", HOME_POS + Vector3(-1.3, 0.35, 1.3), Vector3(1.0, 0.7, 2.0), Color(0.45,0.3,0.22))
	bed.set_meta("kind", "bed")
	var sell := _solid(world,"Selling anchor",SELL_ANCHOR,Vector3(0.2,0.2,0.2),Color(0.37,0.26,0.14))     # invisible, no collision: carts and the clerk measure from here
	sell.collision_layer = 0
	sell.visible = false
	sell.set_meta("kind","sell_anchor")
	sell_body = sell
	_build_workbench()
	var storage := _solid(world,"Storage crate",STORAGE_POS,Vector3(2,1.3,1.6),Color(0.33,0.23,0.13))
	storage.set_meta("kind","storage")
	storage.set_meta("index",0)
	storage_body = storage
	for kind in DEPOSIT_INFO:
		_build_deposit(kind)
	if natural_start_enabled:
		for kind in OUTCROP_INFO:
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

## The blueprint world's ground: one solid ground plane for the yard and everything south and beside it (the quarry's own ground is built by the
## pit zone), boundary walls round the property, and the mountain mass the west tunnel runs into. Everything is collision only; the art layer
## (QuarryArt._blueprint_world) draws the surface, fences, mountains and forests.
func _build_blueprint_ground() -> void:
	var g := _floor_piece("World floor", Vector3(0, -2.75, 36.0), Vector3(400.0, 5.5, 88.0))        # z -8 .. 80: the yard, the service lane, the land beside them
	g.name = "Quarry floor"
	var h := 9.0
	_solid(world, "Boundary south", Vector3(0, h * 0.5, 80.5), Vector3(400.0, h, 1.0), Color(0.3, 0.3, 0.3)).visible = false
	_solid(world, "Boundary west", Vector3(-200.5, h * 0.5, 36.0), Vector3(1.0, h, 90.0), Color(0.3, 0.3, 0.3)).visible = false
	_solid(world, "Boundary east", Vector3(200.5, h * 0.5, 36.0), Vector3(1.0, h, 90.0), Color(0.3, 0.3, 0.3)).visible = false
	# the yard's west and east edges outside the tunnel: solid so nobody walks out of the property onto the mountain side
	for part in [[-8.0, 21.3], [29.5, 80.0]]:          # the mountain north and south of the tunnel (the tunnel's own walls and roof stand between them)
		var m := _solid(world, "Tunnel mountain", Vector3(-62.0, 4.0, (float(part[0]) + float(part[1])) * 0.5), Vector3(76.0, 8.0, float(part[1]) - float(part[0])), Color(0.34, 0.33, 0.3))
		m.visible = false
		m.set_meta("nav_skip", true)

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
		hud.toast("It's getting late", "Your bed is in the little house by the garage (E). The day ends at %02d:00." % int(prog.cfg.get("home", {}).get("curfew_hour", 22.0)), "info")
	# the working day has an end: at the curfew the player is too tired to go on and is sent to bed
	if (h >= float(prog.cfg.get("home", {}).get("curfew_hour", 22.0)) or h < 5.0) and prog.story["intro_seen"] and curfew_enabled:
		force_sleep()

## Past the curfew you cannot keep working: whatever you are doing is put away and you go to bed.
func force_sleep() -> void:
	if sleeping:
		return
	if driving:
		exit_vehicle()
	if placement:
		_cancel_placement()
	construction = false
	if menu != "":
		_close_menu()
	_forced_sleep = true
	sleeping = true
	player.locked = true
	hud.fade_to(1.0, 0.9)
	sleep_timer = 1.1
	hud.toast("Time to turn in", "It is too late to keep working. You head to bed.", "info")

## True when the player is not busy: no vehicle, menu, card, placement, sleep or other conversation.
func player_free_for_intro() -> bool:
	return player != null and not driving and menu == "" and not placement and not sleeping and not construction \
		and not player.locked and dialog == null and not (hud and hud.card_open())

## A new employee who has walked up to the player starts the introduction (never forced: busy players are left alone,
## the employee just starts working and the conversation happens the next time they meet).
func _check_introductions() -> void:
	if dialog != null or not introductions_enabled or not player_free_for_intro():
		return
	for w in worker_nodes.values():
		if not w.visible or bool(w.e.get("away", false)) or bool(w.e.get("intro_done", true)):
			continue
		if w.global_position.distance_to(player.global_position) < 3.4:
			_start_intro(w)
			return

func _start_intro(w: Node3D) -> void:
	dialog_worker = w
	dialog = QuarryIntroDialog.new()
	dialog.setup(str(w.e["name"]), str(w.e.get("personality", "friendly")), str(business.profession(str(w.e["profession"]))["title"]),
		UiArt.portrait_index(str(w.e["name"]), str(w.e.get("gender", "m")), str(w.e["profession"]), str(w.e.get("candidate", ""))))
	ui.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	dialog.offset_bottom = -150.0
	dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialog.finished.connect(_end_intro)
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# first person: the view turns to the new employee
	var d := w.global_position + Vector3(0, 1.5, 0) - player.global_position
	var yaw := atan2(-d.x, -d.z)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(player, "rotation:y", player.rotation.y + angle_difference(player.rotation.y, yaw), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player.camera, "rotation:x", clampf(atan2(d.y - 1.58, Vector2(d.x, d.z).length()), -0.4, 0.4), 0.5).set_trans(Tween.TRANS_SINE)

func _end_intro(chosen: String, skipped: bool) -> void:
	if dialog_worker != null and is_instance_valid(dialog_worker):
		var e: Dictionary = dialog_worker.e
		e["intro_done"] = true
		if not skipped:
			business.rename_employee(int(e["id"]), chosen)
		hud.toast("Welcome, %s" % str(e["name"]), "%s joins the crew." % str(business.profession(str(e["profession"]))["title"]), "milestone")
	dialog_worker = null
	if dialog:
		dialog.queue_free()
	dialog = null
	var back := create_tween()
	back.tween_property(player.camera, "rotation:x", 0.0, 0.4)
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _hour() -> float:
	return fposmod(state.clock_minutes, 1440.0) / 60.0

## Beds are for the evening and the small hours: from `sleep_from_hour` until `wake_hour`.
func can_sleep() -> bool:
	var h := _hour()
	return h >= float(prog.cfg.get("home", {}).get("sleep_from_hour", 17.0)) or h < float(prog.cfg.get("home", {}).get("wake_hour", 7.0)) - 1.0

func try_sleep() -> void:
	release_cart()
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
	if _forced_sleep:
		_forced_sleep = false
		player.global_position = HOME_POS + Vector3(0.8, 0.25, 0.3)     # waking up at home, by the bed
		player.velocity = Vector3.ZERO
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
		_cleanup_beacon(body, weed)
		world.add_child(body)
		cleanup_nodes[id] = body

## A tall yellow beam, a ground ring and a label on every item still left, so the last one is never lost in the grass.
func _cleanup_beacon(body: Node3D, weed: bool) -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.82, 0.2, 0.55)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.75, 0.15)
	glow.emission_energy_multiplier = 1.4
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.09
	cm.height = 7.0
	cm.radial_segments = 6
	beam.mesh = cm
	beam.material_override = glow
	beam.position = Vector3(0, 3.5, 0)
	beam.name = "Beacon"
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(beam)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.0 if weed else 1.3
	rm.bottom_radius = rm.top_radius
	rm.height = 0.03
	rm.radial_segments = 14
	ring.mesh = rm
	ring.material_override = glow
	ring.position = Vector3(0, 0.03, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(ring)
	var lb := Label3D.new()
	lb.text = "WEEDS" if weed else "RUBBLE"
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.font_size = 28
	lb.pixel_size = 0.008
	lb.outline_size = 8
	lb.modulate = Color(1.0, 0.9, 0.4)
	lb.position = Vector3(0, 2.2, 0)
	lb.visibility_range_end = 45.0
	body.add_child(lb)

## 8-point compass word for a world offset (north is -Z, east is +X).
func _compass(d: Vector3) -> String:
	var a := fposmod(atan2(d.x, -d.z), TAU)
	return ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][int(round(a / (TAU / 8.0))) % 8]

## The nearest cleanup item still left: {"id", "dist", "dir"} or {}.
func nearest_cleanup() -> Dictionary:
	var here: Vector3 = driving.global_position if driving else player.global_position
	var best := {}
	var bd := INF
	for id in prog.cleanup_ids():
		if prog.cleanup["cleared"].get(id, false):
			continue
		var p2: Vector2 = prog.cleanup_pos(str(id))
		var d := Vector3(p2.x, 0.0, p2.y) - Vector3(here.x, 0.0, here.z)
		if d.length() < bd:
			bd = d.length()
			best = {"id": str(id), "dist": d.length(), "dir": _compass(d), "weed": str(id).begins_with("w"), "pos": Vector3(p2.x, 0.0, p2.y)}
	return best

## One strike on a weed clump or rubble heap. Weeds fall after `weed_hp` damage; a heap gives one stone (into the
## bag) per `heap_unit_hp` damage and is gone when its stone is used up. Nothing is lost when the bag is full.
## True while the player stands on top of (or inside the footprint of) a column: that rock cannot be taken away.
func _column_has_player(id: String, col: int) -> bool:
	if player == null or not formation_nodes.has(id) or col < 0 or col >= prog.column_count(id) or prog.column_units(id, col) <= 0:
		return false
	var d: Vector3 = player.global_position - prog.column_pos(id, col)
	var l: Vector3 = Basis(Vector3.UP, prog.column_yaw(id, col)).inverse() * d
	var half := float(prog.fdef(id)["cell"]) * 0.5 + 0.3
	return absf(l.x) <= half and absf(l.z) <= half and absf(d.y) <= float(prog.chunks_left(id, col)) * float(prog.fdef(id).get("tier_h", 1.2)) + 1.0

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
	if blueprint and formation_nodes.has("q_top"):
		(formation_nodes["q_top"] as QuarryFormation).clean_decor(node.global_position, 7.0)      # the scrub, grass and stones around it go with it
	var last := prog.clear_cleanup_item(id)
	if not last:
		var nx := nearest_cleanup()
		var more := ""
		if not nx.is_empty():
			more = " Nearest: %s, %d m %s - follow the yellow beam." % ["weeds" if nx["weed"] else "rubble", int(nx["dist"]), nx["dir"]]
		_notify("Site cleanup: %d left.%s" % [prog.cleanup_left(), more])
		if prog.cleanup_left() <= 3 and hud:
			hud.toast("Almost clean", "%d left. Look for the yellow beams." % prog.cleanup_left(), "info")

## A contract is complete: a clear notice, the reward (paid once by the progression), and the next job when there is one.
func _on_area_completed(id: String) -> void:
	var def := prog.area_def(id)
	if hud:
		hud.toast(str(def.get("title", id)) + " COMPLETE", "Contract reward $%d. The rest of the rock here stays yours to cut." % int(def.get("reward", 0)), "milestone")
	_sfx_unlock()
	hud.refresh_panels() if hud else null

## The whole site is clean: Walt's letter arrives with money, and the hillside opens.
func _on_site_cleared() -> void:
	if blueprint and formation_nodes.has("q_top"):
		(formation_nodes["q_top"] as QuarryFormation).clean_decor(Vector3.ZERO, 0.0, true)       # every bush, tuft and loose stone: only dirt is left
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
	return PitZoneScript.gate_transform(prog.pit_cfg())

## True near the access corridor (world builders use it to keep scenery out of the way).
func in_pit_corridor(p: Vector3, margin := 0.0) -> bool:
	var c: Dictionary = prog.pit_cfg()
	if c.is_empty():
		return false
	var l := pit_gate_xf().affine_inverse() * p
	return absf(l.x) <= float(c.get("corridor_width", 8.0)) * 0.5 + margin and l.z <= 12.0 and l.z >= -(float(c.get("corridor_length", 30.0)) + 3.0)

## Retires the ring pieces in the gate's mouth (low rim walls, the cliff filler) and builds the zone behind it.
func _build_pit_zone() -> void:
	if prog.pit_cfg().is_empty():
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
	if blueprint:
		return Rect2()            # there is no hillside in the blueprint world: its rock is the quarry itself
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
		var di: Dictionary = DEPOSIT_INFO[kind].duplicate()
		if blueprint:
			di["pos"] = Vector3(-48.0, 0, -62.0)     # the infinite limestone face stands on the quarry surface, off the tutorial debris
		return di
	if OUTCROP_INFO.has(kind):
		var oi: Dictionary = OUTCROP_INFO[kind].duplicate()
		if blueprint:
			oi["pos"] = Vector3(-64.0, 0, -60.0) if kind == "coal_outcrop" else Vector3(44.0, 0, -62.0)    # on the quarry surface, off the roads and the tutorial debris
		return oi
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

## Loose pieces carry their column in the id. New ids are PIECE_V2 + generation * 10000 + column (any column of any formation,
## including the 100+ columns of the big pit benches); ids below PIECE_V2 are from older saves (generation * 100 + column).
const PIECE_V2 := 100000000
static func piece_code(generation: int, col: int) -> int:
	return PIECE_V2 + generation * 10000 + col

static func piece_column(code: int) -> int:
	return (code - PIECE_V2) % 10000 if code >= PIECE_V2 else posmod(code, 100)

func _place_formation_piece(kind: String, generation: int, i: int) -> void:
	var col := piece_column(generation)
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
		_notify("Bag full! Sell at the office computer or store at the crate. Extra rock drops beside the formation.")

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
func player_mine(kind: String, col: int, damage: float, point := Vector3.INF, continuous := false, in_aoe := false) -> int:
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
			col = prog.nearest_column(kind, player.global_position if point == Vector3.INF else point, true, 2.6, "hand")
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
	if _column_has_player(kind, col):
		_notify("Step off that rock first - you are standing on it.")
		return 0
	var bag_room := state.capacity() - state.total(state.inventory)
	var drop_room := maxi(0, int(prog.cfg.get("loose_piece_cap", 36)) - loose_count(kind))
	if not in_aoe:
		damage *= prog.tool_modifier(res)
	var why := prog.extraction_block(kind, col, "hand")
	if why != "":
		if not continuous:
			_notify(why)
		return 0
	var ex := prog.extract(kind, col, damage, bag_room + drop_room, "hand")
	var n := int(ex["units"])
	var at := node.column_top(col) if point == Vector3.INF else point
	if in_aoe:
		fx.impact(at, res, 0.6, mine_normal)
	elif not continuous:
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
		prog.area_add(prog.area_of_formation(kind), "recovered", put)
		if put > 0:
			_reward_popup(res, put)
		for i in range(n - put):
			_spawn_formation_piece(kind, col, i)
		if n - put > 0:
			_bag_full_notice()
	elif bag_room + drop_room <= 0:
		_bag_full_notice()
	_vein_bonus(ex, kind, col, "player")
	if int(ex["chunks"]) > 0:
		node.refresh()
	else:
		node.update_label()
	var left := prog.column_units(kind, col)
	hud.show_mining("%s  %d LEFT" % [prog.display(res).to_upper(), prog.units_left(kind)], 1.0 - prog.top_chunk_damage(kind, col) if left > 0 else 0.0)
	if not in_aoe and not continuous:
		var aoe := prog.tool_aoe()
		if aoe.x > 0.0:
			# impact tools: the neighbouring exposed blocks take part of the blow (normal mining rules: only minable columns)
			var d := prog.dims(kind)
			var cands := []
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx: int = col % d.x + ox
					var ny: int = col / d.x + oy
					if (ox != 0 or oy != 0) and nx >= 0 and ny >= 0 and nx < d.x and ny < d.y:
						var nc := ny * d.x + nx
						if prog.column_minable(kind, nc) and not _column_has_player(kind, nc):
							cands.append([absf(float(ox)) + absf(float(oy)), nc])
			cands.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
			for k in range(mini(int(aoe.x), cands.size())):
				n += player_mine(kind, int(cands[k][1]), damage * aoe.y, Vector3.INF, false, true)
	return n

## Loose piece beside a formation column (deterministic spot, so saved pieces reload in place).
func _spawn_formation_piece(kind: String, col: int, i: int) -> void:
	var d: Dictionary = state.deposits[kind]
	d["generation"] = int(d.get("generation", 0)) + 1
	_spawn_piece(kind, piece_code(int(d["generation"]), col), i)

func _player_mining(delta: float) -> void:
	var tv: QuarryToolView = player.tool_view
	tv.equip(prog.model_tier())
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
	gamepad = PadScript.new()
	add_child(gamepad)
	gamepad.setup(self)
	# Station menus (selling booth, upgrade board, storage, machines): one cozy clickable panel.
	panel = QuarryStationUI.new()
	ui.add_child(panel)
	(panel as QuarryStationUI).setup(self)

func _notify(s: String) -> void:
	message = s
	message_timer = 3.0
	if hud:
		hud.set_message(s, 3.2)

## Interaction highlight (Phase 8.5): a thin warm outline on the one thing you could press E on. Only real interactables get it
## (never terrain, rock, loose pieces or weeds), it is removed the moment you look away, open a menu, drive or build, and it is
## never used for construction ghosts, which have their own blueprint look.
const HIGHLIGHT_KINDS := ["repair_part", "cart", "door", "bed", "sell", "upgrades", "storage", "crusher", "output", "shop", "office", "rig", "vehicle", "worker", "discovery", "walter", "fossil", "egg", "conveyor", "gate"]
var highlight_node: Node3D
var highlight_meshes: Array = []
var _hl_mat: StandardMaterial3D

func _highlight_material() -> StandardMaterial3D:
	if _hl_mat == null:
		_hl_mat = StandardMaterial3D.new()
		_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hl_mat.albedo_color = Color(1.0, 0.82, 0.38)
		_hl_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		_hl_mat.grow = true
		_hl_mat.grow_amount = 0.025
		_hl_mat.no_depth_test = false
	return _hl_mat

func _clear_highlight() -> void:
	for mi in highlight_meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = null
	highlight_meshes.clear()
	highlight_node = null

func _update_highlight() -> void:
	var t: Node3D = last_target
	var ok := t != null and is_instance_valid(t) and not driving and menu == "" and not placement and not construction \
		and not (hud and hud.card_open()) and HIGHLIGHT_KINDS.has(str(t.get_meta("kind", "")))
	if ok and str(t.get_meta("kind", "")) == "walter" and walter_mode != "waiting":
		ok = false
	if not ok:
		if highlight_node != null:
			_clear_highlight()
		return
	if t == highlight_node:
		return
	_clear_highlight()
	highlight_node = t
	var meshes := t.find_children("*", "MeshInstance3D", true, false)
	if t is MeshInstance3D:
		meshes.append(t)
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.visible and m.mesh != null and not (m.get_parent() is Label3D) and m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			m.material_overlay = _highlight_material()
			highlight_meshes.append(m)

func _look_target() -> Node3D:
	var start := player.camera.global_position
	var end := start - player.camera.global_transform.basis.z * 4.0
	var query := PhysicsRayQueryParameters3D.create(start,end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit["collider"] is Node3D:
		return hit["collider"]
	return null

## Which contract area the player (or the machine they drive) is standing in: the yard-side Area 1 by its rectangle, the pit areas by
## the pit's own frame and floor height (basin floor = Area 2, the level-2 pit = Area 3). "" in the yard or elsewhere.
func area_at(p: Vector3) -> String:
	if pit_zone != null and is_instance_valid(pit_zone):
		var l: Vector3 = pit_zone.to_loc(p)
		for lp in pit_zone.level_pits:
			var r: Rect2 = lp["rect"]
			if r.has_point(Vector2(l.x, l.z)) and l.y < float(lp["y_bot"]) + 1.6 and l.y > float(lp["y_bot"]) - 1.0:
				for ad in prog.area_defs():
					if int(ad.get("level", 0)) == int(lp["n"]) + 0 and ad.get("frame", "") == "pit":
						var zr: Array = ad.get("z_range_filled", ad.get("z_range", [])) if prog.filled_world() else ad.get("z_range", [])
						var xr: Array = ad.get("x_range", []) if prog.filled_world() else []
						if (zr.is_empty() or (l.z >= float(zr[0]) and l.z <= float(zr[1]))) and (xr.is_empty() or (l.x >= float(xr[0]) and l.x <= float(xr[1]))):
							return str(ad["id"])
				return ""
	var a1 := prog.area_for_point(p)
	if a1 != "":
		return a1
	if pit_zone == null or not is_instance_valid(pit_zone) or prog.filled_world():
		return ""
	var l2: Vector3 = pit_zone.to_loc(p)
	if absf(l2.x) <= pit_zone.basin_w * 0.5 and l2.z <= pit_zone.basin_zs() and l2.z >= pit_zone.basin_zn() and l2.y > -5.0 and l2.y < -2.0:
		return "area_2"
	return ""

var _area_check_t := 0.0

func _physics_process(delta: float) -> void:
	_area_check_t -= delta
	if _area_check_t <= 0.0 and player != null:
		_area_check_t = 0.5
		var here := area_at(driving.global_position if driving else player.global_position)
		if here != "":
			prog.area_visit(here)
	_truck_step(delta)
	if held_cart != null:
		_cart_follow(delta)
	for i in range(mini(output_nodes.size(), business.outputs.size())):
		var arm = output_nodes[i].get_meta("arm") if output_nodes[i].has_meta("arm") else null
		if arm != null and is_instance_valid(arm):
			var working: bool = business.sorter_busy(i)
			var goal := sin(Time.get_ticks_msec() * 0.006) * 0.55 if working else 0.0
			arm.rotation.y = lerpf(arm.rotation.y, goal, minf(1.0, delta * 8.0))
	if menu != "":
		return
	_sleep_tick(delta)
	if sleeping:
		return
	if art and art.garage_roof:
		# the chase camera would sit inside the roof: take the roof off while a vehicle is driven under it
		var inside := driving != null and driving.global_position.x > -6.5 + GARAGE_DX and driving.global_position.x < 16.0 + GARAGE_DX and driving.global_position.z > 12.5 and driving.global_position.z < 24.0
		art.garage_roof.visible = not inside
	safety.tick(delta)
	if fossil_reveal_active and Input.is_action_just_pressed("interact"):
		_end_fossil_reveal()
	player.blueprint.set_active(placement or construction)
	_check_introductions()
	_check_walter_visit()
	_walter_tick(delta)
	_fossil_tick(delta)
	_companion_tick(delta)
	if autosave_enabled:
		autosave_t += delta
		if autosave_t >= AUTOSAVE_SECONDS and not sleeping and not placement:
			autosave_t = 0.0
			_save(true)
	state.tick(delta)
	business.tick(delta)
	fleet.tick()
	if nav_dirty:
		_rebake_nav()
	for w in worker_nodes.values():
		w.step(delta)
	if driving and not scripted_input:
		driving.input = {"throttle": Input.get_axis("move_back", "move_forward"), "steer": Input.get_axis("move_left", "move_right"), "brake": Input.is_physical_key_pressed(KEY_SPACE)}
		if driving.digging:
			if not scripted_input and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				driving.digging = false
			else:
				_excavator_dig(driving, delta)
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
	_update_highlight()
	if placement:
		_update_ghost()
	_player_mining(delta)
	_phase5_tick(delta)
	var prompt := ""
	if last_target:
		match str(last_target.get_meta("kind","")):
			"deposit": prompt = "%s %s  -  %s" % ["Hold left click: drill" if prog.is_continuous() else "Left click: mine", prog.display(str(last_target.get_meta("resource"))), _deposit_status(str(last_target.get_meta("deposit")))]
			"debris":
				var did := str(last_target.get_meta("debris_id", ""))
				prompt = "Left click: cut the weeds" if did.begins_with("w") else "Left click: break the rubble heap (%d stone left)" % prog.heap_units_left(did)
			"door":
				var dn := str(last_target.get_meta("door"))
				prompt = "E: use the door"
				for dr in doors:
					if str(dr.name) == dn:
						prompt = "E: close the %s" % dn.to_lower() if dr.want_open else "E: open the %s" % dn.to_lower()
			"bed": prompt = "E: sleep until morning" if can_sleep() else "Too early to sleep (rest after %02d:00)" % int(prog.cfg.get("home", {}).get("sleep_from_hour", 17.0))
			"discovery": prompt = "E: open the old lockbox"
			"fossil": prompt = "E: examine the fossil"
			"egg": prompt = "E: pick up the egg" if prog.companion_egg_waiting(prog.current_day) else "The egg is warm. It will hatch soon."
			"walter": prompt = "E: talk to Grandpa Walt" if walter_visit != "" else "Grandpa Walt"
			"rig":
				var ri := int(last_target.get_meta("index"))
				if ri < prog.rigs.size():
					var rr: Dictionary = prog.rigs[ri]
					prompt = "E: %s  -  %s  (bin %d/%d)" % [str(prog.machine(str(rr["type"]))["title"]), str(rr["status"]), prog.rig_bin_total(rr), prog.rig_bin_cap(rr)]
			"piece": prompt = "E: collect "+str(last_target.get_meta("resource"))
			"crusher": prompt = "E: use crusher"
			"sell": prompt = "E: sell materials"
			"shop": prompt = "E: order machinery"
			"output":
				var ov := str(last_target.get_meta("variant", "output"))
				prompt = {"output": "E: output storage", "hopper": "E: small hopper", "sorter": "E: sorting table"}[ov]
			"conveyor":
				var ci := int(last_target.get_meta("index"))
				var link: Dictionary = business.links[ci] if ci < business.links.size() else {}
				prompt = "Conveyor #%d: %s -> %s | B to move" % [ci + 1, business.describe_ep(link.get("src", {})), business.describe_ep(link.get("dst", {}))]
			"office": prompt = "E: management office"
			"worker":
				var who := business.employee(int(last_target.get_meta("employee")))
				if not who.is_empty():
					prompt = "%s (%s): %s" % [who["name"], business.profession(who["profession"])["title"], who["task"]]
			"repair_part":
				var rp := str(last_target.get_meta("part"))
				prompt = "E: pick up the %s" % str(prog.opening_cfg().get("parts", {}).get(rp, {}).get("title", rp)).to_lower()
			"cart":
				var cid := str(last_target.get_meta("cart"))
				prompt = "E: %s  (%d / %d)" % [str(prog.gear_def(cid).get("title", cid)), state.cart_total(cid), state.cart_cap(cid)]
			"upgrades": prompt = "E: use the workbench and tools"
			"storage": prompt = "E: storage"
			"vehicle":
				var vrec := fleet.vehicle(int(last_target.get_meta("vehicle_id")))
				if not vrec.is_empty() and str(vrec["type"]) == "starter_excavator" and not prog.excavator_ready():
					prompt = ("E: fit the %s" % prog.carried_part()) if prog.carried_part() != "" else ("E: Grandpa's excavator - %d of 3 repairs done" % prog.repairs_done())
				elif not vrec.is_empty():
					prompt = "E: drive %s (%d/%d %s)" % [fleet.spec(vrec["type"])["title"], fleet.cargo_total(vrec), fleet.capacity(vrec), "in bucket" if fleet.kind(str(vrec["type"])) != "truck" else "in bed"]
			"pile":
				prompt = "%s: %d units - scoop it with a front loader" % [fleet.cfg["piles"][str(last_target.get_meta("pile"))]["title"], int(fleet.piles[str(last_target.get_meta("pile"))]["amount"])]
	if construction and not placement:
		prompt = _construction_prompt()
	if driving:
		prompt = str(hud_drive_info().get("action", ""))
	if placement:
		prompt = "PLACE %s: %s | left click place | R rotate | G grid %s | Esc cancel%s" % [placement_kind.replace("output","output storage").to_upper(), "VALID" if ghost_valid else "BLOCKED", "on" if grid_snap else "off", placement_hint]
	hud.set_prompt(prompt)
	hud.hint_text = _hint_text()
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
		landscape.set_time(state.clock_minutes)

func _unhandled_input(event: InputEvent) -> void:
	if dialog:
		if event.is_action_pressed("ui_cancel"):
			dialog.skip_btn.pressed.emit()          # Esc skips the conversation
			get_viewport().set_input_as_handled()
		return
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
	if menu == "title":
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
			if autosave_enabled:
				_save(true)                          # opening the pause menu is a natural checkpoint
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F and held_cart != null and menu == "":
		release_cart()
		_notify("You let go of the cart.")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q and not placement and not driving and menu == "" and name_dialog == null:
		cycle_tool()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N and not placement and not driving and menu == "" and name_dialog == null:
		set_survey(not survey_on)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_U and not placement and not driving and menu == "":
		safety.rescue("asked to be lifted out")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T and not placement and name_dialog == null:
		_companion_command()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		construction = not construction
		sell_confirm = ""
		_notify("Construction mode: aim at a crusher, conveyor, storage crate or output storage. left click move, X sell, B exit." if construction else "Construction mode off")
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
		_notify("Order machinery at the office computer first.")
	if event.is_action_pressed("interact") and last_target:
		_interact(last_target)

func _interact(target: Node3D) -> void:
	match str(target.get_meta("kind","")):
		"piece":
			var kind := str(target.get_meta("resource"))
			if state.add_item(kind,1) == 1:
				prog.area_add(prog.area_of_formation(str(target.get_meta("deposit", ""))), "recovered", 1)
				ground_pieces.erase(str(target.get_meta("piece_id")))
				target.queue_free()
				pickup_audio.play()
				_notify("Collected "+kind)
			else:
				_notify("Backpack full")
		"sell", "upgrades", "storage", "crusher", "output", "shop":
			_open_menu(str(target.get_meta("kind")),int(target.get_meta("index",-1)))
		"cart":
			_open_menu("cart", state.carts.find(str(target.get_meta("cart"))))
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
		"walter":
			_talk_to_walter()
		"fossil":
			_talk_to_fossil()
		"egg":
			_take_egg()
		"rig":
			_open_menu("rig", int(target.get_meta("index")))
		"repair_part":
			_pick_up_part(str(target.get_meta("part")))
		"vehicle":
			var v = vehicle_nodes.get(int(target.get_meta("vehicle_id")))
			if v and v.vtype == "starter_excavator":
				_use_starter(v)
			elif v:
				enter_vehicle(v)

func _open_menu(kind: String, index := -1) -> void:
	menu = kind
	if hud:
		hud.menu_open = true
	panel.set_meta("crusher_index",index)
	panel.visible = kind != "manage"
	management.visible = kind == "manage"
	if kind == "manage":
		if management.tab in ["sales"]:
			management.tab = "home"
		management.refresh()
	player.locked = true
	if crusher_audio.playing:
		crusher_audio.stream_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_draw_menu()

func _close_menu() -> void:
	menu = ""
	if hud:
		hud.menu_open = false
	_confirm_new = false
	player.tool_view.equip(prog.model_tier(), true)   # always back in hand with the tool you own
	panel.visible = false
	panel.pane.pause()                              # the preview stops rendering while no shop is open
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
			p.text("The game saves itself every minute and when you close it. Save now with the button or F5." if not _confirm_new else "Erase your save and start a brand new game? Click NEW GAME again to confirm.", QuarryTheme.DIM if not _confirm_new else QuarryTheme.WARN, true)
			p.button_bar([["resume", "RESUME", true, func(): _confirm_new = false; _close_menu()], ["save", "SAVE GAME", true, func(): _save()], ["load", "LOAD GAME", true, func(): _load()], ["main_menu", "MAIN MENU", true, func(): to_main_menu()],
				["new", "NEW GAME" if not _confirm_new else "ERASE & RESTART", true, func():
					if _confirm_new:
						new_game()
					else:
						_confirm_new = true
						_draw_menu()]])
			p.text("Music: %s" % ("muted" if music.muted else "%d%%" % int(round(music.volume * 100.0))), QuarryTheme.DIM, true)
			p.button_bar([["music_down", "MUSIC -", true, func(): music.set_volume(music.volume - 0.1), 130], ["music_up", "MUSIC +", true, func(): music.set_volume(music.volume + 0.1), 130],
				["music_mute", "UNMUTE" if music.muted else "MUTE", true, func(): music.set_muted(not music.muted), 130]])
		"sell": _draw_sell(p)
		"upgrades": _draw_upgrades(p)
		"cart": _draw_cart(p, idx)
		"storage":
			p.begin("STORAGE   %d / %d" % [state.total(state.storage), state.storage_capacity()], -1, "Optional keys: 1-6 store all, Shift+1-6 take all")
			for i in range(RESOURCE_ORDER.size()):
				var key: String = RESOURCE_ORDER[i]
				p.row([[prog.display(key), QuarryTheme.INK, 150], ["bag %d" % int(state.inventory[key]), QuarryTheme.DIM, 90], ["stored %d" % int(state.storage[key]), QuarryTheme.DIM, 110]],
					[["store_" + key, "STORE ALL", int(state.inventory[key]) > 0, func(): menu_act("storage", i, false)], ["take_" + key, "TAKE ALL", int(state.storage[key]) > 0, func(): menu_act("storage", i, true)]], QuarryTheme.RES_COLORS.get(key, Color.WHITE))
		"crusher":
			if idx >= 0 and idx < state.crushers.size():
				var c: Dictionary = state.crushers[idx]
				p.begin("SMALL JAW CRUSHER #%d" % (idx + 1), m, "Optional keys: 1 load, 2 start, 3 collect, 4 hopper")
				p.text("Hopper (automated feed): %d      Limestone input: %d      Crushed output: %d" % [c.get("hopper", 0), c["input"], c["output"]], QuarryTheme.INK)
				p.text("Limestone in your bag: %d      %s" % [state.inventory["limestone"], ("Running: %.1f sec left" % c["remaining"]) if c["running"] else "Idle"])
				p.button_bar([["load", "LOAD LIMESTONE", int(state.inventory["limestone"]) > 0, func(): menu_act("crusher", 0, false)], ["start", "START", not bool(c["running"]) and int(c["input"]) > 0, func(): menu_act("crusher", 1, false)]])
				p.button_bar([["collect", "COLLECT OUTPUT", int(c["output"]) > 0, func(): menu_act("crusher", 2, false)], ["hopper", "HOPPER > INPUT", int(c.get("hopper", 0)) > 0, func(): menu_act("crusher", 3, false)]])
		"output":
			if idx >= 0 and idx < business.outputs.size():
				var items: Dictionary = business.outputs[idx]["items"]
				if business.variant_of(idx) != "output":
					_draw_variant_output(p, idx)
					return
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

## Hand transfers at a hopper or a sorting table: bag -> bin and bin -> bag, never more than either side can take.
func output_deposit(idx: int, key: String) -> int:
	var ep := {"type": "output", "index": idx, "resource": key}
	var n := mini(int(state.inventory[key]), business.ep_space(ep, key))
	if n <= 0:
		return 0
	state.inventory[key] -= n
	business.ep_put(ep, key, n, false)
	return n

func output_withdraw(idx: int, key: String) -> int:
	var n := mini(int(business.outputs[idx]["items"].get(key, 0)), state.capacity() - state.total(state.inventory))
	if n <= 0:
		return 0
	business.outputs[idx]["items"][key] = int(business.outputs[idx]["items"][key]) - n
	state.inventory[key] += n
	return n

func sorter_sell_now(idx: int) -> int:
	var pay := business.sorter_sell(idx)
	if pay > 0:
		sfx["coin"].play()
		_notify("Sorted rock sold for %s (%d%% of the full price)" % [QuarryTheme.money_text(pay), int(round(float(business.cfg.get("sort_bonus", 1.3)) * 100.0))])
	return pay

func _draw_variant_output(p: QuarryStationUI, idx: int) -> void:
	var v := business.variant_of(idx)
	var items: Dictionary = business.outputs[idx]["items"]
	var cap := business.output_capacity_of(idx)
	if v == "hopper":
		p.begin("SMALL HOPPER #%d   %d / %d" % [idx + 1, business.output_total(idx), cap], -1, "Belts feed it and empty it. By hand: put material in, take it out.")
		for key in RESOURCE_ORDER:
			var k: String = key
			p.row([[prog.display(k), QuarryTheme.INK, 130], ["in hopper %d" % int(items[k]), QuarryTheme.DIM, 120], ["bag %d" % int(state.inventory[k]), QuarryTheme.DIM, 80]],
				[["hd_" + k, "PUT IN", int(state.inventory[k]) > 0 and business.output_total(idx) < cap, func(): output_deposit(idx, k)], ["hw_" + k, "TAKE OUT", int(items[k]) > 0, func(): output_withdraw(idx, k)]], QuarryTheme.RES_COLORS.get(k, Color.WHITE))
		return
	var o: Dictionary = business.outputs[idx]
	p.begin("MANUAL SORTING TABLE #%d   %d / %d" % [idx + 1, business.output_total(idx), cap], state.money, "Put rock on the table, sort a batch, then sell the sorted rock for %d%% of the price." % int(round(float(business.cfg.get("sort_bonus", 1.3)) * 100.0)))
	var sorted_total := 0
	for key in business.SORTABLE:
		var k: String = key
		sorted_total += business.sorter_sorted(idx, k)
		p.row([[prog.display(k), QuarryTheme.INK, 110], ["on table %d" % int(items[k]), QuarryTheme.DIM, 100], ["sorted %d" % business.sorter_sorted(idx, k), QuarryTheme.GOOD, 90], ["bag %d" % int(state.inventory[k]), QuarryTheme.DIM, 70]],
			[["sd_" + k, "PUT ON", int(state.inventory[k]) > 0 and business.output_total(idx) < cap, func(): output_deposit(idx, k)], ["sw_" + k, "TAKE OFF", int(items[k]) > 0, func(): output_withdraw(idx, k)]], QuarryTheme.RES_COLORS.get(k, Color.WHITE))
	var left := float(o.get("sort_left", 0.0))
	p.text(("Sorting: %.1f seconds left" % left) if left > 0.0 else "The table is idle.", QuarryTheme.INK)
	p.button_bar([["sort", "SORT A BATCH", not business.sorter_busy(idx), func(): business.sorter_start(idx)], ["sell_sorted", "SELL SORTED (%d)" % sorted_total, sorted_total > 0, func(): sorter_sell_now(idx)]])

func _draw_cart(p: QuarryStationUI, idx: int) -> void:
	if idx < 0 or idx >= state.carts.size():
		p.begin("CART", -1, "")
		return
	var id := str(state.carts[idx])
	var title := str(prog.gear_def(id).get("title", id)).to_upper()
	var near_store := cart_near(id, storage_body)
	var near_sell := cart_near(id, sell_body)
	p.begin("%s   %d / %d" % [title, state.cart_total(id), state.cart_cap(id)], state.money, "Load it from your bag, push it (E to let go), unload at the storage crate or sell from it at the office (beside its door).")
	for i in range(RESOURCE_ORDER.size()):
		var key: String = RESOURCE_ORDER[i]
		var buttons := [["cl_" + key, "LOAD", int(state.inventory[key]) > 0 and state.cart_space(id) > 0, func(): cart_move("load", id, key)],
			["cu_" + key, "UNLOAD", state.cart_units(id, key) > 0, func(): cart_move("unload", id, key)]]
		if near_store:
			buttons.append(["cs_" + key, "TO CRATE", state.cart_units(id, key) > 0, func(): cart_move("store", id, key)])
			buttons.append(["ct_" + key, "FROM CRATE", int(state.storage[key]) > 0 and state.cart_space(id) > 0, func(): cart_move("take", id, key)])
		if near_sell:
			buttons.append(["cx_" + key, "SELL", state.cart_units(id, key) > 0, func(): cart_move("sell", id, key)])
		p.row([[prog.display(key), QuarryTheme.INK, 110], ["cart %d" % state.cart_units(id, key), QuarryTheme.DIM, 80], ["bag %d" % int(state.inventory[key]), QuarryTheme.DIM, 70]], buttons, QuarryTheme.RES_COLORS.get(key, Color.WHITE))
	var held := held_cart != null and held_cart.cart_id == id
	var bar := [["grab", ("LET GO" if held else ("PULL IT" if QuarryCart.mode_of(id) == "pull" else "PUSH IT")), true, func():
		if held_cart != null and held_cart.cart_id == id:
			release_cart()
		else:
			hold_cart(id)]]
	if near_sell:
		bar.append(["sell_all", "SELL ALL", state.cart_total(id) > 0, func(): cart_move_all("sell", id)])
	if near_store:
		bar.append(["store_all", "STORE ALL", state.cart_total(id) > 0, func(): cart_move_all("store", id)])
	p.button_bar(bar)
	p.text("The crate and the office are %s." % ("in reach of this cart" if (near_store or near_sell) else "too far away: push the cart close to one"), QuarryTheme.DIM)

func _draw_sell(p: QuarryStationUI) -> void:
	var bag_value := 0
	for key in RESOURCE_ORDER:
		bag_value += int(round(float(int(state.inventory[key]) + int(state.storage.get(key, 0))) * state.unit_price(key)))
	p.begin("SALES", state.money, "Optional keys: 1-8 sell, 9 sell all, Shift+1-8 clerk on/off")
	var R := HORIZONTAL_ALIGNMENT_RIGHT
	p.row([["MATERIAL", QuarryTheme.DIM, 110], ["BAG", QuarryTheme.DIM, 44, R], ["STORAGE", QuarryTheme.DIM, 64, R], ["PRICE EACH", QuarryTheme.DIM, 80, R], ["SALE VALUE", QuarryTheme.DIM, 90, R]], [], Color(0, 0, 0, 0), true)
	for i in range(RESOURCE_ORDER.size()):
		var key: String = RESOURCE_ORDER[i]
		var nb := int(state.inventory[key])
		var ns := int(state.storage.get(key, 0))
		var n := nb + ns
		var price_f := state.unit_price(key)
		var ok: bool = business.authorized[key]
		p.row([[prog.display(key), QuarryTheme.INK, 110, HORIZONTAL_ALIGNMENT_LEFT, true], [str(nb), QuarryTheme.INK if nb > 0 else QuarryTheme.DIM, 44, R], [str(ns), QuarryTheme.INK if ns > 0 else QuarryTheme.DIM, 64, R], [("$%.2f" % price_f) if state.price_mult < 0.995 else ("$%d" % int(price_f)), QuarryTheme.DIM, 80, R], [QuarryTheme.money_text(int(round(float(n) * price_f))), QuarryTheme.MONEY if n > 0 else QuarryTheme.DIM, 90, R, true]],
			[["clerk_" + key, "Clerk: " + ("on" if ok else "off"), true, func(): menu_act("sell", i, true), 84, "toggle"], ["sell_" + key, "SELL", n > 0, func(): menu_act("sell", i, false), 80, "primary"]], QuarryTheme.RES_COLORS.get(key, Color.WHITE))
	p.button_bar([["sell_all", "SELL ALL   %s" % QuarryTheme.money_text(bag_value), bag_value > 0, func(): menu_act("sell", RESOURCE_ORDER.size(), false), 260, "primary"], ["office", "OFFICE COMPUTER", true, func(): _open_menu("manage"), 200]])
	p.text("'Clerk' chooses what the sales clerk may sell for you. It never stops you selling by hand.")
	if state.price_mult < 0.995:
		p.text("Small lots: buyers pay %d%% of the full price. The pay rises as your quarry grows." % int(round(state.price_mult * 100.0)), QuarryTheme.DIM)

## The workbench panel (Phase 8.3): what is in your hand, what the next tool on the pegboard would change, the price, and the
## other upgrades. Same data and purchases as before (menu_act "upgrades"); only the presentation is new.
func _bar(value: float, top: float, width := 18) -> String:
	var n := clampi(int(round(value / maxf(0.01, top) * float(width))), 0, width)
	return "[" + "#".repeat(n) + "-".repeat(width - n) + "]"

func _tool_line(tier: int) -> String:
	var t := prog.tool(tier)
	var hard: String = ["", "Stone and coal", "Up to iron", "Up to copper", "Anything, gold too"][clampi(int(t.get("max_hardness", 1)), 0, 4)]
	if prog.is_continuous(tier):
		return "%s   mining power %.0f/s, held down   hardness: %s" % [str(t["title"]), prog.tool_dps(tier), hard]
	return "%s   %.0f damage a swing, %.1f swings a second   hardness: %s" % [str(t["title"]), prog.tool_power(tier), 1.0 / prog.tool_interval(tier) * prog.speed_mult(), hard]

func _draw_upgrades(p: QuarryStationUI) -> void:
	p.begin("WORKBENCH", state.money, "Click BUY on the bench. Keys 1-6 also work.")
	var top := 0.0
	for i in range(prog.tools().size()):
		top = maxf(top, prog.tool_dps(i))
	p.text("IN YOUR HAND", QuarryTheme.ACCENT)
	p.text(_tool_line(state.tool_tier), QuarryTheme.INK)
	p.text(_bar(prog.tool_dps(state.tool_tier), top) + "  %.0f damage a second" % prog.tool_dps(state.tool_tier), QuarryTheme.GOOD)
	var nt := prog.next_tool()
	var tools_total := prog.tools().size()
	if nt.is_empty():
		p.text("Every tool on the pegboard is yours. The jackhammer breaks anything.", QuarryTheme.GOOD)
		p.offer_item("tool", str(prog.tool()["title"]), str(prog.tool().get("desc", "")), 0, "In your hand", PurchaseOffers.tool_owned(self))
	else:
		var nxt := state.tool_tier + 1
		p.text("NEXT ON THE PEGBOARD", QuarryTheme.ACCENT)
		p.text(_tool_line(nxt), QuarryTheme.INK)
		p.text(_bar(prog.tool_dps(nxt), top) + "  %.0f damage a second  (+%d%%)" % [prog.tool_dps(nxt), prog.tool_gain_percent(state.tool_tier, nxt)], QuarryTheme.MONEY)
		var newly := int(nt.get("max_hardness", 1)) > int(prog.tool().get("max_hardness", 1))
		var short := maxi(0, int(nt["cost"]) - state.money)
		var lock_txt := prog.unlock_missing_text(str(nt["id"]))
		p.offer_item("tool", str(nt["title"]), "%s%s" % [str(nt.get("desc", "")), "  It can break harder rock than your current tool." if newly else ""], int(nt["cost"]),
			"Tool %d of %d" % [nxt + 1, tools_total], PurchaseOffers.tool_next(self, func(): menu_act("upgrades", 0, false)), lock_txt if lock_txt != "" else ("" if short <= 0 else "Need %s more" % QuarryTheme.money_text(short)))
	# Phase 9.2: the rest of the pegboard - specialist tools (Q swaps the tool in your hand) and hauling aids
	var cats := [["TOOLS FOR THE JOB", ["pointed_chisel", "flat_chisel", "repaired_pickaxe", "sledgehammer", "steel_pickaxe", "hardened_pickaxe", "hand_splitter", "powered_hammer", "pneumatic_chisel", "air_compressor"]], ["HAULING", ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow"]]]
	for cat in cats:
		p.text(str(cat[0]), QuarryTheme.ACCENT)
		for gid in cat[1]:
			var gd := prog.gear_def(str(gid))
			var have := prog.owns(str(gid))
			var note := ""
			if not have:
				note = prog.unlock_missing_text(str(gid))
			var gcopy := str(gid)
			p.offer_item("gear_" + gcopy, str(gd["title"]), str(gd.get("desc", "")), int(gd["cost"]), "OWNED" if have else str(gd.get("class", "")).capitalize(),
				PurchaseOffers.gear(self, gcopy, func(): buy_gear(gcopy)), note)
	p.text("TUNING AND GEAR", QuarryTheme.ACCENT)
	for i in range(UPGRADE_MENU.size()):
		var key: String = UPGRADE_MENU[i]
		var info: Dictionary = prog.cfg.get("player_upgrades", {}).get(key, {})
		var owned: bool = state.upgrades[key]
		p.item("up_" + key, str(info.get("title", key)), str(info.get("effect", "")), int(state.config["upgrades"][key]),
			"INSTALLED" if owned else "", "OWNED" if owned else "BUY", not owned, func(): menu_act("upgrades", i + 1, false))

## Workbench in the office: the bench top, a vise, and the pegboard of tools above it (Phase 8.3). The tools you own hang
## in full colour; the next one is lit and has a price tag; the rest are dim.
var workbench_tools: Node3D
var workbench_tag: Label3D

func _build_workbench() -> void:
	# On the office's front wall, left of the door: clear wall, nothing in the way, in view as you walk in.
	var b := TOOLSHED_POS + Vector3(0.0, 0.0, 1.75)       # against the back wall, clear of the door
	var wood := MeshKit.mat(QuarryArt.M_WOOD)
	var steel := MeshKit.mat("SteelPlate")
	var bench := _solid(world, "Workbench", b + Vector3(0, 0.5, 0), Vector3(1.5, 1.0, 0.7), Color(0.40, 0.28, 0.16))
	bench.set_meta("kind", "upgrades")
	for ch in bench.get_children():
		if ch is MeshInstance3D:
			ch.visible = false                                  # the collider's plain box is replaced by the parts below
	MeshKit.inst(bench, MeshKit.box(Vector3(1.56, 0.07, 0.74)), wood, b + Vector3(0, 0.965, 0) - bench.position)                 # bench top
	MeshKit.inst(bench, MeshKit.box(Vector3(1.44, 0.16, 0.05)), wood, b + Vector3(0, 0.84, 0.31) - bench.position)               # front apron
	for sx in [-0.7, 0.7]:
		for sz in [-0.3, 0.3]:
			MeshKit.inst(bench, MeshKit.box(Vector3(0.08, 0.93, 0.08)), wood, b + Vector3(sx, 0.465, sz) - bench.position)     # legs
	MeshKit.inst(bench, MeshKit.box(Vector3(1.4, 0.04, 0.6)), wood, b + Vector3(0, 0.28, 0) - bench.position)                    # lower shelf
	MeshKit.inst(bench, MeshKit.box(Vector3(0.36, 0.2, 0.3)), steel, b + Vector3(-0.45, 0.4, 0.0) - bench.position)              # toolbox on the shelf
	MeshKit.inst(bench, MeshKit.box(Vector3(0.3, 0.14, 0.26)), wood, b + Vector3(0.1, 0.37, 0.0) - bench.position)               # crate
	MeshKit.inst(bench, MeshKit.box(Vector3(0.18, 0.1, 0.22)), steel, b + Vector3(0.55, 1.04, 0.05) - bench.position)            # vise base
	MeshKit.inst(bench, MeshKit.box(Vector3(0.05, 0.12, 0.2)), steel, b + Vector3(0.64, 1.13, 0.05) - bench.position)           # vise jaw
	MeshKit.inst(bench, MeshKit.box(Vector3(0.32, 0.04, 0.22)), MeshKit.flat(Color(0.66, 0.5, 0.2)), b + Vector3(-0.35, 1.02, 0.0) - bench.position)   # parts tray
	# pegboard on the wall above, clear of the door, the lamp and the whiteboard
	MeshKit.inst(world, MeshKit.box(Vector3(1.5, 1.05, 0.04)), MeshKit.flat(Color(0.62, 0.5, 0.34)), Vector3(b.x, 1.78, TOOLSHED_POS.z + 2.205))
	workbench_tools = Node3D.new()
	workbench_tools.name = "WorkbenchTools"
	world.add_child(workbench_tools)
	workbench_tools.position = Vector3(b.x, 1.72, TOOLSHED_POS.z + 2.15)
	workbench_tools.rotation.y = -PI * 0.5            # tools are modelled along z: turn them to run along the wall
	workbench_tools.scale = Vector3.ONE * 0.8
	workbench_tag = Label3D.new()
	workbench_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	workbench_tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	workbench_tag.font_size = 22
	workbench_tag.pixel_size = 0.005
	workbench_tag.outline_size = 8
	workbench_tag.position = Vector3(b.x, 2.5, TOOLSHED_POS.z + 1.9)
	workbench_tag.visibility_range_end = 9.0
	world.add_child(workbench_tag)
	_refresh_workbench()

func _wb_box(pos: Vector3, size_v: Vector3, col: Color, t: float) -> void:
	_visual_box(workbench_tools, pos, size_v, Color(col.r * t, col.g * t, col.b * t))

var _dim_mat: StandardMaterial3D

## Pegboard: every tool of the workbench hangs there as its real model. Owned tools and the next one are in full colour,
## the rest are dimmed. The tools of Phase 9 sit beside the original five, two rows along the board.
func _refresh_workbench() -> void:
	if workbench_tools == null:
		return
	for c in workbench_tools.get_children():
		c.queue_free()
	if _dim_mat == null:
		_dim_mat = StandardMaterial3D.new()
		_dim_mat.albedo_color = Color(0.05, 0.04, 0.03, 0.62)
		_dim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var steel := Color(0.62, 0.64, 0.68)
	var wood := Color(0.5, 0.35, 0.2)
	var next_id := str(prog.next_tool().get("id", ""))
	# [id, ladder tier or -1] in the order they are bought; ladder tools and the new tools interleave by price
	var order := [["hand", 0], ["pointed_chisel", -1], ["pickaxe", 1], ["flat_chisel", -1], ["repaired_pickaxe", -1], ["reinforced", 2], ["sledgehammer", -1],
		["steel_pickaxe", -1], ["hardened_pickaxe", -1], ["hand_splitter", -1], ["powered_hammer", -1], ["drill", 3], ["pneumatic_chisel", -1], ["jackhammer", 4]]
	var viewer := QuarryToolView.new()               # only used to build the ladder models without hands
	for i in range(order.size()):
		var id: String = order[i][0]
		var lt: int = order[i][1]
		var owned := prog.owns(id)
		var is_next := id == next_id
		var col := i % 5
		var row := i / 5
		var z := float(col - 2) * 0.37
		var y := 0.42 - float(row) * 0.42
		var m: Node3D
		if lt == 0 or lt == 4:
			m = viewer._build(lt, false)              # the rock hammer and the jackhammer: their real models
		elif lt > 0:
			m = GearModels.build_ladder(lt)
		else:
			m = GearModels.build_tool(id)
		workbench_tools.add_child(m)
		var sc := 0.42 if lt != 4 else 0.38
		m.scale = Vector3.ONE * sc
		# hang it by its middle: centre the model's mesh bounds on the slot
		var bb := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			if mesh == null:
				continue
			var xf := Transform3D.IDENTITY
			var cur: Node = mi
			while cur != null and cur != m:
				xf = (cur as Node3D).transform * xf
				cur = cur.get_parent()
			bb = (xf * mesh.get_aabb()) if first else bb.merge(xf * mesh.get_aabb())
			first = false
		var centre := bb.get_center() * sc
		m.position = Vector3(0, y - centre.y, z - centre.z)
		m.set_meta("tool_id", id)
		if not (owned or is_next):
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = null
				(mi as MeshInstance3D).material_overlay = _dim_mat
		# a small name label under each tool
		var lbl := Label3D.new()
		lbl.text = prog.item_title(id)
		lbl.font_size = 14
		lbl.pixel_size = 0.0035
		lbl.outline_size = 5
		lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		lbl.modulate = Color(1, 0.95, 0.82) if (owned or is_next) else Color(0.6, 0.58, 0.52)
		lbl.visibility_range_end = 5.0
		lbl.rotation.y = -PI * 0.5                      # the parent is turned along the wall: face out of it
		lbl.position = Vector3(-0.07, y - 0.19, z)
		workbench_tools.add_child(lbl)
	viewer.free()
	var nt := prog.next_tool()
	if nt.is_empty():
		workbench_tag.text = "WORKBENCH\nAll tools owned"
	else:
		workbench_tag.text = "WORKBENCH\nNext: %s  %s" % [str(nt["title"]), QuarryTheme.money_text(int(nt["cost"]))]
	_refresh_gear_props()

# ------------------------------------------------------------------ hauling aids and compressor standing in the yard (Phase 9)

const GEAR_PROP_SPOTS := {"hand_cart": Vector3(-19.2, 0, 9.4), "wheelbarrow": Vector3(-19.2, 0, 11.4), "reinforced_wheelbarrow": Vector3(-19.2, 0, 13.4), "air_compressor": Vector3(-21.5, 0, 10.0)}
const CART_IDS := ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow"]
var gear_props := {}          ## the compressor (a fixed prop)
var cart_nodes := {}          ## cart id -> QuarryCart
var natural_start_enabled := true      ## Phase 10: false keeps the three old starting piles (legacy layouts and older tests)
var soil: QuarrySoil
var spoil_node: Node3D
var held_cart: QuarryCart
var _cart_save_t := 0.0

## Bought carts stand in the yard (where they were left), the compressor beside the office.
func _refresh_gear_props() -> void:
	for id in CART_IDS:
		var owned: bool = id in state.carts
		if owned and not cart_nodes.has(id):
			var cart := QuarryCart.new()
			cart.setup(id)
			world.add_child(cart)
			cart_nodes[id] = cart
		elif not owned and cart_nodes.has(id):
			if held_cart == cart_nodes[id]:
				held_cart = null
				player.speed_mult = 1.0
			cart_nodes[id].queue_free()
			cart_nodes.erase(id)
		if cart_nodes.has(id) and cart_nodes[id] != held_cart:
			var cp: Array = state.cart_pos.get(id, [])
			var spot: Vector3 = GEAR_PROP_SPOTS[id]
			cart_nodes[id].global_position = Vector3(float(cp[0]), float(cp[1]), float(cp[2])) if cp.size() >= 4 else spot
			cart_nodes[id].rotation.y = float(cp[3]) if cp.size() >= 4 else PI * 0.5
			cart_nodes[id].velocity = Vector3.ZERO
	if "air_compressor" in state.gear and not gear_props.has("air_compressor"):
		var body := StaticBody3D.new()
		body.name = "Prop_air_compressor"
		body.position = GEAR_PROP_SPOTS["air_compressor"]
		body.rotation.y = PI
		body.set_meta("gear_prop", "air_compressor")
		body.add_child(GearModels.build_prop("air_compressor"))
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.7, 1.0, 1.0)
		cs.shape = box
		cs.position = Vector3(0, 0.5, 0.15)
		body.add_child(cs)
		world.add_child(body)
		gear_props["air_compressor"] = body
	_update_cart_load()

func _update_cart_load() -> void:
	for id in cart_nodes:
		cart_nodes[id].show_load(state.cart_load.get(id, {}), state.cart_cap(id))

# ------------------------------------------------------------------ pushing and pulling a cart, loading and unloading it

func hold_cart(id: String) -> void:
	if not cart_nodes.has(id):
		return
	if held_cart and held_cart != cart_nodes[id]:
		release_cart()
	held_cart = cart_nodes[id]
	held_cart.held = true
	player.speed_mult = 0.8
	_notify("%s %s. Move to take it along. F or E lets go." % ["Pulling" if QuarryCart.mode_of(id) == "pull" else "Pushing", str(prog.gear_def(id).get("title", id)).to_lower()])

func release_cart() -> void:
	if held_cart and is_instance_valid(held_cart):
		held_cart.held = false
		held_cart.velocity = Vector3.ZERO
		var id := held_cart.cart_id
		state.cart_pos[id] = [held_cart.global_position.x, held_cart.global_position.y, held_cart.global_position.z, held_cart.rotation.y]
	held_cart = null
	if player:
		player.speed_mult = 1.0

func _cart_follow(delta: float) -> void:
	if held_cart == null or not is_instance_valid(held_cart) or driving != null or sleeping:
		release_cart()
		return
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var id := held_cart.cart_id
	var target := player.global_position + fwd * QuarryCart.offset_of(id)
	target.y = held_cart.global_position.y
	var gap := held_cart.follow(target, player.rotation.y, delta)
	if gap > 2.2:
		release_cart()
		_notify("The cart is stuck: you let go of it.")
		return
	_cart_save_t += delta
	if _cart_save_t > 0.4:
		_cart_save_t = 0.0
		state.cart_pos[id] = [held_cart.global_position.x, held_cart.global_position.y, held_cart.global_position.z, held_cart.rotation.y]

## The cart stands close enough to a station (the storage crate, the office door) to be unloaded there.
func cart_near(id: String, station: Node3D, radius := 6.5) -> bool:
	if not cart_nodes.has(id) or station == null:
		return false
	return Vector2(cart_nodes[id].global_position.x - station.global_position.x, cart_nodes[id].global_position.z - station.global_position.z).length() <= radius

## One transfer of the cart menu. op: load (bag -> cart), unload (cart -> bag), store (cart -> crate), take (crate -> cart), sell (cart -> money).
func cart_move(op: String, id: String, key: String, n := 9999) -> int:
	var moved := 0
	match op:
		"load": moved = state.cart_load_from_bag(id, key, n)
		"unload": moved = state.cart_unload_to_bag(id, key, n)
		"store":
			if cart_near(id, storage_body):
				moved = state.cart_store(id, key, n)
		"take":
			if cart_near(id, storage_body):
				moved = state.cart_take(id, key, n)
		"sell":
			if cart_near(id, sell_body):
				var before := state.money
				moved = state.cart_sell(id, key, n)
				if moved > 0:
					sfx["coin"].play()
					_notify("Sold %d %s for %s" % [moved, prog.display(key).to_lower(), QuarryTheme.money_text(state.money - before)])
	_update_cart_load()
	return moved

## All of one cart's contents through one transfer type; returns units moved.
func cart_move_all(op: String, id: String) -> int:
	var total := 0
	for key in RESOURCE_ORDER:
		total += cart_move(op, id, str(key))
	return total

func _draw_shop(p: QuarryStationUI) -> void:
	p.begin("MACHINERY ORDERS", state.money, "Click an item to see it turn, then BUY. Placement: R rotate, G grid snap, left click place, Esc refund.")
	var machines_ok := prog.unlocked("crusher")
	var stage_note := "Unlocks at the %s stage" % prog.feature_stage_title("crusher")
	var cs := int(state.config.get("crusher_seconds", 18))
	var cl := int(state.config.get("crusher_input_limit", 12))
	p.offer_item("shop_crusher", "Small jaw crusher", "Limestone to gravel: %d stone per batch, %d s a batch." % [cl, cs], int(state.config["crusher_price"]), _shop_tag("crusher", "Owned: %d" % state.crushers.size()), _shop_offer("crusher", 0), "" if machines_ok else stage_note)
	p.offer_item("shop_output", "Output storage", "Holds %d crushed stone from a crusher chute or a belt." % business.output_capacity(), int(business.cfg["output_storage_price"]), _shop_tag("output", "Owned: %d" % _variant_count("output")), _shop_offer("output", 1), "" if machines_ok else stage_note)
	var conv_ok := business.conveyors_unlocked()
	var cr := float(business.cfg.get("conveyor_rate", 0.5))
	var cc := int(business.cfg.get("conveyor_capacity", 3))
	var conv_note := "" if conv_ok else "Needs a crusher and an operator"
	p.offer_item("shop_conveyor", "Conveyor, straight", "2 m belt: %.1f items a second, holds %d. Snaps onto machine ports." % [cr, cc], int(business.cfg["conveyor_price"]), _shop_tag("conveyor", "Owned: %d" % business.conveyors.size()), _shop_offer("conveyor", 2), conv_note)
	p.offer_item("shop_conveyor_left", "Conveyor, left corner", "Turns material 90 degrees to the left.", int(business.cfg["conveyor_price"]), _shop_tag("conveyor_left", ""), _shop_offer("conveyor_left", 7), conv_note)
	p.offer_item("shop_conveyor_right", "Conveyor, right corner", "Turns material 90 degrees to the right.", int(business.cfg["conveyor_price"]), _shop_tag("conveyor_right", ""), _shop_offer("conveyor_right", 8), conv_note)
	p.offer_item("shop_sorter", "Manual sorting table", "Sort raw rock by hand: sorted stone, coal and iron sell for %d%% more." % int(round(float(business.cfg.get("sort_bonus", 1.3)) * 100.0)), int(business.cfg["sorter_price"]), _shop_tag("sorter", "Owned: %d" % _variant_count("sorter")), _shop_offer("sorter", 11), "" if prog.unlocked("sorter") else "Unlocks at the %s stage" % prog.feature_stage_title("sorter"))
	p.offer_item("shop_hopper", "Small hopper", "A funnel bin for %d units of any material. Belts feed it and empty it." % int(business.cfg.get("hopper_capacity", 60)), int(business.cfg["hopper_price"]), _shop_tag("hopper", "Owned: %d" % _variant_count("hopper")), _shop_offer("hopper", 12), "" if prog.unlocked("hopper") else "Unlocks at the %s stage" % prog.feature_stage_title("hopper"))
	var adv_ok := prog.unlocked("advanced_crusher")
	var am: Dictionary = prog.machine("advanced_crusher")
	p.offer_item("shop_advanced", "Advanced crusher", "Batches of %d stone, %.0f s a batch." % [cl * int(am.get("capacity_mult", 2)), cs * float(am.get("speed_mult", 0.45))], int(am["price"]), _shop_tag("advanced_crusher", ""), _shop_offer("advanced_crusher", 3), "" if adv_ok else "Unlocks at the %s stage" % prog.feature_stage_title("advanced_crusher"))
	for pair in [["drill_rig", "Drilling rig", "Works stone, coal, iron and copper from a fixed pad.", 4], ["improved_rig", "Improved drilling rig", "%.0f damage a second, reaches gold-bearing rock." % float(prog.machine("improved_rig").get("dps", 0)), 9], ["rock_breaker", "Rock breaker", "Breaks any rock, gold too.", 5], ["heavy_breaker", "Heavy-duty rock breaker", "%.0f damage a second: the strongest machine." % float(prog.machine("heavy_breaker").get("dps", 0)), 10]]:
		var t: String = pair[0]
		var owned := 0
		for r in prog.rigs:
			if str(r["type"]) == t:
				owned += 1
		var ok := prog.unlocked(t)
		p.offer_item("shop_" + t, str(pair[1]), str(pair[2]), int(prog.machine(t)["price"]), "Owned: %d" % owned, _shop_offer(t, int(pair[3])), "" if ok else "Unlocks at the %s stage" % prog.feature_stage_title(t))
	if prog.level_unlocked >= 2:
		p.item("shop_permit", "Excavation permit", "The lower level is open.", 0, "OWNED", "OWNED", false, func(): pass)
	else:
		var pok := prog.unlocked("permit")
		p.item("shop_permit", "Excavation permit", "Opens a 3.5 m lower level with copper and gold.", prog.permit_cost(), "", "BUY", pok, func(): menu_act("shop", 6, false), "" if pok else "Unlocks at the %s stage" % prog.feature_stage_title("permit"))
	p.text("Rigs work a formation from a drilling pad and fill their own output bin: collect it (E), send a hauler, a belt or the loader.")
	p.button_bar([["office", "OFFICE COMPUTER", true, func(): _open_menu("manage"), 200]])

## The offer shown in the pane for a shop card. Something already delivered is simply placed instead of bought.
func _shop_offer(key: String, digit: int) -> Dictionary:
	var o := PurchaseOffers.machine(self, key, func(): menu_act("shop", digit, false))
	var n := int(business.inventory.get(key, 0))
	if n > 0:
		o["price"] = 0
		o["reason"] = ""
		o["buy_text"] = "PLACE  (%d delivered)" % n
	return o

## "In inventory: n" once something has been delivered and not yet placed.
func _shop_tag(key: String, owned: String) -> String:
	var n := int(business.inventory.get(key, 0))
	return ("In inventory: %d" % n) if n > 0 else owned

# ------------------------------------------------------------------ Phase 10.1: the opening - Grandpa's excavator and the natural ground

var opening_parts := {}          ## part id -> StaticBody3D lying near the workshop
var natural_root: Node3D
var repair_busy := false

func _starter_vehicle() -> QuarryVehicle:
	for v in vehicle_nodes.values():
		if v.vtype == "starter_excavator":
			return v
	return null

## Builds or removes everything that belongs to the opening, from the progression record (so a load, a new game and the first
## launch all agree): the machine itself, the parts still lying around, the natural ground, Grandpa at his post.
func _ensure_opening() -> void:
	prog.natural_start_enabled = natural_start_enabled
	var natural := natural_start_enabled and prog.natural_start()
	var ex := prog.excavator_state()
	if _truck_should_be_gone():
		_truck_leaves(true)
	if natural and not bool(ex["granted"]):
		var oc: Dictionary = prog.opening_cfg().get("excavator", {})
		var pp: Array = oc.get("pos", [-12.0, 0.0, 6.6])
		var park: Array = fleet.cfg.get("parking", [])
		if blueprint and park.size() >= 2:
			pp = park[0]                       # the excavator and the old truck stand in the machinery garage, in their own parking slots
		var rec := fleet.give("starter_excavator", Vector3(float(pp[0]), float(pp[1]), float(pp[2])), float(oc.get("yaw", 0.0)))
		if not rec.is_empty():
			ex["granted"] = true
			var tc: Dictionary = prog.cfg_for("soil").get("truck", {})
			if not tc.is_empty() and not fleet.owns_type("starter_truck"):
				var tp: Array = tc["pos"]
				if blueprint and park.size() >= 2:
					tp = park[1]
				fleet.give("starter_truck", Vector3(float(tp[0]), float(tp[1]), float(tp[2])), float(tc.get("yaw", 0.0)))
			_sync_vehicles()
	_decorate_starter()
	_spawn_repair_parts()
	_build_natural_ground(natural)
	if soil and is_instance_valid(soil):
		soil.apply(state.soil_units)
		_update_spoil()
	if natural and not bool(ex["started"]) and bool(prog.story["intro_seen"]) and not walter_intro_running:
		_grandpa_to_post()

func _decorate_starter() -> void:
	var v := _starter_vehicle()
	if v == null or v.model_root == null:
		return
	var cab: Node3D = v.turret if v.turret != null else v.model_root
	for holder in [v.model_root, cab]:
		for nm in ["OpeningParts", "OpeningGround"]:
			var old: Node = holder.get_node_or_null(nm)
			if old:
				old.free()
	OpeningModels.fitted(cab, prog.repair_done("battery"), prog.repair_done("hose"), prog.repair_done("fuel"), v.model_root)

func _spawn_repair_parts() -> void:
	var natural := natural_start_enabled and prog.natural_start()
	for id in QuarryProgression.REPAIR_PARTS:
		var want: bool = natural and not prog.repair_done(id) and prog.carried_part() != id
		if want and not opening_parts.has(id):
			var pc: Dictionary = prog.opening_cfg().get("parts", {}).get(id, {})
			var pp: Array = pc.get("pos", [0, 0, 0])
			var body := StaticBody3D.new()
			body.name = "Repair_" + id
			body.position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
			body.collision_layer = 32
			body.set_meta("kind", "repair_part")
			body.set_meta("part", id)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.6, 0.5, 0.6)
			cs.shape = box
			cs.position.y = 0.25
			body.add_child(cs)
			body.add_child(OpeningModels.part(id))
			world.add_child(body)
			opening_parts[id] = body
		elif not want and opening_parts.has(id):
			opening_parts[id].queue_free()
			opening_parts.erase(id)

func _build_natural_ground(natural: bool) -> void:
	if not natural:
		if natural_root and is_instance_valid(natural_root):
			natural_root.queue_free()
		natural_root = null
		if soil and is_instance_valid(soil):
			soil.queue_free()
		soil = null
		if spoil_node and is_instance_valid(spoil_node):
			spoil_node.queue_free()
		spoil_node = null
		return
	if natural_root and is_instance_valid(natural_root):
		return
	var ok := func(p: Vector2) -> bool:
		var v := Vector3(p.x, 0.0, p.y)
		return not in_pit_corridor(v, 5.0) and not in_hillside_zone(v, 4.0) and not hub_rect().grow(3.0).has_point(p) and p.distance_to(Vector2(2.0, -14.0)) > 3.0 and p.distance_to(Vector2(11.5, -11.0)) > 3.0 and absf(p.x) > 4.4 
	var ok_bp := func(p: Vector2) -> bool:
		if not ok.call(p):
			return false
		if blueprint:                                   # nothing permanent stands where an access road will be built (rects are in the pit frame: local z = world z + 8)
			for lv in prog.levels():
				for r in lv.get("roads", []):
					if Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])).grow(2.0).has_point(Vector2(p.x, p.y + 8.0)):
						return false
		return true
	var info: Dictionary
	if blueprint:
		var nr := Node3D.new()                       # no permanent boulders, mounds or scrub in the blueprint quarry: the loose rocks and weeds are the cleanable debris
		nr.name = "NaturalStart"
		world.add_child(nr)
		info = {"root": nr, "boulders": 0, "outcrops": 0, "patches": 0, "scrub": 0, "pebbles": 0}
	else:
		info = OpeningModels.natural_ground(world, ok_bp, Rect2(-23.0, -29.0, 46.0, 21.5) if not blueprint else Rect2(-32.0, -56.0, 64.0, 42.0), 1010)
	natural_root = info["root"]
	_build_soil()
	natural_root.set_meta("counts", {"boulders": info["boulders"], "outcrops": info["outcrops"], "patches": info["patches"], "scrub": info["scrub"], "pebbles": info["pebbles"]})
	nav_dirty = true

## The soil field: cells clear of the boulders and outcrops, the paths, the ore outcrops and the spoil heap. State comes from the save.
func _build_soil() -> void:
	var sc: Dictionary = prog.cfg_for("soil")
	if sc.is_empty() or (soil and is_instance_valid(soil)):
		return
	var cols := int(sc["cols"])
	var rows := int(sc["rows"])
	var cell := float(sc.get("cell", 2.0))
	var org := Vector2(float(sc["origin"][0]), float(sc["origin"][1]))
	var sp: Array = sc["spoil"]["pos"]
	var spoil_pos := Vector2(float(sp[0]), float(sp[2]))
	var mask := PackedByteArray()
	mask.resize(cols * rows)
	var solids: Array = []
	for c in natural_root.get_children():
		if c is StaticBody3D:
			solids.append(Vector2(c.global_position.x, c.global_position.z))
	var avoid: Array = [Vector2(2.0, -14.0), Vector2(11.5, -11.0), spoil_pos]
	for i in range(cols * rows):
		var p := Vector2(org.x + (float(i % cols) + 0.5) * cell, org.y + (float(i / cols) + 0.5) * cell)
		var ok := not in_pit_corridor(Vector3(p.x, 0, p.y), 3.0) and not in_hillside_zone(Vector3(p.x, 0, p.y), 1.5) and not hub_rect().has_point(p) and absf(p.x) > 5.0     # the quarry road stays clear (a cell is 2 m wide)
		for q in solids:
			if (q as Vector2).distance_to(p) < 2.6:
				ok = false
		for q in avoid:
			if (q as Vector2).distance_to(p) < 3.6:
				ok = false
		for cid in prog.cleanup_ids():
			if prog.cleanup_pos(str(cid)).distance_to(p) < 1.8:
				ok = false           # weeds and rubble are never buried under a soil pile: the ground around them stays bare
		mask[i] = 1 if ok else 0
	soil = QuarrySoil.new()
	world.add_child(soil)
	soil.setup(sc, mask, state.soil_units)
	# the spoil heap: a marked patch whose mound grows with what has been dumped there
	spoil_node = Node3D.new()
	spoil_node.name = "SpoilHeap"
	spoil_node.position = Vector3(spoil_pos.x, 0.0, spoil_pos.y)
	world.add_child(spoil_node)
	var ring := MeshKit.Soup.new()
	MeshKit.frustum_into(ring, Vector3.ZERO, float(sc["spoil"]["radius"]), float(sc["spoil"]["radius"]), 0.04, 14)
	MeshKit.inst(spoil_node, ring.mesh(), MeshKit.mat("ExcavatedDirt"))
	var mound := MeshKit.inst(spoil_node, MeshKit.rock(Vector3(3.6, 1.8, 3.6), 77, 3, 8), MeshKit.mat("ExcavatedDirt"))
	spoil_node.set_meta("mound", mound)
	for k in range(4):
		var a := TAU * float(k) / 4.0 + 0.4
		var stake := MeshKit.Soup.new()
		MeshKit.box_into(stake, Vector3.ZERO, Vector3(0.08, 1.2, 0.08))
		MeshKit.box_into(stake, Vector3(0, 0.55, 0), Vector3(0.3, 0.12, 0.02))
		MeshKit.inst(spoil_node, stake.mesh(), MeshKit.flat(Color(0.9, 0.55, 0.15)), Vector3(cos(a) * float(sc["spoil"]["radius"]), 0.6, sin(a) * float(sc["spoil"]["radius"])))
	_update_spoil()

func _update_spoil() -> void:
	if spoil_node == null or not is_instance_valid(spoil_node):
		return
	var mound: MeshInstance3D = spoil_node.get_meta("mound")
	var f := clampf(float(state.soil_dumped) / 120.0, 0.0, 1.0)
	mound.visible = state.soil_dumped > 0
	mound.scale = Vector3(0.3 + 0.7 * f, 0.15 + 0.85 * f, 0.3 + 0.7 * f)
	mound.position.y = -0.1

func soil_sync_state() -> void:
	if soil and is_instance_valid(soil):
		state.soil_units = Array(soil.units)

func _pick_up_part(id: String) -> void:
	if prog.carried_part() != "":
		_notify("You are already carrying the %s: fit it to the excavator first." % prog.carried_part())
		return
	if prog.pick_up_part(id):
		_spawn_repair_parts()
		pickup_audio.play()
		hud.toast("Picked up the " + str(prog.opening_cfg().get("parts", {}).get(id, {}).get("title", id)).to_lower(), "Take it to Grandpa's excavator and press E.", "info")

## E on Grandpa's machine: fit the carried part, start it once repaired, or say what is still broken.
func _use_starter(v: QuarryVehicle) -> void:
	if repair_busy or walter_dialog != null:
		return
	if prog.carried_part() != "":
		_install_part(v)
	elif prog.repairs_complete() and not bool(prog.excavator_state()["started"]):
		_excavator_start_scene(v)
	elif prog.excavator_ready():
		enter_vehicle(v)
	else:
		var missing := []
		for p in QuarryProgression.REPAIR_PARTS:
			if not prog.repair_done(p):
				missing.append(str(prog.opening_cfg().get("parts", {}).get(p, {}).get("title", p)).to_lower())
		_notify("The excavator is broken: it still needs the %s. Pick the parts up near the workshop." % ", ".join(missing))

## A short first-person repair: the view drops to the engine, three wrench taps with sparks, the part is fitted and the machine changes.
func _install_part(v: QuarryVehicle) -> void:
	var part := prog.carried_part()
	repair_busy = true
	player.locked = true
	var at := v.global_position + Vector3(0, 1.3, 0)
	_turn_view_to(at, 0.35)
	var tw := create_tween()
	tw.tween_property(player.camera, "rotation:x", -0.35, 0.3)
	for k in range(3):
		tw.tween_callback(func():
			sfx["hit_reinforced"].play()
			fx.impact(at + Vector3(0.0, 0.1 * float(k), 0.0), "iron_ore", 0.8, Vector3.UP))
		tw.tween_interval(0.32)
	tw.tween_callback(func():
		prog.install_part()
		_decorate_starter()
		_spawn_repair_parts()
		sfx["unlock"].play()
		hud.toast(str(prog.opening_cfg().get("parts", {}).get(part, {}).get("title", part)) + " fitted", "%d of 3 repairs done" % prog.repairs_done(), "unlock")
		create_tween().tween_property(player.camera, "rotation:x", 0.0, 0.4)
		player.locked = false
		repair_busy = false
		if prog.repairs_complete():
			_excavator_start_scene(v))

## Everything is fitted: Grandpa helps start it. The engine struggles before it catches; then normal play resumes at once.
func _excavator_start_scene(v: QuarryVehicle) -> void:
	if walter_dialog != null or bool(prog.excavator_state()["started"]):
		return
	_turn_view_to(v.global_position + Vector3(0, 1.4, 0), 0.4)
	_open_walter_dialog(prog.opening_cfg().get("start_lines", []), func(_skipped: bool): _engine_struggle(v))

func _engine_struggle(v: QuarryVehicle) -> void:
	repair_busy = true
	player.locked = true
	var base: Vector3 = v.model_root.position
	var tw := create_tween()
	for k in range(4):
		tw.tween_callback(func():
			sfx["hit_reinforced"].play()
			fx.chunk_break(v.global_position + Vector3(0.4, 1.7, -0.9), "coal"))
		tw.tween_property(v.model_root, "position", base + Vector3(0.0, 0.05, 0.0), 0.12)
		tw.tween_property(v.model_root, "position", base, 0.12)
		tw.tween_interval(0.28)
	tw.tween_callback(func(): _engine_runs(v, base))

func _engine_runs(v: QuarryVehicle, base: Vector3) -> void:
	v.model_root.position = base
	prog.excavator_state()["started"] = true
	sfx["unlock"].play()
	fx.chunk_break(v.global_position + Vector3(0.4, 1.9, -0.9), "coal")
	_open_walter_dialog(prog.opening_cfg().get("running_lines", []), func(_s2: bool): _after_start(), true)

func _after_start() -> void:
	create_tween().tween_property(player.camera, "rotation:x", 0.0, 0.4)
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	repair_busy = false
	hud.toast("Grandpa's excavator is running", "Press E on it to climb in.", "unlock")
	_walter_leave()

## Grandpa waits by the excavator until it runs (and hints at the next repair when talked to).
func _grandpa_to_post() -> void:
	var gc: Array = prog.opening_cfg().get("grandpa", {}).get("pos", [-14.9, 0.0, 5.6])
	var at := Vector3(float(gc[0]), float(gc[1]), float(gc[2]))
	var face: Array = prog.opening_cfg().get("excavator", {}).get("pos", [-12.0, 0.0, 6.6])
	if walter_node == null or not is_instance_valid(walter_node):
		_spawn_walter(at, Vector3(float(face[0]), 0.0, float(face[2])))
	else:
		walter_node.global_position = at
		walter_node.rotation.y = atan2(-(float(face[0]) - at.x), -(float(face[2]) - at.z))
	walter_mode = "waiting"
	walter_pose = "idle"
	walter_path = PackedVector3Array()

func _grandpa_hint() -> void:
	var next := prog.next_repair()
	var text := "Take your time."
	if prog.carried_part() != "":
		text = "That's the right part. Fit it to the machine: press E on her."
	elif next != "":
		text = str(prog.opening_cfg().get("parts", {}).get(next, {}).get("hint", text))
	_walter_face_player()
	_open_walter_dialog([{"speaker": "GRANDPA WALTER", "text": text}], func(_s: bool):
		player.locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

func _variant_count(variant: String) -> int:
	var n := 0
	for i in range(business.outputs.size()):
		if business.variant_of(i) == variant:
			n += 1
	return n

func _shop_button(key: String) -> String:
	return "PLACE (%d)" % int(business.inventory.get(key, 0)) if int(business.inventory.get(key, 0)) > 0 else "ORDER"

## Orders a stationary machine: it is paid for and delivered straight to the construction inventory (no driving),
## ready to be placed with the blueprint system.
func order_machine(key: String) -> bool:
	var kind := key
	if key.begins_with("conveyor"):
		kind = "conveyor"
	if kind in ["hopper", "sorter"] and not prog.unlocked(kind):
		_notify("The %s unlocks at the %s stage." % [("small hopper" if kind == "hopper" else "sorting table"), prog.feature_stage_title(kind)])
		return false
	if kind in ["crusher", "output", "advanced_crusher"] and not prog.unlocked("crusher"):
		_notify("Machinery unlocks at the %s stage." % prog.feature_stage_title("crusher"))
		return false
	if kind == "advanced_crusher" and not prog.unlocked("advanced_crusher"):
		_notify("The advanced crusher unlocks at the %s stage." % prog.feature_stage_title("advanced_crusher"))
		return false
	if kind == "conveyor" and not business.conveyors_unlocked():
		_notify("Conveyors unlock with the Mechanized Quarry milestone.")
		return false
	var price := _placement_price(kind)
	if not business.buy(price):
		_notify("Need $%d" % price)
		return false
	business.inventory[key] = int(business.inventory.get(key, 0)) + 1
	var titles := {"crusher": "Small jaw crusher", "hopper": "Small hopper", "sorter": "Manual sorting table", "output": "Output storage", "advanced_crusher": "Advanced crusher", "conveyor": "Straight conveyor",
		"conveyor_left": "Left corner conveyor", "conveyor_right": "Right corner conveyor"}
	hud.toast("Delivery confirmed", "%s is in your construction inventory - place it from the order screen or in construction mode." % titles.get(key, key), "unlock")
	_sfx_unlock()
	return true

func _shop_pick(key: String) -> void:
	if int(business.inventory.get(key, 0)) > 0:
		_start_placement(key)
	else:
		order_machine(key)

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
			elif digit == RESOURCE_ORDER.size():
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
				0: _shop_pick("crusher")
				1: _shop_pick("output")
				2: _shop_pick("conveyor")
				3: _shop_pick("advanced_crusher")
				7: _shop_pick("conveyor_left")
				8: _shop_pick("conveyor_right")
				11: _shop_pick("sorter")
				12: _shop_pick("hopper")
				4, 5, 9, 10:
					var t: String = {4: "drill_rig", 5: "rock_breaker", 9: "improved_rig", 10: "heavy_breaker"}[digit]
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

const MACHINE_FOOT := Vector2(2.2, 1.6)      ## x (across) and z (along) footprint of a placed machine at yaw 0

func placement_valid(pos: Vector3, yaw: float, machine := true) -> bool:
	if not in_build_area(pos) or pos.distance_to(Vector3(0,0,8))<2.0 or not _on_ground(pos) or _near_vehicle(pos, 3.0):
		return false
	if machine and not footprint_ok(pos, yaw):
		return false
	for body in world.get_children():
		if body == ghost or not body is StaticBody3D or body.name == "Quarry floor" or body.has_meta("ground"):
			continue
		if not body.collision_layer:
			continue
		var d: Vector3 = body.position - pos
		if str(body.get_meta("kind", "")) == "conveyor":
			if Vector2(d.x, d.z).length() < 1.7:     # a belt end may touch a machine's port: only the belt body itself blocks
				return false
			continue
		if absf(d.x)<2.1 and absf(d.z)<2.1:
			return false
	for i in range(state.crushers.size()):
		if str(relocating.get("kind", "")) == "crusher" and int(relocating["index"]) == i:
			continue
		var p: Array = state.crushers[i]["position"]
		if Vector2(pos.x,pos.z).distance_to(Vector2(float(p[0]),float(p[2])))<2.5:
			return false
	return true

## Phase 1: the machine's real (rotated) footprint must stand on level, solid ground - every sample point of it lands on the floor within
## 0.2 m of the machine's own height on a gentle surface, so nothing floats over a drop or a step - and nothing solid (rock, wall, another
## machine) may occupy the volume the machine would fill.
func footprint_ok(pos: Vector3, yaw: float) -> bool:
	var basis := Basis(Vector3.UP, yaw)
	var space := get_world_3d().direct_space_state
	for ox in [-0.5, 0.0, 0.5]:
		for oz in [-0.5, 0.0, 0.5]:
			var p: Vector3 = pos + basis * Vector3(ox * MACHINE_FOOT.x, 0.0, oz * MACHINE_FOOT.y)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.5, 0), p - Vector3(0, 1.2, 0), 1)
			var h := space.intersect_ray(q)
			if h.is_empty():
				return false
			var body: Node = h["collider"]
			if not (body.name == "Quarry floor" or body.has_meta("ground")):
				return false
			if absf(float(h["position"].y) - pos.y) > 0.2 or float(h["normal"].y) < 0.9:
				return false
	var box := BoxShape3D.new()
	box.size = Vector3(MACHINE_FOOT.x - 0.1, 1.3, MACHINE_FOOT.y - 0.1)
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = box
	sq.transform = Transform3D(basis, pos + Vector3(0, 0.25 + 0.65, 0))
	sq.collision_mask = 1
	for hit in space.intersect_shape(sq, 16):
		var c: Node = hit["collider"]
		if c == ghost or c.has_meta("ground") or c.name == "Quarry floor" or str(c.get_meta("kind", "")) in ["conveyor", "piece"]:
			continue
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
	var hub := hub_rect()
	if pos.x >= hub.position.x + margin and pos.x <= hub.end.x - margin and pos.z >= hub.position.y and pos.z <= hub.end.y - margin:
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
		var snap := conveyor_snap(ghost.position, placement_belt)
		if not snap.is_empty():
			ghost.position = Vector3(snap["pos"].x, ghost.position.y, snap["pos"].z)
			placement_yaw = float(snap["yaw"])
	var snap_note := ""
	if placement_kind in ["crusher", "advanced_crusher", "output"] and grid_snap:
		var ms := machine_snap(placement_kind, ghost.position)
		if not ms.is_empty():
			ghost.position = Vector3(ms["pos"].x, ghost.position.y, ms["pos"].z)
			placement_yaw = float(ms["yaw"])
			snap_note = str(ms["note"])
	ghost.rotation.y = placement_yaw
	ghost.visible = true
	placement_hint = ""
	if placement_kind == "conveyor":
		ghost_valid = conveyor_valid(ghost.position,placement_yaw,placement_belt)
		var link := business.link_for(ghost.position,placement_yaw,-1,placement_belt)
		placement_hint = "\nIN: %s  ->  OUT: %s%s" % [business.describe_ep(link["src"]), business.describe_ep(link["dst"]), "  |  CONNECTED" if not link["src"].is_empty() and not link["dst"].is_empty() else "  |  align both ends"]
	else:
		ghost_valid = placement_valid(ghost.position,placement_yaw)
		if snap_note != "":
			placement_hint = "\nCONNECTS: " + snap_note + "  (G = place freely)"
		elif grid_snap:
			placement_hint = "\nMove next to a belt end or machine and it snaps into place"
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
		"hopper":
			_create_output(business.add_output(ghost.position,placement_yaw,"hopper"))
			_notify("Small hopper placed. Feed it by hand or from a belt, and empty it with a belt or by hand.")
		"sorter":
			_create_output(business.add_output(ghost.position,placement_yaw,"sorter"))
			_notify("Sorting table placed. Put rock on it, press SORT, then sell the sorted stone for more.")
		"conveyor":
			_create_conveyor(business.add_conveyor(ghost.position,placement_yaw,placement_belt))
			var link: Dictionary = business.links.back()
			_notify("Conveyor: %s -> %s. B then left click to move it if disconnected." % [business.describe_ep(link["src"]), business.describe_ep(link["dst"])])
	business.compute_links()
	business.check_milestones()
	nav_dirty = true
	_cancel_placement(false)

func _placement_price(kind: String) -> int:
	match kind:
		"advanced_crusher": return int(prog.machine("advanced_crusher")["price"])
		"output": return int(business.cfg["output_storage_price"])
		"hopper": return int(business.cfg["hopper_price"])
		"sorter": return int(business.cfg["sorter_price"])
		"conveyor": return int(business.cfg["conveyor_price"])
	return int(state.config["crusher_price"])

## Key of a placeable in the construction inventory.
func inventory_key(kind: String, belt := "straight") -> String:
	return "conveyor" if kind == "conveyor" and belt == "straight" else ("conveyor_" + belt if kind == "conveyor" else kind)

func _start_placement(kind: String) -> void:
	placement_belt = "straight"
	if kind == "conveyor_left" or kind == "conveyor_right":
		placement_belt = kind.substr(9)
		kind = "conveyor"
	if kind in ["hopper", "sorter"] and not prog.unlocked(kind):
		_notify("The %s unlocks at the %s stage." % [("small hopper" if kind == "hopper" else "sorting table"), prog.feature_stage_title(kind)])
		return
	if kind in ["crusher", "output", "advanced_crusher"] and not prog.unlocked("crusher"):
		_notify("Machinery unlocks at the %s stage." % prog.feature_stage_title("crusher"))
		return
	if kind == "advanced_crusher" and not prog.unlocked("advanced_crusher"):
		_notify("The advanced crusher unlocks at the %s stage." % prog.feature_stage_title("advanced_crusher"))
		return
	if kind == "conveyor" and not business.conveyors_unlocked():
		_notify("Conveyors unlock with the Mechanized Quarry milestone.")
		return
	# an item already delivered to the construction inventory is used first; otherwise it is ordered and paid for now
	var inv_key := inventory_key(kind, placement_belt)
	placement_from_inventory = false
	if int(business.inventory.get(inv_key, 0)) > 0:
		business.inventory[inv_key] = int(business.inventory[inv_key]) - 1
		placement_from_inventory = true
	elif not business.buy(_placement_price(kind)):
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
		"hopper", "sorter":
			if art:
				if kind == "hopper":
					art.hopper_model(ghost, 0.0)
				else:
					art.sorting_table_model(ghost, 0.0)
			for child in ghost.get_children():
				if child is GeometryInstance3D:
					child.transparency = 0.45
		"conveyor": _conveyor_visual(ghost,true,placement_belt)
	_notify("Choose a clear patch of ground. R rotates, G toggles grid snap, left click places.")

func _cancel_placement(refund := true) -> void:
	if not relocating.is_empty():
		_restore_relocated() # cancel a move: original spot, no money involved
		refund = false
	if refund:
		if placement_from_inventory:
			var ik := inventory_key(placement_kind, placement_belt)
			business.inventory[ik] = int(business.inventory.get(ik, 0)) + 1     # back into the construction inventory
		else:
			state.money += _placement_price(placement_kind)
	placement_from_inventory = false
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

func _save(quiet := false) -> void:
	var placing := placement
	if placement and not quiet:
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
		if not rec.is_empty() and not v.has_meta("delivering"):   # a machine still being delivered is saved on its bay
			v.save_into(rec)
	fleet.driving_id = driving.vehicle_id if driving else -1
	var data := state.snapshot()
	data["pieces"] = pieces
	var vps := []
	for pid in vein_pieces:
		if ground_pieces.has(pid) and is_instance_valid(ground_pieces[pid]):
			var vp: Dictionary = vein_pieces[pid]
			vps.append({"id": pid, "kind": vp["kind"], "col": vp["col"], "res": vp["res"], "i": vp["i"]})
	data["vein_pieces"] = vps
	data["vein_seq"] = vein_seq
	data["phase2"] = business.snapshot()
	data["phase3"] = fleet.snapshot()
	data["phase5"] = prog.snapshot()
	# write to a temporary file first, keep the previous good save as a backup, then swap: a crash or a closed window
	# in the middle of a save can no longer leave a broken or empty save behind
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		if not quiet:
			_notify("Save failed")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	if _save_usable(tmp) == null:                     # never promote a file that would not load
		DirAccess.remove_absolute(tmp)
		if not quiet:
			_notify("Save failed")
		return
	if _save_usable(SAVE_PATH) != null:               # only a GOOD current save becomes the backup: a broken one must not overwrite it
		DirAccess.copy_absolute(SAVE_PATH, SAVE_BACKUP)
	if DirAccess.rename_absolute(tmp, SAVE_PATH) != OK:
		DirAccess.remove_absolute(SAVE_PATH)
		if DirAccess.rename_absolute(tmp, SAVE_PATH) != OK:
			if not quiet:
				_notify("Save failed")
			return
	if not quiet:
		_notify("Saved quarry progress")
	elif placing:
		pass

## A save is usable only if it parses AND the game state really restores from it (a file that is valid JSON but has lost its
## state, or was written half-way, is not a save).
func _save_usable(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or not d.has("pieces") or not (d["pieces"] is Array):
		return null
	var scratch := State.new(state.config)
	if not scratch.restore(d):
		return null
	return d

## The newest usable save: the main file, or the backup of the one before it.
func _read_save() -> Variant:
	for path in [SAVE_PATH, SAVE_BACKUP]:
		var d = _save_usable(path)
		if d != null:
			return d
	return null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and autosave_enabled and player != null:
		_save(true)                                  # closing the window keeps your progress

## The main menu: the world is paused behind it and a film camera shows the quarry.
func _show_title() -> void:
	if title != null or player == null:
		return
	menu = "title"
	player.locked = true
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title = QuarryTitleMenu.new()
	ui.add_child(title)
	title.setup(self, _save_usable(SAVE_PATH) != null or _save_usable(SAVE_BACKUP) != null)
	title.chosen.connect(_title_chosen)

func _title_chosen(what: String) -> void:
	match what:
		"quit":
			get_tree().quit()
		"new":
			if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BACKUP):
				Engine.set_meta("qd_skip_title", true)         # the reload that follows goes straight into the new game
				new_game()
				return
			_close_title()
		"continue":
			_close_title()

func _close_title() -> void:
	if title == null:
		return
	title.release()
	title.queue_free()
	title = null
	menu = ""
	hud.visible = true
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not prog.story["intro_seen"]:
		call_deferred("_show_intro")

## Back to the main menu (from the pause menu): the game is saved first.
func to_main_menu() -> void:
	if autosave_enabled:
		_save(true)
	get_tree().reload_current_scene()

## Erases the save and starts over (asked twice in the pause menu).
func new_game() -> void:
	autosave_enabled = false
	for path in [SAVE_PATH, SAVE_BACKUP, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	get_tree().reload_current_scene()

func _load(quiet := false) -> void:
	release_cart()
	var data = _read_save()
	if data == null:
		if not quiet:
			_notify("No save yet" if not FileAccess.file_exists(SAVE_PATH) else "Save could not be read")
		return
	if not state.restore(data):
		if not quiet:
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
	vein_pieces.clear()
	vein_seq = int(data.get("vein_seq", 0))
	for vp in data.get("vein_pieces", []):
		if vp is Dictionary and formation_nodes.has(str(vp.get("kind", ""))) and int(vp.get("col", -1)) < prog.column_count(str(vp["kind"])):
			_spawn_vein_piece(str(vp["kind"]), int(vp["col"]), str(vp["res"]), int(vp.get("i", 0)), str(vp["id"]))
	_cine_stop()
	_remove_walter()
	_remove_fossil()
	_remove_companion()
	if fossil_dialog:
		fossil_dialog.queue_free()
		fossil_dialog = null
	walter_visit = ""
	walter_intro_running = false
	if walter_dialog:
		walter_dialog.queue_free()
		walter_dialog = null
	for did in discovery_nodes.keys():
		discovery_nodes[did].queue_free()
	discovery_nodes.clear()
	for did in prog.story["found"]:
		if not prog.story["read"].get(did, false):
			_spawn_discovery(did, str(prog.story.get("found_at", prog.cfg.get("starting_formations", ["stone_mountain"])[0])))
	player.tool_view.equip(prog.model_tier(), true)
	_refresh_workbench()
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
	_relocate_pit_vehicles()
	_ensure_opening()
	_rebake_nav()
	var p: Array = state.player_position
	# the quarry has floors below ground level: keep the saved height (a terrace at y -7 is not lifted to the surface), then make
	# sure there really is ground under it
	player.position = Vector3(float(p[0]), float(p[1]) + 0.1, float(p[2]))
	player.rotation.y = state.player_yaw
	player.velocity = Vector3.ZERO
	_validate_loaded_position.call_deferred()
	_update_light()
	if menu != "":
		_close_menu()
	if resume_driving >= 0 and vehicle_nodes.has(resume_driving):
		enter_vehicle(vehicle_nodes[resume_driving])
	_notify("Loaded quarry progress" + (" - your old quarry has grown: three huge formations replace the small rocks." if legacy else ""))
	if hud:
		hud.shown_money = float(state.money)
		hud.refresh_panels()

## An old-world save (the pre-dug pit) has machines parked where the new quarry is solid or has a different shape: they are moved to the garage row
## or the apron, never lost or duplicated. Only the staging lane and the ramp keep what stands on them.
func _relocate_pit_vehicles() -> void:
	if pit_zone == null or not prog.migrated_filled:
		return
	prog.migrated_filled = false
	for v in vehicle_nodes.values():
		var l: Vector3 = pit_zone.to_loc(v.global_position)
		var in_basin: bool = absf(l.x) <= pit_zone.basin_w * 0.5 + 2.0 and l.z <= pit_zone.basin_zs() and l.z >= pit_zone.basin_zn() - 2.0
		var access: bool = Rect2(-52.0, -81.0, 64.0, 14.0).has_point(Vector2(l.x, l.z)) or (absf(l.x) <= 6.0 and l.z > -70.0)
		if not in_basin or access:
			continue
		var slot = free_parking_slot(v.vtype)
		if slot == null:
			slot = free_fallback_slot(v.vtype)
		if slot == null:
			continue
		v.global_position = slot
		v.rotation.y = 0.0
		v.speed = 0.0
		v.velocity = Vector3.ZERO
		var rec := fleet.vehicle(v.vehicle_id)
		if not rec.is_empty():
			rec["position"] = [slot.x, slot.y, slot.z]
			rec["yaw"] = 0.0

## After a load: if there is no floor within 3 m below the restored position (the terrain changed, an old save, a removed machine),
## the player is put back on the last safe ground instead of falling through the world.
func _validate_loaded_position() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player == null or driving != null:
		return
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.6, 0), player.global_position + Vector3(0, -3.0, 0), 1 | 8)
	q.exclude = [player.get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		safety.rescue("loaded where there is no ground")

# ===================================================================== Phase 2

func _on_milestone(id: String) -> void:
	if hud:
		var titles := {"first_employee": ["Milestone: First Employee", "Remote management (M) and +5% staff productivity"], "mechanized": ["Milestone: Mechanized Quarry", "Conveyor belts and the front loader unlocked"], "automated": ["Milestone: Automated Business", "The east expansion is open"]}
		var t: Array = titles.get(id, [id, ""])
		hud.toast(str(t[0]), str(t[1]), "milestone")
		_sfx_unlock()
	match id:
		"first_employee": _notify("Milestone: First Employee - remote management (M) and +5% productivity unlocked")
		"mechanized": _notify("Milestone: Mechanized Quarry - conveyor belts unlocked on the office computer")
		"automated":
			_notify("Milestone: Automated Business - the east quarry expansion is open!")
			_set_expansion(true)

func fmt_time(minutes: int) -> String:
	return "%02d:%02d" % [posmod(minutes, 1440) / 60, posmod(minutes, 60)]

func _build_phase2_area() -> void:
	if not blueprint:                        # the old east expansion: grey cliff blocks and a rockfall barrier east of the old yard. The blueprint world has no such area.
		var floor_body := _solid(world, "Expansion floor", Vector3(39,-0.25,0), Vector3(20,0.5,26), Color(0.36,0.33,0.27))
		floor_body.set_meta("ground", true)
		_solid(world, "Expansion cliff", Vector3(39,3,-14), Vector3(22,6,2), Color(0.33,0.32,0.29))
		_solid(world, "Expansion cliff", Vector3(39,3,14), Vector3(22,6,2), Color(0.34,0.32,0.29))
		_solid(world, "Expansion cliff", Vector3(50,3,0), Vector3(2,6,30), Color(0.32,0.31,0.28))
		var barrier := _solid(world, "Rockfall barrier", Vector3(29.6,2.0,0), Vector3(1.2,4.0,26), Color(0.42,0.37,0.31))
		expansion_gate.append(barrier)
	var desk := _solid(world, "Management desk", Vector3(OFFICE_POS.x, 0.5, OFFICE_POS.z + 1.4), Vector3(1.8,1.0,0.8), Color(0.30,0.20,0.12))
	desk.set_meta("kind", "office")
	_visual_box(desk, Vector3(-0.4,0.62,0), Vector3(0.5,0.24,0.06), Color(0.12,0.2,0.16))

## Shows or hides the east expansion. Locked: barrier + cliff in place, no deposits there.
func _set_expansion(unlocked: bool) -> void:
	if blueprint:
		return                               # no east expansion in the blueprint world (the quarry itself is the expansion)
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
		if body is QuarryFormation and str(prog.fdef(body.fid).get("frame", "")) == "pit":
			continue # the pit's benches are baked by the pit zone's own region (and lie outside this baking box)
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
	mesh.filter_baking_aabb = AABB(Vector3(-30,-6,-30), Vector3(82,14,60)) if not blueprint else AABB(Vector3(-50,-6,-30), Vector3(102,14,62))
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

## Where off-duty workers leave the site and come back to work: the service gate (there is no break area any more).
func break_spot(slot: int) -> Vector3:
	if blueprint:
		var g := QuarryDelivery.gate_for(true)
		return Vector3(g.x - 0.9 * float(clampi(slot, 0, 3) / 3), 0, g.z + 0.9 * float(clampi(slot, 0, 3) % 3 - 1))
	return Vector3(0.5 + 0.9 * float(clampi(slot, 0, 3) % 3 - 1), 0, QuarryDelivery.GATE.z - 0.9 * float(clampi(slot, 0, 3) / 3))

## Standing area for a workplace endpoint: centre, radius of reachable ring, preferred side.
func workplace(ep: Dictionary) -> Dictionary:
	match str(ep.get("type", "")):
		"storage": return {"pos": business.storage_pos, "radius": 2.1, "face": Vector3(-0.3,0,-1)}
		"sell": return {"pos": Vector3(SELL_ANCHOR.x, 0, SELL_ANCHOR.z), "radius": 2.0, "face": Vector3(0,0,1)}
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
		if not prog.crew_can_mine(res) or prog.formation_locked(kind) != "":
			continue # staff carry company tools: nothing harder than the best owned tool; locked faces stay closed
		var p: Vector3 = deposit_nodes[kind].global_position
		if formation_nodes.has(kind):
			var col := prog.nearest_column(kind, from, true, INF, "crew")
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
	prog.area_add(prog.area_of_formation(str(piece.get_meta("deposit", ""))), "recovered", 1)
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

func _conveyor_visual(parent: Node3D, transparent := false, belt := "straight") -> void:
	if art:
		if belt == "straight":
			art.conveyor_model(parent, 0.0)
		else:
			art.conveyor_corner_model(parent, 0.0, belt)
		if transparent:
			for child in parent.find_children("*", "MeshInstance3D", true, false):
				child.transparency = 0.0
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
	var variant := str(data.get("variant", "output"))
	var size := Vector3(1.4, 1.1, 1.4) if variant == "output" else (Vector3(1.4, 1.2, 1.4) if variant == "hopper" else Vector3(1.55, 1.0, 0.95))
	var body := _solid(world,{"output": "Output storage", "hopper": "Small hopper", "sorter": "Sorting table"}[variant],Vector3(p.x,p.y+size.y*0.5,p.z),size,Color(0.24,0.30,0.22),float(data["yaw"]))
	body.set_meta("ground_y", p.y)
	body.set_meta("kind","output")
	body.set_meta("variant", variant)
	body.set_meta("index",index)
	_visual_box(body,Vector3(0,0.57,0),Vector3(1.5,0.08,1.5),Color(0.40,0.36,0.22))
	var fill := _visual_box(body,Vector3(0,0.3,0),Vector3(1.2,0.5,1.2),Color(0.75,0.73,0.66))
	body.set_meta("fill", fill)
	if art:
		match variant:
			"hopper": art.dress_hopper(body)
			"sorter": art.dress_sorter(body)
			_: art.dress_output(body)
	output_nodes.append(body)

func _create_conveyor(index: int) -> void:
	var data: Dictionary = business.conveyors[index]
	var p := Business.v3(data["position"])
	# Phase 3: a low belt on its own collision layer (16). People step over it; vehicles,
	# placement and interaction still see it. Small supports mark the crossing points.
	var bk := str(data.get("kind", "straight"))
	var body := _solid(world,"Conveyor",Vector3(p.x,p.y+0.13,p.z),Vector3(0.9,0.26,2.0),Color(0.16,0.17,0.18),float(data["yaw"]))
	body.set_meta("ground_y", p.y)
	body.collision_layer = 16
	body.set_meta("kind","conveyor")
	body.set_meta("belt_kind", bk)
	body.set_meta("index",index)
	if bk != "straight":
		# an L: one box under each half (entry half behind the centre, exit half out to the side)
		var sgn := -1.0 if bk == "left" else 1.0
		for ch in body.get_children():
			if ch is CollisionShape3D:
				(ch.shape as BoxShape3D).size = Vector3(0.9, 0.26, 1.0)
				ch.position = Vector3(0, 0, 0.5)
		var cs2 := CollisionShape3D.new()
		var bx2 := BoxShape3D.new()
		bx2.size = Vector3(1.0, 0.26, 0.9)
		cs2.shape = bx2
		cs2.position = Vector3(sgn * 0.5, 0, 0)
		body.add_child(cs2)
	_visual_box(body,Vector3(0,0.14,0),Vector3(0.7,0.04,2.0 if bk == "straight" else 0.7),Color(0.07,0.07,0.07))
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
	# status lamp on a post beside the entry end: green carrying, amber blocked, red disconnected, dim idle
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.07
	lm.height = 0.14
	lm.radial_segments = 8
	lm.rings = 4
	lamp.mesh = lm
	lamp.material_override = StandardMaterial3D.new()
	lamp.position = Vector3(0.5, 0.2, 0.85)
	body.add_child(lamp)
	body.set_meta("lamp", lamp)
	conveyor_nodes.append(body)

## Cheap per-frame visuals: belt items slide along, output storages show their fill level.
## The heap in a bin or crate shows what is really inside: the dominant material's own rock material (coal is charcoal,
## iron rusty brown, copper orange, gold gold, stone grey), and a small floating label lists the contents when it
## changes. Nothing here depends on which kind of container it is.
func _style_fill(host: Node3D, fill: MeshInstance3D, items: Dictionary, label_y: float) -> void:
	var best := ""
	var best_n := 0
	var parts := []
	for res in items:
		var n := int(items[res])
		if n > 0:
			parts.append("%s %d" % [prog.display(str(res)), n])
			if n > best_n:
				best_n = n
				best = str(res)
	var key := best + "|" + ",".join(parts)
	if str(host.get_meta("fill_key", "")) == key:
		return
	host.set_meta("fill_key", key)
	if best != "":
		fill.material_override = MeshKit.mat(QuarryArt.ROCK_MAT.get(best, "RockLimestone"))
	var lbl: Label3D = host.get_meta("fill_label") if host.has_meta("fill_label") else null
	if lbl == null:
		lbl = Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.pixel_size = 0.0035
		lbl.font_size = 40
		lbl.outline_size = 10
		lbl.modulate = Color(1, 0.95, 0.8)
		lbl.position = Vector3(0, label_y, 0)
		lbl.no_depth_test = false
		lbl.visibility_range_end = 14.0
		host.add_child(lbl)
		host.set_meta("fill_label", lbl)
	lbl.text = "\n".join(parts)
	lbl.visible = not parts.is_empty()

func _update_structures() -> void:
	for i in range(mini(conveyor_nodes.size(), business.conveyors.size())):
		var c: Dictionary = business.conveyors[i]
		var items: Array = conveyor_nodes[i].get_meta("items")
		var n := int(c["items"])
		for k in range(items.size()):
			var item: MeshInstance3D = items[k]
			item.visible = k < n
			if item.visible:
				var zi := minf(0.75, 0.75 - 1.5 * float(c["progress"]) + 0.55 * k)
				var bkind := str(c.get("kind", "straight"))
				if bkind == "straight":
					item.position.z = zi
				else:
					# along the L: back edge -> centre (1 m), then centre -> the exit side (1 m)
					var d := (0.75 - zi) / 1.5 * 2.0
					var sg := -1.0 if bkind == "left" else 1.0
					item.position.x = 0.0 if d < 1.0 else sg * (d - 1.0)
					item.position.z = 1.0 - d if d < 1.0 else 0.0
				item.material_override = _mat(WorkerScript.RESOURCE_COLORS.get(str(c["resource"]), Color.GRAY))
	if storage_body.has_meta("fill"):
		_style_fill(storage_body, storage_body.get_meta("fill"), state.storage, 0.95)
		var sf: MeshInstance3D = storage_body.get_meta("fill")
		var sratio := float(state.total(state.storage)) / float(maxi(1, state.storage_capacity()))
		sf.visible = sratio > 0.0
		sf.scale.y = maxf(0.08, sratio)
		sf.position.y = -0.5                           # on the crate floor, heaping up inside the walls
	for i in range(mini(output_nodes.size(), business.outputs.size())):
		var fill: MeshInstance3D = output_nodes[i].get_meta("fill")
		_style_fill(output_nodes[i], fill, business.outputs[i]["items"], 0.82)
		var ratio := float(business.output_total(i)) / float(business.output_capacity_of(i))
		fill.visible = ratio > 0.0
		fill.scale.y = maxf(0.05, ratio)
		fill.position.y = float(output_nodes[i].get_meta("fill_y", -0.04))   # on the bin floor, heaping up inside the walls (not under the hopper)

## Magnetic placement for belts (grid snap on): within 2.6 m of a machine port or the end of another belt, the
## ghost jumps to the spot where its end touches the machine and faces along the flow, so it links with no
## fiddling. Returns {"pos", "yaw"} or {} when nothing is near. Press G to place freely.
func conveyor_snap(at: Vector3, kind := "straight") -> Dictionary:
	var best := {}
	var best_d := 2.6
	var cands := []
	# Port based candidates (all belt kinds): a new piece starts where a source port leaves, or ends where a destination
	# port takes material in. Corners turn 90 degrees to the right or left of the flow, so a corner snapped onto a
	# straight belt, a crusher, a storage or another corner always lines up end to end.
	for port in belt_ports():
		if kind == "straight" and str(port.get("src", "")) in ["crusher", "output"]:
			continue   # straight belts keep their established machine snap spots (below)
		var pd: Vector3 = port["dir"]
		var pp: Vector3 = port["pos"]
		var yd := atan2(-pd.x, -pd.z)
		if str(port["io"]) == "out":
			cands.append({"pos": pp + pd, "yaw": yd})
		else:
			if kind == "straight":
				cands.append({"pos": pp - pd, "yaw": yd})
			elif kind == "left":
				cands.append({"pos": pp - pd, "yaw": yd - PI * 0.5})
			else:
				cands.append({"pos": pp - pd, "yaw": yd + PI * 0.5})
	if kind != "straight":
		return _pick_belt_snap(at, cands, kind)
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
	for k in range(4):
		var yk := float(k) * PI * 0.5
		cands.append({"pos": business.storage_pos * Vector3(1, 0, 1) - Business.forward(yk) * 2.0, "yaw": yk})   # delivers into the storage crate
		cands.append({"pos": business.storage_pos * Vector3(1, 0, 1) + Business.forward(yk) * 2.0, "yaw": yk})   # carries away from it
		for ri in range(prog.rigs.size()):
			cands.append({"pos": prog.rig_bin_pos(prog.rigs[ri]) * Vector3(1, 0, 1) + Business.forward(yk) * 1.0, "yaw": yk})   # takes from a rig's bin
	for j in range(business.conveyors.size()):
		var cp: Vector3 = Business.v3(business.conveyors[j]["position"]) * Vector3(1, 0, 1)
		var yj := float(business.conveyors[j]["yaw"])
		cands.append({"pos": cp + Business.forward(yj) * 2.0, "yaw": yj})
		cands.append({"pos": cp - Business.forward(yj) * 2.0, "yaw": yj})
	return _pick_belt_snap(at, cands, kind)

func _pick_belt_snap(at: Vector3, cands: Array, kind: String) -> Dictionary:
	var best := {}
	var best_d := 2.6
	for cd in cands:
		var d := Vector2(at.x, at.z).distance_to(Vector2(cd["pos"].x, cd["pos"].z))
		if d < best_d and conveyor_valid(Vector3(cd["pos"].x, at.y, cd["pos"].z), float(cd["yaw"]), kind):
			best_d = d
			best = cd
	return best

## Every place a belt piece can start or end: machine ports, storage sides and the free ends of existing belts.
## {"pos": where the belt end sits, "dir": the direction material flows there, "io": "out" (a belt may start here) or
## "in" (a belt may end here)}.
func belt_ports() -> Array:
	var ports := []
	for i in range(state.crushers.size()):
		var c: Vector3 = Business.v3(state.crushers[i]["position"]) * Vector3(1, 0, 1)
		var f := Business.forward(float(state.crushers[i]["yaw"]))
		ports.append({"pos": c + f * 1.15, "dir": f, "io": "out", "src": "crusher"})
		ports.append({"pos": c - f * 1.15, "dir": f, "io": "in", "src": "crusher"})
	for o in business.outputs:
		var op: Vector3 = Business.v3(o["position"]) * Vector3(1, 0, 1)
		for k in range(4):
			var d := Business.forward(float(k) * PI * 0.5)
			ports.append({"pos": op - d * 0.9, "dir": d, "io": "in", "src": "output"})
	var sp: Vector3 = business.storage_pos * Vector3(1, 0, 1)
	for k in range(4):
		var d2 := Business.forward(float(k) * PI * 0.5)
		ports.append({"pos": sp - d2 * 1.2, "dir": d2, "io": "in"})
		ports.append({"pos": sp + d2 * 1.2, "dir": d2, "io": "out"})
	for r in prog.rigs:
		for k in range(4):
			var d3 := Business.forward(float(k) * PI * 0.5)
			ports.append({"pos": prog.rig_bin_pos(r) * Vector3(1, 0, 1) + d3 * 0.9, "dir": d3, "io": "out"})
	for j in range(business.conveyors.size()):
		var cj: Dictionary = business.conveyors[j]
		var kj := str(cj.get("kind", "straight"))
		var ends := business.conveyor_ends(Business.v3(cj["position"]), float(cj["yaw"]), kj)
		var link: Dictionary = business.links[j] if j < business.links.size() else {}
		if link.get("dst", {}).is_empty():
			ports.append({"pos": ends[1], "dir": Business.belt_out_dir(float(cj["yaw"]), kj), "io": "out"})
		if link.get("src", {}).is_empty():
			ports.append({"pos": ends[0], "dir": Business.forward(float(cj["yaw"])), "io": "in"})
	return ports

## Magnetic placement for crushers and output storages: next to a belt end, a crusher chute or an output, the ghost
## jumps to the spot where the ports meet, facing along the flow, so the machine is connected the moment it is placed.
## Returns {"pos", "yaw", "note"} or {} when nothing is near (or the connecting spot is blocked).
func machine_snap(kind: String, at: Vector3) -> Dictionary:
	var adv := kind == "advanced_crusher"
	var cands := []
	for j in range(business.conveyors.size()):
		var cp: Vector3 = Business.v3(business.conveyors[j]["position"]) * Vector3(1, 0, 1)
		var yj := float(business.conveyors[j]["yaw"])
		var fj := Business.forward(yj)
		var link: Dictionary = business.links[j] if j < business.links.size() else {}
		if kind == "output":
			if link.get("dst", {}).is_empty():
				cands.append({"pos": cp + fj * 1.75, "yaw": yj, "note": "end of conveyor #%d" % (j + 1)})
		else:
			if link.get("dst", {}).is_empty():
				cands.append({"pos": cp + fj * (2.2 if adv else 2.0), "yaw": yj, "note": "feeds from conveyor #%d" % (j + 1)})
			if link.get("src", {}).is_empty():
				cands.append({"pos": cp - fj * (2.2 if adv else 2.0), "yaw": yj, "note": "its chute starts conveyor #%d" % (j + 1)})
	if kind == "output":
		for i in range(state.crushers.size()):
			var c: Vector3 = Business.v3(state.crushers[i]["position"]) * Vector3(1, 0, 1)
			var yc := float(state.crushers[i]["yaw"])
			cands.append({"pos": c + Business.forward(yc) * (2.8 if int(state.crushers[i].get("tier", 1)) >= 2 else 2.6), "yaw": yc, "note": "crusher #%d chute" % (i + 1)})
	else:
		for o in range(business.outputs.size()):
			var op: Vector3 = Business.v3(business.outputs[o]["position"]) * Vector3(1, 0, 1)
			for k in range(4):
				var yk := float(k) * PI * 0.5
				cands.append({"pos": op - Business.forward(yk) * (2.4 if adv else 2.2), "yaw": yk, "note": "its chute drops into output storage #%d" % (o + 1)})
	var best := {}
	var best_d := 3.2
	for cd in cands:
		var d := Vector2(at.x, at.z).distance_to(Vector2(cd["pos"].x, cd["pos"].z))
		var pos := Vector3(cd["pos"].x, at.y, cd["pos"].z)
		if d < best_d and placement_valid(pos, float(cd["yaw"]), false):
			best_d = d
			best = cd
	return best

func conveyor_valid(pos: Vector3, yaw: float, kind := "straight") -> bool:
	if not in_build_area(pos) or not _on_ground(pos) or _near_vehicle(pos, 2.6):
		return false
	if player and Vector2(pos.x,pos.z).distance_to(Vector2(player.global_position.x,player.global_position.z)) < 1.3:
		return false
	var fwd := Business.forward(yaw)
	var side := Vector3(fwd.z, 0, -fwd.x)
	var points := [pos, pos + fwd * 0.85, pos - fwd * 0.85, pos + side * 0.4, pos - side * 0.4]
	if kind != "straight":
		var od := Business.belt_out_dir(yaw, kind)
		points = [pos, pos - fwd * 0.85, pos + od * 0.85, pos - fwd * 0.4 + od * 0.4]
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

## Equipment parking (Phase 8.3). Bays are not fixed any more: a machine is packed into the garage row (tail toward the door,
## nose toward the apron), left to right, wherever its real footprint fits between the walls, people and the machines already
## there. When the garage row is full it goes on the apron in front of the garage, in a second row.
var PARK_X_MIN := -4.4
var PARK_X_MAX := 14.0
const GARAGE_TAIL_Z := 20.7       ## the back edge of a machine in the garage row
const APRON_TAIL_Z := 14.6        ## the back edge of a machine in the apron row

func _vehicle_extent(sz: Vector3, yaw: float) -> Vector2:
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	return Vector2(c * sz.x * 0.5 + s * sz.z * 0.5, s * sz.x * 0.5 + c * sz.z * 0.5)

## True when a machine of this footprint fits at `pos` (garage floor, nothing on it, no other machine or promised bay overlapping).
func parking_fits(pos: Vector3, sz: Vector3) -> bool:
	var half := Vector2(sz.x * 0.5 + 0.45, sz.z * 0.5 + 0.45)
	for v in vehicle_nodes.values():
		if v.has_meta("delivering"):
			continue
		var e := _vehicle_extent(v.size, v.rotation.y)
		if absf(pos.x - v.global_position.x) < half.x + e.x and absf(pos.z - v.global_position.z) < half.y + e.y:
			return false
	if delivery:
		for slot in delivery.reserved:
			var rs: Vector3 = delivery.reserved_sizes.get(slot, Vector3(2.4, 1.8, 4.8))
			var re := _vehicle_extent(rs, 0.0)
			if absf(pos.x - slot.x) < half.x + re.x and absf(pos.z - slot.z) < half.y + re.y:
				return false
	var shape := BoxShape3D.new()
	shape.size = Vector3(sz.x + 0.3, 1.8, sz.z + 0.3)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), pos + Vector3(0, 1.1, 0))
	q.collision_mask = 1 | 4 | 16        # world, people and belts; machines were checked above
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _find_parking(type: String, apron: bool) -> Variant:
	var sp: Array = fleet.spec(type)["size"]
	var sz := Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	var zc := (APRON_TAIL_Z if apron else GARAGE_TAIL_Z) - sz.z * 0.5
	var x := PARK_X_MIN + sz.x * 0.5
	while x <= PARK_X_MAX - sz.x * 0.5:
		var pos := Vector3(x, 0.05, zc)
		if parking_fits(pos, sz):
			return pos
		x += 0.5
	return null

## First place in the garage row for this machine type (null when it is full).
func free_parking_slot(type := "loader") -> Variant:
	return _find_parking(type, false)

## Overflow: a place on the apron in front of the garage.
func free_fallback_slot(type := "loader") -> Variant:
	return _find_parking(type, true)

func enter_vehicle(v: QuarryVehicle) -> void:
	release_cart()
	if v != null and v.vtype == "starter_excavator" and not prog.excavator_ready():
		_use_starter(v)               # still broken: say what is missing (or fit the carried part)
		return
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

# ------------------------------------------------------------------ Phase 10.3: survey mode

var survey_on := false
var survey_root: Node3D

## N toggles the survey: every buried mineral pocket of a benched formation lights up through the rock (colour = mineral).
func set_survey(on: bool) -> void:
	survey_on = on
	_survey_refresh()
	_notify("Survey mode on: mineral pockets glow through the rock. N to switch off." if on else "Survey mode off")

func _survey_refresh() -> void:
	if survey_root != null and is_instance_valid(survey_root):
		survey_root.queue_free()
	survey_root = null
	if not survey_on:
		return
	survey_root = Node3D.new()
	survey_root.name = "Survey"
	world.add_child(survey_root)
	for id in formation_nodes:
		var all := prog.veins(id)
		var node: QuarryFormation = formation_nodes[id]
		for k in range(all.size()):
			if prog.vein_taken(id, k):
				continue
			var vn: Dictionary = all[k]
			var col := int(vn["col"])
			if prog.column_units(id, col) <= 0:
				continue
			var at: Vector3 = prog.column_pos(id, col)
			at.y = node.global_position.y + (float(vn["tier"]) + 0.5) * node.tier_h
			var c: Color = QuarryTheme.RES_COLORS.get(str(vn["res"]), Color.WHITE)
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 1.6
			m.no_depth_test = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.28
			sm.height = 0.56
			sm.radial_segments = 6
			sm.rings = 3
			mi.mesh = sm
			mi.material_override = m
			mi.position = at
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			survey_root.add_child(mi)
			var lb := Label3D.new()
			lb.text = "%s +%d" % [prog.display(str(vn["res"])).to_upper(), int(vn["units"])]
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.no_depth_test = true
			lb.font_size = 26
			lb.pixel_size = 0.008
			lb.outline_size = 8
			lb.modulate = c
			lb.position = Vector3(0, 0.6, 0)
			lb.visibility_range_end = 30.0
			mi.add_child(lb)

func _driving_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not touch_mode:
		driving.rotate_camera(event.screen_relative * QuarryPlayer.MOUSE_LOOK_SCALE)
		return true
	if event.is_action_pressed("interact"):
		exit_vehicle()
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if driving.vkind == "excavator" and (not excavator_target(driving).is_empty() or soil_target(driving) >= 0):
				driving.digging = true            # held: dig the rock in reach (see _excavator_dig)
				driving.bucket_target = 0.0
			elif driving.has_bucket():
				loader_primary(driving)
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			vehicle_dump(driving)
			return true
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		driving.digging = false
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_N:
			set_survey(not survey_on)
			return true
		if event.physical_keycode == KEY_R:
			driving.recover()
			_notify("Vehicle recovered to its last clear position")
			return true
		if event.physical_keycode == KEY_B:
			return true
	return false

## Horizontal distance between two points, but only when they are on the same level (within `dy` metres of height): material on
## another terrace is not "close", whatever its x and z are. INF otherwise.
func _flat_dist(a: Vector3, b: Vector3, dy := 2.4) -> float:
	if absf(a.y - b.y) > dy:
		return INF
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _nearest_pile(point: Vector3, radius: float) -> String:
	var best := ""
	var best_d := radius
	for id in pile_nodes:
		if not fleet.pile_active(id):
			continue
		var d := _flat_dist(point, pile_nodes[id].global_position)
		if d < best_d:
			best_d = d
			best = id
	return best

## Contextual left click: a lowered bucket scoops (pile first, then loose pieces) and lifts;
## a raised bucket lowers.
func loader_primary(v: QuarryVehicle) -> int:
	var rec := fleet.vehicle(v.vehicle_id)
	if v.bucket_target > 0.5:
		v.bucket_target = 0.0
		_notify("Bucket lowered - drive into a rubble pile and press left click to scoop.")
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
		if fleet.space(rec) > 0 and got == 0 and prog.rig_bin_total(r) > 0 and _flat_dist(point, bp) < 2.6:
			var res := prog.rig_resource(r)
			var n := fleet.add_cargo(rec, res, prog.rig_bin_total(r), prog.area_of_formation(str(r["formation"])))
			prog.rig_take(r, res, n)
			got += n
			source = "the rig's output bin"
	if fleet.space(rec) > 0:
		var near := []
		for id in ground_pieces:
			var body: Node3D = ground_pieces[id]
			if not body.is_queued_for_deletion() and _flat_dist(point, body.global_position) < 2.6:
				near.append(id)
		for id in near:
			if fleet.space(rec) <= 0:
				break
			var body: Node3D = ground_pieces[id]
			if fleet.add_cargo(rec, str(body.get_meta("resource")), 1, prog.area_of_formation(str(body.get_meta("deposit", "")))) == 1:
				prog.area_add(prog.area_of_formation(str(body.get_meta("deposit", ""))), "recovered", 1)
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
		_notify("Bucket is full - dump it into a truck, crusher hopper or the storage crate (right click).")
	else:
		_notify("Nothing to scoop here. Lower the bucket at a rubble pile or loose rock.")
	return got

## The exposed rock an excavator can dig from where it stands: {"kind", "col", "res", "node"} or {}.
func excavator_target(v: QuarryVehicle) -> Dictionary:
	var s: Dictionary = fleet.spec(v.vtype)
	var reach := float(s.get("dig_reach", 4.0))
	var wp := v.work_point()
	var best := {}
	var best_d := reach
	for id in formation_nodes:
		if prog.formation_locked(id) != "":
			continue
		var c := prog.nearest_column(id, wp, true, reach, "excavator")
		if c < 0:
			continue
		var d := prog.column_pos(id, c).distance_to(wp)
		if d < best_d:
			best_d = d
			best = {"kind": id, "col": c, "res": str(state.deposits[id]["resource"]), "node": formation_nodes[id]}
	return best

## One frame of digging: the excavator's dps goes into the same extraction rules as every other tool (hardness, exposure,
## locked levels, nothing under anyone's feet). Rock goes into the bucket; what does not fit drops beside the column.
## The soil cell the bucket can reach (-1 when there is none).
func soil_target(v: QuarryVehicle) -> int:
	if soil == null or not is_instance_valid(soil):
		return -1
	return soil.nearest_cell(v.work_point(), float(fleet.spec(v.vtype).get("dig_reach", 4.0)))

var _soil_progress := {}

## One frame of digging soil: the damage becomes whole units, taken from the cell only as far as the bucket has room. What
## the bucket holds is real cargo (it can be dumped into a truck or on the spoil heap).
func _dig_soil(v: QuarryVehicle, delta: float) -> bool:
	var i := soil_target(v)
	if i < 0:
		return false
	var s: Dictionary = fleet.spec(v.vtype)
	var rec := fleet.vehicle(v.vehicle_id)
	if fleet.space(rec) <= 0:
		v.digging = false
		_notify("The bucket is full. Right click to dump it into a truck or on the spoil heap.")
		return true
	var acc := float(_soil_progress.get(v.vehicle_id, 0.0)) + float(s.get("dig_dps", 10.0)) * delta / float(prog.cfg["soil"].get("hp", 3.0))
	var n := mini(int(floor(acc)), fleet.space(rec))
	acc -= float(n)
	_soil_progress[v.vehicle_id] = minf(acc, 0.99)
	if n > 0:
		var took := soil.remove(i, n)
		prog.area_add(prog.area_for_point(soil.cell_center(i)), "soil_removed", took)
		fleet.add_cargo(rec, "soil", took)
		soil.refresh()
		soil_sync_state()
		nav_dirty = true                 # the walkable surface changed: workers must not path over the soil that was just removed
		fx.impact(soil.cell_center(i) + Vector3(0, 0.3, 0), "limestone", 0.8)
		_sfx_at("hit_pick", soil.cell_center(i), -6.0)
	return true

func _excavator_dig(v: QuarryVehicle, delta: float) -> void:
	var s: Dictionary = fleet.spec(v.vtype)
	power_feedback_t = maxf(0.0, power_feedback_t - delta)
	var t := excavator_target(v)
	if t.is_empty():
		if _dig_soil(v, delta):
			return
		v.digging = false
		return
	if prog.material(str(t["res"])).get("hardness", 1) > int(s.get("dig_hardness", 1)):
		v.digging = false
		_notify("The %s cannot break %s. A bigger machine or a drilling rig is needed." % [str(s["title"]).to_lower(), prog.display(str(t["res"]))])
		return
	var rec := fleet.vehicle(v.vehicle_id)
	var kind: String = t["kind"]
	var col: int = t["col"]
	var room := maxi(0, fleet.space(rec)) + maxi(0, int(prog.cfg.get("loose_piece_cap", 36)) - loose_count(kind))
	var block := prog.extraction_block(kind, col, "excavator", int(s.get("dig_hardness", 1)))
	if block != "":
		v.digging = false
		_notify(block)
		return
	var ex := prog.extract(kind, col, float(s.get("dig_dps", 10.0)) * delta, room, "excavator")
	var n := int(ex["units"])
	var node: QuarryFormation = t["node"]
	node.hit(col)
	if power_feedback_t <= 0.0:
		power_feedback_t = 0.18
		fx.impact(node.column_top(col), str(t["res"]), 0.9)
		_sfx_at("hit_pick", node.column_top(col), -3.0)
	if n > 0:
		var put := fleet.add_cargo(rec, str(t["res"]), n, prog.area_of_formation(kind))
		prog.area_add(prog.area_of_formation(kind), "recovered", put)
		for i in range(n - put):
			_spawn_formation_piece(kind, col, i)
	_vein_bonus(ex, kind, col, "bucket", rec)
	if int(ex["chunks"]) > 0:
		node.refresh()
	else:
		node.update_label()

## Phase 10.3: mineral pockets buried in a formation. When the block holding one is cut away, the pocket falls out: its
## minerals go in the bag (hand tools) or the bucket (excavator); crew and the companion leave them at the foot of the face.
func _vein_bonus(ex: Dictionary, kind: String, col: int, to: String, rec := {}) -> void:
	for vn in ex.get("veins", []):
		var r := str(vn["res"])
		var n := int(vn["units"])
		var put := 0
		if to == "player":
			put = state.add_item(r, n)
		elif to == "bucket" and not rec.is_empty():
			put = fleet.add_cargo(rec, r, n, prog.area_of_formation(kind))          # the bucket's real capacity applies; the rest lies on the ground below
		var left := n - put
		for k in range(left):
			_spawn_vein_piece(kind, col, r, k)         # nothing is lost: what does not fit becomes loose pieces of the RIGHT mineral
		if n > 0:
			hud.toast("Mineral pocket!", "+%d %s%s" % [n, prog.display(r), "" if left == 0 else " (%d on the ground)" % left], "unlock")
			fx.impact(formation_nodes[kind].column_top(col) + Vector3(0, 0.4, 0), r, 1.2)
			_sfx_unlock()
	if not ex.get("veins", []).is_empty():
		_survey_refresh()

## A loose piece of a mineral found inside a formation (a pocket's overflow): a normal pickup of THAT resource beside the column. These
## are saved with their resource (data["vein_pieces"]), so they stay coal or iron after a reload instead of turning into limestone.
var vein_pieces := {}              ## piece id -> {kind, col, res, i}
var vein_seq := 0

func _spawn_vein_piece(kind: String, col: int, res: String, i: int, pid := "") -> void:
	if pid == "":
		vein_seq += 1
		pid = "vp_%d" % vein_seq
	var base := prog.column_pos(kind, col)
	var out := prog.column_open_dir(kind, col, player.global_position if player else base + Vector3(0, 0, 5))
	var side := Vector3(out.z, 0, -out.x)
	var cell := float(prog.fdef(kind)["cell"])
	var p := base + out * (cell * 0.5 + 0.6) + side * ((float(i % 3) - 1.0) * 0.5)
	var body := _solid(world, "Loose " + res, p + Vector3(0, 0.27, 0), Vector3(0.44, 0.46, 0.42), TUNE_VEIN_COLOR.get(res, Color.GRAY), float(i))
	body.collision_layer = 2
	body.set_meta("kind", "piece")
	body.set_meta("resource", res)
	body.set_meta("deposit", kind)
	body.set_meta("piece_id", pid)
	if art:
		art.dress_piece(body, res, i)
	ground_pieces[pid] = body
	vein_pieces[pid] = {"kind": kind, "col": col, "res": res, "i": i}

const TUNE_VEIN_COLOR := {"coal": Color(0.16, 0.16, 0.18), "iron_ore": Color(0.62, 0.34, 0.24), "copper_ore": Color(0.5, 0.7, 0.55), "gold_ore": Color(0.95, 0.78, 0.25), "limestone": Color(0.8, 0.78, 0.7)}

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
		var d := _flat_dist(point, c[1])
		if d < best_d:
			best_d = d
			best = {"ep": c[0]}
	if spoil_node and is_instance_valid(spoil_node) and fleet.cargo_total(fleet.vehicle(from.vehicle_id)) > 0 and int(fleet.vehicle(from.vehicle_id)["cargo"].get("soil", 0)) > 0:
		var sr := float(prog.cfg_for("soil")["spoil"]["radius"])
		var spoil_d := _flat_dist(point, spoil_node.global_position)
		if spoil_d < sr + 1.5:
			best = {"spoil": true}
			best_d = 0.0
	if from.has_bucket():
		for other in vehicle_nodes.values():
			if other != from and other.vkind == "truck":
				var c: Vector3 = other.bed_center()
				var d := _flat_dist(point, c)
				if d < maxf(best_d, 3.2):
					best_d = d
					best = {"truck": other}
	return best

func _target_name(t: Dictionary) -> String:
	if t.has("spoil"):
		return "the spoil heap"
	if t.has("truck"):
		return "the dump truck"
	return business.describe_ep(t["ep"])

## right click: loader dumps its bucket; truck raises its bed and unloads.
func vehicle_dump(v: QuarryVehicle) -> int:
	var rec := fleet.vehicle(v.vehicle_id)
	if fleet.cargo_total(rec) <= 0:
		_notify("Nothing to unload.")
		return 0
	var t := dump_target(v.work_point(), 3.0, v)
	if t.is_empty():
		_notify("Nothing to unload into here. Get close to a storage crate, crusher, output storage%s." % (" or truck" if v.has_bucket() else ""))
		return 0
	if v.vkind == "truck":
		if v.unload_timer > 0.0:
			return 0
		v.start_unload(t)
		_notify("Raising the bed over %s..." % _target_name(t))
		return 0
	var moved := 0
	if t.has("spoil"):
		moved = _dump_soil(rec)
	elif t.has("truck"):
		moved = fleet.transfer(rec, fleet.vehicle(t["truck"].vehicle_id))       # loading a truck is not a shipment: the rock keeps its area and is counted when it is delivered
	else:
		moved = fleet.dump_to(rec, t["ep"])
		_credit_delivery(rec)
	v.dump_timer = 1.0
	if moved > 0:
		fx.chunk_break(v.work_point() + Vector3(0, 1.0, 0), "limestone")
	_notify("Dumped %d into %s.%s" % [moved, _target_name(t), (" %d left in the bucket (target full or wrong material)." % fleet.cargo_total(rec)) if fleet.cargo_total(rec) > 0 else ""])
	return moved

## A delivery to a destination (storage crate, crusher, output storage) is the only thing that counts as a shipment, and only for the units
## the destination accepted, each for the excavation area it was cut in (fleet.dump_to records them in rec["delivered"]).
func _credit_delivery(rec: Dictionary) -> void:
	var d: Dictionary = rec.get("delivered", {})
	for a in d:
		prog.area_add(str(a), "shipped", int(d[a]))
	rec.erase("delivered")

## Soil cargo goes onto the spoil heap: it leaves the vehicle and is counted (soil_dumped); nothing else is touched.
func _dump_soil(rec: Dictionary) -> int:
	var n := fleet.take_cargo(rec, "soil", int(rec["cargo"].get("soil", 0)))
	state.soil_dumped += n
	prog.area_add("area_1", "soil_hauled", n)        # all the soil on the site lies in Area 1 (the spoil heap is its dump)
	_update_spoil()
	return n

func truck_finish_unload(v: QuarryVehicle, t: Dictionary) -> int:
	var rec := fleet.vehicle(v.vehicle_id)
	if t.has("spoil"):
		var sm := _dump_soil(rec)
		_notify("Tipped %d soil onto the spoil heap." % sm)
		return sm
	if rec.is_empty() or not t.has("ep") or not business.ep_valid(t["ep"]):
		return 0
	var moved := fleet.dump_to(rec, t["ep"])
	_credit_delivery(rec)
	if moved > 0:
		fx.chunk_break(v.work_point() + Vector3(0, 0.8, 0), "limestone")
	_notify("Unloaded %d into %s.%s" % [moved, _target_name(t), (" %d stays on the truck (target full or wrong material)." % fleet.cargo_total(rec)) if fleet.cargo_total(rec) > 0 else ""])
	return moved

## Everything the vehicle plate and the prompt line need while a machine is driven: its name, speed against its top speed, load against capacity (and what
## it carries), and the one thing the buttons can do right now.
func hud_drive_info() -> Dictionary:
	if driving == null or not is_instance_valid(driving):
		return {}
	var rec := fleet.vehicle(driving.vehicle_id)
	if rec.is_empty():
		return {}
	var spec: Dictionary = fleet.spec(driving.vtype)
	var carried := ""
	var amount := 0
	for k in rec["cargo"]:
		if int(rec["cargo"][k]) > amount:
			carried = str(k)
			amount = int(rec["cargo"][k])
	var action := ""
	var point := driving.work_point()
	if driving.has_bucket():
		var pile := _nearest_pile(point, 3.0)
		if driving.bucket_target < 0.5 and pile != "":
			action = "Left click: scoop %s (%d)" % [fleet.cfg["piles"][pile]["title"], fleet.piles[pile]["amount"]]
	if fleet.cargo_total(rec) > 0:
		var t := dump_target(point, 3.0, driving)
		if not t.is_empty():
			action = "Right click: unload into " + _target_name(t)
	if driving.vkind == "excavator" and action == "":
		if not excavator_target(driving).is_empty():
			action = "Hold left click: dig %s" % prog.display(str(excavator_target(driving)["res"]))
		elif soil_target(driving) >= 0:
			action = "Hold left click: dig soil"
		else:
			action = "Mouse spins the cab  Up/Down boom  Z X stick  C V bucket  N survey"
	return {"name": str(rec.get("name", spec["title"])).to_upper(), "speed": absf(driving.speed), "max_speed": float(spec.get("max_speed", 6.0)),
		"load": fleet.cargo_total(rec), "capacity": fleet.capacity(rec), "carried": carried, "action": action, "kind": driving.vkind}

func _driving_hud() -> String:
	var rec := fleet.vehicle(driving.vehicle_id)
	var cargo := ""
	for k in rec["cargo"]:
		cargo += " %s %d" % [str(k).replace("_", " "), rec["cargo"][k]]
	var hint := ""
	var point := driving.work_point()
	if driving.has_bucket():
		var pile := _nearest_pile(point, 3.0)
		if driving.bucket_target < 0.5 and pile != "":
			hint = "  >> left click scoop %s (%d)" % [fleet.cfg["piles"][pile]["title"], fleet.piles[pile]["amount"]]
	if fleet.cargo_total(rec) > 0:
		var t := dump_target(point, 3.0, driving)
		if not t.is_empty():
			hint = "  >> right click unload into " + _target_name(t)
	var load_label := "BUCKET" if driving.has_bucket() else "BED"
	var lmb := ""
	if driving.vkind == "loader":
		lmb = "Left click bucket %s  " % ("down" if driving.bucket_target > 0.5 else "up/scoop")
	elif driving.vkind == "excavator":
		lmb = "HOLD LEFT CLICK dig  "
		if not excavator_target(driving).is_empty():
			hint = "  >> HOLD LEFT CLICK dig %s" % prog.display(str(excavator_target(driving)["res"]))
		elif soil_target(driving) >= 0:
			hint = "  >> HOLD LEFT CLICK dig soil"
		else:
			hint = "  WASD tracks  MOUSE spins the cab  UP/DOWN boom  Z X stick  C V bucket  N survey"
	var controls := "WASD drive  Mouse look  %sright click %s  Space brake  R recover  E exit" % [lmb, "dump bucket" if driving.has_bucket() else "raise bed / unload"]
	return "%s  %.1f m/s   %s %d/%d%s%s" % [str(rec.get("name", fleet.spec(driving.vtype)["title"])).to_upper(), absf(driving.speed), load_label, fleet.cargo_total(rec), fleet.capacity(rec), cargo, hint]

## The survey crew cuts a level's access road (ramp and floor roads) for a fee. Returns the message for the office screen.
func ui_buy_road(n: int) -> String:
	var reason := prog.road_block_reason(n)
	if reason != "":
		return reason
	var cost := prog.road_cost(n)
	if not prog.buy_road(n):
		return "The crew could not start the road."
	return "The crew has cut the level %d access road ($%d). Trucks and excavators can drive down." % [n, cost]

func ui_buy_vehicle(type: String) -> String:
	if not prog.unlocked(type):
		return "The %s unlocks at the %s stage" % [fleet.spec(type)["title"], prog.feature_stage_title(type)]
	var reason := fleet.buy_block_reason(type)
	if reason != "":
		return reason
	var slot = free_parking_slot(type)
	var fallback := false
	if slot == null:
		slot = free_fallback_slot(type)
		fallback = true
		if slot == null:
			return "Equipment parking is blocked - the %s will not fit in the garage or on the apron. Drive another machine out of the way first." % fleet.spec(type)["title"]
	var rec := fleet.buy(type, slot, 0.0)
	_sync_vehicles()
	nav_dirty = true
	if delivery and not rec.is_empty() and delivery.start(int(rec["id"]), slot, fallback):
		if fallback:
			hud.toast("Garage is full", "The %s will be parked on the apron in front of it." % fleet.spec(type)["title"], "info")
			return "%s is being driven in and will be parked on the apron in front of the garage." % fleet.spec(type)["title"]
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
		return "Storage crate  |  left click move  (the main crate cannot be sold)  |  B exit"
	var n := business.contents_total(business.structure_contents(kind, index))
	return "%s%s  |  left click move  |  X sell (+$%d refund)  |  B exit" % [_structure_name(kind, index), (" holding %d items" % n) if n > 0 else "", business.refund_value(kind, index)]

func start_relocation(kind: String, index: int) -> bool:
	var node := _structure_node(kind, index)
	if node == null or placement:
		return false
	relocating = {"kind": kind, "index": index, "layer": node.collision_layer}
	if kind == "conveyor":
		placement_belt = str(business.conveyors[index].get("kind", "straight"))
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
		"conveyor": _conveyor_visual(ghost, true, str(business.conveyors[index].get("kind", "straight")))
		"storage":
			if art:
				art.storage_model(ghost, 0.0)
			else:
				_visual_box(ghost, Vector3(0,0.65,0), Vector3(2,1.3,1.6), Color(0.33,0.23,0.13))
	_notify("Moving %s. left click confirm, R rotate, Esc cancel (stays where it was)." % _structure_name(kind, index))
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
			_vein_bonus({"veins": ev.get("veins", [])}, id, int(ev["column"]), "ground")      # the rig's pockets lie beside the face
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
	if music:
		music.duck()                                  # the jingle sits on top of the music for a moment

# ------------------------------------------------------------------ Phase 7.5: Walter (alive, retiring, visiting)

var walter_node: Node3D
var walter_dialog: QuarryWalterDialog
var walter_visit := ""        ## visit id Walter has come for ("" while he is not around)
var walter_intro_running := false
var walter_mode := ""         ## "", "arriving", "waiting", "leaving"
var walter_wave_t := 0.0      ## seconds left of his farewell wave before he starts to walk off
var walter_pose := "idle"
var walter_path: PackedVector3Array = PackedVector3Array()
var walter_path_i := 0
var walter_goal := Vector3.ZERO
var walter_speed := 1.7
var truck_node: Node3D
var cine_tweens: Array = []
var cine_keys: Node3D

func walter_pos() -> Vector3:
	var p: Array = prog.walter_cfg().get("pos", [-4.2, 0, 5.2])
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

## Walter's old truck, parked at the edge of the yard for good.
func _build_truck() -> void:
	if truck_node != null:
		return
	_build_dino_bed()
	var t: Dictionary = prog.walter_cfg().get("truck", {})
	var p: Array = t.get("pos", [-8.6, 0, 4.8])
	var root := StaticBody3D.new()
	root.name = "WaltersTruck"
	root.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	root.rotation.y = float(t.get("yaw", 1.5708))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 1.6, 4.4)
	cs.shape = sh
	cs.position.y = 0.9
	root.add_child(cs)
	# the game's own dump-truck model, small and weathered: cab, tipping bed and six wheels, all properly joined
	var pv := QuarryPreview.PreviewVehicle.new()
	pv.paint_cab = "PaintRed"
	pv.paint_bed = "PaintRed"
	pv.model_root = Node3D.new()
	pv.add_child(pv.model_root)
	pv.model_root.scale = Vector3(1.9 / 2.2, 1.7 / 1.8, 4.0 / 4.6)
	VehicleModels.truck(pv)
	truck_wheels = pv.wheels
	root.add_child(pv)
	world.add_child(root)
	truck_node = root

## Walter (or Dr. Marsh): their own character model. Anyone can talk to him with E while he waits.
func _spawn_walter(at := Vector3.INF, face_to := Vector3.ZERO, npc := "walter") -> void:
	if walter_node != null and is_instance_valid(walter_node):
		return
	var root := StaticBody3D.new()
	root.name = "Walter"
	root.position = walter_pos() if at == Vector3.INF else at
	root.set_meta("kind", "walter")
	root.collision_layer = 32            # seen by the look-at ray, never an obstacle for people or vehicles
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	root.add_child(cs)
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	# their own models (tools/character_cast): Walter's flat cap, glasses, moustache, flannel and stoop are modelled in
	var body: Node3D = (load("res://assets/characters/CHR_QD_Marsh.glb" if npc == "marsh" else "res://assets/characters/CHR_QD_Walter.glb") as PackedScene).instantiate()
	model.add_child(body)
	for gi in body.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var found := body.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		var r := VeilRig.new()
		r.setup(found[0], 3.3)
		r.elder = npc == "walter"          # Grandpa: stooped, a careful limping step, fidgets while he waits
		root.set_meta("rig", r)
	world.add_child(root)
	walter_node = root
	walter_pose = "idle"
	if face_to != Vector3.ZERO:
		root.rotation.y = atan2(-(face_to.x - root.position.x), -(face_to.z - root.position.z))

## Phase 10: Walter's old truck does not sit in the yard for good. When Walter leaves he walks to it, climbs in and drives
## out along the open lane to the service gate (the garage door rolls up for it), then on through the tunnel and away.
var truck_route: Array = []
var truck_wheels: Array = []       ## the old truck's wheel pivots: they turn with the distance it drives
var truck_driving := false

func _truck_depart() -> void:
	if truck_node == null or not is_instance_valid(truck_node):
		return
	var t := truck_node
	var p := t.global_position
	var lane_clear := true
	for v in vehicle_nodes.values():
		if v.global_position.x > -2.5 and v.global_position.x < 3.5 and v.global_position.z > 5.0 and v.global_position.z < 26.0:
			lane_clear = false
	if not lane_clear:
		_truck_leaves(true)      # something is parked in the lane: it is simply gone by the next frame
		return
	t.collision_layer = 0
	if blueprint:
		# out of the yard: west along the open lane north of the garage, down the west side to the service lane, through the tunnel gate
		truck_route = [Vector3(p.x, 0.0, 11.5), Vector3(-19.5, 0.0, 11.5), Vector3(-19.5, 0.0, delivery.door_c.z), Vector3(delivery.door_c.x + 1.0, 0.0, delivery.door_c.z), Vector3(-46.0, 0.0, delivery.door_c.z)]
	else:
		truck_route = [Vector3(-2.0, 0.0, p.z), Vector3(0.5, 0.0, p.z + 2.6), Vector3(0.5, 0.0, 15.0), Vector3(0.5, 0.0, 26.0), Vector3(0.5, 0.0, 43.0)]
	truck_driving = true
	delivery.passers.append(t)
	_rebake_nav()
	_sfx_at("breaker_hit", p, -8.0)

func _truck_step(delta: float) -> void:
	if not truck_driving:
		return
	if truck_node == null or not is_instance_valid(truck_node) or truck_route.is_empty():
		_truck_leaves(true)
		return
	var t := truck_node
	var goal: Vector3 = truck_route[0]
	var to := goal - t.global_position
	to.y = 0.0
	if to.length() < 0.35:
		truck_route.pop_front()
		if truck_route.is_empty():
			_truck_leaves(true)
		return
	# waits for the garage door to roll up while it is at the door
	if blueprint:
		if absf(t.global_position.x - delivery.door_c.x) < 3.5 and t.global_position.x > delivery.door_c.x - 0.5 and not delivery.is_open():
			return
	elif t.global_position.z > delivery.DOOR_Z - 4.0 and t.global_position.z < delivery.DOOR_Z + 0.5 and not delivery.is_open():
		return
	var want := atan2(-to.x, -to.z)                      # the cab leads: forward is -Z
	t.rotation.y = lerp_angle(t.rotation.y, want, clampf(delta * 3.0, 0.0, 1.0))
	var fwd := -t.global_transform.basis.z
	var speed := 2.6 if absf(angle_difference(t.rotation.y, want)) > 0.35 else 3.4
	var step := minf(speed * delta, to.length())
	t.global_position += fwd * step
	for w in truck_wheels:
		if is_instance_valid(w):
			w.rotate_x(-step / float(w.get_meta("radius", 0.5)))

func _truck_leaves(instant := false) -> void:
	if truck_node == null or not is_instance_valid(truck_node):
		truck_driving = false
		return
	delivery.passers.erase(truck_node)
	truck_node.queue_free()
	truck_node = null
	truck_driving = false
	truck_route.clear()
	_rebake_nav()

func _truck_should_be_gone() -> bool:
	if not bool(prog.story.get("intro_seen", false)):
		return false
	# a new game keeps the truck by the broken excavator until Grandpa has left with it
	if natural_start_enabled and prog.natural_start():
		return bool(prog.excavator_state().get("started", false))
	return true

func _remove_walter() -> void:
	if walter_node != null and is_instance_valid(walter_node):
		walter_node.queue_free()
	walter_node = null
	walter_mode = ""
	walter_wave_t = 0.0
	walter_path = PackedVector3Array()

## Walter walks to `goal` along the navigation mesh (a straight line while it is not ready).
func _walter_goto(goal: Vector3) -> void:
	walter_goal = goal
	var from := walter_node.global_position
	walter_path = NavigationServer3D.map_get_path(nav_map, from, goal, true) if nav_ready() else PackedVector3Array()
	if walter_path.size() < 2:
		walter_path = PackedVector3Array([from, goal])
	walter_path_i = 0

## Returns true while he is still walking.
func _walter_walk(delta: float) -> bool:
	while walter_path_i < walter_path.size():
		var wp := walter_path[walter_path_i]
		var d := Vector3(wp.x - walter_node.global_position.x, 0, wp.z - walter_node.global_position.z)
		if d.length() < 0.25:
			walter_path_i += 1
			continue
		var step := d.normalized() * minf(walter_speed * delta, d.length())
		walter_node.global_position += step
		walter_node.rotation.y = lerp_angle(walter_node.rotation.y, atan2(-d.x, -d.z), clampf(delta * 8.0, 0.0, 1.0))
		return true
	return false

func _walter_tick(delta: float) -> void:
	if walter_node == null or not is_instance_valid(walter_node):
		return
	var walking := false
	if walter_wave_t > 0.0 and (walter_mode == "leaving" or walter_mode == "to_truck"):
		walter_wave_t -= delta                      # a goodbye wave to the player before he turns and goes
		if walter_node.has_meta("rig"):
			walter_node.get_meta("rig").pose(delta, "wave", 0.0, "miner", false)
		return
	if walter_mode == "arriving" or walter_mode == "leaving" or walter_mode == "to_truck":
		walking = _walter_walk(delta)
		if not walking:
			if walter_mode == "to_truck":
				_remove_walter()
				_truck_depart()
				return
			if walter_mode == "arriving":
				walter_mode = "waiting"
				_walter_face_player()
				if hud:
					var who := str(prog.visit_def(walter_visit).get("npc_name", "Grandpa Walt"))
					hud.toast("%s is here" % who, "%s is waiting in the yard. Go and say hello (E)." % who, "milestone")
			else:
				_remove_walter()
				return
	if walter_node.has_meta("rig"):
		var st := "walk" if walking else walter_pose
		walter_node.get_meta("rig").pose(delta, st, walter_speed if walking else 0.0, "miner", false)

func _walter_face_player() -> void:
	if walter_node and player:
		var d := player.global_position - walter_node.global_position
		walter_node.rotation.y = atan2(-d.x, -d.z)

func _face_player_at(point: Vector3) -> void:
	var d := point - player.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player.pitch = 0.0
	player.camera.rotation.x = 0.0

func _cine_tween() -> Tween:
	var tw := create_tween()
	cine_tweens.append(tw)
	return tw

func _cine_stop() -> void:
	for tw in cine_tweens:
		if tw and tw.is_valid():
			tw.kill()
	cine_tweens.clear()
	if cine_keys and is_instance_valid(cine_keys):
		cine_keys.queue_free()
	cine_keys = null

## The opening scene of a new game (Part 10): the player walks up to Walter at his old truck. He retires, hands over the
## keys, and points at the hill. First person, skippable, never plays again once seen.
func _show_intro() -> void:
	if not hud or prog.story["intro_seen"]:
		return
	player.locked = true
	walter_intro_running = true
	_build_truck()
	_spawn_walter(Vector3.INF, player.global_position)
	walter_mode = "waiting"
	var start := Vector3(2.5, 0.2, 9.5)
	player.global_position = start
	var cam_look := truck_node.global_position + Vector3(0, 1.2, 0)
	_face_player_at(cam_look)
	hud.fade_to(1.0, 0.0)
	hud.fade_to(0.0, 1.6)
	# walk up to Walter while the view swings from the truck to him
	var meet := walter_pos() + Vector3(2.4, 0.2, 1.4)
	var yaw_to_walter := atan2(-(walter_pos().x - meet.x), -(walter_pos().z - meet.z))
	var tw := _cine_tween()
	tw.set_parallel(true)
	tw.tween_property(player, "global_position", meet, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "rotation:y", player.rotation.y + angle_difference(player.rotation.y, yaw_to_walter), 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walter_face_player_to(meet)
	var lines := []
	for l in prog.walter_cfg().get("cinematic", []):
		var e: Dictionary = l.duplicate()
		e["speaker"] = "YOU" if str(l["who"]) == "PLAYER" else "GRANDPA WALTER"
		lines.append(e)
	if not lines.is_empty():
		lines[0]["dur"] = float(lines[0]["dur"]) + 2.4        # the walk up happens under the first line
	_open_walter_dialog(lines, _end_walter_intro, true)
	if walter_dialog:
		walter_dialog.line_changed.connect(_cine_line)
		_cine_line(0)

func _walter_face_player_to(p: Vector3) -> void:
	if walter_node:
		var d := p - walter_node.global_position
		walter_node.rotation.y = atan2(-d.x, -d.z)

## Gestures for the line that has just started.
func _cine_line(i: int) -> void:
	var cine: Array = prog.walter_cfg().get("cinematic", [])
	if i < 0 or i >= cine.size() or walter_node == null or not is_instance_valid(walter_node):
		return
	var l: Dictionary = cine[i]
	var act := str(l.get("act", "talk"))
	var who := str(l.get("who", "WALTER"))
	walter_pose = "talk" if who == "WALTER" else "idle"
	match act:
		"keys":
			walter_pose = "offer"
			_cine_keys()
		"point":
			walter_pose = "point"
			var lk: Array = prog.walter_cfg().get("cinematic_look", [-22.3, 1.4, -10.6])
			var look := Vector3(float(lk[0]), float(lk[1]), float(lk[2]))
			var wd := look - walter_node.global_position
			var w_yaw: float = atan2(-wd.x, -wd.z)
			var pd := look - player.global_position
			var p_yaw: float = atan2(-pd.x, -pd.z)
			var tw := _cine_tween()
			tw.set_parallel(true)
			tw.tween_property(walter_node, "rotation:y", walter_node.rotation.y + angle_difference(walter_node.rotation.y, w_yaw), 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(player, "rotation:y", player.rotation.y + angle_difference(player.rotation.y, p_yaw), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(player.camera, "rotation:x", 0.14, 1.6).set_trans(Tween.TRANS_SINE)

## The keys travel from Walter's hand to the camera while the view dips to meet them.
func _cine_keys() -> void:
	if cine_keys and is_instance_valid(cine_keys):
		return
	var k := Node3D.new()
	k.name = "Keys"
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.05
	tm.outer_radius = 0.09
	ring.mesh = tm
	ring.material_override = _mat(Color(0.85, 0.75, 0.3))
	ring.rotation.x = PI / 2.0
	k.add_child(ring)
	var tag := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.16, 0.02)
	tag.mesh = bm
	tag.material_override = _mat(Color(0.7, 0.62, 0.28))
	tag.position = Vector3(0, -0.14, 0)
	k.add_child(tag)
	world.add_child(k)
	var fwd: Vector3 = -walter_node.global_transform.basis.z
	k.global_position = walter_node.global_position + Vector3(0, 1.15, 0) + fwd * 0.55
	cine_keys = k
	var target := player.camera.global_position + (-player.camera.global_transform.basis.z) * 0.45 + Vector3(0, -0.25, 0)
	var tw := _cine_tween()
	tw.set_parallel(true)
	tw.tween_property(k, "global_position", target, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player.camera, "rotation:x", -0.22, 1.2).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func():
		if cine_keys and is_instance_valid(cine_keys):
			cine_keys.queue_free()
		cine_keys = null
		if hud:
			hud.toast("Keys received", "Walter handed over the quarry.", "unlock"))
	tw.tween_property(player.camera, "rotation:x", 0.0, 0.9)

func _open_walter_dialog(lines: Array, on_done: Callable, timed := false) -> void:
	if walter_dialog != null or lines.is_empty():
		return
	walter_dialog = QuarryWalterDialog.new()
	walter_dialog.setup(lines, timed)
	ui.add_child(walter_dialog)
	walter_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	walter_dialog.offset_bottom = -150.0
	walter_dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	walter_dialog.finished.connect(func(skipped: bool):
		var d := walter_dialog
		walter_dialog = null
		if d:
			d.queue_free()
		on_done.call(skipped))
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _end_walter_intro(_skipped: bool) -> void:
	_cine_stop()
	walter_intro_running = false
	walter_pose = "idle"
	prog.journal_add("handover")
	# the camera comes back to the player smoothly
	var tw := create_tween()
	tw.tween_property(player.camera, "rotation:x", 0.0, 0.6)
	var st: Dictionary = prog.cfg.get("story", {})
	if str(st.get("intro2", "")) != "":
		hud.show_card(str(st.get("intro2_title", "YOUR FIRST DAY")), str(st.get("intro2", "")), func(): _finish_intro())
	else:
		_finish_intro()

func _finish_intro() -> void:
	prog.story["intro_seen"] = true
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if natural_start_enabled and prog.natural_start() and not bool(prog.excavator_state()["started"]):
		_grandpa_to_post()   # Phase 10: he waits by the broken excavator and helps once it is repaired
	else:
		_walter_leave()           # he walks off to the road; he comes back for visits

func _walter_leave() -> void:
	if walter_node == null or not is_instance_valid(walter_node):
		return
	walter_pose = "idle"
	walter_wave_t = 2.0 if player != null and player.global_position.distance_to(walter_node.global_position) < 14.0 else 0.0
	if walter_wave_t > 0.0:
		_walter_face_player()
	if truck_node != null and is_instance_valid(truck_node) and not truck_driving:
		# he leaves the way he came: over to the truck, in, and off down the road
		walter_mode = "to_truck"
		_walter_goto(truck_node.global_transform * Vector3(-1.7, 0.0, -0.9))
		return
	walter_mode = "leaving"
	_walter_goto(Vector3(0.5, 0.0, 25.4))

## Walter comes by in the day when something new has happened at the quarry. He walks in from the road, waits to be
## talked to, and walks away again. Never forced on the player: only a toast.
func _check_walter_visit() -> void:
	if walter_intro_running or walter_dialog != null:
		return
	var h := _hour()
	if walter_visit != "":
		if walter_mode == "waiting" and (h >= 18.0 or h < 8.0):
			_walter_leave()
		elif walter_node == null:
			walter_visit = ""
		return
	if h < 8.0 or h >= 17.0 or not player_free_for_intro():
		return
	var due := prog.due_visit()
	if due == "":
		return
	walter_visit = due
	_spawn_walter(Vector3(0.5, 0.0, 25.4), Vector3.ZERO, str(prog.visit_def(due).get("npc", "walter")))
	walter_mode = "arriving"
	_walter_goto(walter_pos())

## Smoothly turns the player's view toward a point (used by the conversations and reveals). Returns the tween.
func _turn_view_to(point: Vector3, secs := 0.5) -> Tween:
	var d := point - player.camera.global_position
	var yaw := atan2(-d.x, -d.z)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.45, 0.45)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(player, "rotation:y", player.rotation.y + angle_difference(player.rotation.y, yaw), secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player.camera, "rotation:x", pitch, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

func _talk_to_walter() -> void:
	if walter_dialog == null and walter_mode == "waiting" and walter_visit == "" and prog.natural_start() and not bool(prog.excavator_state()["started"]):
		_grandpa_hint()
		return
	if walter_visit == "" or walter_dialog != null or walter_mode != "waiting":
		return
	var v := prog.visit_def(walter_visit)
	var lines := []
	for t in v.get("lines", []):
		if t is Dictionary:
			lines.append(t)
		else:
			lines.append({"speaker": "GRANDPA WALTER", "text": str(t)})
	var id := walter_visit
	_walter_face_player()
	_turn_view_to(walter_node.global_position + Vector3(0, 1.5, 0), 0.5)
	walter_pose = "talk"
	_open_walter_dialog(lines, func(_skipped: bool):
		prog.complete_visit(id)
		walter_visit = ""
		walter_pose = "idle"
		create_tween().tween_property(player.camera, "rotation:x", 0.0, 0.4)
		player.locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_walter_leave()
		if id == "marsh_egg":
			_spawn_egg()
		elif hud:
			hud.toast("Journal updated", "Walter's journal has a new entry (press M, Milestones).", "unlock"))

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

# ------------------------------------------------------------------ Phase 7.6: the fossil

var fossil_node: Node3D
var fossil_dialog: QuarryFossilDialog
var _fossil_timer := 0.0

## Bones lying in the floor of the lowest level where the gold bench stood.
func _spawn_fossil() -> void:
	if fossil_node != null and is_instance_valid(fossil_node):
		return
	var p := prog.fossil_pos()
	var root := StaticBody3D.new()
	root.name = "Fossil"
	root.position = Vector3(p.x, p.y, p.z)
	root.set_meta("kind", "fossil")
	root.collision_layer = 32
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.4, 0.9, 1.2)
	cs.shape = sh
	cs.position.y = 0.45
	root.add_child(cs)
	var bone := _mat(Color(0.86, 0.80, 0.66))
	for i in range(7):                            # ribs and spine along the floor
		var rib := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.7 - absf(float(i) - 3.0) * 0.08, 0.12)
		rib.mesh = bm
		rib.material_override = bone
		rib.position = Vector3(-1.0 + float(i) * 0.33, 0.35, 0.0)
		rib.rotation.z = (0.35 if i % 2 == 0 else -0.35)
		root.add_child(rib)
	var spine := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(2.4, 0.14, 0.16)
	spine.mesh = sm
	spine.material_override = bone
	spine.position.y = 0.1
	root.add_child(spine)
	var skull := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.7, 0.4, 0.45)
	skull.mesh = km
	skull.material_override = bone
	skull.position = Vector3(1.4, 0.25, 0.0)
	root.add_child(skull)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.9, 0.65)
	glow.light_energy = 0.9
	glow.omni_range = 4.0
	glow.position = Vector3(0, 1.2, 0)
	root.add_child(glow)
	world.add_child(root)
	fossil_node = root

func _remove_fossil() -> void:
	if fossil_node != null and is_instance_valid(fossil_node):
		fossil_node.queue_free()
	fossil_node = null

## Checked about once a second while the player works in the lowest level.
func _fossil_tick(delta: float) -> void:
	_fossil_timer -= delta
	if _fossil_timer > 0.0:
		return
	_fossil_timer = 1.0
	if prog.fossil_state() == "" and prog.quarry_level >= 4 and prog.check_fossil():
		_spawn_fossil()
		_sfx_unlock()
		_fossil_reveal()
		var t: Array = prog.fossil_cfg().get("toast", ["", ""])
		if hud:
			hud.toast(str(t[0]), str(t[1]), "milestone")
	elif prog.fossil_state() == "found" and fossil_node == null:
		_spawn_fossil()

var reveal_cinematic := DisplayServer.get_name() != "headless"
var fossil_reveal_active := false

## The moment the bones come out of the rock: control is taken for a few seconds, the view swings to them, holds, and returns.
## E skips it.
func _fossil_reveal() -> void:
	if not reveal_cinematic or fossil_node == null or not hud or driving or menu != "":
		return
	fossil_reveal_active = true
	player.locked = true
	var tw := _turn_view_to(fossil_node.global_position + Vector3(0, 0.4, 0), 1.0)
	tw.chain().tween_interval(2.0)
	tw.chain().tween_callback(_end_fossil_reveal)

func _end_fossil_reveal() -> void:
	if not fossil_reveal_active:
		return
	fossil_reveal_active = false
	create_tween().tween_property(player.camera, "rotation:x", 0.0, 0.5)
	player.locked = false

func _talk_to_fossil() -> void:
	if prog.fossil_state() != "found" or fossil_dialog != null or not hud:
		return
	var f := prog.fossil_cfg()
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_card(str(f.get("found_title", "FOSSIL")), str(f.get("found_text", "")), func(): _open_fossil_choice())

func _open_fossil_choice() -> void:
	if fossil_dialog != null:
		return
	fossil_dialog = QuarryFossilDialog.new()
	fossil_dialog.setup(prog.fossil_cfg())
	ui.add_child(fossil_dialog)
	fossil_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	fossil_dialog.chosen.connect(_fossil_chosen)
	fossil_dialog.cancelled.connect(_close_fossil_dialog)

func _close_fossil_dialog() -> void:
	if fossil_dialog:
		fossil_dialog.queue_free()
	fossil_dialog = null
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _fossil_chosen(who: String) -> void:
	var paid := prog.fossil_choose(who)
	_close_fossil_dialog()
	if paid <= 0 and who != "scientist":
		return
	_remove_fossil()
	if hud:
		hud.popup_money(paid)
		player.locked = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_card("THE FOSSIL", str(prog.fossil_cfg().get("results", {}).get(who, "")), func():
			player.locked = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	_sfx_unlock()
	_notify("The fossil went to %s." % str(prog.fossil_cfg()["buyers"][who]["who"]))

# ------------------------------------------------------------------ Phase 7.7: the dinosaur companion

var companion_node: QuarryCompanion
var egg_node: Node3D
var name_dialog: PanelContainer
var _companion_timer := 0.0

func _sim_day() -> int:
	return int(floorf(state.clock_minutes / 1440.0))

## A straw bed by the home where the companion sleeps at night.
func _build_dino_bed() -> void:
	var rp: Array = prog.companion_cfg().get("rest_pos", [-13.8, 0, 20.0])
	var bed := Node3D.new()
	bed.name = "DinoBed"
	bed.position = Vector3(float(rp[0]), 0.0, float(rp[2]))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.12, 2.2)
	mi.mesh = bm
	mi.material_override = _mat(Color(0.72, 0.6, 0.3))
	mi.position.y = 0.06
	bed.add_child(mi)
	world.add_child(bed)

func _spawn_egg() -> void:
	if egg_node != null and is_instance_valid(egg_node):
		return
	var p: Array = prog.companion_cfg().get("egg_pos", [-1.0, 0, 9.5])
	var root := StaticBody3D.new()
	root.name = "DinoEgg"
	root.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	root.set_meta("kind", "egg")
	root.collision_layer = 32
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.4
	cs.shape = sh
	cs.position.y = 0.4
	root.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.8
	mi.mesh = sm
	mi.material_override = _mat(Color(0.82, 0.78, 0.62))
	mi.position.y = 0.4
	root.add_child(mi)
	_solid(root, "Nest", Vector3(0, 0.05, 0), Vector3(1.0, 0.1, 1.0), Color(0.42, 0.30, 0.16))
	world.add_child(root)
	egg_node = root

func _remove_egg() -> void:
	if egg_node != null and is_instance_valid(egg_node):
		egg_node.queue_free()
	egg_node = null

## The first time the dinosaur breaks rock Walter, watching from the road, has something to say.
func _walter_cheer() -> void:
	var lines: Array = prog.companion_cfg().get("walter_mining_lines", [])
	if not hud:
		return
	for i in range(lines.size()):
		var txt := str(lines[i]["text"])
		var delay := 0.1 + float(i) * 3.4
		get_tree().create_timer(delay).timeout.connect(func(): hud.toast("Grandpa Walt", txt, "milestone"))

func _remove_companion() -> void:
	if companion_node != null and is_instance_valid(companion_node):
		companion_node.queue_free()
	companion_node = null
	_remove_egg()
	if name_dialog:
		name_dialog.queue_free()
		name_dialog = null

func _spawn_companion() -> void:
	if companion_node != null and is_instance_valid(companion_node):
		return
	companion_node = QuarryCompanion.new()
	world.add_child(companion_node)
	companion_node.setup(self, prog.companion_stage(prog.current_day))
	var at := player.global_position + Vector3(1.5, 0, 1.5)
	companion_node.global_position = Vector3(at.x, companion_node.ground_y(at), at.z)

## Egg delivery, hatching, growth and the companion's movement, driven from the physics tick.
func _companion_tick(delta: float) -> void:
	prog.current_day = _sim_day()
	var c := prog.companion()
	var st := str(c.get("state", "none"))
	_companion_timer -= delta
	if _companion_timer <= 0.0:
		_companion_timer = 0.5
		for mm in prog.check_quarry_milestones():
			if hud:
				hud.toast(str(mm["title"]), "%s Bonus %s." % [str(mm["text"]), QuarryTheme.money_text(int(mm["reward"]))], "milestone")
				hud.popup_money(int(mm["reward"]))
			_sfx_unlock()
		for jid in prog.check_level_journal():
			if hud:
				hud.toast("Walter's journal", str(prog.journal_entry(jid).get("title", "")), "unlock")
		if prog.companion_egg_waiting(prog.current_day) and egg_node == null and not sleeping:
			_spawn_egg()
		elif st == "egg":
			if egg_node == null:
				_spawn_egg()
			if prog.companion_stage(prog.current_day) != "egg" and name_dialog == null and not _hatching:
				_hatch_egg()
		elif st == "alive":
			if companion_node == null:
				_spawn_companion()
			var now_stage := prog.companion_stage(prog.current_day)
			if now_stage != companion_node.stage:
				companion_node.set_stage(now_stage)
				var key := "adult_text" if now_stage == "adult" else ("juvenile_text" if now_stage == "juvenile" else "")
				if key != "" and hud:
					hud.toast("%s grew up" % str(c.get("name", "Your dinosaur")), str(prog.companion_cfg().get(key, "")) % str(c.get("name", "Your dinosaur")), "milestone")
				if now_stage == "adult":
					prog.journal_add("companion_adult")
	if companion_node != null and is_instance_valid(companion_node):
		var h := _hour()
		var rest := Vector3.INF
		if sleeping or h >= 22.0 or h < 6.0:
			var rp: Array = prog.companion_cfg().get("rest_pos", [-13.8, 0, 20.0])
			rest = Vector3(float(rp[0]), float(rp[1]), float(rp[2]))
		companion_node.step(delta, player.global_position, rest)

var hatch_wobble := DisplayServer.get_name() != "headless"      ## the egg rocks and cracks for a moment before it opens
var _hatching := false

func _hatch_egg() -> void:
	if hatch_wobble and egg_node != null and is_instance_valid(egg_node) and not _hatching:
		_hatching = true
		var tw := create_tween()
		for i in range(8):
			tw.tween_property(egg_node, "rotation:z", (0.32 if i % 2 == 0 else -0.32) * (0.5 + float(i) * 0.1), 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_property(egg_node, "scale", Vector3.ONE * 1.2, 0.12)
		tw.tween_callback(func():
			_hatching = false
			_finish_hatch())
		return
	_finish_hatch()

func _finish_hatch() -> void:
	prog.companion_hatch(prog.current_day, "")
	_remove_egg()
	_spawn_companion()
	prog.journal_add("companion_born")
	if hud:
		hud.show_card("IT HATCHED", str(prog.companion_cfg().get("hatch_text", "")), func(): _open_name_dialog())
		player.locked = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _open_name_dialog() -> void:
	if name_dialog != null:
		return
	var pc := PanelContainer.new()
	pc.name = "NameDialog"
	pc.custom_minimum_size = Vector2(420, 0)
	pc.add_theme_stylebox_override("panel", QuarryTheme.panel_box(QuarryTheme.BG, QuarryTheme.ACCENT, 14, 4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(QuarryTheme.label("NAME YOUR DINOSAUR", 12, QuarryTheme.ACCENT, true))
	var le := LineEdit.new()
	le.name = "NameEdit"
	le.max_length = 16
	var names: Array = prog.companion_cfg().get("default_names", ["Pebble"])
	le.text = str(names[randi() % names.size()])
	le.select_all_on_focus = true
	v.add_child(le)
	var ok := Button.new()
	ok.text = "That's its name"
	ok.pressed.connect(func(): _finish_naming(le.text))
	v.add_child(ok)
	ui.add_child(pc)
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	name_dialog = pc
	le.grab_focus()

func _finish_naming(text: String) -> void:
	prog.companion_rename(text)
	if name_dialog:
		name_dialog.queue_free()
	name_dialog = null
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hud:
		hud.toast(str(prog.companion().get("name", "")), "is part of the family now.", "unlock")

func _take_egg() -> void:
	if prog.companion_take_egg(prog.current_day):
		if hud:
			hud.show_card("A GIFT FROM DR. MARSH", str(prog.companion_cfg().get("arrival_text", "")))
		_notify("You take care of the egg. It should hatch in a couple of days.")

## T: the companion walks up to the rock you are looking at and smashes it with its tail.
func _companion_command() -> void:
	if companion_node == null or not is_instance_valid(companion_node) or sleeping or driving or menu != "":
		return
	var nm := str(prog.companion().get("name", "Your dinosaur"))
	if companion_node.busy():
		companion_node.cancel_smash()
		_notify("%s stops." % nm)
		return
	var hit := _mining_ray()
	if not hit.is_empty() and str(hit["node"].get_meta("kind", "")) == "debris":
		var dm := companion_node.command_debris(hit["node"])
		_notify(dm if dm != "" else "%s goes to clear it." % nm)
		return
	if hit.is_empty() or str(hit["node"].get_meta("kind", "")) != "deposit":
		_notify("Look at exposed rock or rubble and press T to send %s to it." % nm)
		return
	var kind := str(hit["node"].get_meta("deposit"))
	if not formation_nodes.has(kind) or prog.formation_locked(kind) != "":
		_notify(prog.formation_locked(kind) if formation_nodes.has(kind) else "Nothing to smash here.")
		return
	var col := int(hit["column"])
	if col < 0 or prog.column_units(kind, col) <= 0 or not prog.column_minable(kind, col):
		col = prog.nearest_column(kind, hit["point"], true, 2.6)
	if col < 0:
		_notify("%s can only smash exposed rock." % nm)
		return
	var msg := companion_node.command_smash(kind, col)
	if msg != "":
		_notify(msg)
	else:
		_notify("%s goes to smash the rock." % nm)

## One tail hit on a column. Same rules as every other tool: hardness, exposure, unlock. Units fall as loose pieces.
func companion_strike(kind: String, col: int, damage: float, who: Node3D) -> void:
	if not formation_nodes.has(kind) or prog.formation_locked(kind) != "":
		return
	var res := str(state.deposits[kind]["resource"])
	if not prog.companion_can_break(res, prog.current_day):
		return
	if prog.extraction_block(kind, col, "companion", 99) != "":
		return
	var node: QuarryFormation = formation_nodes[kind]
	var room := maxi(0, int(prog.cfg.get("loose_piece_cap", 36)) - loose_count(kind))
	var ex := prog.extract(kind, col, damage, room, "companion")
	for i in range(int(ex["units"])):
		_spawn_formation_piece(kind, col, i)
	_vein_bonus(ex, kind, col, "ground")       # a pocket the club opens lies on the ground as pieces of its own mineral: nothing vanishes
	node.hit(col)
	if int(ex["chunks"]) > 0:
		node.refresh()
	else:
		node.update_label()
	if not bool(prog.story.get("dino_mining_seen", false)) and int(ex["units"]) > 0:
		prog.story["dino_mining_seen"] = true
		_walter_cheer()
	var at: Vector3 = who.club_pos() if who != null and who.has_method("club_pos") else node.column_top(col)     # dust where the club met the rock
	if player and player.global_position.distance_to(at) < 24.0:
		fx.impact(at, res, 1.2)
		_sfx_at("hit_pick", at, -2.0)

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
	prog.journal_add("lockbox")
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
## The bottom key hint follows what the player is doing.
## Structured controls for the bottom strip: [key, what it does], in plain words (Phase 8.4).
func hud_hints() -> Array:
	if driving:
		var h := [["W A S D", "Drive"], ["SPACE", "Brake"]]
		if driving.vkind == "loader":
			h.append(["LEFT CLICK", "Scoop with the bucket"])
			h.append(["RIGHT CLICK", "Dump the bucket"])
		elif driving.vkind == "excavator":
			h.append(["HOLD LEFT CLICK", "Dig the rock"])
			h.append(["RIGHT CLICK", "Dump the bucket"])
		else:
			h.append(["RIGHT CLICK", "Raise the bed and unload"])
		h += [["R", "Recover"], ["E", "Get out"]]
		return h
	if placement:
		return [["LEFT CLICK", "Place"], ["R", "Rotate"], ["G", "Grid snap"], ["ESC", "Cancel"]]
	if construction:
		return [["LEFT CLICK", "Select a machine"], ["B", "Move it"], ["X", "Sell it"], ["ESC", "Leave build mode"]]
	var mine := "HOLD LEFT CLICK" if prog.is_continuous() else "LEFT CLICK"
	return [["W A S D", "Move"], ["SHIFT", "Sprint"], [mine, "Mine"], ["E", "Interact"], ["B", "Build mode"], ["M", "Management"], ["ESC", "Pause"]]

## What the blueprint plate shows (empty while not building).
func build_info() -> Dictionary:
	if placement:
		var name_k := placement_kind.replace("_", " ")
		name_k = {"output": "output storage", "conveyor": "conveyor", "advanced crusher": "advanced crusher"}.get(placement_kind, name_k)
		var price := 0 if placement_from_inventory else _placement_price(placement_kind)
		return {"active": true, "title": name_k.capitalize(), "rotation": int(round(rad_to_deg(placement_yaw))) % 360, "grid": grid_snap, "valid": ghost_valid, "price": price, "hint": placement_hint}
	if construction:
		var t := _construction_target()
		if t.is_empty():
			return {"active": true, "title": "Build mode", "hint": "Aim at a crusher, conveyor, storage crate or output storage."}
		return {"active": true, "title": _structure_name(str(t["kind"]), int(t["index"])), "hint": "Left click to move it, X to sell it."}
	return {"active": false}

func _hint_text() -> String:
	if driving:
		return "WASD drive  Mouse look  Space brake  R recover  E exit vehicle"
	if placement:
		return "Left click place  R rotate  G grid snap  Esc cancel"
	if construction:
		return "Left click select a machine  B move  X sell  Esc leave construction"
	return "WASD move  SHIFT sprint  left click mine  E use  M manage  B build  F5 save  ESC pause"

## Small status lines under the clock: deliveries waiting in the construction inventory, vehicles on their way, belts
## that are not connected at both ends.
func hud_badges() -> Array:
	var lines := []
	var n := 0
	for k in business.inventory:
		n += int(business.inventory[k])
	if n > 0:
		lines.append(["%d delivered machine%s waiting - place %s from the order screen" % [n, "" if n == 1 else "s", "it" if n == 1 else "them"], false])
	if delivery and not delivery.jobs.is_empty():
		lines.append(["%d vehicle%s arriving" % [delivery.jobs.size(), "" if delivery.jobs.size() == 1 else "s"], false])
	var loose := 0
	for i in range(business.links.size()):
		var l: Dictionary = business.links[i]
		if l.get("src", {}).is_empty() or l.get("dst", {}).is_empty():
			loose += 1
	if loose > 0:
		lines.append(["%d belt%s not connected at both ends" % [loose, "" if loose == 1 else "s"], true])
	return lines

## A level's access road was built (paid for): the rock it cut disappears, the crews re-plan their routes.
func _on_road_built(n: int) -> void:
	for lv in range(1, n + 1):
		for fid in prog.level_formations(lv):
			if formation_nodes.has(fid):
				_refresh_deposit(fid)
	if pit_zone:
		pit_zone.request_bake()
	nav_dirty = true
	if hud:
		hud.toast("Access road built", "Level %d is open to trucks and excavators." % n, "milestone")

func _on_quarry_level(n: int) -> void:
	# Phase 8.7: the level's haul road was cut out of its rock (progression.open_roads): show it, and let the crews find the way
	for lv in range(1, n + 1):
		for fid in prog.level_formations(lv):
			if formation_nodes.has(fid):
				_refresh_deposit(fid)
	if pit_zone:
		pit_zone.request_bake()
	if hud:
		var road_note := ("  Build its access road at the office (Quarry Plan, $%d)." % prog.road_cost(n)) if blueprint and prog.level_def(n).has("roads") and not prog.road_built(n) else ""
		hud.toast("Quarry level %d reached" % n, str(prog.level_def(n).get("title", "")) + road_note, "milestone")
		_sfx_unlock()

## The industrial hub's boundary (data/progression.json "world"): the permanent business yard, never excavated.
func hub_rect() -> Rect2:
	var h: Dictionary = prog.cfg_for("world").get("hub", {})
	var xs: Array = h.get("x", [-23.5, 23.5])
	var zs: Array = h.get("z", [-6.0, 23.5])
	return Rect2(float(xs[0]), float(zs[0]), float(xs[1]) - float(xs[0]), float(zs[1]) - float(zs[0]))

## Where the player is, in words, for the location banner: the yard, the quarry surface, a numbered area, the tunnel.
func hud_location() -> String:
	var src: Node3D = driving if driving else player
	if src == null:
		return ""
	var p := src.global_position
	if not blueprint:
		return "THE YARD" if hub_rect().has_point(Vector2(p.x, p.z)) else "THE QUARRY"
	var ar := area_at(p)
	if ar != "":
		var def := prog.area_def(ar)
		var lvl := int(def.get("level", 1))
		return "QUARRY  -  AREA %d" % (lvl if ar != "area_6" else 5) if lvl > 1 else "QUARRY  -  SURFACE (AREA 1)"
	if hub_rect().has_point(Vector2(p.x, p.z)):
		return "THE YARD"
	if delivery != null and p.x < hub_rect().position.x and p.z > 18.0:
		return "THE WEST TUNNEL"
	return "OUTSIDE THE FENCE"

## What the map's objective marker points at: the next loose debris during the cleanup, then the office once a level's access road is waiting to be built.
func hud_waypoint() -> Dictionary:
	if prog == null or player == null:
		return {}
	if prog.cleanup_active():
		var nx := nearest_cleanup()
		if not nx.is_empty() and nx.has("pos"):
			return {"pos": nx["pos"], "label": "Next debris"}
	if blueprint:
		for n in range(2, prog.quarry_level + 1):
			if not prog.road_built(n) and prog.level_def(n).has("roads"):
				return {"pos": OFFICE_POS, "label": "Build the level %d road at the office" % n}
	return {}

func hud_status_text() -> String:
	var lines := []
	if blueprint:
		for n in range(2, prog.quarry_level + 1):
			if not prog.road_built(n) and prog.level_def(n).has("roads"):
				lines.append("Level %d is open: build its road at the office computer (Quarry Plan, $%d)" % [n, prog.road_cost(n)])
				break
	if prog.cleanup_active():
		lines.append("Site cleanup %d/%d" % [prog.cleanup_total() - prog.cleanup_left(), prog.cleanup_total()])
		var nx := nearest_cleanup()
		if not nx.is_empty():
			lines.append("%s: %s %d m %s" % ["LAST ONE" if prog.cleanup_left() == 1 else "Next", "weeds" if nx["weed"] else "rubble", int(nx["dist"]), nx["dir"]])
	var shown := 0
	for a in prog.area_defs():
		var aid := str(a["id"])
		if shown < 2 and prog.area_available(aid) and not prog.area_complete(aid):
			var ap := prog.area_progress(aid)
			if not ap.is_empty():
				var next_part := ""
				for pt in ap["parts"]:
					if int(pt["have"]) < int(pt["need"]):
						next_part = "  -  %s %d/%d" % [str(pt["label"]).split(" ")[0], int(pt["have"]), int(pt["need"])]
						break
				lines.append("%s  %d%%%s" % [str(ap["title"]), int(ap["pct"]), next_part])
				shown += 1
	if prog.level_built(prog.quarry_level) and not prog.cleanup_active():
		lines.append("Quarry level %d: %d%% cut" % [prog.quarry_level, int(prog.level_cleared_fraction(prog.quarry_level) * 100.0)])
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
	return prog.nearest_column(kind, from, true, INF, "crew")

func _crew_strike_formation(kind: String, hits: int, extra: int, w: Node3D) -> void:
	var node: QuarryFormation = formation_nodes[kind]
	var col: int = int(w.mine_col) if w and "mine_col" in w else -1
	if col < 0 or prog.column_units(kind, col) <= 0:
		col = prog.nearest_column(kind, w.global_position if w else node.global_position, true, INF, "crew")
	if col < 0 or prog.extraction_block(kind, col, "crew") != "":
		return
	var room := maxi(0, int(prog.cfg.get("loose_piece_cap", 36)) - loose_count(kind))
	var ex := prog.extract(kind, col, prog.crew_damage(float(hits), float(extra)), room, "crew")
	var res := str(state.deposits[kind]["resource"])
	for i in range(int(ex["units"])):
		_spawn_formation_piece(kind, col, i)
	_vein_bonus(ex, kind, col, "ground")
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
		var ns := int(state.storage.get(key, 0))
		if n <= 0 and ns <= 0:
			continue
		var before := state.money
		state.sell(key, n)                    # the bag first, then whatever waits in the storage bin
		state.sell_storage(key, ns)
		total += state.money - before
		parts.append("%d %s" % [n + ns, prog.display(key).to_upper()])
	if total > 0:
		sfx["coin"].play()
		hud.toast("Sold " + ", ".join(parts), "+" + QuarryTheme.money_text(total), "sale")
		_notify("Sold %s for %s" % [", ".join(parts), QuarryTheme.money_text(total)])
	else:
		_notify("Nothing of that in your bag or in storage.")
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
	player.tool_view.equip(prog.model_tier(), menu != "")   # behind a menu nobody sees the swap animation: just show the new tool
	_refresh_workbench()
	hud.toast("New tool: " + str(nt["title"]), "MINING POWER +%d%%" % prog.tool_gain_percent(from, state.tool_tier), "unlock")
	_sfx_unlock()
	_notify(str(nt.get("desc", "")))
	return true

func buy_gear(id: String) -> bool:
	var g := prog.gear_def(id)
	var why := prog.gear_block_reason(id)
	if why != "":
		_notify(why)
		return false
	prog.buy_gear(id)
	player.tool_view.equip(prog.model_tier(), menu != "")
	_refresh_workbench()
	if str(g.get("kind", "tool")) == "cart":
		hud.toast(str(g["title"]), "BAG NOW HOLDS %d" % state.capacity(), "unlock")
	elif str(g.get("kind", "tool")) == "equipment":
		hud.toast(str(g["title"]), "POWERED TOOLS +%d%%" % int(round((float(g.get("power_mult", 1.0)) - 1.0) * 100.0)), "unlock")
	else:
		hud.toast("New tool: " + str(g["title"]), str(g.get("class", "")).to_upper(), "unlock")
	_sfx_unlock()
	_notify(str(g.get("desc", "")))
	return true

## Q: take the next tool you own into your hand.
func cycle_tool() -> void:
	if prog.held_options().size() < 2:
		_notify("You only have one tool. Buy more at the workbench.")
		return
	prog.cycle_tool()
	player.tool_view.equip(prog.model_tier(), false)
	var t := prog.tool()
	hud.toast(str(t["title"]), "%s - %s" % [str(t.get("class", "general")).to_upper(), ("%.0f damage a second" % prog.tool_dps()) if prog.is_continuous() else ("%.0f damage, %.1f swings a second" % [prog.tool_power(), 1.0 / prog.tool_interval() * prog.speed_mult()])], "info")

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

const BELT_LAMP := {"active": Color(0.3, 0.9, 0.3), "blocked": Color(1.0, 0.65, 0.1), "disconnected": Color(0.95, 0.2, 0.15), "idle": Color(0.35, 0.38, 0.35)}
var belt_mat_moving: StandardMaterial3D
var _belt_scroll := 0.0

## Crushers: flywheels/mantle spin up and down smoothly, the jaw cycles only while really crushing,
## the hopper shows its real contents, the output pile grows when a run completes, and a small label
## shows run progress. Conveyors: the belt texture scrolls only while the belt carries material.
## Extra flywheel turn so rotation rate scales with processing speed (the base spin above is unchanged at speed 1).
func fw_scale_apply(body: Node3D, speedup: float, ease: float, delta: float, axis_y: bool) -> void:
	var extra := (speedup - 1.0) * delta * 8.0 * ease
	for fw in body.get_meta("flywheels", []):
		if axis_y:
			fw.rotation.y += extra
		else:
			fw.rotation.x += extra

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
		# animation speed follows the real processing speed: a faster crusher (efficiency upgrade, advanced tier) cycles faster
		var speedup := clampf(float(state.config["crusher_seconds"]) / maxf(0.2, state.process_seconds(i)), 0.6, 4.0)
		var cyc := 5.5 + 2.0 * speedup
		if body.has_meta("jaw") and not axis_y:
			body.get_meta("jaw").rotation.x = sin(t * cyc) * 0.16 * ease
		fw_scale_apply(body, speedup, ease, delta, axis_y)
		# subtle whole-machine vibration while active; it settles back to rest exactly when switched off
		if not body.has_meta("rest_pos"):
			body.set_meta("rest_pos", body.position)
		var rest: Vector3 = body.get_meta("rest_pos")
		if (body.position - rest).length() > 0.05:      # moved by a relocation: take the new spot as rest
			rest = body.position
			body.set_meta("rest_pos", rest)
		var shake := 0.006 * ease
		body.position = rest + Vector3(sin(t * 47.0 + i) * shake, absf(sin(t * 31.0)) * shake, cos(t * 53.0) * shake)
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
			var st := business.belt_status(i)
			belt.material_override = belt_mat_moving if st == "active" else MeshKit.mat("Belt")   # a blocked belt stops running
			var lamp: MeshInstance3D = cnode.get_meta("lamp", null)
			if lamp:
				var lc: Color = BELT_LAMP.get(st, Color.GRAY)
				var lmat := lamp.material_override as StandardMaterial3D
				lmat.albedo_color = lc
				lmat.emission_enabled = st != "idle"
				lmat.emission = lc
				lmat.emission_energy_multiplier = 1.6 if st != "idle" else 0.0
				cnode.set_meta("status", st)
	if any_running:
		var top := 1.0
		for ci in range(state.crushers.size()):
			if bool(state.crushers[ci]["running"]):
				top = maxf(top, float(state.config["crusher_seconds"]) / maxf(0.2, state.process_seconds(ci)))
		crusher_audio.pitch_scale = clampf(0.9 + 0.12 * top, 0.9, 1.5)   # motor note rises with speed
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
