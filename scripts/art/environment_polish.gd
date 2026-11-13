extends RefCounted
class_name QuarryEnvironmentPolish
## Environment-only mesh dressing. Facility coordinates, economy and quarry geometry are owned by existing systems.
const MAT := "res://assets/environment/M_"

static func material(name: String) -> String:
	return MAT + name + ".tres"

static func roads(a) -> void:
	# Tessellate the UNION, rather than stack four coplanar asphalt rectangles at intersections.
	var rects := [Rect2(-3.5, -8, 7, 20), Rect2(-23.5, 8.5, 47, 6), Rect2(-22.5, 11.5, 6, 18), Rect2(-23.5, 22.9, 33.5, 5)]
	var xs: Array = []
	var zs: Array = []
	for r in rects:
		for x in [r.position.x, r.end.x]:
			if not xs.has(x): xs.append(x)
		for z in [r.position.y, r.end.y]:
			if not zs.has(z): zs.append(z)
	xs.sort()
	zs.sort()
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var cell := Rect2(float(xs[i]), float(zs[j]), float(xs[i + 1]) - float(xs[i]), float(zs[j + 1]) - float(zs[j]))
			var inside := false
			for r in rects:
				inside = inside or r.has_point(cell.get_center())
			if not inside: continue
			a.quad_flat(a.M_ASPHALT, Vector3(cell.get_center().x, 0, cell.get_center().y), cell.size, 0, 0.085)
	# Thin gravel shoulders only on the outside edges; grade from the road to yard gravel, no overlapping coplanar strips.
	for r in rects:
		for edge in range(4):
			var vertical := edge < 2
			var count := int(ceil((r.size.y if vertical else r.size.x) / 0.5))
			for n in range(count):
				var t0 := float(n) / count
				var t1 := float(n + 1) / count
				var p0 := Vector2(r.position.x if edge == 0 else r.end.x, lerpf(r.position.y, r.end.y, t0)) if vertical else Vector2(lerpf(r.position.x, r.end.x, t0), r.position.y if edge == 2 else r.end.y)
				var p1 := Vector2(p0.x, lerpf(r.position.y, r.end.y, t1)) if vertical else Vector2(lerpf(r.position.x, r.end.x, t1), p0.y)
				var out := Vector2(-1 if edge == 0 else 1, 0) if vertical else Vector2(0, -1 if edge == 2 else 1)
				var mid := (p0 + p1) * 0.5 + out * 0.02
				var covered := false
				for other in rects: covered = covered or other.has_point(mid)
				if covered: continue
				var q0 := p0 + out * 0.22
				var q1 := p1 + out * 0.22
				var s: MeshKit.Soup = a.soup(a.M_GRAVEL)
				var corners := [Vector3(p0.x, .084, p0.y), Vector3(p1.x, .084, p1.y), Vector3(q1.x, .052, q1.y), Vector3(q0.x, .052, q0.y)]
				if (corners[1] - corners[0]).cross(corners[2] - corners[0]).y < 0: corners.reverse()
				s.quad(corners[0], corners[1], corners[2], corners[3])

static func build(a) -> void:
	_architecture(a)
	_home_garden(a)
	_kiosk(a)
	# The west tunnel opening is intentional. Complete the short fence-to-portal joins instead of closing it.
	var hub: Rect2 = a.game.hub_rect()
	for z in [21.3, 29.5]:
		a._fence_line(Vector2(hub.position.x, z), Vector2(QuarryDelivery.WEST_GATE.x - 0.9, z), true, 1.6)
	# Give the existing east service opening visible gateposts and a track; it stays passable.
	for z in [9.0, 15.0]:
		a.bx("SteelGreen", Vector3(hub.end.x, 1.0, z), Vector3(.22, 2.0, .22))
		a.solid("Service gate post", Vector3(hub.end.x, 1.0, z), Vector3(.22, 2.0, .22))
	a.quad_flat(a.M_DIRT_ROAD, Vector3(29, 0, 12), Vector2(11, 5.5), 0, .051)

static func _architecture(a) -> void:
	var trim := material("Trim")
	var metal := material("Metal")
	for c in [a.game.HOME_POS, a.game.OFFICE_POS, a.game.SHED_POS, a.game.TOOLSHED_POS]:
		# Corner boards, sills, rain gutters and a quiet stone foundation break the rectangular silhouettes.
		for x in [-2.48, 2.48]:
			for z in [-2.38, 2.38]:
				a.bx(trim, c + Vector3(x, 1.42, z), Vector3(.13, 2.8, .13))
		for z in [-2.79, 2.79]:
			a.bx(metal, c + Vector3(0, 2.8, z), Vector3(5.85, .12, .13))
		for x in [-2.65, 2.65]:
			a.bx(trim, c + Vector3(x, 2.66, 0), Vector3(.13, .20, 5.5))
		a.bx(metal, c + Vector3(2.62, 1.40, 2.51), Vector3(.075, 2.72, .075))
		a.bx(trim, c + Vector3(0, .31, -2.48), Vector3(1.38, .08, .22))
	# Porch canopy and brackets: keep all structure to either side of the doorway/approach ramp.
	var hc: Vector3 = a.game.HOME_POS
	for x in [-1.12, 1.12]:
		a.bx(trim, hc + Vector3(x, 1.22, -2.65), Vector3(.10, 2.44, .10))
		a.solid("Home porch post", hc + Vector3(x, 1.22, -2.65), Vector3(.10, 2.44, .10))
	a.bx(material("Roof"), hc + Vector3(0, 2.48, -2.55), Vector3(2.7, .12, .6))
	a.bx(trim, hc + Vector3(0, 2.38, -2.85), Vector3(2.8, .16, .12))
	# Workshop canopy, tool silhouettes and timber bench make the upgrade entrance distinct.
	var wc: Vector3 = a.game.TOOLSHED_POS
	a.bx(metal, wc + Vector3(0, 2.65, -2.82), Vector3(2.3, .11, 1.0))
	for x in [-1.0, 1.0]:
		a.bx(trim, wc + Vector3(x, 2.40, -2.55), Vector3(.10, .45, .12))
	# Garage / industrial warehouse: visible structural bays, raised seam roof, clerestory windows and substantial supports.
	var x0: float = -4.7 + a.game.GARAGE_DX
	var x1: float = 14.5 + a.game.GARAGE_DX
	for x in a.garage_columns():
		a.bx(metal, Vector3(x, .25, 15), Vector3(.48, .5, .48))
		a.solid("Garage steel column", Vector3(x, 3.25, 15), Vector3(.22, 6.5, .22))
		a.bx(trim, Vector3(x, 6.53, 15), Vector3(.18, .13, 7.8))
		if x == x0 or x == x1:
			for z in [16.8, 19.2]: a._window(Vector3(x + (-.13 if x == x0 else .13), 4.72, z), -PI / 2 if x == x0 else PI / 2, 1.6, .65, false)
	var span := x1 - x0
	a.bx(metal, Vector3((x0 + x1) * .5, 6.04, 15), Vector3(span, .10, .22))
	for i in range(8):
		var start := Vector3(x0 + span * i / 8, 6.08 if i % 2 == 0 else 6.50, 15)
		var end := Vector3(x0 + span * (i + 1) / 8, 6.50 if i % 2 == 0 else 6.08, 15)
		var d := end - start
		MeshKit.box_into(a.soup(metal), Vector3.ZERO, Vector3(d.length(), .065, .10), Vector2.ONE, Transform3D(Basis(Vector3(0, 0, 1), atan2(d.y, d.x)), (start + end) * .5))
	var roof_details := MeshKit.Soup.new()
	for x in range(int(ceil(x0)), int(floor(x1)) + 1):
		# Follow the existing sloping roof, rather than floating straight ribs above it.
		MeshKit.box_into(roof_details, Vector3.ZERO, Vector3(.035, .055, 8.25), Vector2.ONE, Transform3D(Basis(Vector3.RIGHT, .055), Vector3(x, 6.51, 18.75)))

	MeshKit.inst(a.garage_roof, roof_details.mesh(), a._material(metal)).name = "RoofSeams"

static func _home_garden(a) -> void:
	var c: Vector3 = a.game.HOME_POS
	# A connected small garden fence with a 2.8 m front opening aligned with the house door.
	var left := c.x - 3.5
	var right := c.x + 3.5
	var front := c.z - 2.6
	var back := c.z + 3.5
	for run in [[Vector2(left, front), Vector2(left, back)], [Vector2(left, back), Vector2(right, back)], [Vector2(right, back), Vector2(right, front)], [Vector2(left, front), Vector2(c.x - 1.4, front)], [Vector2(c.x + 1.4, front), Vector2(right, front)]]:
		a._fence_line(run[0], run[1], true, 1.05)
	for x in [-2.95, 2.95]:
		a.quad_flat(material("Soil"), c + Vector3(x, 0, .25), Vector2(.55, 2.7), 0, .076)
		for dz in [-1.0, 0.0, 1.0]:
			MeshKit.frustum_into(a.soup(material("Grass")), c + Vector3(x, .08, dz + .25), .30, .18, .42, 7)
			MeshKit.frustum_into(a.soup(material("Roof")), c + Vector3(x, .43, dz + .25), .07, .04, .12, 6)

static func _kiosk(a) -> void:
	var c: Vector3 = a.game.machinery_station_position()
	for b in a.game.world.get_children():
		if b.has_meta("machinery_station"): a._hide(b)
	a.bx(material("Metal"), c + Vector3(0, .55, 0), Vector3(.82, 1.1, .66))
	a.bx(material("Trim"), c + Vector3(0, .08, 0), Vector3(.95, .16, .78))
	a.bx("SteelGreen", c + Vector3(0, 1.25, 0), Vector3(.88, .24, .72))
	a.bx(a.M_GLASS, c + Vector3(0, 1.18, -.37), Vector3(.58, .23, .018))
	a.bx("PaintYellow", c + Vector3(.24, .94, -.345), Vector3(.12, .045, .025))
	var sign := Label3D.new()
	sign.name = "MachineryOrdersSign"
	sign.text = "MACHINERY ORDERS\nE  •  ORDER / PREVIEW"
	sign.font = QuarryTheme.bold()
	sign.font_size = 40
	sign.pixel_size = .0035
	sign.outline_size = 4
	sign.modulate = Color(1.0, .90, .60)
	sign.position = c + Vector3(0, 1.95, -.03)
	sign.rotation.y = PI
	a.root.add_child(sign)
	a.light(c + Vector3(0, 2.1, -.6), Color(1.0, .84, .55), .55, 4)

static func north_range(a) -> void:
	# Continuous, multi-shouldered ridges, never isolated triangular cones.
	for layer in range(3):
		var s := MeshKit.Soup.new()
		var rows := []
		for j in range(5):
			var row := []
			for i in range(65):
				var x := -235.0 + i * 7.35
				var crest := 19 + layer * 6 + 6 * sin(x * .024 + layer) + 4 * sin(x * .057 + layer * 2) + 2 * cos(x * .11)
				var factor: float = [0.0, .54, 1.0, .62, .05][j]
				row.append(Vector3(x, -1 + crest * factor, -114.0 - layer * 25 - j * 12 + 3 * sin(x * .019 + j)))
			rows.append(row)
		for j in range(4):
			for i in range(64): s.quad(rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i])
		var mat := MeshKit.flat(Color(.40 + layer * .045, .44 + layer * .05, .38 + layer * .07))
		MeshKit.inst(a.root, s.mesh(), mat).name = "NorthRange%d" % layer

static func tunnel_hills(a) -> void:
	var all := MeshKit.Soup.new()
	# The clear z 21.3..29.5 corridor belongs exclusively to the existing tunnel shell.
	for interval in [[-8.0, 21.3], [29.5, 80.0]]:
		var rows := []
		for j in range(7):
			var row := []
			for i in range(17):
				var z: float = lerpf(interval[0], interval[1], float(i) / 16)
				var x := -24.0 - j * 12.5
				var envelope: float = [0.0, .68, 1.0, .93, .78, .45, .10][j]
				var h := 17 + 2.5 * sin(z * .09) + 2 * cos(z * .17 + j * .6)
				row.append(Vector3(x, h * envelope - .12, z))
			rows.append(row)
		for j in range(6):
			for i in range(16): all.quad(rows[j][i], rows[j + 1][i], rows[j + 1][i + 1], rows[j][i + 1])
	var mi := MeshKit.inst(a.root, all.mesh(), a._mountain_material())
	mi.name = "TunnelMountain"
	var body := StaticBody3D.new()
	body.name = "Visible tunnel hillside"
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	body.set_meta("nav_skip", true)
	a.game.world.add_child(body)
	# Low rock roof over the existing tunnel, with an irregular shoulder rather than a giant peak.
	var cap := MeshKit.Soup.new()
	MeshKit.rock_into(cap, Vector3(-43, 4.9, 25.4), Vector3(37, 6.5, 8.0), 713, 5, 12)
	MeshKit.inst(a.root, cap.mesh(), a._mountain_material()).name = "TunnelRockRoof"
