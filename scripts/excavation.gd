extends Node3D
class_name QuarryExcavation
## Phase 5 deep excavation: one lower level dug into the main pit floor (data/progression.json "excavation").
## Staged geometry, no voxel terrain:
##   closed : a flat cap over the pit (walkable, built on like the rest of the floor)
##   open   : cap removed -> lower floor 3.5 m down, a 3 m wide access ramp (people, staff and vehicles),
##            deep-rock walls with benches, rim barriers with a gap at the ramp, work lights.
## The surrounding floor pieces (built by main) are 5.5 m thick, so the pit walls are solid colliders.
## More levels can be added by extending the data with further pit rectangles.

var game
var cfg: Dictionary
var cap: StaticBody3D
var lower: StaticBody3D
var ramp: StaticBody3D
var barriers: Array = []
var visuals: Node3D
var is_open := false
var x0 := 0.0
var z0 := 0.0
var x1 := 0.0
var z1 := 0.0
var depth := 3.5

func setup(main_node) -> void:
	game = main_node
	name = "Excavation"
	cfg = game.prog.cfg.get("excavation", {})
	if game.prog.filled_world():
		return                    # the blueprint quarry replaces this old lower pit; its coordinates now lie inside the quarry
	var pit: Array = cfg["pit"]
	x0 = float(pit[0])
	z0 = float(pit[1])
	x1 = float(pit[2])
	z1 = float(pit[3])
	depth = float(cfg.get("depth", 3.5))
	var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	var size := Vector3(x1 - x0, 0, z1 - z0)
	cap = _body("Pit cap", c + Vector3(0, -0.25, 0), Vector3(size.x, 0.5, size.z))
	lower = _body("Lower floor", c + Vector3(0, -depth - 0.25, 0), Vector3(size.x, 0.5, size.z))
	# ramp: from the south rim (y 0) down to the lower floor along the west side
	var r: Array = cfg["ramp"]
	var rx0 := float(r[0])
	var rx1 := float(r[1])
	var rz_top := float(r[2])
	var rz_bot := float(r[3])
	var run := absf(rz_top - rz_bot)
	var ang := atan2(depth, run)
	var length := sqrt(run * run + depth * depth)
	ramp = StaticBody3D.new()
	ramp.name = "Access ramp"
	ramp.set_meta("ground", true)
	var thick := 0.4
	ramp.position = Vector3((rx0 + rx1) * 0.5, -depth * 0.5 - thick * 0.5 / cos(ang) - 0.01, (rz_top + rz_bot) * 0.5)
	ramp.rotation.x = -ang
	var rcs := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(rx1 - rx0, thick, length)
	rcs.shape = rbox
	ramp.add_child(rcs)
	game.world.add_child(ramp)
	# solid fill under the ramp (stepped boxes just below the slab): nobody walks or sees under it
	for i in range(4):
		var seg := run / 4.0
		var top := -depth * float(i + 1) / 4.0 - 0.5
		var hgt := top + depth + 0.25
		if hgt > 0.05:
			var fill := _body("Ramp fill", Vector3((rx0 + rx1) * 0.5, -depth - 0.25 + hgt * 0.5, rz_top - seg * (float(i) + 0.5)), Vector3(rx1 - rx0, hgt, seg))
			fill.remove_meta("ground")
			fill.set_meta("nav_skip", true)
			fill.set_meta("climbable", true)
		# rim barriers (railing height), leaving the ramp mouth open
	var specs := [
		[Vector3((x0 + x1) * 0.5, 0.5, z0 - 0.15), Vector3(x1 - x0 + 0.3, 1.0, 0.3)],
		[Vector3(x0 - 0.15, 0.5, (z0 + z1) * 0.5), Vector3(0.3, 1.0, z1 - z0)],
		[Vector3(x1 + 0.15, 0.5, (z0 + z1) * 0.5), Vector3(0.3, 1.0, z1 - z0)],
		[Vector3((rx1 + x1) * 0.5 + 0.15, 0.5, z1 + 0.15), Vector3(x1 - rx1 - 0.3, 1.0, 0.3)],
	]
	for sp in specs:
		var b := _body("Pit barrier", sp[0], sp[1])
		b.remove_meta("ground")
		barriers.append(b)
	# barrier along the open (east) side of the ramp, down to the lower floor
	var side := StaticBody3D.new()
	side.name = "Ramp barrier"
	side.position = Vector3(rx1 + 0.15, -depth * 0.5 + 0.5, (rz_top + rz_bot) * 0.5)
	side.rotation.x = -ang
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(0.25, 1.0, length - 0.6)
	scs.shape = sbox
	side.add_child(scs)
	game.world.add_child(side)
	barriers.append(side)
	_build_visuals(rx0, rx1, rz_top, rz_bot, ang, length)
	set_open(false)

func _body(label: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	game.world.add_child(body)
	return body

func _fh(gx: int, gz: int) -> float:
	return -depth + 0.012 + 0.02 * sin(gx * 1.3 + gz * 0.7)

func _build_visuals(rx0: float, rx1: float, rz_top: float, rz_bot: float, ang: float, length: float) -> void:
	visuals = Node3D.new()
	visuals.name = "ExcavationVisuals"
	add_child(visuals)
	var floor_s := MeshKit.Soup.new()
	# one continuous surface: every grid corner has a single height shared by the four quads around it, so there are no
	# cracks between tiles for the background to show through (the old tiles each had their own height)
	for gx in range(int(x0), int(x1)):
		for gz in range(int(z0), int(z1)):
			floor_s.quad(Vector3(gx, _fh(gx, gz), gz), Vector3(gx, _fh(gx, gz + 1), gz + 1), Vector3(gx + 1, _fh(gx + 1, gz + 1), gz + 1), Vector3(gx + 1, _fh(gx + 1, gz), gz))
	MeshKit.inst(visuals, floor_s.mesh(), MeshKit.mat("ExcavatedDirt"))
	# deep-rock walls: stratified faces looking into the pit, with a bench line
	var walls := MeshKit.Soup.new()
	var w := x1 - x0
	var d := z1 - z0
	# each wall runs 0.9 m past both ends, so the four faces overlap in the corners and leave no gap
	MeshKit.cliff_into(walls, w + 1.8, depth, 0.8, 501, 3, Transform3D(Basis(Vector3.UP, PI), Vector3((x0 + x1) * 0.5, -depth, z0 - 0.4)))       # north, faces +Z
	MeshKit.cliff_into(walls, d + 1.8, depth, 0.8, 502, 3, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x0 - 0.4, -depth, (z0 + z1) * 0.5))) # west, faces +X
	MeshKit.cliff_into(walls, d + 1.8, depth, 0.8, 503, 3, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x1 + 0.4, -depth, (z0 + z1) * 0.5)))  # east, faces -X
	if rx0 - x0 > 0.5:   # the south wall west of the ramp mouth (it was missing: the gap showed the far side of the floor slab)
		MeshKit.cliff_into(walls, rx0 - x0 + 0.9, depth, 0.8, 505, 3, Transform3D(Basis(), Vector3((x0 + rx0) * 0.5 - 0.45, -depth, z1 + 0.4)))
	MeshKit.cliff_into(walls, x1 - rx1 + 0.9, depth, 0.8, 504, 3, Transform3D(Basis(), Vector3((rx1 + x1) * 0.5 + 0.45, -depth, z1 + 0.4)))      # south, faces -Z
	MeshKit.inst(visuals, walls.mesh(), MeshKit.mat("RockDeep"))
	# ramp surface (dirt road), curb on the open side
	var rs := MeshKit.Soup.new()
	var xf := Transform3D(Basis(Vector3.RIGHT, -ang), Vector3((rx0 + rx1) * 0.5, -depth * 0.5 + 0.02, (rz_top + rz_bot) * 0.5))
	var hw := (rx1 - rx0) * 0.5
	var hl := length * 0.5 + 0.15
	rs.quad(xf * Vector3(-hw, 0, -hl), xf * Vector3(-hw, 0, hl), xf * Vector3(hw, 0, hl), xf * Vector3(hw, 0, -hl))
	var road_mat = MeshKit.mat("GroundRoad")
	if road_mat is BaseMaterial3D:
		(road_mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED   # seen from below too: the space under the ramp is not see-through
	MeshKit.inst(visuals, rs.mesh(), road_mat)
	# the solid body of the ramp: both side faces of the wedge between the road and the lower floor (no hollow underside)
	var wedge := MeshKit.Soup.new()
	for xw in [rx0, rx1]:
		var a := Vector3(xw, 0.0, rz_top)
		var b := Vector3(xw, -depth, rz_top)
		var c := Vector3(xw, -depth, rz_bot)
		wedge.tri(a, b, c)
		wedge.tri(a, c, b)
	MeshKit.inst(visuals, wedge.mesh(), MeshKit.mat("RockDeep"))
	var curb := MeshKit.Soup.new()
	MeshKit.box_into(curb, Vector3.ZERO, Vector3(0.25, 0.35, length - 0.6), Vector2.ONE, Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(rx1 + 0.15, -depth * 0.5 + 0.17, (rz_top + rz_bot) * 0.5)))
	MeshKit.inst(visuals, curb.mesh(), MeshKit.mat("Hazard"))
	# rim railings (THE VEIL railing props) and two flood lights
	for k in range(int(w / 2.5)):
		MeshKit.prop(visuals, QuarryArt.P_RAILING, Vector3(x0 + 1.25 + k * 2.5, 0, z0 - 0.15), 0.0)
	for k in range(int(d / 2.5)):
		MeshKit.prop(visuals, QuarryArt.P_RAILING, Vector3(x0 - 0.15, 0, z0 + 1.25 + k * 2.5), PI * 0.5)
		MeshKit.prop(visuals, QuarryArt.P_RAILING, Vector3(x1 + 0.15, 0, z0 + 1.25 + k * 2.5), PI * 0.5)
	for k in range(int((x1 - rx1) / 2.5)):
		MeshKit.prop(visuals, QuarryArt.P_RAILING, Vector3(rx1 + 1.25 + k * 2.5, 0, z1 + 0.15), 0.0)
	var sign := MeshKit.Soup.new()
	MeshKit.box_into(sign, Vector3(rx0 - 0.3, 0.9, z1 + 0.6), Vector3(0.1, 1.8, 0.1))
	MeshKit.inst(visuals, sign.mesh(), MeshKit.mat("SteelGreen"))
	var plate := MeshKit.inst(visuals, QuadMesh.new(), MeshKit.mat("Hazard"), Vector3(rx0 - 0.3, 1.7, z1 + 0.66), Vector3(0, PI, 0))
	plate.scale = Vector3(1.0, 0.35, 1)
	for p in [Vector3(x0 + 0.6, 3.2, z0 - 0.8), Vector3(x1 - 0.6, 3.2, z0 - 0.8)]:
		var pole := MeshKit.Soup.new()
		MeshKit.box_into(pole, p - Vector3(0, 1.6, 0), Vector3(0.14, 3.2, 0.14))
		MeshKit.box_into(pole, p + Vector3(0, 0.1, 0.25), Vector3(0.45, 0.25, 0.2))
		MeshKit.inst(visuals, pole.mesh(), MeshKit.mat("SteelPlate"))
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, -0.2, 1.2)
		l.light_color = Color(1.0, 0.86, 0.6)
		l.light_energy = 1.3
		l.omni_range = 11.0
		visuals.add_child(l)
		if game.art:
			game.art.lights.append([l, 1.3])

## Opens (or closes) the lower level: colliders, visuals and navigation follow.
func set_open(open: bool) -> void:
	if cap == null:
		return
	is_open = open
	cap.collision_layer = 0 if open else 1
	cap.set_meta("nav_skip", open)
	for b in [lower, ramp] + barriers:
		b.collision_layer = 1 if open else 0
		b.set_meta("nav_skip", not open)
	visuals.visible = open
	if game.art and game.art.pit_cap:
		game.art.pit_cap.visible = not open
	game.nav_dirty = true

func contains_xz(p: Vector3, margin := 0.0) -> bool:
	return p.x >= x0 + margin and p.x <= x1 - margin and p.z >= z0 + margin and p.z <= z1 - margin

## Buildable lower-level ground (away from the ramp and the deep formations' pads).
func lower_build_ok(p: Vector3) -> bool:
	if cap == null:
		return false
	var r: Array = cfg["ramp"]
	return is_open and contains_xz(p, 1.0) and p.y < -1.0 and p.x > float(r[1]) + 1.0
