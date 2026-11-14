extends RefCounted
class_name BuildingDetails
## Furnishing and small construction details for the yard buildings, built on the shell made by QuarryArt (_walls, _gable_roof): office with Walt's CRT computer, the house,
## the storage shed and the workshop. Everything is merged low-poly boxes (one draw call per colour, one mesh node in all) and every box is recorded in `registry`
## so a test can prove nothing floats: each detail must rest on the floor, hang from the ceiling, be fixed to a wall, or touch another detail.
## Interior frame (building centre c, +z = back wall, the door is in the -z wall): floor top y = 0.165, ceiling underside y = 2.74, inner wall faces at x = +-2.27, z = +-2.22.
## Furniture stays out of the door lane (x within 0.8 m of the doorway, z < -1.0) and of the door's swing (a 1.4 m leaf sweeping into the room).

const FLAT := "flat:"
const FLOOR := 0.165
static var registry: Array = []          ## [AABB, tag] of every detail box, in world space

static func col(a, c: Vector3, size: Vector3, color: Color, yaw := 0.0) -> void:
	a.bx(FLAT + color.to_html(false), c, size, yaw)
	registry.append([_aabb(c, size, Basis(Vector3.UP, yaw)), "box"])

static func rot_box(a, c: Vector3, size: Vector3, color: Color, rot: Basis) -> void:
	MeshKit.box_into(a.soup(FLAT + color.to_html(false)), Vector3.ZERO, size, Vector2.ONE, Transform3D(rot, c))
	registry.append([_aabb(c, size, rot), "box"])

static func _aabb(c: Vector3, size: Vector3, rot: Basis) -> AABB:
	var out := AABB(c, Vector3.ZERO)
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				out = out.expand(c + rot * Vector3(size.x * sx, size.y * sy, size.z * sz))
	return out

## A box in a furniture group's local frame: `at` is the group origin on the floor, `yaw` turns the group, `local` is the box centre relative to it.
static func lbox(a, at: Vector3, yaw: float, local: Vector3, size: Vector3, color: Color) -> void:
	col(a, at + Basis(Vector3.UP, yaw) * local, size, color, yaw)

## A wooden chair (front towards +z in its own frame): legs, seat, back. `collide` adds a seat-height collider for a chair people could walk into.
static func chair(a, at: Vector3, yaw: float, wood: Color, collide := true) -> void:
	for p in [Vector2(-0.19, -0.19), Vector2(0.19, -0.19), Vector2(-0.19, 0.19), Vector2(0.19, 0.19)]:
		lbox(a, at, yaw, Vector3(p.x, 0.25, p.y), Vector3(0.04, 0.5, 0.04), wood)
	lbox(a, at, yaw, Vector3(0, 0.52, 0), Vector3(0.44, 0.05, 0.44), wood)
	lbox(a, at, yaw, Vector3(0, 0.78, -0.2), Vector3(0.44, 0.5, 0.04), wood)
	if collide:
		a.solid("Chair", at + Vector3(0, 0.275, 0), Vector3(0.46, 0.55, 0.46), yaw)

## The office swivel chair: a five-point base, a column, a padded seat and back.
static func swivel_chair(a, at: Vector3, yaw: float, fabric: Color, frame: Color) -> void:
	for ang in [0.0, 1.2566, 2.5133, 3.7699, 5.0265]:
		lbox(a, at, yaw, Vector3(cos(ang) * 0.17, 0.02, sin(ang) * 0.17), Vector3(0.34, 0.04, 0.05), frame)
	lbox(a, at, yaw, Vector3(0, 0.25, 0), Vector3(0.06, 0.42, 0.06), frame)
	lbox(a, at, yaw, Vector3(0, 0.5, 0), Vector3(0.48, 0.1, 0.46), fabric)
	lbox(a, at, yaw, Vector3(0, 0.8, -0.22), Vector3(0.46, 0.5, 0.07), fabric)
	var cb: StaticBody3D = a.solid("Office chair", at + Vector3(0, 0.275, 0), Vector3(0.5, 0.55, 0.5), yaw)   # seat height: stops you walking through it
	cb.set_meta("kind", "office")                     # ...and aiming at the chair uses the computer too, so the chair can never hide the desk from the crosshair

# ------------------------------------------------------------------ Grandpa Walt's office

## The desk stands against the back wall with the screen facing the room: you walk up, stand at the chair side and use it. The collider (Management desk) is main's.
const OFFICE_DESK_Z := 1.76
static func office_interior(a, c: Vector3) -> void:
	var game = a.game
	var wood := Color(0.42, 0.28, 0.17)
	var wood_dark := Color(0.3, 0.2, 0.12)
	var plastic := Color(0.80, 0.76, 0.64)
	var plastic_dark := Color(0.2, 0.2, 0.22)
	# rug under the desk end of the room
	a.quad_flat(FLAT + Color(0.46, 0.2, 0.18).to_html(false), c + Vector3(0, 0, 0.95), Vector2(2.6, 1.7), 0.0, FLOOR + 0.004)
	a.quad_flat(FLAT + Color(0.7, 0.55, 0.3).to_html(false), c + Vector3(0, 0, 0.95), Vector2(2.3, 1.4), 0.0, FLOOR + 0.006)
	# the desk: top, two drawer pedestals (drawer fronts face the sitter), a back panel against the wall
	var d := c + Vector3(0, 0, OFFICE_DESK_Z)
	col(a, d + Vector3(0, 0.97, 0), Vector3(1.9, 0.06, 0.9), wood)
	for x in [-0.78, 0.78]:
		col(a, d + Vector3(x, 0.55, 0), Vector3(0.32, 0.76, 0.78), wood_dark)
		for k in range(3):
			col(a, d + Vector3(x, 0.36 + k * 0.24, -0.405), Vector3(0.28, 0.2, 0.03), wood)
			col(a, d + Vector3(x, 0.36 + k * 0.24, -0.425), Vector3(0.1, 0.02, 0.02), Color(0.8, 0.7, 0.4))
	col(a, d + Vector3(0, 0.7, 0.4), Vector3(1.24, 0.5, 0.04), wood_dark)
	# the CRT: base, swivel, case, tube housing, bezel, screen. Faces the room (-z).
	var m := d + Vector3(-0.3, 1.0, 0.0)
	col(a, m + Vector3(0, 0.02, 0), Vector3(0.28, 0.04, 0.24), plastic)
	col(a, m + Vector3(0, 0.06, 0), Vector3(0.14, 0.04, 0.12), plastic)
	col(a, m + Vector3(0, 0.27, -0.04), Vector3(0.48, 0.38, 0.14), plastic)
	col(a, m + Vector3(0, 0.27, 0.15), Vector3(0.36, 0.3, 0.26), plastic.darkened(0.08))
	col(a, m + Vector3(0, 0.27, 0.3), Vector3(0.22, 0.2, 0.08), plastic.darkened(0.15))
	col(a, m + Vector3(0, 0.275, -0.115), Vector3(0.4, 0.31, 0.01), plastic_dark)
	for i in range(5):
		col(a, m + Vector3(0.1 + i * 0.012, 0.12, -0.12), Vector3(0.006, 0.05, 0.012), plastic_dark)
	col(a, m + Vector3(-0.17, 0.115, -0.12), Vector3(0.025, 0.012, 0.012), Color(0.3, 0.85, 0.35))
	var screen := QuadMesh.new()
	screen.size = Vector2(0.34, 0.265)
	var smat := MeshKit.flat(Color(0.0, 0.5, 0.5), 0.9)
	smat.albedo_texture = load("res://assets/ui/os/wallpaper_tile.png") if ResourceLoader.exists("res://assets/ui/os/wallpaper_tile.png") else null
	smat.uv1_scale = Vector3(10.0, 8.0, 1.0)
	smat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	MeshKit.inst(a.root, screen, smat, m + Vector3(0, 0.275, -0.1215), Vector3(0, PI, 0))
	col(a, m + Vector3(0, 0.15, -0.1225), Vector3(0.34, 0.025, 0.004), Color(0.75, 0.75, 0.75))           # a taskbar strip on the screen
	col(a, m + Vector3(-0.15, 0.15, -0.124), Vector3(0.05, 0.02, 0.004), Color(0.2, 0.3, 0.55))
	game.pc_screen_pos = m + Vector3(0, 0.275, -0.1215)
	# the outline proxy for the interaction highlight: the monitor, the desk top and the pedestals as inset boxes (1 cm inside the real surfaces, so only the outline shows)
	var ps := MeshKit.Soup.new()
	for pb in [[m + Vector3(0, 0.27, -0.04), Vector3(0.46, 0.36, 0.12)], [m + Vector3(0, 0.27, 0.15), Vector3(0.34, 0.28, 0.24)], [m + Vector3(0, 0.02, 0), Vector3(0.26, 0.03, 0.22)],
			[d + Vector3(0, 0.97, 0), Vector3(1.88, 0.04, 0.88)], [d + Vector3(-0.78, 0.55, 0), Vector3(0.3, 0.74, 0.76)], [d + Vector3(0.78, 0.55, 0), Vector3(0.3, 0.74, 0.76)]]:
		MeshKit.box_into(ps, pb[0], pb[1])
	var proxy := MeshKit.inst(a.root, ps.mesh(), MeshKit.flat(Color(0.2, 0.2, 0.2)))
	proxy.name = "ComputerHighlight"
	game.computer_proxy = proxy
	# keyboard, mouse and mat on the sitter's side of the monitor
	col(a, d + Vector3(-0.3, 1.015, -0.28), Vector3(0.44, 0.025, 0.15), plastic)
	col(a, d + Vector3(-0.3, 1.03, -0.28), Vector3(0.38, 0.008, 0.1), plastic.darkened(0.2))
	# (the sitter faces +z, so their right hand is -x: the mouse and its mat lie to the right of the keyboard)
	col(a, d + Vector3(-0.72, 1.007, -0.28), Vector3(0.22, 0.01, 0.2), Color(0.18, 0.28, 0.4))
	col(a, d + Vector3(-0.72, 1.025, -0.28), Vector3(0.06, 0.03, 0.1), plastic)
	# papers and invoices, a mug, a pencil cup, a paperweight rock and a framed photo, all lying on the desk top
	col(a, d + Vector3(0.62, 1.01, -0.1), Vector3(0.28, 0.02, 0.36), Color(0.95, 0.93, 0.85), 0.2)
	col(a, d + Vector3(0.64, 1.03, -0.12), Vector3(0.26, 0.012, 0.34), Color(0.9, 0.88, 0.78), -0.1)
	col(a, d + Vector3(0.7, 1.08, 0.12), Vector3(0.1, 0.1, 0.1), Color(0.75, 0.35, 0.25))
	col(a, d + Vector3(-0.78, 1.08, 0.18), Vector3(0.09, 0.14, 0.09), Color(0.25, 0.3, 0.35))
	col(a, d + Vector3(-0.8, 1.17, 0.18), Vector3(0.012, 0.1, 0.012), Color(0.9, 0.75, 0.2), 0.2)
	col(a, d + Vector3(-0.68, 1.035, -0.05), Vector3(0.1, 0.07, 0.09), Color(0.74, 0.7, 0.6))
	col(a, d + Vector3(0.82, 1.12, 0.3), Vector3(0.16, 0.2, 0.02), Color(0.35, 0.22, 0.12))
	col(a, d + Vector3(0.82, 1.12, 0.288), Vector3(0.12, 0.15, 0.005), Color(0.72, 0.8, 0.85))
	# desk lamp: a base on the desk, an arm, a shade, and its warm light
	col(a, d + Vector3(0.85, 1.015, -0.25), Vector3(0.16, 0.03, 0.16), Color(0.2, 0.3, 0.22))
	col(a, d + Vector3(0.85, 1.2, -0.25), Vector3(0.02, 0.34, 0.02), Color(0.2, 0.3, 0.22))
	col(a, d + Vector3(0.8, 1.38, -0.25), Vector3(0.2, 0.08, 0.12), Color(0.24, 0.4, 0.28))
	a.light(d + Vector3(0.7, 1.3, -0.25), Color(1.0, 0.82, 0.5), 0.8, 2.6)
	# the chair is pulled out from the desk, turned to it: room to sit, room to walk round (it has a collider)
	swivel_chair(a, c + Vector3(0.15, FLOOR, 0.9), 0.15, Color(0.3, 0.22, 0.2), Color(0.18, 0.18, 0.2))
	# bookcase against the back wall, right of the desk
	var bk := c + Vector3(1.6, 0, 2.05)
	col(a, bk + Vector3(0, 0.95, 0.15), Vector3(1.0, 1.8, 0.04), wood_dark)
	col(a, bk + Vector3(-0.49, 0.95, 0.0), Vector3(0.03, 1.8, 0.28), wood)
	col(a, bk + Vector3(0.49, 0.95, 0.0), Vector3(0.03, 1.8, 0.28), wood)
	for k in range(5):
		col(a, bk + Vector3(0, 0.2 + k * 0.4, 0.0), Vector3(1.0, 0.03, 0.28), wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var binder := [Color(0.55, 0.2, 0.18), Color(0.2, 0.32, 0.5), Color(0.25, 0.45, 0.3), Color(0.72, 0.6, 0.3), Color(0.4, 0.3, 0.2)]
	for k in range(1, 4):
		var x := -0.42
		while x < 0.4:
			var wdt := rng.randf_range(0.04, 0.09)
			col(a, bk + Vector3(x + wdt * 0.5, 0.2 + k * 0.4 + 0.015 + 0.14, 0.0), Vector3(wdt, 0.28, 0.2), binder[rng.randi() % binder.size()])
			x += wdt + 0.012
	a.solid("Office bookcase", bk + Vector3(0, 0.98, 0.0), Vector3(1.0, 1.8, 0.32))
	# quarry plans pinned to the back wall above the desk: contour lines on aged paper, clear of the monitor
	var map_tex := _map_texture(rng)
	var mm := MeshKit.flat(Color(1, 1, 1))
	mm.albedo_texture = map_tex
	mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.78)
	MeshKit.inst(a.root, q, mm, c + Vector3(-0.35, 2.0, 2.205), Vector3(0, PI, 0))
	col(a, c + Vector3(-0.35, 2.0, 2.2), Vector3(1.16, 0.84, 0.01), wood_dark)
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.6, 0.45)
	MeshKit.inst(a.root, q2, mm, c + Vector3(0.7, 2.05, 2.205), Vector3(0, PI, 0.05))
	col(a, c + Vector3(0.7, 2.05, 2.2), Vector3(0.66, 0.5, 0.01), wood_dark)
	# a wastebin beside the desk
	col(a, c + Vector3(-1.2, 0.35, 1.9), Vector3(0.3, 0.38, 0.3), Color(0.35, 0.36, 0.38))

## A small hand-drawn quarry plan: contour rings around a pit, a track and survey marks. Never any text.
static func _map_texture(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(64, 46, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.86, 0.8, 0.62))
	for y in range(46):
		for x in range(64):
			var dx := (x - 30.0) / 22.0
			var dy := (y - 22.0) / 15.0
			var r := sqrt(dx * dx + dy * dy)
			if absf(fmod(r * 5.0, 1.0)) < 0.12 and r < 1.0:
				img.set_pixel(x, y, Color(0.52, 0.38, 0.24))
			if r < 0.28:
				img.set_pixel(x, y, Color(0.62, 0.5, 0.34))
	for i in range(26):
		var t := float(i) / 25.0
		img.set_pixel(clampi(int(2 + 20.0 * t + sin(t * 8.0) * 3.0), 0, 63), clampi(int(40.0 - 18.0 * t), 0, 45), Color(0.4, 0.32, 0.22))
	for i in range(8):
		img.set_pixel(rng.randi_range(3, 60), rng.randi_range(3, 42), Color(0.7, 0.2, 0.18))
	for x in range(64):
		img.set_pixel(x, 0, Color(0.45, 0.35, 0.22))
		img.set_pixel(x, 45, Color(0.45, 0.35, 0.22))
	for y in range(46):
		img.set_pixel(0, y, Color(0.45, 0.35, 0.22))
		img.set_pixel(63, y, Color(0.45, 0.35, 0.22))
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ the home

## A modest house: living area with the bed corner, a small kitchen along the back wall, a table with two chairs under the east windows, and a bathroom in
## the front-left corner with its own doorway. The door (hinge on the east, leaf swinging into the room) sweeps x -0.7..0.95, z < -0.95: nothing stands there.
static func home_interior(a, c: Vector3) -> void:
	var wood := Color(0.5, 0.34, 0.2)
	var white := Color(0.9, 0.9, 0.86)
	var steel := Color(0.72, 0.74, 0.76)
	# kitchen: counter with a sink and a stove against the back wall, a cupboard above
	col(a, c + Vector3(1.45, 0.62, 1.93), Vector3(1.5, 0.9, 0.58), wood)
	col(a, c + Vector3(1.45, 1.095, 1.93), Vector3(1.54, 0.05, 0.62), Color(0.8, 0.78, 0.7))
	col(a, c + Vector3(1.05, 1.125, 1.93), Vector3(0.45, 0.02, 0.34), steel)
	col(a, c + Vector3(1.05, 1.25, 2.1), Vector3(0.03, 0.23, 0.03), steel)
	col(a, c + Vector3(1.85, 1.13, 1.93), Vector3(0.4, 0.04, 0.4), Color(0.16, 0.16, 0.18))
	for p in [Vector2(-0.09, -0.09), Vector2(0.09, -0.09), Vector2(-0.09, 0.09), Vector2(0.09, 0.09)]:
		col(a, c + Vector3(1.85 + p.x, 1.16, 1.93 + p.y), Vector3(0.1, 0.01, 0.1), Color(0.35, 0.34, 0.34))
	col(a, c + Vector3(0.95, 1.75, 2.09), Vector3(1.0, 0.5, 0.26), wood)
	a.solid("Kitchen counter", c + Vector3(1.45, 0.62, 1.93), Vector3(1.5, 0.9, 0.58))
	# table, tucked under the east windows; the chairs sit north and south of it, pulled out a hand's width
	col(a, c + Vector3(1.5, 0.78, -0.45), Vector3(0.9, 0.05, 0.8), wood)
	for p in [Vector2(-0.4, -0.35), Vector2(0.4, -0.35), Vector2(-0.4, 0.35), Vector2(0.4, 0.35)]:
		col(a, c + Vector3(1.5 + p.x, 0.4, -0.45 + p.y), Vector3(0.05, 0.76, 0.05), wood)
	col(a, c + Vector3(1.5, 0.845, -0.45), Vector3(0.14, 0.08, 0.14), Color(0.72, 0.35, 0.25))
	a.solid("Kitchen table", c + Vector3(1.5, 0.45, -0.45), Vector3(0.95, 0.9, 0.85))
	chair(a, c + Vector3(1.5, FLOOR, -1.25), 0.0, Color(0.45, 0.3, 0.2))                            # north side, facing the table
	chair(a, c + Vector3(1.5, FLOOR, 0.35), PI, Color(0.45, 0.3, 0.2))                              # south side
	# a rug by the bed
	a.quad_flat(FLAT + Color(0.35, 0.42, 0.5).to_html(false), c + Vector3(-1.0, 0, 0.2), Vector2(1.6, 1.0), 0.0, FLOOR + 0.004)
	# bathroom in the front-left corner: two partition walls, a doorway facing the room, toilet, basin, mirror, shower tray
	var wall := Color(0.86, 0.84, 0.78)
	col(a, c + Vector3(-1.575, 1.44, -0.6), Vector3(1.35, 2.6, 0.1), wall)                           # the long partition, floor to ceiling
	col(a, c + Vector3(-0.9, 1.44, -1.95), Vector3(0.1, 2.6, 0.5), wall)                             # the strip beside the door
	col(a, c + Vector3(-0.9, 2.5, -1.2), Vector3(0.1, 0.5, 1.0), wall)                              # the head over the doorway
	for z in [-1.7, -0.7]:
		col(a, c + Vector3(-0.9, 1.1, z), Vector3(0.14, 2.2, 0.06), Color(0.86, 0.84, 0.76))        # door casing
	a.solid("Bathroom partition", c + Vector3(-1.575, 1.44, -0.6), Vector3(1.35, 2.6, 0.12))
	a.solid("Bathroom partition", c + Vector3(-0.9, 1.44, -1.95), Vector3(0.12, 2.6, 0.5))
	a.quad_flat(FLAT + Color(0.7, 0.78, 0.8).to_html(false), c + Vector3(-1.55, 0, -1.4), Vector2(1.3, 1.4), 0.0, FLOOR + 0.004)
	col(a, c + Vector3(-2.02, 0.4, -1.0), Vector3(0.4, 0.4, 0.5), white)                           # toilet bowl
	col(a, c + Vector3(-2.17, 0.75, -1.0), Vector3(0.1, 0.4, 0.4), white)                           # cistern against the west wall
	col(a, c + Vector3(-1.55, 0.9, -0.68), Vector3(0.5, 0.1, 0.3), white)                           # basin on the partition
	col(a, c + Vector3(-1.55, 0.5, -0.68), Vector3(0.1, 0.8, 0.1), white)                           # its pedestal
	col(a, c + Vector3(-1.55, 1.55, -0.65), Vector3(0.5, 0.6, 0.02), Color(0.7, 0.85, 0.9))          # mirror on the partition
	col(a, c + Vector3(-1.85, 0.23, -1.95), Vector3(0.8, 0.12, 0.5), white)                         # shower tray
	a.light(c + Vector3(-1.5, 2.3, -1.4), Color(1.0, 0.92, 0.75), 0.5, 2.5)

# ------------------------------------------------------------------ sheds

## Three tie beams across the room, directly under the ceiling and meeting both walls.
static func ceiling_beams(a, c: Vector3, color: Color) -> void:
	for z in [-1.4, 0.0, 1.4]:
		col(a, c + Vector3(0, 2.67, z), Vector3(4.54, 0.14, 0.1), color)         # top face at 2.74: flush with the ceiling underside

## A gable-end vent on the outer face of each gable wall: a dark frame with three slats. (Fixed to the wall: nothing hangs in the air.)
static func gable_vents(a, c: Vector3, h: float, rise: float) -> void:
	for sx in [-1.0, 1.0]:
		var x: float = sx * 2.53
		col(a, c + Vector3(x, h + rise * 0.42, 0), Vector3(0.04, 0.3, 0.56), Color(0.16, 0.16, 0.18))
		for k in range(3):
			col(a, c + Vector3(x + sx * 0.02, h + rise * 0.42 - 0.09 + k * 0.09, 0), Vector3(0.03, 0.04, 0.5), Color(0.5, 0.52, 0.55))

## The storage shed: a roll-up door on its guides, two shelving bays (placed by the art), crates stacked against the back wall, drums beside them.
static func storage_shed(a, c: Vector3) -> void:
	var steel := Color(0.5, 0.52, 0.55)
	ceiling_beams(a, c, Color(0.36, 0.38, 0.4))
	gable_vents(a, c, 2.8, 0.7)
	for x in [-0.82, 0.82]:
		col(a, c + Vector3(x, 1.3, -2.46), Vector3(0.07, 2.6, 0.1), steel)                       # door guide rails
	col(a, c + Vector3(0, 2.62, -2.46), Vector3(1.8, 0.2, 0.18), steel)                         # the roll housing over the door
	var crate := Color(0.58, 0.44, 0.27)
	for p in [Vector3(-0.3, 0.42, 1.97), Vector3(0.35, 0.42, 1.97), Vector3(0.02, 0.89, 1.97)]:
		col(a, c + p, Vector3(0.6, 0.5, 0.5), crate)
	a.solid("Shed crates", c + Vector3(0.02, 0.6, 1.97), Vector3(1.3, 1.0, 0.5))
	for p in [Vector2(1.12, 1.9), Vector2(-1.12, 1.9)]:                                          # oil drums: round, beside the crates, clear of the shelving bays
		MeshKit.frustum_into(a.soup(FLAT + Color(0.3, 0.42, 0.55).to_html(false)), c + Vector3(p.x, FLOOR, p.y), 0.26, 0.26, 0.7, 8)
		registry.append([AABB(c + Vector3(p.x - 0.26, FLOOR, p.y - 0.26), Vector3(0.52, 0.7, 0.52)), "drum"])
		a.solid("Shed drum", c + Vector3(p.x, FLOOR + 0.35, p.y), Vector3(0.52, 0.7, 0.52))
	a.quad_flat(FLAT + Color(0.1, 0.1, 0.12).to_html(false), c + Vector3(0.4, 0, -0.5), Vector2(0.9, 0.6), 0.5, FLOOR + 0.004)       # an oil stain on the concrete

## The workshop: tie beams, gable vents and a pendant work lamp on its cord from the ceiling. The workbench and pegboard are main's; the shelving and boxes are the art's.
static func workshop(a, c: Vector3) -> void:
	ceiling_beams(a, c, Color(0.36, 0.26, 0.18))
	gable_vents(a, c, 2.8, 0.9)
	col(a, c + Vector3(0, 2.52, 0.7), Vector3(0.02, 0.44, 0.02), Color(0.15, 0.15, 0.17))        # the cord: from the ceiling slab down to the shade
	col(a, c + Vector3(0, 2.23, 0.7), Vector3(0.4, 0.14, 0.4), Color(0.2, 0.32, 0.22))
	a.light(c + Vector3(0, 2.05, 0.7), Color(1.0, 0.9, 0.7), 0.7, 4.0)
