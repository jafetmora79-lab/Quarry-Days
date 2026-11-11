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
const M_BRUSHED := VEIL + "Materials_Godot/Furniture/M_Furn_MetalBrushed.tres"
const M_RUSTED := VEIL + "Materials_Godot/Furniture/M_Furn_MetalRusted.tres"
const M_RUBBER := VEIL + "Materials_Godot/Furniture/M_Furn_Rubber.tres"
const M_WOOD := VEIL + "Materials_Godot/Furniture/M_Furn_WoodLight.tres"
const M_GLASS := VEIL + "05_Vehicles/Shared_Materials/M_Veh_Glass_Dirty.tres"
const ROCK_MAT := {"limestone": "RockLimestone", "coal": "RockCoal", "iron_ore": "RockIron", "crushed_stone": "RockGravel", "copper_ore": "RockCopper", "gold_ore": "RockGold"}

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
	_ground()
	_cliffs()
	_office()
	_shed()
	_garage()
	_stations()
	_site_props()
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
			elif nm in ["Quarry floor", "Expansion floor", "Pit cap"] or nm.begins_with("Office ") or nm.begins_with("Storage shed ") \
					or nm.begins_with("Break bench") or nm.begins_with("Upgrade board") or nm.begins_with("Selling station") \
					or nm.begins_with("Crusher order kiosk") or nm.begins_with("Management desk"):
				_hide(n)

# ------------------------------------------------------------------ ground

func _ground() -> void:
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
	quad_flat(M_DIRT_ROAD, Vector3(0, 0, 4.5), Vector2(7.0, 10.0), 0.0, 0.018)            # pit entrance ramp
	quad_flat(M_DIRT_ROAD, Vector3(19.5, 0, 7.5), Vector2(21.0, 4.0), 0.0, 0.02)         # road to the expansion
	quad_flat(M_DIRT_ROAD, Vector3(34.0, 0, 4.0), Vector2(10.0, 4.0), -0.35, 0.02)
	quad_flat(M_DIRT_ROAD, Vector3(5.5, 0, 13.0), Vector2(4.0, 6.0), 0.0, 0.022)         # garage apron road
	quad_flat(M_GRAVEL, Vector3(2.0, 0, 9.0), Vector2(26.0, 5.0), 0.0, 0.016)            # processing yard
	quad_flat(M_CONCRETE, Vector3(5.0, 0, 19.2), Vector2(19.6, 6.6), 0.0, 0.024)         # garage slab
	quad_flat(M_CONCRETE, Vector3(-14.0, 0, 12.0), Vector2(6.4, 6.4), 0.0, 0.024)        # office pad
	quad_flat(M_CONCRETE, Vector3(14.0, 0, 12.0), Vector2(6.0, 6.0), 0.0, 0.024)         # shed pad
	quad_flat(M_CONCRETE, Vector3(-7.0, 0, 10.6), Vector2(4.0, 3.2), 0.0, 0.026)         # sales booth
	quad_flat(M_CONCRETE, Vector3(-9.6, 0, 15.7), Vector2(4.0, 2.2), 0.0, 0.026)         # break area
	for slot in game.fleet.cfg.get("parking", []):                                        # painted bay lines
		for side in [-1.4, 1.4]:
			quad_flat("Hazard", Vector3(float(slot[0]) + side, 0, float(slot[2])), Vector2(0.12, 4.2), 0.0, 0.03)
	# Outer embankments: soil slopes rising behind the cliffs to close the horizon.
	var e := soup(M_SOIL)
	var seg := 28
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var rings := [[29.0, 0.0], [33.0, 4.5], [40.0, 7.5], [52.0, 9.0]]
		for r in range(rings.size() - 1):
			var p := [_ring(a0, rings[r]), _ring(a1, rings[r]), _ring(a1, rings[r + 1]), _ring(a0, rings[r + 1])]
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
		var cs: CollisionShape3D = null
		for c in n.get_children():
			if c is CollisionShape3D:
				cs = c
		if cs == null or not cs.shape is BoxShape3D:
			continue
		var size: Vector3 = cs.shape.size
		if nm.begins_with("Cliff") or nm.begins_with("Expansion cliff") or nm.begins_with("Excavated rim"):
			_hide(n)
			seed += 1
			var mesh := MeshKit.Soup.new()
			var low := nm.begins_with("Excavated rim")
			var length := maxf(size.x, size.z) + (0.8 if low else 1.6)
			var depth := minf(size.x, size.z) + (0.4 if low else 0.8)
			var turn := PI if size.x >= size.z else PI * 0.5
			if nm.begins_with("Expansion cliff") and n.position.z > 0.0:
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
		if i == 0 or i == 9:
			continue
		var p := Vector3(cos(a) * 28.6, 3.2, sin(a) * 28.6)
		var yaw := -a - PI / 2
		solid("Cliff filler", p, Vector3(8.0, 6.4, 3.4), yaw)
		var mesh := MeshKit.Soup.new()
		MeshKit.cliff_into(mesh, 9.5, 7.0, 4.2, 100 + i, 4, Transform3D(Basis(Vector3.UP, yaw + PI), p - Vector3(0, 3.2, 0)))
		MeshKit.inst(root, mesh.mesh(), _material("CliffStrata"))
	# rockfall barrier closing the east expansion (removed with its body when the milestone opens it)
	for body in game.expansion_gate:
		if str(body.name).begins_with("Rockfall barrier"):
			_hide(body)
			var r := MeshKit.Soup.new()
			for k in range(9):
				MeshKit.rock_into(r, Vector3(0.0 + (k % 2) * 0.4 - 0.2, -2.0, -11.5 + k * 2.9), Vector3(2.4, 2.6 + (k % 3) * 0.7, 3.2), 300 + k)
			MeshKit.inst(body, r.mesh(), _material("RockLimestone"))

# ------------------------------------------------------------------ buildings

## Walled building on an existing collision footprint: textured walls, inner lining, plinth, roof.
func _walls(center: Vector3, ext_key: String, int_key: String, h := 2.8) -> void:
	var c := center
	var specs := [[Vector3(-2.4, 0, 0), Vector3(0.22, h, 4.8)], [Vector3(2.4, 0, 0), Vector3(0.22, h, 4.8)], [Vector3(0, 0, 2.35), Vector3(5.0, h, 0.22)],
		[Vector3(-1.6, 0, -2.35), Vector3(1.8, h, 0.22)], [Vector3(1.6, 0, -2.35), Vector3(1.8, h, 0.22)]]
	for sp in specs:
		bx(ext_key, c + sp[0] + Vector3(0, h * 0.5, 0), sp[1] + Vector3(0.02, 0, 0.02))
	bx(int_key, c + Vector3(-2.27, h * 0.5, 0), Vector3(0.02, h - 0.1, 4.5))
	bx(int_key, c + Vector3(2.27, h * 0.5, 0), Vector3(0.02, h - 0.1, 4.5))
	bx(int_key, c + Vector3(0, h * 0.5, 2.22), Vector3(4.5, h - 0.1, 0.02))
	bx(M_FOUNDATION, c + Vector3(0, 0.08, 0), Vector3(5.24, 0.16, 5.04))
	# Match the collision ramp from the yard to the raised office/shed floor.
	MeshKit.box_into(soup(M_FOUNDATION), Vector3.ZERO, Vector3(1.42, 0.08, 1.0), Vector2.ONE,
		Transform3D(Basis(Vector3.RIGHT, -atan(0.16)), c + Vector3(0, 0.04, -2.95)))
	bx(M_TRIM, c + Vector3(0, 2.5, -2.38), Vector3(1.5, 0.3, 0.24))                       # door header
	for x in [-0.76, 0.76]:
		bx(M_TRIM, c + Vector3(x, 1.25, -2.4), Vector3(0.1, 2.5, 0.08))                    # door jambs

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
	var c := Vector3(-14, 0, 12)
	_walls(c, M_SIDING, M_DRYWALL)
	_gable_roof(c, "CorrugatedRed", 5.6, 5.6, 2.8, 1.1)
	quad_flat(M_LINO, c, Vector2(4.6, 4.5), 0.0, 0.16)
	_sign(root, "Sign_Office", c + Vector3(0, 2.5, -2.62), Vector2(2.2, 0.55), PI)
	for z in [-0.9, 1.0]:
		prop(P_WINDOW, c + Vector3(-2.53, 1.05, z), -PI * 0.5)
		prop(P_WINDOW, c + Vector3(2.53, 1.05, z), PI * 0.5)
	prop(P_WINDOW_WIDE, c + Vector3(1.0, 1.0, 2.48), 0.0)
	var door := prop(P_DOOR, c + Vector3(-0.72, 0.16, -2.3), PI * 0.5 + 0.35)              # open, swung inside
	prop(P_WALL_LAMP, c + Vector3(1.0, 2.3, -2.5), PI)
	light(c + Vector3(0, 2.4, 0.3), Color(1.0, 0.86, 0.62), 1.1, 6.0)
	# interior: the management desk keeps its collision; the THE VEIL desk + computer sits on it
	prop(P_DESK, c + Vector3(0, 0.16, 1.4), PI)
	prop(P_CHAIR, c + Vector3(0.1, 0.16, 1.95), PI)
	prop(P_FILING, c + Vector3(-1.95, 0.16, 1.85), PI * 0.5)
	prop(P_DOCS, c + Vector3(-1.95, 0.16, 0.9), PI * 0.5)
	prop(P_NOTICE, c + Vector3(-2.22, 1.0, -0.6), PI * 0.5)
	prop(P_CLOCK, c + Vector3(1.4, 2.1, 2.2), PI)
	prop(P_CALENDAR, c + Vector3(2.22, 1.4, 1.2), -PI * 0.5)
	prop(P_WAITING, c + Vector3(1.85, 0.16, -0.6), -PI * 0.5)
	solid("Office cabinets", c + Vector3(-1.95, 0.6, 1.4), Vector3(0.6, 1.2, 1.4))
	# upgrade board outside the door: THE VEIL notice board on two posts
	var ub := Vector3(-14, 0, 7.8)
	prop(P_NOTICE, ub + Vector3(0, 0.55, 0.05), PI)
	for x in [-0.95, 0.95]:
		bx(M_WOOD, ub + Vector3(x, 0.95, 0.1), Vector3(0.1, 1.9, 0.1))
	_sign(root, "Sign_Upgrades", ub + Vector3(0, 2.05, -0.06), Vector2(1.2, 0.3), PI)
	# break area
	prop(P_BENCH, Vector3(-9.6, 0, 15.3), PI)
	prop(P_TRASH, Vector3(-11.6, 0, 15.6))

func _shed() -> void:
	var c := Vector3(14, 0, 12)
	_walls(c, "Corrugated", M_BASEMENT)
	_gable_roof(c, "CorrugatedRed", 5.6, 5.6, 2.8, 0.7)
	quad_flat(M_BASEMENT, c, Vector2(4.6, 4.5), 0.0, 0.16)
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
func _garage() -> void:
	var x0 := -4.7
	var x1 := 14.5
	var z0 := 16.0
	var z1 := 22.4
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	solid("Garage back wall", Vector3(cx, 2.0, z1), Vector3(w, 4.0, 0.25))
	solid("Garage wall", Vector3(x0, 2.0, (z0 + z1) * 0.5), Vector3(0.25, 4.0, z1 - z0))
	solid("Garage wall", Vector3(x1, 2.0, (z0 + z1) * 0.5), Vector3(0.25, 4.0, z1 - z0))
	bx("Corrugated", Vector3(cx, 2.0, z1), Vector3(w, 4.0, 0.2))
	bx("Corrugated", Vector3(x0, 2.0, (z0 + z1) * 0.5), Vector3(0.2, 4.0, z1 - z0))
	bx("Corrugated", Vector3(x1, 2.0, (z0 + z1) * 0.5), Vector3(0.2, 4.0, z1 - z0))
	bx(M_FOUNDATION, Vector3(cx, 0.2, z1), Vector3(w + 0.1, 0.4, 0.3))
	for x in [x0, x1]:
		bx(M_FOUNDATION, Vector3(x, 0.2, (z0 + z1) * 0.5), Vector3(0.3, 0.4, z1 - z0))
	# steel frame: front columns, I-beam, roof trusses
	for x in [x0, x0 + w / 3.0, x0 + 2.0 * w / 3.0, x1]:
		bx("SteelGreen", Vector3(x, 2.25, z0 + 0.1), Vector3(0.22, 4.5, 0.22))
		bx("SteelGreen", Vector3(x, 4.35, (z0 + z1) * 0.5), Vector3(0.18, 0.3, z1 - z0))   # truss
	bx("SteelGreen", Vector3(cx, 4.45, z0 + 0.1), Vector3(w + 0.3, 0.35, 0.3))
	var roof := PackedVector2Array([Vector2(z0 - 0.6, 4.6), Vector2(z1 + 0.3, 4.15), Vector2(z1 + 0.3, 4.27), Vector2(z0 - 0.6, 4.72)])
	MeshKit.extrude_into(soup("Corrugated"), roof, w + 0.6, Transform3D(Basis(), Vector3(cx, 0, 0)))
	bx("Hazard", Vector3(cx, 4.45, z0 - 0.07), Vector3(w + 0.3, 0.12, 0.02))
	_sign(root, "Sign_Garage", Vector3(cx, 4.95, z0 - 0.02), Vector2(4.0, 0.5), PI)
	_sign(root, "Sign_Safety", Vector3(x0 - 0.13, 2.6, z0 + 1.2), Vector2(1.5, 0.5), -PI * 0.5)
	# workshop along the walls
	prop(P_WORKBENCH, Vector3(x0 + 0.55, 0.0, 19.6), PI * 0.5)
	prop(P_TOOLBOX, Vector3(x0 + 0.5, 0.95, 19.2), PI * 0.5)
	prop(P_SHELF, Vector3(x0 + 0.4, 0.0, 21.5), PI * 0.5)
	prop(P_SHELF, Vector3(1.2, 0.0, z1 - 0.4), PI)
	prop(P_SHELF, Vector3(5.2, 0.0, z1 - 0.4), PI)
	prop(P_ELEC, Vector3(9.8, 0.0, z1 - 0.35), PI)
	prop(P_BOXES, Vector3(14.0, 0.0, 21.6), -PI * 0.5)
	prop(P_BIN, Vector3(14.0, 0.0, 17.2), -PI * 0.5)
	prop(P_CONE, Vector3(x0 + 0.6, 0.0, 16.8))
	prop(P_CONE, Vector3(x0 + 1.0, 0.0, 17.2))
	for k in range(3):                                                                   # oil drums
		MeshKit.frustum_into(soup("PaintRed" if k != 1 else "SteelGreen"), Vector3(13.7 - 0.6 * (k % 2), 0, 19.0 + 0.62 * k), 0.29, 0.29, 0.88, 8)
	solid("Garage shelving", Vector3(cx, 0.9, z1 - 0.45), Vector3(w - 0.4, 1.8, 0.6))       # behind the bays
	solid("Garage workbench", Vector3(x0 + 0.5, 0.5, 20.2), Vector3(0.75, 1.0, 3.6))
	solid("Garage drums", Vector3(13.6, 0.45, 19.6), Vector3(0.9, 0.9, 1.9))
	light(Vector3(cx - 5, 4.0, 19.5), Color(0.9, 0.95, 1.0), 1.2, 9.0)
	light(Vector3(cx + 5, 4.0, 19.5), Color(0.9, 0.95, 1.0), 1.2, 9.0)

func _stations() -> void:
	# Sales booth on the selling-station footprint (2.2 x 1.7 x 1.25 at -7, 10).
	var s := Vector3(-7, 0, 10)
	bx(M_WOOD, s + Vector3(0, 1.08, 0), Vector3(2.3, 0.08, 1.35))
	bx("SteelGreen", s + Vector3(0, 0.52, 0), Vector3(2.2, 1.04, 1.25))
	bx("Hazard", s + Vector3(0, 0.08, -0.63), Vector3(2.2, 0.16, 0.02))
	bx("SteelPlate", s + Vector3(-0.6, 1.25, 0.2), Vector3(0.4, 0.26, 0.35), 0.2)        # cash register
	bx("SteelPlate", s + Vector3(0.6, 1.14, 0.0), Vector3(0.6, 0.05, 0.5))               # weigh scale
	for x in [-1.0, 1.0]:
		bx("SteelGreen", s + Vector3(x, 1.75, 0.55), Vector3(0.1, 1.3, 0.1))
	bx("CorrugatedRed", s + Vector3(0, 2.45, 0.15), Vector3(2.7, 0.08, 1.8), 0.0)
	_sign(root, "Sign_Sales", s + Vector3(0, 2.66, -0.76), Vector2(1.6, 0.4), PI)
	# Machinery order kiosk (1.4 x 1.5 x 1.0 at -2, 10).
	var k := Vector3(-2, 0, 10)
	bx("SteelPlate", k + Vector3(0, 0.62, 0), Vector3(1.4, 1.24, 1.0), 0.0, Vector2(0.92, 0.8))
	var screen := PackedVector2Array([Vector2(-0.45, 1.24), Vector2(0.4, 1.24), Vector2(0.4, 1.36), Vector2(-0.45, 1.56)])
	MeshKit.extrude_into(soup("SteelGreen"), screen, 1.2, Transform3D(Basis(), k))
	bx("SteelGreen", k + Vector3(0.62, 1.6, 0.42), Vector3(0.08, 1.4, 0.08))
	_sign(root, "Sign_Orders", k + Vector3(0.62, 2.4, 0.37), Vector2(1.0, 0.5), PI)
	var glow := MeshKit.inst(root, QuadMesh.new(), MeshKit.flat(Color(0.35, 0.75, 0.6), 1.2), k + Vector3(0, 1.43, -0.27), Vector3(-0.5, PI, 0))
	glow.scale = Vector3(0.8, 0.28, 1)

func _site_props() -> void:
	prop(P_DUMPSTER, Vector3(-19.0, 0, 6.5), PI * 0.5)
	solid("Dumpster", Vector3(-19.0, 0.65, 6.5), Vector3(1.2, 1.3, 2.0))
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
	for i in range(14):                                                                  # scree at the cliff feet
		var a := TAU * (i + 0.3) / 14.0
		if absf(wrapf(a, -PI, PI)) < 0.45:
			continue
		prop(P_ROCKS, Vector3(cos(a) * 25.5, 0, sin(a) * 25.5), a, 1.3)
	for p in [Vector3(-16.0, 0, -2.5), Vector3(16.0, 0, -2.5), Vector3(-8.0, 0, -22.5)]:   # clear of the Phase 5 formations
		prop(P_MOUND, p, p.x, 1.4)
	prop(P_GRAVEL, Vector3(15.5, 0, -13.5), 0.0, 1.2)
	for p in [Vector3(-24.0, 0, 12.0), Vector3(24.0, 0, -6.0), Vector3(-6.0, 0, 25.5), Vector3(18.0, 0, -18.0), Vector3(-18.0, 0, -18.0)]:
		prop(P_WEEDS if int(p.x) % 2 == 0 else P_DEAD, p, p.z)
	for p in [Vector3(46.0, 0, -10.0), Vector3(31.0, 0, 11.0), Vector3(47.0, 0, 11.0)]:
		prop(P_ROCKS, p, p.x, 1.4)
	prop(P_STUMP, Vector3(-23.0, 0, 15.0))

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
	for y in range(5):                                                                             # side ladder
		MeshKit.box_into(p["SteelPlate"], Vector3(0.74, g + 0.15 + y * 0.22, 0.0), Vector3(0.04, 0.03, 0.36))
	_parts(parent, p)

func dress_output(body: StaticBody3D) -> void:
	var fill: MeshInstance3D = body.get_meta("fill")
	_strip(body, [fill])
	output_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))))
	fill.mesh = MeshKit.rock(Vector3(1.25, 0.5, 1.25), 61, 3, 8)
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

func dress_conveyor(body: StaticBody3D) -> void:
	var items: Array = body.get_meta("items")
	_strip(body, items)
	conveyor_model(body, -(body.position.y - float(body.get_meta("ground_y", 0.0))))
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
	var fill := MeshKit.inst(body, MeshKit.rock(Vector3(1.8, 0.6, 1.4), 62, 3, 8), _material("RockLimestone"), Vector3(0, -0.5, 0))
	body.set_meta("fill", fill)
	_sign(body, "Sign_Storage", Vector3(0, 0.45, -0.84), Vector2(1.0, 0.25), PI)
