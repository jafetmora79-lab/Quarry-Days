extends RefCounted
class_name QuarryArt
## Phase 4 art pass: dresses the existing quarry in THE VEIL's style (pixel textures, chunky low-poly
## geometry, reused THE VEIL props) WITHOUT changing gameplay. Every existing collision box, interaction
## body, navigation input and placement rule stays as it was; placeholder meshes are swapped or hidden and
## modelled geometry is added on top. Static geometry is batched per material (few draw calls).

const VEIL := "res://THE_VEIL_ASSETS_V2/"
const P_DESK := VEIL + "03_Residential/Furniture/RES_Desk_Computer.glb"
const P_CHAIR := VEIL + "03_Residential/Furniture/RES_DeskChair_Office.glb"
const P_NOTICE := VEIL + "04_Commercial/Shared_Props/COM_NoticeBoard.glb"
const P_FILING := VEIL + "04_Commercial/Shared_Props/COM_FilingCabinet.glb"
const P_CLOCK := VEIL + "03_Residential/Furniture/RES_WallClock.glb"
const P_CALENDAR := VEIL + "03_Residential/Furniture/RES_WallCalendar.glb"
const P_WAITING := VEIL + "04_Commercial/Shared_Props/COM_WaitingChairs.glb"
const P_DOCS := VEIL + "04_Commercial/Shared_Props/COM_DocumentBoxes.glb"
const P_WALL_LAMP := VEIL + "02_Town/Street_Props/SP_Lamp_Wall.glb"
const P_DOOR := VEIL + "03_Residential/Exterior_Modules/RES_Ext_Door_Back_HalfGlass.glb"
const P_WINDOW := VEIL + "03_Residential/Exterior_Modules/RES_Ext_Window_DoubleHung_1.1x1.3.glb"
const P_WINDOW_WIDE := VEIL + "03_Residential/Exterior_Modules/RES_Ext_Window_Picture_1.6x1.4.glb"
const P_WORKBENCH := VEIL + "03_Residential/Furniture/RES_Workbench.glb"
const P_SHELF := VEIL + "03_Residential/Furniture/RES_Shelving_Metal.glb"
const P_TOOLBOX := VEIL + "03_Residential/Furniture/RES_Toolbox.glb"
const P_RACK := VEIL + "04_Commercial/Shared_Props/COM_PalletRack.glb"
const P_PALLETS := VEIL + "04_Commercial/Shared_Props/COM_PalletStack.glb"
const P_BOXES := VEIL + "03_Residential/Furniture/RES_CardboardBox_Stack.glb"
const P_BIN := VEIL + "03_Residential/Furniture/RES_StorageBin.glb"
const P_ELEC := VEIL + "02_Town/Utilities/UT_ElectricalCabinet.glb"
const P_JUNCTION := VEIL + "02_Town/Utilities/UT_JunctionBox.glb"
const P_BARRIER := VEIL + "02_Town/Street_Props/SP_RoadBarrier.glb"
const P_CONE := VEIL + "02_Town/Street_Props/SP_TrafficCone.glb"
const P_DUMPSTER := VEIL + "02_Town/Street_Props/SP_Dumpster.glb"
const P_POLE := VEIL + "02_Town/Street_Props/SP_UtilityPole_Streetlight.glb"
const P_BENCH := VEIL + "02_Town/Street_Props/SP_Bench_Wood.glb"
const P_TRASH := VEIL + "02_Town/Street_Props/SP_TrashBin_Public.glb"
const P_RETAIN := VEIL + "02_Town/Fences/FN_RetainingWall_2.5m.glb"
const P_RAILING := VEIL + "02_Town/Fences/FN_MetalRailing_2.5m.glb"
const P_ROCKS := VEIL + "02_Town/Vegetation/VG_RocksSmall.glb"
const P_MOUND := VEIL + "02_Town/Vegetation/VG_DirtMound.glb"
const P_GRAVEL := VEIL + "02_Town/Vegetation/VG_GravelPile.glb"
const P_PINE := VEIL + "02_Town/Vegetation/VG_Tree_Pine.glb"
const P_STUMP := VEIL + "02_Town/Vegetation/VG_TreeStump.glb"
const P_WEEDS := VEIL + "02_Town/Vegetation/VG_Weeds.glb"
const P_DEAD := VEIL + "02_Town/Vegetation/VG_DeadVegetation.glb"
const M_GRAVEL := VEIL + "Materials_Godot/Roads/M_Road_Gravel.tres"
const M_DIRT_ROAD := VEIL + "Materials_Godot/Roads/M_Road_DirtRoad.tres"
const M_CONCRETE := VEIL + "Materials_Godot/Roads/M_Road_ConcreteCracked.tres"
const M_ASPHALT := VEIL + "Materials_Godot/Roads/M_Road_ParkingLotAsphalt.tres"
const M_CURB := VEIL + "Materials_Godot/Roads/M_Road_CurbConcrete.tres"
const M_SOIL := VEIL + "Materials_Godot/Ground/M_Grnd_Soil.tres"
const M_GRASS := VEIL + "Materials_Godot/Ground/M_Grnd_GrassDry.tres"
const M_FOUNDATION := VEIL + "Materials_Godot/Architecture/M_Arch_ConcreteFoundation.tres"
const M_SIDING := VEIL + "Materials_Godot/Architecture/M_Arch_SidingWhite.tres"
const M_TRIM := VEIL + "Materials_Godot/Architecture/M_Arch_TrimPainted.tres"
const M_INDUSTRIAL := VEIL + "Materials_Godot/Commercial/M_Com_IndustrialWallDirty.tres"
const M_METAL_DOOR := VEIL + "Materials_Godot/Commercial/M_Com_MetalDoorPainted.tres"
const M_LINO := VEIL + "Materials_Godot/Interiors/M_Int_Linoleum.tres"
const M_DRYWALL := VEIL + "Materials_Godot/Interiors/M_Int_DrywallLight.tres"
const M_BASEMENT := VEIL + "Materials_Godot/Interiors/M_Int_BasementConcrete.tres"
const M_BRUSHED := "res://assets/materials/M_QD_MetalBrushed.tres"      # Quarry Days copy of the Veil material, much less shiny
const M_RUSTED := VEIL + "Materials_Godot/Furniture/M_Furn_MetalRusted.tres"
const M_RUBBER := VEIL + "Materials_Godot/Furniture/M_Furn_Rubber.tres"
const M_WOOD := VEIL + "Materials_Godot/Furniture/M_Furn_WoodLight.tres"
const M_FABRIC := VEIL + "Materials_Godot/Furniture/M_Furn_FabricUpholstery.tres"
const M_GLASS := "res://assets/materials/M_QD_Glass.tres"      # clean smoked glass: the Veil dirty-glass texture read as speckle noise on cabs
const ROCK_MAT := {"limestone": "RockLimestone", "coal": "RockCoal", "iron_ore": "RockIron", "crushed_stone": "RockGravel", "copper_ore": "RockCopper", "gold_ore": "RockGold", "soil": "ExcavatedDirt", "topsoil": "ExcavatedDirt", "gravel": "RockGravel"}

var game
var root: Node3D
var batch := {}            ## material key -> MeshKit.Soup (static, merged at the end)
var lights: Array = []     ## [OmniLight3D, base energy]
var piece_meshes := {}
var pit_cap: MeshInstance3D     ## ground surface over the closed deep pit (hidden once it is dug)

func build_environment(main_node) -> void:
	game = main_node
	root = Node3D.new()
	root.name = "Art"
	game.add_child(root)
	_clear_placeholders()
	if game.blueprint:
		_blueprint_world()
	else:
		_ground()
		_cliffs()
	_office()
	_shed()
	_toolshed()
	_home()
	_garage()
	if game.blueprint:
		_site_props_blueprint()
	else:
		_site_props()
	_yard_boundary()
	_flush()
	_atmosphere()

# ------------------------------------------------------------------ batching

func soup(key: String) -> MeshKit.Soup:
	if not batch.has(key):
		batch[key] = MeshKit.Soup.new()
	return batch[key]

func _material(key: String) -> Material:
	return MeshKit.mat(key)

func _flush() -> void:
	MeshKit.repair(batch)
	for key in batch:
		var s: MeshKit.Soup = batch[key]
		if s.verts.size() > 0:
			MeshKit.inst(root, s.mesh(), _material(key))
	batch.clear()

func bx(key: String, c: Vector3, size: Vector3, yaw := 0.0, taper := Vector2.ONE) -> void:
	MeshKit.box_into(soup(key), Vector3.ZERO, size, taper, Transform3D(Basis(Vector3.UP, yaw), c))

func quad_flat(key: String, c: Vector3, size: Vector2, yaw := 0.0, y := 0.02) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.z))
	var h := size * 0.5
	soup(key).quad(xf * Vector3(-h.x, 0, -h.y), xf * Vector3(-h.x, 0, h.y), xf * Vector3(h.x, 0, h.y), xf * Vector3(h.x, 0, -h.y))

func poly_flat(key: String, pts: PackedVector2Array, y: float) -> void:
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	var idx := Geometry2D.triangulate_polygon(pts)
	for k in range(0, idx.size(), 3):
		var a: Vector2 = pts[idx[k]]
		var b: Vector2 = pts[idx[k + 1]]
		var c: Vector2 = pts[idx[k + 2]]
		soup(key).tri(Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(b.x, y, b.y))

func prop(path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	return MeshKit.prop(root, path, pos, yaw, scale)

## Static box collider added to the world (included in navigation bakes like any other structure).
func solid(name: String, c: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	b.position = c
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.set_meta("art", true)
	game.world.add_child(b)
	return b

func light(pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	root.add_child(l)
	lights.append([l, energy])
	return l

## Night factor 0 (day) .. 1 (night): practical lights glow at night, stay dim by day.
func set_night(n: float) -> void:
	for pair in lights:
		pair[0].light_energy = float(pair[1]) * (0.25 + 0.75 * n)

# ------------------------------------------------------------------ placeholders

func _hide(body: Node) -> void:
	for child in body.get_children():
		if child is MeshInstance3D:
			child.visible = false

func _clear_placeholders() -> void:
	for n in game.world.get_children():
		if n is MeshInstance3D:
			n.queue_free()                                      # tree canopies, road strips, parking marks
		elif n is StaticBody3D:
			var nm := str(n.name)
			if nm.begins_with("Tree trunk"):
				var p: Vector3 = n.position
				if absf(p.x - 15.0) < 0.1 and p.z > 10.0:
					n.queue_free()                              # makes room for the equipment garage
				else:
					_hide(n)
					prop(P_PINE, Vector3(p.x, 0, p.z), float(int(p.x * 7.0 + p.z * 3.0) % 6), 1.0)
			elif nm.begins_with("Equipment parking sign"):
				n.queue_free()                                  # the garage carries its own sign now
			elif nm in ["Quarry floor", "Expansion floor", "Pit cap"] or nm.begins_with("Office ") or nm.begins_with("Home ") or nm.begins_with("Storage shed ") \
					or nm.begins_with("Break bench") or nm.begins_with("Upgrade board") or nm.begins_with("Selling station") \
					or nm.begins_with("Crusher order kiosk") or nm.begins_with("Management desk"):
				_hide(n)

# ------------------------------------------------------------------ ground

func _ground() -> void:
	# The ground is a single-sided surface; from inside the pit (looking out through the ramp mouth) its underside was culled
	# and the sky's pale ground colour showed instead. Drawing both sides makes it a solid-looking dirt ceiling there.
	for key in ["QuarryFloor", "ExcavatedDirt"]:
		var gm = MeshKit.mat(key)
		if gm is BaseMaterial3D:
			(gm as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	# Base quarry floor: crushed-limestone gravel with a gentle 3-6 cm undulation (physics stays flat).
	var s := soup("QuarryFloor")
	var step := 2.0
	var pit: Array = game.prog.cfg["excavation"]["pit"]
	var cap := MeshKit.Soup.new()
	for gx in range(-29, 29, int(step)):
		for gz in range(-29, 29, int(step)):
			var in_pit := gx >= float(pit[0]) - 0.01 and gx + step <= float(pit[2]) + 0.01 and gz >= float(pit[1]) - 0.01 and gz + step <= float(pit[3]) + 0.01
			(cap if in_pit else s).quad(_g(gx, gz), _g(gx, gz + step), _g(gx + step, gz + step), _g(gx + step, gz))
	for gx in range(29, 49, int(step)):                         # east expansion: excavated dirt
		for gz in range(-13, 13, int(step)):
			soup("ExcavatedDirt").quad(_g(gx, gz), _g(gx, gz + step), _g(gx + step, gz + step), _g(gx + step, gz))
	# Excavated pit floor (the lower working benches inside the rim).
	# Excavated pit floor disc in 1 m cells, leaving the deep-pit rectangle to its own cap mesh.
	var dirt := soup("ExcavatedDirt")
	for gx in range(-17, 17):
		for gz in range(-25, 9):
			var c := Vector2(gx + 0.5, gz + 0.5)
			if c.distance_to(Vector2(0, -8)) > 16.8:
				continue
			var y := 0.012
			var q := [Vector3(gx, y, gz), Vector3(gx, y, gz + 1), Vector3(gx + 1, y, gz + 1), Vector3(gx + 1, y, gz)]
			if c.x > float(pit[0]) and c.x < float(pit[2]) and c.y > float(pit[1]) and c.y < float(pit[3]):
				cap.quad(q[0], q[1], q[2], q[3])
			else:
				dirt.quad(q[0], q[1], q[2], q[3])
	pit_cap = MeshKit.inst(root, cap.mesh(), _material("ExcavatedDirt"))
	# Haul roads (dirt), yard (gravel) and pads (concrete).
	# The roads and the yard used to be separate overlay patches; their edges showed as faint rectangles all over the
	# floor, so the whole site now shares the one continuous ground (only the concrete pads and bay lines sit on it).
	quad_flat(M_CONCRETE, Vector3(5.0, 0, 18.7), Vector2(19.6, 7.6), 0.0, 0.075)         # garage slab
	quad_flat(M_CONCRETE, game.OFFICE_POS, Vector2(6.4, 6.4), 0.0, 0.075)        # office pad
	quad_flat(M_CONCRETE, game.SHED_POS, Vector2(6.0, 6.0), 0.0, 0.075)         # shed pad
	quad_flat(M_CONCRETE, game.TOOLSHED_POS, Vector2(6.0, 6.0), 0.0, 0.075)      # tool shed pad
	for slot in game.fleet.cfg.get("parking", []):                                        # painted bay lines
		for side in [-1.4, 1.4]:
			quad_flat("Hazard", Vector3(float(slot[0]) + side, 0, float(slot[2])), Vector2(0.12, 4.2), 0.0, 0.115)
	# Outer embankments: soil slopes rising behind the cliffs to close the horizon.
	var e := soup(M_SOIL)
	var seg := 28
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var rings := [[29.0, 0.0], [33.0, 4.5], [40.0, 7.5], [52.0, 9.0]]
		for r in range(rings.size() - 1):
			var p := [_ring(a0, rings[r]), _ring(a1, rings[r]), _ring(a1, rings[r + 1]), _ring(a0, rings[r + 1])]
			if game.in_pit_corridor((p[0] + p[1] + p[2] + p[3]) * 0.25, 5.0):
				continue # the access corridor to the pit cuts through the embankment
			e.quad(p[0], p[1], p[2], p[3])

func _g(x: float, z: float) -> Vector3:
	var h := 0.035 * sin(x * 0.9 + z * 0.4) * cos(z * 0.7 - x * 0.2) - 0.03
	return Vector3(x, h, z)

func _ring(a: float, r: Array) -> Vector3:
	var wob := 1.0 + 0.04 * sin(a * 5.0)
	return Vector3(cos(a) * r[0] * wob, r[1], sin(a) * r[0] * wob)

# ------------------------------------------------------------------ cliffs, rim, expansion walls

func _cliffs() -> void:
	var seed := 1
	for n in game.world.get_children():
		if not n is StaticBody3D:
			continue
		var nm := str(n.name)
		if n.has_meta("fence"):
			continue
		var cs: CollisionShape3D = null
		for c in n.get_children():
			if c is CollisionShape3D:
				cs = c
		if cs == null or not cs.shape is BoxShape3D:
			continue
		var size: Vector3 = cs.shape.size
		# Duplicate names are auto-renamed by the engine, so the name only identifies the first piece of each kind.
		# Classify by the collision box instead: tall long blocks are cliffs, low long blocks are rims.
		var long_side := maxf(size.x, size.z)
		var is_rim: bool = absf(size.y - 2.2) < 0.05 and long_side >= 8.0 and n.collision_layer == 1 and not n.has_meta("ground")
		var is_cliff: bool = absf(size.y - 6.0) < 0.05 and long_side >= 8.0 and n.collision_layer == 1 and not n.has_meta("ground")
		var is_exp: bool = is_cliff and n.position.x > 28.0
		if is_rim or is_cliff:
			_hide(n)
			seed += 1
			var mesh := MeshKit.Soup.new()
			var low := is_rim
			var length := maxf(size.x, size.z) + (0.8 if low else 1.6)
			var depth := minf(size.x, size.z) + (0.4 if low else 0.8)
			var turn := PI if size.x >= size.z else PI * 0.5
			if is_exp and n.position.z > 0.0:
				turn = 0.0 # south wall of the expansion faces north (-Z)
			MeshKit.cliff_into(mesh, length, size.y + (0.3 if low else 0.9), depth, seed, 2 if low else 4,
				Transform3D(Basis(Vector3.UP, turn), Vector3(0, -size.y * 0.5, 0)))
			var mi := MeshKit.inst(n, mesh.mesh(), _material("CliffStrata"))
			mi.set_meta("art", true)
			if low:
				# safety railing along the bench edge, out of reach on top of the wall
				for k in range(-1, 2):
					var rail := MeshKit.prop(n, P_RAILING, Vector3(k * 2.5 if size.x >= size.z else 0.0, size.y * 0.5, 0.0 if size.x >= size.z else k * 2.5), 0.0 if size.x >= size.z else PI * 0.5)
					if rail == null:
						break
	# Close the old gaps between cliff segments (except both sides of the east opening and its road).
	for i in range(10):
		var a := (float(i) + 0.5) * TAU / 10.0
		if i == 0 or i == 9 or i == 2:
			continue          # i == 2 is the south: the service tunnel runs through it (QuarryDelivery._build_tunnel), nothing may fill its mouth
		var p := Vector3(cos(a) * 28.6, 3.2, sin(a) * 28.6)
		var yaw := -a - PI / 2
		solid("Cliff filler", p, Vector3(8.0, 6.4, 3.4), yaw)
		var mesh := MeshKit.Soup.new()
		MeshKit.cliff_into(mesh, 9.5, 7.0, 4.2, 100 + i, 4, Transform3D(Basis(Vector3.UP, yaw + PI), p - Vector3(0, 3.2, 0)))
		var fm := MeshKit.inst(root, mesh.mesh(), _material("CliffStrata"))
		fm.set_meta("filler_xz", Vector2(p.x, p.z)) # lets the world builder hide the one at the north-east gate
	# rockfall barrier closing the east expansion (removed with its body when the milestone opens it)
	for body in game.expansion_gate:
		if str(body.name).begins_with("Rockfall barrier"):
			_hide(body)
			var r := MeshKit.Soup.new()
			for k in range(9):
				MeshKit.rock_into(r, Vector3(0.0 + (k % 2) * 0.4 - 0.2, -2.0, -11.5 + k * 2.9), Vector3(2.4, 2.6 + (k % 3) * 0.7, 3.2), 300 + k)
			MeshKit.inst(body, r.mesh(), _material("RockLimestone"))

# ------------------------------------------------------------------ buildings

## Walled building on an existing collision footprint: textured walls, inner lining, plinth, roof. `windows`: [[wall "L"|"R"|"B", position along the wall, width, height], ...]
## are REAL openings: the wall (and its lining) is cut around each one and a window with a frame, a reveal, a sill, curtains and clear glass fills it, so you see into the room.
func _walls(center: Vector3, ext_key: String, int_key: String, h := 2.8, windows := []) -> void:
	var c := center
	var ops := {"L": [], "R": [], "B": []}
	for w in windows:
		ops[str(w[0])].append(w)
	var specs := [["L", Vector3(-2.4, 0, 0), Vector3(0.22, h, 4.8)], ["R", Vector3(2.4, 0, 0), Vector3(0.22, h, 4.8)], ["B", Vector3(0, 0, 2.35), Vector3(5.0, h, 0.22)],
		["", Vector3(-1.6, 0, -2.35), Vector3(1.8, h, 0.22)], ["", Vector3(1.6, 0, -2.35), Vector3(1.8, h, 0.22)]]
	for sp in specs:
		_wall_cut(ext_key, c + sp[1] + Vector3(0, h * 0.5, 0), sp[2] + Vector3(0.02, 0, 0.02), "x" if sp[0] == "B" else "z", ops.get(sp[0], []))
	_wall_cut(int_key, c + Vector3(-2.27, h * 0.5, 0), Vector3(0.02, h - 0.1, 4.5), "z", ops["L"])
	_wall_cut(int_key, c + Vector3(2.27, h * 0.5, 0), Vector3(0.02, h - 0.1, 4.5), "z", ops["R"])
	_wall_cut(int_key, c + Vector3(0, h * 0.5, 2.22), Vector3(4.5, h - 0.1, 0.02), "x", ops["B"])
	bx(M_FOUNDATION, c + Vector3(0, 0.05, 0), Vector3(5.24, 0.10, 5.04))
	# Match the collision ramp from the yard to the raised office/shed floor.
	MeshKit.box_into(soup(M_FOUNDATION), Vector3.ZERO, Vector3(1.42, 0.08, 1.0), Vector2.ONE,
		Transform3D(Basis(Vector3.RIGHT, -atan(0.16)), c + Vector3(0, 0.04, -2.95)))
	bx(M_TRIM, c + Vector3(0, 2.5, -2.38), Vector3(1.5, 0.3, 0.24))                       # door header
	for x in [-0.76, 0.76]:
		bx(M_TRIM, c + Vector3(x, 1.25, -2.4), Vector3(0.1, 2.5, 0.08))                    # door jambs
	for w in windows:
		_window_real(c, str(w[0]), float(w[1]), float(w[2]), float(w[3]))

## A wall slab (centre `mid`, size) cut around window openings: full-height pieces between them, and a piece below and above each. `along` is the axis the wall runs
## along ("z" for the side walls, "x" for the back wall). Each opening: [wall, pos, width, height]; its sill is at WINDOW_SILL.
const WINDOW_SILL := 1.05
func _wall_cut(key: String, mid: Vector3, size: Vector3, along: String, openings: Array) -> void:
	if openings.is_empty():
		bx(key, mid, size)
		return
	var length: float = size.z if along == "z" else size.x
	var ops := openings.duplicate()
	ops.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	var y0 := mid.y - size.y * 0.5
	var y1 := mid.y + size.y * 0.5
	var cursor := -length * 0.5
	var piece := func(a: float, b: float, ya: float, yb: float):
		ya = maxf(ya, y0)
		yb = minf(yb, y1)
		if b - a < 0.005 or yb - ya < 0.005:
			return
		var cs := Vector3(mid.x, (ya + yb) * 0.5, mid.z + (a + b) * 0.5) if along == "z" else Vector3(mid.x + (a + b) * 0.5, (ya + yb) * 0.5, mid.z)
		var sz := Vector3(size.x, yb - ya, b - a) if along == "z" else Vector3(b - a, yb - ya, size.z)
		bx(key, cs, sz)
	for o in ops:
		var lo: float = float(o[1]) - float(o[2]) * 0.5
		var hi: float = float(o[1]) + float(o[2]) * 0.5
		var top: float = WINDOW_SILL + float(o[3])
		piece.call(cursor, lo, y0, y1)                       # the wall up to the opening
		piece.call(lo, hi, y0, WINDOW_SILL)                  # below the sill
		piece.call(lo, hi, top, y1)                          # above the head
		cursor = hi
	piece.call(cursor, length * 0.5, y0, y1)

## One window set into its opening: reveal lining, frame, two sashes of clear glass with muntins, outside casing, projecting sill and drip, a stool inside, and curtains.
## `wall` L/R/B picks the outward direction; `pos` runs along the wall (z for L and R, x for B).
func _window_real(c: Vector3, wall: String, pos: float, w: float, wh: float) -> void:
	var yaw := 0.0
	var at := Vector3.ZERO
	match wall:
		"L":
			yaw = -PI * 0.5
			at = c + Vector3(-2.4, 0, pos)
		"R":
			yaw = PI * 0.5
			at = c + Vector3(2.4, 0, pos)
		_:
			yaw = 0.0
			at = c + Vector3(pos, 0, 2.35)
	var cy := WINDOW_SILL + wh * 0.5
	var B := Basis(Vector3.UP, yaw)
	var put := func(key: String, local: Vector3, size: Vector3):
		bx(key, at + B * Vector3(local.x, cy + local.y, local.z), size, yaw)
	var t := 0.06
	# reveal: the thickness of the wall lined all round the opening
	put.call(M_TRIM, Vector3(-w * 0.5 + 0.015, 0, 0), Vector3(0.03, wh, 0.23))
	put.call(M_TRIM, Vector3(w * 0.5 - 0.015, 0, 0), Vector3(0.03, wh, 0.23))
	put.call(M_TRIM, Vector3(0, wh * 0.5 - 0.015, 0), Vector3(w, 0.03, 0.23))
	put.call(M_TRIM, Vector3(0, -wh * 0.5 + 0.015, 0), Vector3(w, 0.03, 0.23))
	# the frame, set in the middle of the wall
	put.call(M_TRIM, Vector3(0, wh * 0.5 - t * 0.5 - 0.03, 0), Vector3(w - 0.06, t, 0.07))
	put.call(M_TRIM, Vector3(0, -wh * 0.5 + t * 0.5 + 0.03, 0), Vector3(w - 0.06, t, 0.07))
	put.call(M_TRIM, Vector3(-w * 0.5 + t * 0.5 + 0.03, 0, 0), Vector3(t, wh - 0.06, 0.07))
	put.call(M_TRIM, Vector3(w * 0.5 - t * 0.5 - 0.03, 0, 0), Vector3(t, wh - 0.06, 0.07))
	# glass: one clear pane per sash (upper and lower), with the meeting rail and muntins between and across
	var gw := w - 2.0 * t - 0.06
	var gh := wh - 2.0 * t - 0.06
	put.call(M_GLASS, Vector3(0, gh * 0.25 + 0.01, 0), Vector3(gw, gh * 0.5 - 0.02, 0.012))
	put.call(M_GLASS, Vector3(0, -gh * 0.25 - 0.01, 0), Vector3(gw, gh * 0.5 - 0.02, 0.012))
	put.call(M_TRIM, Vector3(0, 0, 0.005), Vector3(gw, 0.045, 0.055))                    # meeting rail
	put.call(M_TRIM, Vector3(0, 0, 0.005), Vector3(0.035, gh, 0.05))                     # centre muntin
	if w > 1.3:
		for fx in [-0.25, 0.25]:
			put.call(M_TRIM, Vector3(w * fx, 0, 0.005), Vector3(0.03, gh, 0.045))
	# outside: casing round the opening, a drip cap over it, and a sill that projects with an apron under it
	put.call(M_TRIM, Vector3(-w * 0.5 - 0.05, 0, 0.125), Vector3(0.1, wh + 0.14, 0.04))
	put.call(M_TRIM, Vector3(w * 0.5 + 0.05, 0, 0.125), Vector3(0.1, wh + 0.14, 0.04))
	put.call(M_TRIM, Vector3(0, wh * 0.5 + 0.07, 0.14), Vector3(w + 0.26, 0.09, 0.07))
	put.call(M_TRIM, Vector3(0, -wh * 0.5 - 0.03, 0.17), Vector3(w + 0.2, 0.05, 0.16))
	put.call(M_TRIM, Vector3(0, -wh * 0.5 - 0.1, 0.12), Vector3(w + 0.1, 0.1, 0.03))
	# inside: a stool (the inner sill), casing, a curtain rod and two curtains that leave the middle open
	put.call(M_TRIM, Vector3(0, -wh * 0.5 - 0.01, -0.17), Vector3(w + 0.14, 0.04, 0.12))
	put.call(M_TRIM, Vector3(0, wh * 0.5 + 0.1, -0.15), Vector3(w + 0.3, 0.025, 0.025))
	for sx in [-1.0, 1.0]:
		put.call(M_FABRIC, Vector3(sx * (w * 0.5 - 0.1), -0.02, -0.16), Vector3(0.22, wh + 0.1, 0.03))

## A wall window built for the wall it sits in: a shallow painted frame, mullions and a glass pane set a hair proud of the wall face
## (never coplanar with it), and a sill. `at` is the middle of the window on the wall's outer face; `yaw` turns +Z to the outward normal.
func _window(at: Vector3, yaw: float, w: float, h: float, hung := true) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var t := 0.07
	var parts := [
		[M_TRIM, Vector3(0, h * 0.5 - t * 0.5, 0.03), Vector3(w, t, 0.06)],
		[M_TRIM, Vector3(0, -h * 0.5 + t * 0.5, 0.03), Vector3(w, t, 0.06)],
		[M_TRIM, Vector3(-w * 0.5 + t * 0.5, 0, 0.03), Vector3(t, h - 2.0 * t, 0.06)],
		[M_TRIM, Vector3(w * 0.5 - t * 0.5, 0, 0.03), Vector3(t, h - 2.0 * t, 0.06)],
		[M_GLASS, Vector3(0, 0, 0.012), Vector3(w - 2.0 * t + 0.02, h - 2.0 * t + 0.02, 0.01)],
		[M_TRIM, Vector3(0, 0, 0.028), Vector3(0.03, h - 2.0 * t, 0.044)],
		[M_TRIM, Vector3(0, -h * 0.5 - 0.02, 0.07), Vector3(w + 0.14, 0.04, 0.14)]]
	if hung:
		parts.append([M_TRIM, Vector3(0, 0.02, 0.028), Vector3(w - 2.0 * t, 0.04, 0.044)])
	for p in parts:
		bx(p[0], at + basis * p[1], p[2], yaw)

func _gable_roof(center: Vector3, key: String, w: float, d: float, h: float, rise: float) -> void:
	var prof := PackedVector2Array([Vector2(-d * 0.5, 0), Vector2(d * 0.5, 0), Vector2(d * 0.5, 0.12), Vector2(0, rise + 0.12), Vector2(-d * 0.5, 0.12)])
	MeshKit.extrude_into(soup(key), prof, w, Transform3D(Basis(), center + Vector3(0, h, 0)))   # ridge along X
	bx(M_TRIM, center + Vector3(0, h + 0.02, -d * 0.5), Vector3(w + 0.1, 0.18, 0.06))
	bx(M_TRIM, center + Vector3(0, h + 0.02, d * 0.5), Vector3(w + 0.1, 0.18, 0.06))
	var gable := PackedVector2Array([Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(0, rise)])
	for x in [-2.42, 2.42]:
		MeshKit.extrude_into(soup(M_SIDING if key != "CorrugatedRed" else "Corrugated"), gable, 0.18, Transform3D(Basis(Vector3.UP, 0.0), center + Vector3(x, h - 0.02, 0)))

func _sign(parent: Node3D, tex_key: String, pos: Vector3, size: Vector2, yaw := 0.0) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshKit.inst(parent, q, _material(tex_key), pos, Vector3(0, yaw, 0))
	mi.set_meta("art", true)

func _office() -> void:
	var c: Vector3 = game.OFFICE_POS
	_walls(c, M_SIDING, M_DRYWALL, 2.8, [["L", -0.35, 1.1, 1.3], ["L", 1.55, 1.1, 1.3], ["R", -1.45, 1.1, 1.3], ["R", 0.45, 1.1, 1.3], ["B", 1.8, 1.6, 1.4]])
	_gable_roof(c, "CorrugatedRed", 5.6, 5.6, 2.8, 1.1)
	quad_flat(M_LINO, c, Vector2(4.6, 4.5), 0.0, 0.165)
	_sign(root, "Sign_Office", c + Vector3(0, 2.5, -2.51), Vector2(2.2, 0.55), PI)
	prop(P_WALL_LAMP, c + Vector3(1.0, 2.3, -2.5), PI)
	light(c + Vector3(0, 2.4, 0.3), Color(1.0, 0.86, 0.62), 1.1, 6.0)
	# interior: the management desk keeps its collision; the THE VEIL desk + computer sits on it
	prop(P_DESK, c + Vector3(0, 0.16, 1.4), PI)
	prop(P_CHAIR, c + Vector3(0.1, 0.16, 1.95), PI)
	prop(P_FILING, c + Vector3(-1.95, 0.16, 1.85), PI * 0.5)
	prop(P_DOCS, c + Vector3(-1.95, 0.16, 0.9), PI * 0.5)
	prop(P_CLOCK, c + Vector3(1.4, 2.1, 2.2), PI)
	prop(P_CALENDAR, c + Vector3(2.22, 1.4, 1.2), -PI * 0.5)
	prop(P_WAITING, c + Vector3(1.85, 0.16, -0.6), -PI * 0.5)
	solid("Office cabinets", c + Vector3(-1.95, 0.6, 1.4), Vector3(0.6, 1.2, 1.4))
	# break area

## The player's small house by the garage: a bed to sleep in once the day is done (see main.try_sleep).
func _home() -> void:
	var c: Vector3 = game.HOME_POS
	_walls(c, M_SIDING, M_DRYWALL, 2.8, [["R", -1.45, 1.1, 1.3], ["R", 0.45, 1.1, 1.3], ["L", 0.55, 1.1, 1.3]])
	_gable_roof(c, "Corrugated", 5.6, 5.6, 2.8, 1.0)
	quad_flat(M_LINO, c, Vector2(4.6, 4.5), 0.0, 0.165)
	_sign(root, "Sign_Home", c + Vector3(0, 2.5, -2.51), Vector2(1.4, 0.35), PI)
	prop(P_WALL_LAMP, c + Vector3(-1.0, 2.3, -2.5), PI)
	light(c + Vector3(0, 2.4, 0.3), Color(1.0, 0.84, 0.58), 1.0, 6.0)
	# bed in the back-left corner (collision body "Bed" is built by main), bedside table with a lamp
	bx(M_WOOD, c + Vector3(-1.3, 0.3, 1.3), Vector3(1.0, 0.28, 2.0))
	bx(M_WOOD, c + Vector3(-1.3, 0.75, 2.27), Vector3(1.04, 0.9, 0.08))               # headboard
	MeshKit.inst(root, MeshKit.box(Vector3(0.96, 0.18, 1.9)), MeshKit.flat(Color(0.88, 0.85, 0.76)), c + Vector3(-1.3, 0.54, 1.3))   # mattress
	MeshKit.inst(root, MeshKit.box(Vector3(0.9, 0.08, 1.3)), MeshKit.flat(Color(0.27, 0.46, 0.50)), c + Vector3(-1.3, 0.67, 0.95))   # blanket
	MeshKit.inst(root, MeshKit.box(Vector3(0.6, 0.12, 0.34)), MeshKit.flat(Color(0.96, 0.95, 0.9)), c + Vector3(-1.3, 0.67, 2.0))    # pillow
	bx(M_WOOD, c + Vector3(-0.35, 0.3, 2.05), Vector3(0.4, 0.6, 0.4))
	MeshKit.inst(root, MeshKit.frustum(0.09, 0.07, 0.22), MeshKit.flat(Color(1.0, 0.9, 0.6), 1.2), c + Vector3(-0.35, 0.6, 2.05))
	light(c + Vector3(-0.35, 0.95, 2.0), Color(1.0, 0.85, 0.55), 0.7, 3.0)
	prop(P_CLOCK, c + Vector3(1.4, 2.1, 2.2), PI)
	prop(P_SHELF, c + Vector3(1.9, 0.16, 1.5), -PI * 0.5)
	prop(P_BOXES, c + Vector3(1.6, 0.16, -1.2), 0.4)

## The tool shed: its own little building for upgrading the player's tools and vehicles. The workbench stands against the back wall
## (built by main), shelves and a toolchest sit against the side walls, and the doorway and the floor in front of it stay clear.
func _toolshed() -> void:
	var c: Vector3 = game.TOOLSHED_POS
	_walls(c, M_SIDING, M_DRYWALL, 2.8, [["L", -0.6, 1.0, 1.2], ["L", 0.9, 1.0, 1.2], ["R", -0.6, 1.0, 1.2], ["R", 0.9, 1.0, 1.2]])
	_gable_roof(c, "Corrugated", 5.6, 5.6, 2.8, 0.9)
	quad_flat(M_LINO, c, Vector2(4.6, 4.5), 0.0, 0.165)
	_sign(root, "Sign_Upgrades", c + Vector3(0, 2.5, -2.51), Vector2(1.6, 0.4), PI)
	prop(P_WALL_LAMP, c + Vector3(1.0, 2.3, -2.5), PI)
	light(c + Vector3(0, 2.4, 0.2), Color(1.0, 0.88, 0.66), 1.1, 6.0)
	prop(P_SHELF, c + Vector3(-2.0, 0.16, 0.3), PI * 0.5)
	prop(P_BOXES, c + Vector3(1.9, 0.16, 0.3), -PI * 0.5)
	solid("Tool shed shelving", c + Vector3(-2.0, 0.9, 0.3), Vector3(0.6, 1.8, 1.4))
	solid("Tool shed boxes", c + Vector3(1.9, 0.5, 0.3), Vector3(0.7, 1.0, 1.0))

func _shed() -> void:
	var c: Vector3 = game.SHED_POS
	_walls(c, "Corrugated", M_BASEMENT)
	_gable_roof(c, "CorrugatedRed", 5.6, 5.6, 2.8, 0.7)
	quad_flat(M_BASEMENT, c, Vector2(4.6, 4.5), 0.0, 0.165)
	bx("Corrugated", c + Vector3(0, 2.45, -2.42), Vector3(1.5, 0.7, 0.06))                # rolled-up door
	bx("SteelPlate", c + Vector3(0, 2.82, -2.45), Vector3(1.6, 0.14, 0.16))
	_sign(root, "Sign_Storage", c + Vector3(1.6, 2.4, -2.48), Vector2(1.2, 0.3), PI)
	prop(P_SHELF, c + Vector3(-1.9, 0.16, 1.4), PI * 0.5)
	prop(P_SHELF, c + Vector3(1.9, 0.16, 1.4), -PI * 0.5)
	prop(P_PALLETS, c + Vector3(1.4, 0.16, -1.2))
	prop(P_BOXES, c + Vector3(-1.5, 0.16, -1.3), 0.4)
	solid("Shed shelving", c + Vector3(-1.9, 0.9, 1.4), Vector3(0.6, 1.8, 1.4))
	solid("Shed shelving", c + Vector3(1.9, 0.9, 1.4), Vector3(0.6, 1.8, 1.4))
	light(c + Vector3(0, 2.4, 0), Color(0.95, 0.9, 0.75), 0.8, 5.0)

## Open-front equipment garage over the parking bays: steel frame, corrugated walls and roof,
## workbench, shelving and clutter along the walls (clear of the bays).
var garage_roof: MeshInstance3D

func _garage() -> void:
	var ox: float = game.GARAGE_DX
	var x0 := -4.7 + ox
	var x1 := 14.5 + ox
	var z0 := 14.9
	var z1 := 22.4
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	# The back wall has a big service door (see scripts/delivery.gd): deliveries and new hires come in through it.
	var gdx: float = QuarryDelivery.DOOR_X + ox
	var dx0: float = gdx - QuarryDelivery.DOOR_W * 0.5
	var dx1: float = gdx + QuarryDelivery.DOOR_W * 0.5
	for seg in [[x0, dx0], [dx1, x1]]:
		var sc: float = (float(seg[0]) + float(seg[1])) * 0.5
		var sw: float = float(seg[1]) - float(seg[0])
		solid("Garage back wall", Vector3(sc, 2.0, z1), Vector3(sw, 4.0, 0.25))
		bx("Corrugated", Vector3(sc, 3.0, z1), Vector3(sw, 6.0, 0.2))
		bx(M_FOUNDATION, Vector3(sc, 0.2, z1), Vector3(sw + 0.1, 0.4, 0.3))
	bx("Corrugated", Vector3(gdx, 5.0, z1), Vector3(QuarryDelivery.DOOR_W + 0.4, 2.0, 0.2))   # wall over the door
	for dxp in [dx0 - 0.1, dx1 + 0.1]:
		bx("SteelGreen", Vector3(dxp, 3.0, z1 + 0.02), Vector3(0.25, 6.0, 0.34))
	bx("Hazard", Vector3(gdx, 3.65, z1 - 0.12), Vector3(QuarryDelivery.DOOR_W, 0.16, 0.04))
	solid("Garage wall", Vector3(x0, 2.0, (z0 + z1) * 0.5), Vector3(0.25, 4.0, z1 - z0))
	solid("Garage wall", Vector3(x1, 2.0, (z0 + z1) * 0.5), Vector3(0.25, 4.0, z1 - z0))
	bx("Corrugated", Vector3(x0, 3.0, (z0 + z1) * 0.5), Vector3(0.2, 6.0, z1 - z0))
	bx("Corrugated", Vector3(x1, 3.0, (z0 + z1) * 0.5), Vector3(0.2, 6.0, z1 - z0))
	for x in [x0, x1]:
		bx(M_FOUNDATION, Vector3(x, 0.2, (z0 + z1) * 0.5), Vector3(0.3, 0.4, z1 - z0))
	# steel frame: front columns, I-beam, roof trusses
	for x in [x0, x0 + w / 3.0, x0 + 2.0 * w / 3.0, x1]:
		bx("SteelGreen", Vector3(x, 3.25, z0 + 0.1), Vector3(0.22, 6.5, 0.22))
		bx("SteelGreen", Vector3(x, 6.35, (z0 + z1) * 0.5), Vector3(0.18, 0.3, z1 - z0))   # truss
	bx("SteelGreen", Vector3(cx, 6.45, z0 + 0.1), Vector3(w + 0.3, 0.35, 0.3))
	var roof := PackedVector2Array([Vector2(z0 - 0.6, 6.6), Vector2(z1 + 0.3, 6.15), Vector2(z1 + 0.3, 6.27), Vector2(z0 - 0.6, 6.72)])
	var roof_soup := MeshKit.Soup.new()
	MeshKit.extrude_into(roof_soup, roof, w + 0.6, Transform3D(Basis(), Vector3(cx, 0, 0)))
	garage_roof = MeshKit.inst(root, roof_soup.mesh(), _material("Corrugated"))   # its own node: hidden while a vehicle is driven inside
	bx("Hazard", Vector3(cx, 6.45, z0 - 0.07), Vector3(w + 0.3, 0.12, 0.02))
	_sign(root, "Sign_Garage", Vector3(cx, 6.95, z0 - 0.02), Vector2(4.0, 0.5), PI)
	_sign(root, "Sign_Safety", Vector3(x0 - 0.13, 2.6, z0 + 1.6), Vector2(1.5, 0.5), -PI * 0.5)
	# workshop along the walls
	prop(P_WORKBENCH, Vector3(x0 + 0.55, 0.0, 19.6), PI * 0.5)
	prop(P_TOOLBOX, Vector3(x0 + 0.5, 0.95, 19.2), PI * 0.5)
	prop(P_SHELF, Vector3(x0 + 0.4, 0.0, 21.5), PI * 0.5)
	prop(P_SHELF, Vector3(11.8 + ox, 0.0, z1 - 0.4), PI)
	prop(P_SHELF, Vector3(5.2 + ox, 0.0, z1 - 0.4), PI)
	prop(P_ELEC, Vector3(9.8 + ox, 0.0, z1 - 0.35), PI)
	prop(P_BOXES, Vector3(14.0 + ox, 0.0, 21.6), -PI * 0.5)
	prop(P_BIN, Vector3(14.0 + ox, 0.0, 17.2), -PI * 0.5)
	prop(P_CONE, Vector3(x0 + 0.6, 0.0, 16.8))
	prop(P_CONE, Vector3(x0 + 1.0, 0.0, 17.2))
	for k in range(3):                                                                   # oil drums
		MeshKit.frustum_into(soup("PaintRed" if k != 1 else "SteelGreen"), Vector3(13.7 + ox - 0.6 * (k % 2), 0, 19.0 + 0.62 * k), 0.29, 0.29, 0.88, 8)
	solid("Garage shelving", Vector3((dx1 + x1) * 0.5, 0.9, z1 - 0.45), Vector3(x1 - dx1 - 0.4, 1.8, 0.6))       # behind the bays, clear of the door
	solid("Garage workbench", Vector3(x0 + 0.5, 0.5, 20.2), Vector3(0.75, 1.0, 3.6))
	solid("Garage drums", Vector3(13.6 + ox, 0.45, 19.6), Vector3(0.9, 0.9, 1.9))
	light(Vector3(cx - 5, 5.6, 19.0), Color(0.9, 0.95, 1.0), 1.2, 9.0)
	light(Vector3(cx + 5, 5.6, 19.0), Color(0.9, 0.95, 1.0), 1.2, 9.0)

## The operations yard and the quarry are two places. The yard is grey gravel ground inside a fence along its north edge; the only way
## out to the quarry is the gate in the middle of that fence, which opens onto a gravel haul road running north into Area 1. Outside
## the fence the ground is raw quarry dirt. The fence has colliders (so nothing walks or drives through it) and a gap for the gate.
const FENCE_Z := -6.35
const GATE_HALF := 4.8
func _yard_boundary() -> void:
	if game.blueprint:
		_yard_boundary_blueprint()
		return
	var hub: Rect2 = game.hub_rect()
	quad_flat(M_GRAVEL, Vector3(hub.get_center().x, 0, hub.get_center().y), hub.size, 0.0, 0.068)                    # the yard's own ground
	quad_flat(M_GRAVEL, Vector3(0, 0, FENCE_Z - 11.0), Vector2(7.0, 22.0), 0.0, 0.066)              # the haul road beyond the gate
	var x0 := hub.position.x
	var x1 := hub.end.x
	for side in [-1.0, 1.0]:
		var a: float = GATE_HALF if side > 0.0 else x0
		var b: float = x1 if side > 0.0 else -GATE_HALF
		solid("Yard fence", Vector3((a + b) * 0.5, 0.7, FENCE_Z), Vector3(b - a, 1.4, 0.2))
		var x: float = a
		while x <= b + 0.01:
			bx("SteelPlate", Vector3(x, 0.7, FENCE_Z), Vector3(0.14, 1.4, 0.14))                         # posts every 3 m
			x += 3.0
		bx(M_WOOD, Vector3((a + b) * 0.5, 1.15, FENCE_Z), Vector3(b - a, 0.07, 0.07))                    # two rails
		bx(M_WOOD, Vector3((a + b) * 0.5, 0.65, FENCE_Z), Vector3(b - a, 0.07, 0.07))
	for side in [-1.0, 1.0]:                                                                                # the gate: two tall posts with hazard bands, a lintel and the sign
		bx("SteelGreen", Vector3(side * GATE_HALF, 1.7, FENCE_Z), Vector3(0.4, 3.4, 0.4))
		bx("Hazard", Vector3(side * GATE_HALF, 0.55, FENCE_Z - 0.21), Vector3(0.4, 0.8, 0.02), PI)
	bx("SteelGreen", Vector3(0, 3.25, FENCE_Z), Vector3(GATE_HALF * 2.0 + 0.4, 0.3, 0.3))
	_sign(root, "Sign_Safety", Vector3(0, 3.25, FENCE_Z - 0.17), Vector2(2.6, 0.85), PI)
	_sign(root, "Sign_Safety", Vector3(0, 3.25, FENCE_Z + 0.17), Vector2(2.6, 0.85), 0.0)

## A fence run between two points on the ground (x, z): collision box, steel posts every 3 m and two rails. Industrial fencing, not walls.
func _fence_line(a: Vector2, b: Vector2, collide := true, height := 1.4) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.2:
		return
	var yaw := atan2(d.x, d.y) - PI * 0.5            # the box's long axis (x) along the line
	var c := (a + b) * 0.5
	if collide:
		solid("Yard fence", Vector3(c.x, height * 0.5, c.y), Vector3(len, height, 0.2), -atan2(d.y, d.x))
	var n := int(ceil(len / 3.0))
	for i in range(n + 1):
		var p := a + d * (float(i) / float(n))
		bx("SteelPlate", Vector3(p.x, height * 0.5, p.y), Vector3(0.14, height, 0.14))
	var ang := -atan2(d.y, d.x)
	bx(M_WOOD, Vector3(c.x, height * 0.82, c.y), Vector3(len, 0.07, 0.07), ang)
	bx(M_WOOD, Vector3(c.x, height * 0.46, c.y), Vector3(len, 0.07, 0.07), ang)

func _pads() -> void:
	var ox: float = game.GARAGE_DX
	quad_flat(M_CONCRETE, Vector3(5.0 + ox, 0, 18.7), Vector2(19.6, 7.6), 0.0, 0.075)         # garage slab
	quad_flat(M_CONCRETE, game.OFFICE_POS, Vector2(6.4, 6.4), 0.0, 0.075)
	quad_flat(M_CONCRETE, game.SHED_POS, Vector2(6.0, 6.0), 0.0, 0.075)
	quad_flat(M_CONCRETE, game.TOOLSHED_POS, Vector2(6.0, 6.0), 0.0, 0.075)
	quad_flat(M_CONCRETE, game.HOME_POS, Vector2(6.0, 6.0), 0.0, 0.075)
	for slot in game.fleet.cfg.get("parking", []):                                        # painted bay lines
		for side in [-1.4, 1.4]:
			quad_flat("Hazard", Vector3(float(slot[0]) + side, 0, float(slot[2])), Vector2(0.12, 4.2), 0.0, 0.115)

## The blueprint world's surroundings: ground beside the yard, the yard's roads, the quarry's industrial fence, the mountain range to the north,
## and the mountain the west tunnel runs into. (The quarry's own surface is drawn by the pit zone; forests by the landscape.)
func _blueprint_world() -> void:
	var grass := "res://THE_VEIL_ASSETS_V2/Materials_Godot/Ground/M_Grnd_GrassDry.tres"     # dry grass around the property, bare soil inside the quarry fence
	quad_flat(grass, Vector3(0, 0, 36.0), Vector2(400.0, 88.0), 0.0, 0.02)
	quad_flat(grass, Vector3(-180.0, 0, -58.0), Vector2(40.0, 100.0), 0.0, 0.02)
	quad_flat(grass, Vector3(180.0, 0, -58.0), Vector2(40.0, 100.0), 0.0, 0.02)
	quad_flat(grass, Vector3(0, 0, -176.0), Vector2(420.0, 134.0), 0.0, 0.02)          # the land beyond the quarry up to the mountain range (no sky showing through)
	_land_detail()
	_pads()
	# yard roads: the central road from the quarry gate, the cross road, the west road down to the service lane behind the garage, the lane itself
	quad_flat(M_ASPHALT, Vector3(0, 0, 2.0), Vector2(7.0, 20.0), 0.0, 0.071)
	quad_flat(M_ASPHALT, Vector3(0, 0, 11.5), Vector2(47.0, 6.0), 0.0, 0.071)
	quad_flat(M_ASPHALT, Vector3(-19.5, 0, 20.5), Vector2(6.0, 18.0), 0.0, 0.071)
	quad_flat(M_ASPHALT, Vector3(-6.75, 0, 25.4), Vector2(33.5, 5.0), 0.0, 0.071)
	for z in [-5.0, 2.0, 9.0]:                                                           # centre dashes on the gate road
		quad_flat("Hazard", Vector3(0, 0, z), Vector2(0.16, 2.0), 0.0, 0.074)
	# the quarry's industrial fence (the south side, with the central gate, is _yard_boundary)
	var fx := 126.0
	var fz0 := -108.0
	var fz1 := -8.0
	_fence_line(Vector2(-fx, fz1), Vector2(-fx, fz0), false, 2.0)
	_fence_line(Vector2(fx, fz1), Vector2(fx, fz0), false, 2.0)
	_fence_line(Vector2(-fx, fz0), Vector2(fx, fz0), false, 2.0)
	# the mountain range to the north: not interactable, only seen
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var rs := MeshKit.Soup.new()
	for i in range(22):
		var x := -200.0 + float(i) * 19.5 + rng.randf_range(-6.0, 6.0)
		var h := rng.randf_range(26.0, 52.0) * (1.0 - 0.45 * absf(x) / 220.0)
		MeshKit.rock_into(rs, Vector3(x, -2.0, rng.randf_range(-170.0, -140.0)), Vector3(rng.randf_range(44.0, 70.0), h, rng.randf_range(36.0, 52.0)), 400 + i, 4, 8)
	for i in range(14):
		var x2 := -190.0 + float(i) * 29.0 + rng.randf_range(-8.0, 8.0)
		MeshKit.rock_into(rs, Vector3(x2, -2.0, rng.randf_range(-128.0, -118.0)), Vector3(rng.randf_range(30.0, 46.0), rng.randf_range(8.0, 15.0), rng.randf_range(16.0, 24.0)), 500 + i, 3, 7)
	var rock_mat := _mountain_material()
	MeshKit.inst(root, rs.mesh(), rock_mat).name = "NorthRange"
	# the west mountain with the tunnel: rock masses beside and above the tunnel (its own walls and roof are built by the delivery system)
	var ms := MeshKit.Soup.new()
	MeshKit.rock_into(ms, Vector3(-62.0, -1.0, 6.0), Vector3(74.0, 26.0, 40.0), 611, 4, 8)
	MeshKit.rock_into(ms, Vector3(-66.0, -1.0, 52.0), Vector3(80.0, 30.0, 50.0), 612, 4, 8)
	MeshKit.rock_into(ms, Vector3(-38.0, 5.2, 25.4), Vector3(34.0, 12.0, 16.0), 613, 3, 7)
	MeshKit.rock_into(ms, Vector3(-86.0, -1.0, 27.0), Vector3(40.0, 20.0, 30.0), 614, 3, 7)
	MeshKit.inst(root, ms.mesh(), rock_mat).name = "TunnelMountain"

## The strata rock of the mountains, a touch darker and warmer than the quarry cliffs so the range reads as distant hills rather than pale boulder piles.
func _mountain_material() -> Material:
	var base := MeshKit.mat("CliffStrata")
	if base is StandardMaterial3D:
		var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = Color(0.66, 0.58, 0.48)
		return m
	return base

## Scatter on the land around the property: grass tufts, dark and pale patches, stones and pebbles, drawn as four instanced batches (one draw call each).
## Kept off the yard, the roads, the quarry and the tunnel mouth.
func _land_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var tuft := MeshKit.Soup.new()
	for bl in range(7):
		var a := rng.randf() * TAU
		MeshKit.frustum_into(tuft, Vector3(cos(a) * rng.randf_range(0.05, 0.45), 0.0, sin(a) * rng.randf_range(0.05, 0.45)), 0.08, 0.008, rng.randf_range(0.4, 0.95), 4)
	var stone := MeshKit.Soup.new()
	MeshKit.rock_into(stone, Vector3.ZERO, Vector3(1.0, 0.6, 1.0), 31, 3, 6)
	var pebbles := MeshKit.Soup.new()
	for pk in range(5):
		MeshKit.rock_into(pebbles, Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6)), Vector3(0.25, 0.15, 0.22), 50 + pk, 2, 5)
	var patch := MeshKit.Soup.new()
	for k in range(9):
		var a0 := float(k) / 9.0 * TAU
		var a1 := float(k + 1) / 9.0 * TAU
		patch.tri(Vector3.ZERO, Vector3(sin(a0) * (1.0 + 0.25 * sin(a0 * 3.0)), 0.0, cos(a0) * (1.0 + 0.25 * sin(a0 * 3.0))), Vector3(sin(a1) * (1.0 + 0.25 * sin(a1 * 3.0)), 0.0, cos(a1) * (1.0 + 0.25 * sin(a1 * 3.0))))
	var hub: Rect2 = game.hub_rect()
	# kind: [mesh, base colour, spread, count, scale range, lift]
	var kinds := [
		[tuft.mesh(), Color(0.56, 0.58, 0.3), 0.22, 900, Vector2(0.8, 1.7), 0.0],
		[patch.mesh(), Color(0.5, 0.42, 0.27), 0.16, 260, Vector2(1.2, 3.2), 0.03],
		[stone.mesh(), Color(0.6, 0.57, 0.5), 0.22, 150, Vector2(0.6, 1.6), -0.05],
		[pebbles.mesh(), Color(0.55, 0.5, 0.42), 0.25, 260, Vector2(0.9, 1.8), 0.0],
	]
	for ki in range(kinds.size()):
		var kd: Array = kinds[ki]
		var xfs: Array = []
		var tints: Array = []
		var tries := 0
		while xfs.size() < int(kd[3]) and tries < 6000:
			tries += 1
			var p := Vector2(rng.randf_range(-196.0, 196.0), rng.randf_range(-112.0, 78.0))
			if p.x > -131.0 and p.x < 131.0 and p.y > -112.0 and p.y < -4.0:
				continue                       # inside / at the quarry fence
			if hub.grow(4.0).has_point(p) or (p.x > -70.0 and p.x < -20.0 and p.y > 16.0 and p.y < 36.0):
				continue                       # the yard, and the service lane + tunnel approach
			if p.x > 24.0 and p.x < 56.0 and p.y > -4.0 and p.y < 30.0:
				continue                       # the east extension
			var sc: float = rng.randf_range(float(kd[4].x), float(kd[4].y))
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc if ki != 1 else 1.0, sc))
			xfs.append(Transform3D(basis, Vector3(p.x, float(kd[5]), p.y)))
			var bc: Color = kd[1]
			var f := rng.randf_range(1.0 - float(kd[2]), 1.0 + float(kd[2]))
			tints.append(Color(clampf(bc.r * f, 0.0, 1.0), clampf(bc.g * f, 0.0, 1.0), clampf(bc.b * f, 0.0, 1.0)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = kd[0]
		mm.instance_count = xfs.size()
		for q in range(xfs.size()):
			mm.set_instance_transform(q, xfs[q])
			mm.set_instance_color(q, tints[q])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "LandDetail%d" % ki
		mmi.material_override = QuarryFormation._decor_material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 140.0
		root.add_child(mmi)

## The blueprint yard's dressing: a few lamps, the dumpster and cones, drums by the garage. (The old yard's scatter of mounds, scree and brush
## is gone: the yard is gravel and buildings; everything green lives in the quarry and the forest.)
func _site_props_blueprint() -> void:
	for p in [Vector3(-21.0, 0, 8.0), Vector3(21.0, 0, 22.0), Vector3(-4.0, 0, 27.6), Vector3(21.0, 0, 2.0)]:
		prop(P_POLE, p, 0.0)
		solid("Light pole", p + Vector3(0, 2.0, 0), Vector3(0.35, 4.0, 0.35))
		light(p + Vector3(0, 6.0, 0), Color(1.0, 0.82, 0.55), 1.4, 14.0)
	prop(P_DUMPSTER, Vector3(9.5, 0, 24.2), PI * 0.5)
	solid("Dumpster", Vector3(9.5, 0.65, 24.2), Vector3(1.2, 1.3, 2.0))
	for p in [Vector3(-5.6, 0, -6.6), Vector3(5.6, 0, -6.6), Vector3(-12.0, 0, 25.0)]:
		prop(P_CONE, p)
	prop(P_BARRIER, Vector3(-13.5, 0, 9.0), 0.2)
	prop(P_JUNCTION, Vector3(-21.8, 0.9, 14.0), -PI * 0.5)
	prop(P_GRAVEL, Vector3(21.0, 0, 6.0), 0.0, 1.0)

## The blueprint yard's boundary: the fence along the quarry's whole south edge (252 m, with the one central vehicle gate), the yard's own west,
## east and south fences (gaps: the tunnel gate in the west, the east extension's gate), the yard's gravel and the gate posts.
func _yard_boundary_blueprint() -> void:
	var hub: Rect2 = game.hub_rect()
	quad_flat(M_GRAVEL, Vector3(hub.get_center().x, 0, hub.get_center().y), hub.size, 0.0, 0.068)
	quad_flat(M_GRAVEL, Vector3(0, 0, -16.0), Vector2(7.0, 16.0), 0.0, 0.066)                  # the road onto the quarry surface
	var fz := -8.0
	var fx := 126.0
	_fence_line(Vector2(-fx, fz), Vector2(-GATE_HALF, fz), true, 2.0)
	_fence_line(Vector2(GATE_HALF, fz), Vector2(fx, fz), true, 2.0)
	var x0 := hub.position.x
	var x1 := hub.end.x
	var z1 := hub.end.y
	_fence_line(Vector2(x0, fz), Vector2(x0, 21.3), true, 1.6)               # west, down to the tunnel gate
	_fence_line(Vector2(x0, z1), Vector2(x1, z1), true, 1.6)                 # south
	_fence_line(Vector2(x1, fz), Vector2(x1, z1), true, 1.6)                 # east: ONE closed fence. The old gate at z 9..15 led out to open woodland with nothing in it
	# the old gap is a locked service gate now: two posts, a hazard-striped panel and a sign, with the fence's collider behind it
	for gz in [9.0, 15.0]:
		bx("SteelGreen", Vector3(x1, 1.5, gz), Vector3(0.3, 3.0, 0.3))
	bx("Hazard", Vector3(x1, 1.2, 12.0), Vector3(0.08, 1.2, 5.6))
	bx("SteelGreen", Vector3(x1, 2.4, 12.0), Vector3(0.12, 0.12, 5.8))
	_sign(root, "Sign_Safety", Vector3(x1 + 0.1, 1.7, 12.0), Vector2(2.0, 0.65), PI * 0.5)
	_sign(root, "Sign_Safety", Vector3(x1 - 0.1, 1.7, 12.0), Vector2(2.0, 0.65), -PI * 0.5)
	for side in [-1.0, 1.0]:
		bx("SteelGreen", Vector3(side * GATE_HALF, 1.7, fz), Vector3(0.4, 3.4, 0.4))
		bx("Hazard", Vector3(side * GATE_HALF, 0.55, fz - 0.21), Vector3(0.4, 0.8, 0.02), PI)
	bx("SteelGreen", Vector3(0, 3.25, fz), Vector3(GATE_HALF * 2.0 + 0.4, 0.3, 0.3))
	_sign(root, "Sign_Safety", Vector3(0, 3.25, fz - 0.17), Vector2(2.6, 0.85), PI)
	_sign(root, "Sign_Safety", Vector3(0, 3.25, fz + 0.17), Vector2(2.6, 0.85), 0.0)

func _site_props() -> void:
	# Phase 1: the dumpster stands clear of Grandpa's truck (parked at x -21, z 5), which it used to touch
	prop(P_DUMPSTER, Vector3(-16.6, 0, 6.5), PI * 0.5)
	solid("Dumpster", Vector3(-16.6, 0.65, 6.5), Vector3(1.2, 1.3, 2.0))
	if not game.in_hillside_zone(Vector3(-21.2, 0, 0.5), 1.0): # the Phase 6.1 hillside stands here now
		for z in [-2.0, 0.5, 3.0]:
			prop(P_RETAIN, Vector3(-21.2, 0, z), PI * 0.5)
		solid("Retaining wall", Vector3(-21.2, 0.6, 0.5), Vector3(0.4, 1.2, 7.5))
	for p in [Vector3(-22.0, 0, 9.0), Vector3(19.5, 0, 12.5), Vector3(2.0, 0, 23.8)]:
		prop(P_POLE, p, 0.0)
		solid("Light pole", p + Vector3(0, 2.0, 0), Vector3(0.35, 4.0, 0.35))
	light(Vector3(-21.0, 6.0, 9.0), Color(1.0, 0.82, 0.55), 1.4, 14.0)
	light(Vector3(18.8, 6.0, 12.3), Color(1.0, 0.82, 0.55), 1.4, 14.0)
	prop(P_BARRIER, Vector3(-12.0, 0, 7.0), 0.2)
	for p in [Vector3(-9.0, 0, 6.2), Vector3(-9.6, 0, 6.6), Vector3(12.6, 0, 4.4)]:
		prop(P_CONE, p)                                                                   # off the haul road
	prop(P_JUNCTION, Vector3(-16.7, 0.9, 12.8), -PI * 0.5)
	# Phase yard pass: the decorative mounds, scree, grass, dead brush and stump that stood about the yard are gone - they looked like
	# weeds and rubble that could not be cleaned. Only the placed gravel pile and the far-away rocks remain.
	prop(P_GRAVEL, Vector3(15.5, 0, -13.5), 0.0, 1.2)
	for p in [Vector3(46.0, 0, -10.0), Vector3(31.0, 0, 11.0), Vector3(47.0, 0, 11.0)]:
		prop(P_ROCKS, p, p.x, 1.4)

func _atmosphere() -> void:
	var env: Environment = game.sky_light.environment
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.6, 0.55)
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.4

# ------------------------------------------------------------------ dynamic gameplay objects

## Faceted rock formation for a deposit (swaps the placeholder box mesh; scaling/collision stay in main).
func dress_deposit(body: StaticBody3D, info: Dictionary, size: Vector3) -> void:
	var mi: MeshInstance3D = body.get_child(0)
	var s := MeshKit.Soup.new()
	var seed := int(absf(info["pos"].x * 13.0 + info["pos"].z * 7.0))
	if bool(info.get("infinite", false)):
		MeshKit.cliff_into(s, size.x + 0.6, size.y + 0.4, size.z + 0.3, seed, 3, Transform3D(Basis(Vector3.UP, PI), Vector3(0, -size.y * 0.5, 0)))
	else:
		MeshKit.rock_into(s, Vector3(0, -size.y * 0.5, 0), Vector3(size.x * 1.05, size.y * 1.05, size.z * 1.05), seed, 4, 8)
		MeshKit.rock_into(s, Vector3(size.x * 0.32, -size.y * 0.5, size.z * 0.25), Vector3(size.x * 0.55, size.y * 0.7, size.z * 0.6), seed + 1, 3, 6)
		MeshKit.rock_into(s, Vector3(-size.x * 0.35, -size.y * 0.5, -size.z * 0.2), Vector3(size.x * 0.5, size.y * 0.55, size.z * 0.5), seed + 2, 3, 6)
	mi.mesh = s.mesh()
	mi.material_override = _material(ROCK_MAT.get(str(info["resource"]), "RockLimestone"))

## Loose piece: a small faceted chunk (3 shared shapes per material).
func dress_piece(body: StaticBody3D, res: String, idx: int) -> void:
	var key := "%s_%d" % [res, idx % 3]
	if not piece_meshes.has(key):
		piece_meshes[key] = MeshKit.rock(Vector3(0.5, 0.42, 0.46), 900 + idx % 3, 3, 6)
	var mi: MeshInstance3D = body.get_child(0)
	mi.mesh = piece_meshes[key]
	mi.position.y = -0.23
	mi.material_override = _material(ROCK_MAT.get(res, "RockLimestone"))

## Rubble pile mound (Node3D "mound" scaled by main with the pile amount).
func dress_pile(body: StaticBody3D, res: String, seed: int) -> void:
	var mound: Node3D = body.get_meta("mound")
	for c in mound.get_children():
		c.queue_free()
	var s := MeshKit.Soup.new()
	MeshKit.rock_into(s, Vector3.ZERO, Vector3(2.9, 1.0, 2.6), seed, 3, 9)
	for k in range(5):
		var a := TAU * k / 5.0 + 0.4
		MeshKit.rock_into(s, Vector3(cos(a) * 1.0, 0, sin(a) * 0.9), Vector3(0.9, 0.6, 0.8), seed + k + 1, 3, 6)
	MeshKit.inst(mound, s.mesh(), _material(ROCK_MAT.get(res, "RockLimestone")))
	_hide(body)
	mound.visible = true

# ------------------------------------------------------------------ processing machinery
# Builders put one MeshInstance3D per material directly under `parent` (so placement ghosts can tint
# them). `g` = local height of the ground below the parent's origin.

func _parts(parent: Node3D, parts: Dictionary) -> Dictionary:
	MeshKit.repair(parts)
	var out := {}
	for key in parts:
		var s: MeshKit.Soup = parts[key]
		if s.verts.size() > 0:
			out[key] = MeshKit.inst(parent, s.mesh(), _material(key))
	return out

func _strip(parent: Node3D, keep: Array) -> void:
	for c in parent.get_children():
		if c is MeshInstance3D and not keep.has(c):
			c.visible = false

func crusher_model(parent: Node3D, g: float, tier := 1) -> void:
	if tier >= 2:
		advanced_crusher_model(parent, g)
		return
	var p := {"SteelPlate": MeshKit.Soup.new(), "SteelGreen": MeshKit.Soup.new(), "PaintYellow": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new()}
	for x in [-0.68, 0.68]:
		MeshKit.box_into(p["SteelPlate"], Vector3(x, g + 0.08, 0), Vector3(0.16, 0.16, 1.75))           # skids
	MeshKit.box_into(p["SteelGreen"], Vector3(0, g + 0.55, 0), Vector3(1.3, 0.8, 1.25), Vector2(0.94, 0.94))
	MeshKit.box_into(p["Hazard"], Vector3(0, g + 0.2, -0.63), Vector3(1.25, 0.12, 0.02))
	# jaw housing as two cheek plates, open at the front so the moving jaw is visible
	for x in [-0.5, 0.5]:
		MeshKit.box_into(p["PaintYellow"], Vector3(x, g + 1.08, -0.05), Vector3(0.12, 0.32, 1.0))
	MeshKit.box_into(p["PaintYellow"], Vector3(0, g + 1.08, 0.38), Vector3(1.12, 0.32, 0.24))       # fixed jaw (back)
	MeshKit.box_into(p["PaintYellow"], Vector3(0, g + 1.48, 0.28), Vector3(0.82, 0.5, 0.62), Vector2(1.38, 1.4))   # feed hopper (+Z = input)
	MeshKit.box_into(p["SteelPlate"], Vector3(-0.32, g + 1.34, -0.42), Vector3(0.42, 0.3, 0.36))  # motor
	var chute := PackedVector2Array([Vector2(-0.55, 0.42), Vector2(-0.55, 0.32), Vector2(-1.0, 0.08), Vector2(-1.0, 0.18)])
	MeshKit.extrude_into(p["SteelPlate"], chute, 0.9, Transform3D(Basis(), Vector3(0, g, 0)))      # discharge chute (-Z)
	MeshKit.drum_into(p["SteelPlate"], Vector3(0, g + 0.78, 0.05), 0.045, 1.76, 8)                    # flywheel shaft through the housing
	_parts(parent, p)
	var wheels := []
	for x in [-0.78, 0.78]:
		var pivot := Node3D.new()
		pivot.position = Vector3(x, g + 0.78, 0.05)
		parent.add_child(pivot)
		var w := MeshKit.Soup.new()
		MeshKit.drum_into(w, Vector3.ZERO, 0.42, 0.1, 8)
		MeshKit.box_into(w, Vector3.ZERO, Vector3(0.12, 0.08, 0.78))                                # spokes
		MeshKit.box_into(w, Vector3.ZERO, Vector3(0.12, 0.78, 0.08))
		MeshKit.inst(pivot, w.mesh(), _material("SteelPlate"))
		wheels.append(pivot)
	parent.set_meta("flywheels", wheels)
	# swing jaw: pivots at the top on the eccentric shaft, its lower end moves toward the fixed jaw
	var jaw := Node3D.new()
	jaw.position = Vector3(0, g + 1.26, -0.2)
	parent.add_child(jaw)
	var j := MeshKit.Soup.new()
	MeshKit.box_into(j, Vector3(0, -0.2, 0), Vector3(0.82, 0.4, 0.12), Vector2(1.0, 0.9))
	for k in range(4):
		MeshKit.box_into(j, Vector3(-0.3 + 0.2 * k, -0.2, 0.07), Vector3(0.05, 0.36, 0.04))        # wear teeth
	MeshKit.inst(jaw, j.mesh(), _material("SteelPlate"))
	parent.set_meta("jaw", jaw)
	_crusher_fill(parent, g, Vector3(0, 1.62, 0.28), Vector3(0.62, 0.32, 0.5), Vector3(0, 0.18, -1.35), Vector3(0.9, 0.36, 0.8))

## Shared hopper-fill and output-pile meshes, scaled by main with the crusher's real contents.
func _crusher_fill(parent: Node3D, g: float, hop_pos: Vector3, hop_size: Vector3, out_pos: Vector3, out_size: Vector3) -> void:
	var fill := MeshKit.inst(parent, MeshKit.rock(hop_size, 81, 3, 7), _material("RockLimestone"), hop_pos + Vector3(0, g, 0))
	fill.visible = false
	parent.set_meta("hopper_fill", fill)
	var pile := MeshKit.inst(parent, MeshKit.rock(out_size, 82, 3, 8), _material("RockGravel"), out_pos + Vector3(0, g, 0))
	pile.visible = false
	parent.set_meta("output_pile", pile)

## Phase 5 advanced crusher: a cone crusher with a gyrating mantle, belt-driven motor and twin chute.
func advanced_crusher_model(parent: Node3D, g: float) -> void:
	var p := {"SteelPlate": MeshKit.Soup.new(), "SteelGreen": MeshKit.Soup.new(), "PaintOrange": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new()}
	for x in [-0.82, 0.82]:
		MeshKit.box_into(p["SteelPlate"], Vector3(x, g + 0.1, 0), Vector3(0.2, 0.2, 2.0))
	MeshKit.box_into(p["SteelGreen"], Vector3(0, g + 0.42, 0), Vector3(1.7, 0.5, 1.7))
	MeshKit.frustum_into(p["PaintOrange"], Vector3(0, g + 0.67, 0), 0.82, 0.7, 0.7, 10)          # crusher bowl
	MeshKit.frustum_into(p["PaintOrange"], Vector3(0, g + 1.37, 0), 0.7, 0.86, 0.32, 10)         # feed ring
	MeshKit.box_into(p["Hazard"], Vector3(0, g + 0.24, -0.86), Vector3(1.7, 0.14, 0.02))
	MeshKit.box_into(p["SteelPlate"], Vector3(0.95, g + 0.75, 0.55), Vector3(0.45, 0.42, 0.6))    # motor
	MeshKit.box_into(p["SteelGreen"], Vector3(0.95, g + 0.95, 0.1), Vector3(0.12, 0.5, 0.95))     # belt guard
	var chute := PackedVector2Array([Vector2(-0.7, 0.5), Vector2(-0.7, 0.38), Vector2(-1.25, 0.1), Vector2(-1.25, 0.22)])
	MeshKit.extrude_into(p["SteelPlate"], chute, 1.1, Transform3D(Basis(), Vector3(0, g, 0)))
	_parts(parent, p)
	var mantle := Node3D.new()
	mantle.position = Vector3(0, g + 1.3, 0)
	parent.add_child(mantle)
	var m := MeshKit.Soup.new()
	MeshKit.frustum_into(m, Vector3(0, -0.1, 0), 0.5, 0.12, 0.42, 8)
	MeshKit.box_into(m, Vector3(0.0, 0.3, 0), Vector3(0.1, 0.12, 0.6))
	MeshKit.inst(mantle, m.mesh(), _material("SteelPlate"))
	parent.set_meta("flywheels", [mantle])
	parent.set_meta("spin_axis", "y")
	parent.set_meta("jaw", mantle)
	_crusher_fill(parent, g, Vector3(0, 1.55, 0), Vector3(0.9, 0.3, 0.9), Vector3(0, 0.2, -1.65), Vector3(1.1, 0.4, 0.9))

func dress_crusher(body: StaticBody3D, tier := 1) -> void:
	_strip(body, [])
	crusher_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))), tier)

## Phase 9.6: the Small Hopper. A funnel on a braced frame: open rim, spout, belt port plate and the material heaped in the funnel.
func hopper_model(parent: Node3D, g: float) -> void:
	var p := {"SteelPlate": MeshKit.Soup.new(), "SteelGreen": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new(), "PaintYellow": MeshKit.Soup.new()}
	for x in [-0.55, 0.55]:
		for z in [-0.55, 0.55]:
			MeshKit.box_into(p["SteelPlate"], Vector3(x, g + 0.45, z), Vector3(0.08, 0.9, 0.08))               # legs
	for y in [0.3, 0.9]:
		MeshKit.box_into(p["SteelPlate"], Vector3(0, g + y, -0.55), Vector3(1.1, 0.05, 0.05))                 # frame rails
		MeshKit.box_into(p["SteelPlate"], Vector3(0, g + y, 0.55), Vector3(1.1, 0.05, 0.05))
		MeshKit.box_into(p["SteelPlate"], Vector3(-0.55, g + y, 0), Vector3(0.05, 0.05, 1.1))
		MeshKit.box_into(p["SteelPlate"], Vector3(0.55, g + y, 0), Vector3(0.05, 0.05, 1.1))
	MeshKit.frustum_into(p["SteelGreen"], Vector3(0, g + 0.5, 0), 0.16, 0.7, 0.68, 8, Transform3D.IDENTITY, false)       # the funnel (open top)
	MeshKit.box_into(p["SteelPlate"], Vector3(0, g + 0.52, 0), Vector3(0.34, 0.02, 0.34))                       # dark floor under the funnel
	for sd in [[Vector3(0, 0, -0.72), Vector3(1.46, 0.07, 0.07)], [Vector3(0, 0, 0.72), Vector3(1.46, 0.07, 0.07)], [Vector3(-0.72, 0, 0), Vector3(0.07, 0.07, 1.46)], [Vector3(0.72, 0, 0), Vector3(0.07, 0.07, 1.46)]]:
		MeshKit.box_into(p["Hazard"], sd[0] + Vector3(0, g + 1.17, 0), sd[1])                                   # painted rim
	MeshKit.frustum_into(p["SteelGreen"], Vector3(0, g + 0.18, 0), 0.1, 0.16, 0.34, 8)                         # spout
	MeshKit.box_into(p["PaintYellow"], Vector3(0, g + 0.3, -0.66), Vector3(0.36, 0.3, 0.06))                   # belt port plate (the belt meets it here)
	MeshKit.box_into(p["SteelPlate"], Vector3(0.74, g + 0.9, 0.0), Vector3(0.04, 0.5, 0.1))                    # level gauge rail
	_parts(parent, p)

func dress_hopper(body: StaticBody3D) -> void:
	var fill: MeshInstance3D = body.get_meta("fill")
	_strip(body, [fill])
	hopper_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))))
	body.set_meta("fill_key", "")
	body.set_meta("fill_y", 0.42)
	fill.mesh = MeshKit.rock(Vector3(1.1, 0.7, 1.1), 62, 3, 8)
	fill.material_override = _material("RockLimestone")

## Phase 9.6: the Manual Sorting Table. A plank work surface on legs with a back rail, a raw-rock tray on the left, three sorting
## trays in front (stone / coal / iron colours) and a sweeping arm that works while a batch is being sorted.
func sorting_table_model(parent: Node3D, g: float) -> void:
	var p := {QuarryArt.M_WOOD: MeshKit.Soup.new(), "SteelPlate": MeshKit.Soup.new(), "PaintYellow": MeshKit.Soup.new(), "PaintRed": MeshKit.Soup.new(), "SteelGreen": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new()}
	var w: MeshKit.Soup = p[QuarryArt.M_WOOD]
	MeshKit.box_into(w, Vector3(0, g + 0.88, 0), Vector3(1.5, 0.08, 0.85))                                    # work surface
	for x in [-0.68, 0.68]:
		for z in [-0.36, 0.36]:
			MeshKit.box_into(w, Vector3(x, g + 0.44, z), Vector3(0.08, 0.88, 0.08))                           # legs
	MeshKit.box_into(w, Vector3(0, g + 0.28, 0), Vector3(1.36, 0.05, 0.7))                                    # lower shelf
	MeshKit.box_into(w, Vector3(0, g + 1.12, 0.4), Vector3(1.5, 0.4, 0.05))                                   # back rail
	# raw-rock tray (left): a sloped tipping tray
	MeshKit.box_into(p["SteelGreen"], Vector3(-0.52, g + 0.98, -0.02), Vector3(0.4, 0.12, 0.6))
	for sx in [-0.72, -0.32]:
		MeshKit.box_into(p["SteelGreen"], Vector3(sx, g + 1.05, -0.02), Vector3(0.03, 0.16, 0.6))
	# three sorting trays (front right), each an open box with its own colour
	var cols := ["PaintYellow", "SteelPlate", "PaintRed"]
	for k in range(3):
		var cx := -0.05 + 0.32 * k
		var m: MeshKit.Soup = p[cols[k]]
		MeshKit.box_into(m, Vector3(cx, g + 0.95, -0.2), Vector3(0.28, 0.04, 0.4))
		MeshKit.box_into(m, Vector3(cx, g + 1.0, -0.4), Vector3(0.28, 0.12, 0.03))
		MeshKit.box_into(m, Vector3(cx, g + 1.0, 0.0), Vector3(0.28, 0.12, 0.03))
		MeshKit.box_into(m, Vector3(cx - 0.14, g + 1.0, -0.2), Vector3(0.03, 0.12, 0.4))
		MeshKit.box_into(m, Vector3(cx + 0.14, g + 1.0, -0.2), Vector3(0.03, 0.12, 0.4))
	MeshKit.box_into(p["Hazard"], Vector3(0.28, g + 0.93, 0.18), Vector3(0.92, 0.015, 0.06))                  # bench edge marking
	_parts(parent, p)
	# the sweeping arm: pivots on the back rail and sweeps from the raw tray across the trays
	var arm := Node3D.new()
	arm.position = Vector3(0.1, g + 1.06, 0.34)
	parent.add_child(arm)
	var a := MeshKit.Soup.new()
	MeshKit.box_into(a, Vector3(0.0, 0.0, -0.2), Vector3(0.05, 0.05, 0.42))
	MeshKit.box_into(a, Vector3(0.0, -0.03, -0.43), Vector3(0.14, 0.04, 0.05))                                # the paddle
	MeshKit.inst(arm, a.mesh(), _material("SteelPlate"))
	parent.set_meta("arm", arm)

func dress_sorter(body: StaticBody3D) -> void:
	var fill: MeshInstance3D = body.get_meta("fill")
	_strip(body, [fill])
	sorting_table_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))))
	body.set_meta("fill_key", "")
	body.set_meta("fill_y", 0.36)
	fill.mesh = MeshKit.rock(Vector3(0.36, 0.2, 0.52), 63, 3, 7)
	fill.position = Vector3(-0.52, 0.36, 0.0)
	fill.material_override = _material("RockLimestone")

func output_model(parent: Node3D, g: float) -> void:
	var p := {"SteelGreen": MeshKit.Soup.new(), "SteelPlate": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new()}
	for x in [-0.6, 0.6]:
		for z in [-0.6, 0.6]:
			MeshKit.box_into(p["SteelPlate"], Vector3(x, g + 0.35, z), Vector3(0.1, 0.7, 0.1))           # legs
	MeshKit.box_into(p["SteelGreen"], Vector3(0, g + 0.28, 0), Vector3(0.7, 0.36, 0.7), Vector2(1.7, 1.7))      # hopper cone
	for side in [[Vector3(0, 0, -0.68), Vector3(1.4, 0.62, 0.06)], [Vector3(0, 0, 0.68), Vector3(1.4, 0.62, 0.06)],
			[Vector3(-0.68, 0, 0), Vector3(0.06, 0.62, 1.4)], [Vector3(0.68, 0, 0), Vector3(0.06, 0.62, 1.4)]]:
		MeshKit.box_into(p["SteelGreen"], side[0] + Vector3(0, g + 0.79, 0), side[1])               # bin walls
	MeshKit.box_into(p["Hazard"], Vector3(0, g + 1.12, -0.7), Vector3(1.42, 0.08, 0.02))
	for z in [-0.19, 0.19]:
		MeshKit.box_into(p["SteelPlate"], Vector3(0.725, g + 0.6, z), Vector3(0.04, 0.95, 0.03))        # ladder rails, bolted to the bin wall
	for y in range(5):                                                                             # rungs between the rails
		MeshKit.box_into(p["SteelPlate"], Vector3(0.735, g + 0.2 + y * 0.2, 0.0), Vector3(0.03, 0.03, 0.4))
	_parts(parent, p)

func dress_output(body: StaticBody3D) -> void:
	var fill: MeshInstance3D = body.get_meta("fill")
	_strip(body, [fill])
	output_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))))
	body.set_meta("fill_key", "")
	fill.mesh = MeshKit.rock(Vector3(1.22, 0.9, 1.22), 61, 3, 8)     # heaped inside the bin walls (floor at local y -0.07)
	fill.material_override = _material("RockLimestone")

func conveyor_model(parent: Node3D, g: float) -> void:
	var p := {"SteelPlate": MeshKit.Soup.new(), "Belt": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new(), "SteelGreen": MeshKit.Soup.new()}
	for x in [-0.42, 0.42]:
		MeshKit.box_into(p["SteelGreen"], Vector3(x, g + 0.2, 0), Vector3(0.06, 0.14, 2.0))         # side channels
		for z in [-0.8, 0.8]:
			MeshKit.box_into(p["SteelPlate"], Vector3(x, g + 0.07, z), Vector3(0.06, 0.14, 0.06))     # legs
	MeshKit.box_into(p["Belt"], Vector3(0, g + 0.25, 0), Vector3(0.74, 0.03, 1.94))
	for z in [-0.97, 0.97]:
		MeshKit.drum_into(p["SteelPlate"], Vector3(0, g + 0.22, z), 0.07, 0.78, 6)                  # end rollers
	MeshKit.box_into(p["Hazard"], Vector3(0, g + 0.275, -0.75), Vector3(0.18, 0.012, 0.3))         # travel arrow
	for z in [-0.95, 0.95]:
		MeshKit.box_into(p["Hazard"], Vector3(0, g + 0.02, z), Vector3(1.0, 0.04, 0.08))            # crossing marks
	var made := _parts(parent, p)
	if made.has("Belt"):
		parent.set_meta("belt", made["Belt"])

## A 90 degree belt corner (kind "left" or "right"): material enters at the back, leaves through the side. Two half belts
## joined by a centre square, with an outer rail round the bend and an open inner corner, built from the same parts as the
## straight belt. Forward is -Z; the exit side is -X for a left corner and +X for a right one.
func conveyor_corner_model(parent: Node3D, g: float, kind: String) -> void:
	var s := -1.0 if kind == "left" else 1.0
	var p := {"SteelPlate": MeshKit.Soup.new(), "Belt": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new(), "SteelGreen": MeshKit.Soup.new()}
	MeshKit.box_into(p["Belt"], Vector3(0, g + 0.25, 0.5), Vector3(0.74, 0.03, 1.0))              # entry half
	MeshKit.box_into(p["Belt"], Vector3(s * 0.5, g + 0.25, 0), Vector3(1.0, 0.03, 0.74))          # exit half
	MeshKit.box_into(p["Belt"], Vector3(0, g + 0.25, 0), Vector3(0.74, 0.03, 0.74))               # the bend itself
	MeshKit.box_into(p["SteelGreen"], Vector3(-s * 0.42, g + 0.2, 0.29), Vector3(0.06, 0.14, 1.42))   # outer rail, entry side
	MeshKit.box_into(p["SteelGreen"], Vector3(s * 0.29, g + 0.2, -0.42), Vector3(1.42, 0.14, 0.06))   # outer rail, exit side
	MeshKit.box_into(p["SteelGreen"], Vector3(s * 0.42, g + 0.2, 0.71), Vector3(0.06, 0.14, 0.58))    # inner rails stop short of the bend
	MeshKit.box_into(p["SteelGreen"], Vector3(s * 0.71, g + 0.2, 0.42), Vector3(0.58, 0.14, 0.06))
	for leg in [Vector3(-0.42, 0, 0.8), Vector3(0.42, 0, 0.8), Vector3(s * 0.8, 0, -0.42), Vector3(s * 0.8, 0, 0.42), Vector3(-s * 0.42, 0, -0.42)]:
		MeshKit.box_into(p["SteelPlate"], Vector3(leg.x, g + 0.07, leg.z), Vector3(0.06, 0.14, 0.06))
	MeshKit.drum_into(p["SteelPlate"], Vector3(0, g + 0.22, 0.97), 0.07, 0.78, 6)                 # entry roller
	MeshKit.box_into(p["SteelPlate"], Vector3(s * 0.97, g + 0.22, 0), Vector3(0.14, 0.14, 0.78))   # exit roller
	MeshKit.box_into(p["Hazard"], Vector3(0, g + 0.02, 0.95), Vector3(1.0, 0.04, 0.08))
	MeshKit.box_into(p["Hazard"], Vector3(s * 0.95, g + 0.02, 0), Vector3(0.08, 0.04, 1.0))
	var made := _parts(parent, p)
	if made.has("Belt"):
		parent.set_meta("belt", made["Belt"])

func dress_conveyor(body: StaticBody3D) -> void:
	var items: Array = body.get_meta("items")
	_strip(body, items)
	var bk: String = str(body.get_meta("belt_kind", "straight"))
	if bk == "straight":
		conveyor_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))))
	else:
		conveyor_corner_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))), bk)
	if not piece_meshes.has("belt_item"):
		piece_meshes["belt_item"] = MeshKit.rock(Vector3(0.28, 0.2, 0.26), 55, 3, 5)
	for it in items:
		it.mesh = piece_meshes["belt_item"]

func storage_model(parent: Node3D, g: float) -> void:
	var p := {"SteelPlate": MeshKit.Soup.new(), "SteelGreen": MeshKit.Soup.new(), "Hazard": MeshKit.Soup.new()}
	MeshKit.box_into(p["SteelPlate"], Vector3(0, g + 0.08, 0), Vector3(2.0, 0.16, 1.6))
	for side in [[Vector3(0, 0, -0.78), Vector3(2.0, 1.14, 0.06)], [Vector3(0, 0, 0.78), Vector3(2.0, 1.14, 0.06)],
			[Vector3(-0.98, 0, 0), Vector3(0.06, 1.14, 1.6)], [Vector3(0.98, 0, 0), Vector3(0.06, 1.14, 1.6)]]:
		MeshKit.box_into(p["SteelGreen"], side[0] + Vector3(0, g + 0.72, 0), side[1])
	for x in [-0.6, -0.2, 0.2, 0.6]:
		for z in [-0.82, 0.82]:
			MeshKit.box_into(p["SteelPlate"], Vector3(x, g + 0.72, z), Vector3(0.06, 1.1, 0.04))      # ribs
	MeshKit.box_into(p["Hazard"], Vector3(0, g + 1.24, -0.82), Vector3(2.02, 0.1, 0.03))
	_parts(parent, p)

func dress_storage(body: StaticBody3D) -> void:
	_strip(body, [])
	storage_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))))
	var fill := MeshKit.inst(body, MeshKit.rock(Vector3(1.76, 1.5, 1.36), 62, 3, 8), _material("RockLimestone"), Vector3(0, -0.5, 0))
	body.set_meta("fill", fill)
	body.set_meta("fill_key", "")
	_sign(body, "Sign_Storage", Vector3(0, 0.45, -0.84), Vector2(1.0, 0.25), PI)
