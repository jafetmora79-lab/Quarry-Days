extends RefCounted
class_name BuildingDetails
## The practical details of every yard building: eave and ridge carpentry, porch awnings, interior furnishing that fits each building's job, and Grandpa Walt's
## office with its physical computer. Everything is built from merged low-poly boxes (one draw call per material) on top of the existing shell
## (QuarryArt._walls: wall thickness, real window openings, foundation, door frame). `a` is the QuarryArt that owns the batches, colliders and lights.
## Furniture colliders are kept clear of the door lane (x within 0.8 m of the doorway, the first 1.2 m inside) and of every window.

const FLAT := "flat:"

static func col(a, c: Vector3, size: Vector3, color: Color, yaw := 0.0) -> void:
	a.bx(FLAT + color.to_html(false), c, size, yaw)

static func rot_box(a, c: Vector3, size: Vector3, color: Color, rot: Basis) -> void:
	MeshKit.box_into(a.soup(FLAT + color.to_html(false)), Vector3.ZERO, size, Vector2.ONE, Transform3D(rot, c))

# ------------------------------------------------------------------ shell carpentry shared by every building

## Rafter tails under the eaves, gutters, a ridge cap and the barge boards of the gable ends. h = wall height, rise = roof rise.
static func eaves(a, c: Vector3, w: float, d: float, h: float, rise: float, tint: Color) -> void:
	var tail := Color(0.34, 0.24, 0.16)
	var n := int(w / 0.55)
	for i in range(n + 1):
		var x := -w * 0.5 + 0.2 + (w - 0.4) * float(i) / float(n)
		for s in [-1.0, 1.0]:
			col(a, c + Vector3(x, h - 0.06, s * (d * 0.5 - 0.22)), Vector3(0.07, 0.11, 0.42), tail)
	for s in [-1.0, 1.0]:
		col(a, c + Vector3(0, h + 0.07, s * (d * 0.5 + 0.01)), Vector3(w + 0.1, 0.07, 0.07), Color(0.28, 0.28, 0.3))     # gutter
	col(a, c + Vector3(0, h + rise + 0.15, 0), Vector3(w + 0.12, 0.07, 0.24), tint)                                       # ridge cap
	# barge boards: the sloped boards along both gable ends
	var slope := atan2(rise, d * 0.5)
	for x in [-w * 0.5 + 0.1, w * 0.5 - 0.1]:
		for s in [-1.0, 1.0]:
			var mid := Vector3(x, h + 0.12 + rise * 0.5, s * d * 0.25)
			rot_box(a, c + mid, Vector3(0.07, 0.1, sqrt(pow(d * 0.5, 2) + rise * rise) + 0.1), Color(0.86, 0.84, 0.76), Basis(Vector3.RIGHT, -s * slope))

## A small awning over the front door on two posts (the door is on the -z face), so the entrance reads as one: roof, posts, a lantern.
static func porch_awning(a, c: Vector3, color: Color) -> void:
	col(a, c + Vector3(0, 2.62, -3.0), Vector3(2.1, 0.07, 1.0), color)
	col(a, c + Vector3(0, 2.7, -3.2), Vector3(2.1, 0.07, 0.12), color.darkened(0.2))
	for x in [-0.95, 0.95]:
		col(a, c + Vector3(x, 1.35, -3.38), Vector3(0.09, 2.5, 0.09), Color(0.86, 0.84, 0.76))
	col(a, c + Vector3(0, 2.2, -2.86), Vector3(0.12, 0.2, 0.12), Color(0.2, 0.2, 0.22))
	a.light(c + Vector3(0, 2.1, -3.0), Color(1.0, 0.84, 0.55), 0.9, 4.5)

# ------------------------------------------------------------------ Grandpa Walt's office

static func office_interior(a, c: Vector3) -> void:
	var game = a.game
	var wood := Color(0.42, 0.28, 0.17)
	var wood_dark := Color(0.3, 0.2, 0.12)
	var plastic := Color(0.80, 0.76, 0.64)
	var plastic_dark := Color(0.2, 0.2, 0.22)
	var fl := 0.165                                                  # the office floor
	# rug under the desk
	a.quad_flat(FLAT + Color(0.46, 0.2, 0.18).to_html(false), c + Vector3(0, 0, 0.7), Vector2(2.6, 1.5), 0.0, fl + 0.004)
	a.quad_flat(FLAT + Color(0.7, 0.55, 0.3).to_html(false), c + Vector3(0, 0, 0.7), Vector2(2.3, 1.2), 0.0, fl + 0.006)
	# the desk: a top, two drawer pedestals, a modesty panel. Its collider (Management desk, 1.8 x 1.0 x 0.8) is built by main.
	var d := c + Vector3(0, 0, 1.4)
	col(a, d + Vector3(0, 0.97, 0), Vector3(1.9, 0.06, 0.9), wood)
	for x in [-0.78, 0.78]:
		col(a, d + Vector3(x, 0.57, 0), Vector3(0.32, 0.8, 0.78), wood_dark)
		for k in range(3):
			col(a, d + Vector3(x, 0.38 + k * 0.26, -0.4), Vector3(0.28, 0.2, 0.02), wood)
			col(a, d + Vector3(x, 0.38 + k * 0.26, -0.415), Vector3(0.1, 0.02, 0.02), Color(0.8, 0.7, 0.4))
	col(a, d + Vector3(0, 0.75, 0.32), Vector3(1.24, 0.42, 0.03), wood_dark)
	# the CRT computer: base, swivel, case, tube housing, bezel, screen. Faces the player (-z).
	var m := d + Vector3(-0.3, 1.0, 0.0)
	col(a, m + Vector3(0, 0.02, 0), Vector3(0.28, 0.04, 0.24), plastic)
	col(a, m + Vector3(0, 0.06, 0), Vector3(0.14, 0.04, 0.12), plastic)
	col(a, m + Vector3(0, 0.27, -0.04), Vector3(0.48, 0.38, 0.14), plastic)
	col(a, m + Vector3(0, 0.27, 0.15), Vector3(0.36, 0.3, 0.26), plastic.darkened(0.08))
	col(a, m + Vector3(0, 0.27, 0.3), Vector3(0.22, 0.2, 0.08), plastic.darkened(0.15))
	col(a, m + Vector3(0, 0.275, -0.115), Vector3(0.4, 0.31, 0.01), plastic_dark)             # the bezel
	for i in range(5):
		col(a, m + Vector3(0.1 + i * 0.012, 0.12, -0.115), Vector3(0.006, 0.05, 0.012), plastic_dark)   # grille
	col(a, m + Vector3(-0.17, 0.115, -0.115), Vector3(0.025, 0.012, 0.012), Color(0.3, 0.85, 0.35))       # power lamp
	var screen := QuadMesh.new()
	screen.size = Vector2(0.34, 0.265)
	var smat := MeshKit.flat(Color(0.0, 0.5, 0.5), 0.9)
	smat.albedo_texture = load("res://assets/ui/os/wallpaper_tile.png") if ResourceLoader.exists("res://assets/ui/os/wallpaper_tile.png") else null
	smat.uv1_scale = Vector3(10.0, 8.0, 1.0)
	smat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	MeshKit.inst(a.root, screen, smat, m + Vector3(0, 0.275, -0.1215), Vector3(0, PI, 0))
	col(a, m + Vector3(0, 0.15, -0.122), Vector3(0.34, 0.025, 0.004), Color(0.75, 0.75, 0.75))           # a taskbar strip on the screen
	col(a, m + Vector3(-0.15, 0.15, -0.1235), Vector3(0.05, 0.02, 0.004), Color(0.2, 0.3, 0.55))
	game.pc_screen_pos = m + Vector3(0, 0.275, -0.1215)
	# keyboard, mouse and mat
	col(a, d + Vector3(-0.3, 1.015, -0.3), Vector3(0.44, 0.025, 0.15), plastic)
	col(a, d + Vector3(-0.3, 1.03, -0.3), Vector3(0.38, 0.008, 0.1), plastic.darkened(0.2))
	col(a, d + Vector3(0.1, 1.012, -0.3), Vector3(0.22, 0.006, 0.2), Color(0.18, 0.28, 0.4))
	col(a, d + Vector3(0.1, 1.025, -0.3), Vector3(0.06, 0.03, 0.1), plastic)
	# papers, invoices, a mug, a pencil cup, a paperweight rock, a framed photo
	col(a, d + Vector3(0.62, 1.01, -0.1), Vector3(0.28, 0.02, 0.36), Color(0.95, 0.93, 0.85), 0.2)
	col(a, d + Vector3(0.64, 1.03, -0.12), Vector3(0.26, 0.012, 0.34), Color(0.9, 0.88, 0.78), -0.1)
	col(a, d + Vector3(0.7, 1.05, 0.1), Vector3(0.1, 0.1, 0.1), Color(0.75, 0.35, 0.25))
	col(a, d + Vector3(-0.78, 1.05, 0.2), Vector3(0.09, 0.14, 0.09), Color(0.25, 0.3, 0.35))
	col(a, d + Vector3(-0.8, 1.14, 0.2), Vector3(0.012, 0.1, 0.012), Color(0.9, 0.75, 0.2), 0.2)
	col(a, d + Vector3(-0.68, 1.04, -0.05), Vector3(0.1, 0.07, 0.09), Color(0.74, 0.7, 0.6))
	col(a, d + Vector3(0.82, 1.1, 0.3), Vector3(0.16, 0.2, 0.02), Color(0.35, 0.22, 0.12), -0.4)
	col(a, d + Vector3(0.82, 1.1, 0.288), Vector3(0.12, 0.15, 0.005), Color(0.72, 0.8, 0.85), -0.4)
	# desk lamp with a warm pool of light
	col(a, d + Vector3(0.85, 1.015, -0.25), Vector3(0.16, 0.03, 0.16), Color(0.2, 0.3, 0.22))
	col(a, d + Vector3(0.85, 1.2, -0.25), Vector3(0.02, 0.36, 0.02), Color(0.2, 0.3, 0.22))
	col(a, d + Vector3(0.75, 1.38, -0.25), Vector3(0.2, 0.08, 0.12), Color(0.24, 0.4, 0.28))
	a.light(d + Vector3(0.7, 1.3, -0.25), Color(1.0, 0.82, 0.5), 0.8, 2.6)
	# bookcase on the back wall: frame, shelves and a row of binders
	var bk := c + Vector3(1.55, 0, 2.05)
	col(a, bk + Vector3(0, 0.95, 0), Vector3(1.0, 1.8, 0.04), wood_dark, 0.0)
	col(a, bk + Vector3(-0.49, 0.95, -0.1), Vector3(0.03, 1.8, 0.28), wood)
	col(a, bk + Vector3(0.49, 0.95, -0.1), Vector3(0.03, 1.8, 0.28), wood)
	for k in range(5):
		col(a, bk + Vector3(0, 0.2 + k * 0.4, -0.1), Vector3(1.0, 0.03, 0.28), wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var binder := [Color(0.55, 0.2, 0.18), Color(0.2, 0.32, 0.5), Color(0.25, 0.45, 0.3), Color(0.72, 0.6, 0.3), Color(0.4, 0.3, 0.2)]
	for k in range(1, 4):
		var x := -0.42
		while x < 0.4:
			var wdt := rng.randf_range(0.04, 0.09)
			col(a, bk + Vector3(x + wdt * 0.5, 0.2 + k * 0.4 + 0.15, -0.1), Vector3(wdt, rng.randf_range(0.22, 0.32), 0.2), binder[rng.randi() % binder.size()])
			x += wdt + 0.012
	a.solid("Office bookcase", bk + Vector3(0, 0.98, -0.08), Vector3(1.0, 1.8, 0.34))
	# quarry maps on the back wall above the desk: contour-line plans on aged paper, pinned
	var map_tex := _map_texture(rng)
	var mm := MeshKit.flat(Color(1, 1, 1))
	mm.albedo_texture = map_tex
	mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.78)
	MeshKit.inst(a.root, q, mm, c + Vector3(-0.35, 1.85, 2.205), Vector3(0, PI, 0))
	col(a, c + Vector3(-0.35, 1.85, 2.2), Vector3(1.16, 0.84, 0.01), wood_dark)
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.6, 0.45)
	MeshKit.inst(a.root, q2, mm, c + Vector3(0.65, 1.95, 2.205), Vector3(0, PI, 0.05))
	# a coat stand and a waste bin by the door side, clear of the lane
	col(a, c + Vector3(-1.9, 0.9, -1.8), Vector3(0.05, 1.5, 0.05), wood_dark)
	col(a, c + Vector3(-1.9, 1.62, -1.8), Vector3(0.3, 0.04, 0.04), wood_dark)
	col(a, c + Vector3(-1.9, 1.62, -1.8), Vector3(0.04, 0.04, 0.3), wood_dark)
	col(a, c + Vector3(-1.9, 1.2, -1.76), Vector3(0.3, 0.55, 0.08), Color(0.3, 0.36, 0.28))                # a work coat
	col(a, c + Vector3(-1.1, 0.35, 1.95), Vector3(0.3, 0.38, 0.3), Color(0.35, 0.36, 0.38))

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
	for i in range(26):                                                          # a dirt track winding to the pit
		var t := float(i) / 25.0
		img.set_pixel(clampi(int(2 + 20.0 * t + sin(t * 8.0) * 3.0), 0, 63), clampi(int(40.0 - 18.0 * t), 0, 45), Color(0.4, 0.32, 0.22))
	for i in range(8):
		img.set_pixel(rng.randi_range(3, 60), rng.randi_range(3, 42), Color(0.7, 0.2, 0.18))      # survey marks
	for x in range(64):
		img.set_pixel(x, 0, Color(0.45, 0.35, 0.22))
		img.set_pixel(x, 45, Color(0.45, 0.35, 0.22))
	for y in range(46):
		img.set_pixel(0, y, Color(0.45, 0.35, 0.22))
		img.set_pixel(63, y, Color(0.45, 0.35, 0.22))
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ the home

## A modest house: living area with the bed corner, a small kitchen along the back wall, a table, and a bathroom in the front-left corner with its own doorway.
static func home_interior(a, c: Vector3) -> void:
	var wood := Color(0.5, 0.34, 0.2)
	var white := Color(0.9, 0.9, 0.86)
	var steel := Color(0.72, 0.74, 0.76)
	# kitchen: counter with a sink and a stove along the back wall on the right
	col(a, c + Vector3(1.45, 0.62, 1.95), Vector3(1.5, 0.9, 0.55), wood)
	col(a, c + Vector3(1.45, 1.09, 1.95), Vector3(1.54, 0.05, 0.59), Color(0.8, 0.78, 0.7))
	col(a, c + Vector3(1.05, 1.13, 1.95), Vector3(0.45, 0.04, 0.34), steel)                         # sink
	col(a, c + Vector3(1.05, 1.28, 2.1), Vector3(0.03, 0.2, 0.03), steel)                           # tap
	col(a, c + Vector3(1.85, 1.13, 1.95), Vector3(0.4, 0.04, 0.4), Color(0.16, 0.16, 0.18))          # stove top with rings
	for p in [Vector2(-0.09, -0.09), Vector2(0.09, -0.09), Vector2(-0.09, 0.09), Vector2(0.09, 0.09)]:
		col(a, c + Vector3(1.85 + p.x, 1.16, 1.95 + p.y), Vector3(0.1, 0.01, 0.1), Color(0.35, 0.34, 0.34))
	col(a, c + Vector3(0.9, 1.65, 2.18), Vector3(1.0, 0.5, 0.26), wood)                                # wall cupboard
	a.solid("Kitchen counter", c + Vector3(1.45, 0.62, 1.95), Vector3(1.5, 0.9, 0.55))
	# table with two chairs under the right-hand windows (the door lane stays clear)
	col(a, c + Vector3(1.5, 0.78, -0.45), Vector3(0.9, 0.05, 0.8), wood)
	for p in [Vector2(-0.4, -0.35), Vector2(0.4, -0.35), Vector2(-0.4, 0.35), Vector2(0.4, 0.35)]:
		col(a, c + Vector3(1.5 + p.x, 0.47, -0.45 + p.y), Vector3(0.05, 0.62, 0.05), wood)
	for z in [-0.95, 0.05]:
		col(a, c + Vector3(1.0, 0.5, z + 0.0), Vector3(0.38, 0.05, 0.38), Color(0.45, 0.3, 0.2))
		col(a, c + Vector3(0.82, 0.78, z), Vector3(0.05, 0.5, 0.38), Color(0.45, 0.3, 0.2))
	col(a, c + Vector3(1.5, 0.83, -0.45), Vector3(0.14, 0.06, 0.14), Color(0.72, 0.35, 0.25))        # a bowl
	a.solid("Kitchen table", c + Vector3(1.5, 0.45, -0.45), Vector3(0.95, 0.9, 0.85))
	# a rug by the bed
	a.quad_flat(FLAT + Color(0.35, 0.42, 0.5).to_html(false), c + Vector3(-1.0, 0, 0.2), Vector2(1.6, 1.0), 0.0, 0.17)
	# bathroom in the front-left corner: two partition walls, a doorway facing the room, toilet, basin, mirror, shower tray
	var wall := Color(0.86, 0.84, 0.78)
	col(a, c + Vector3(-1.575, 1.35, -0.6), Vector3(1.35, 2.5, 0.1), wall)                           # along x, the long partition
	col(a, c + Vector3(-0.9, 1.35, -1.95), Vector3(0.1, 2.5, 0.5), wall)                             # along z: the strip beside the door
	col(a, c + Vector3(-0.9, 2.45, -1.2), Vector3(0.12, 0.3, 1.0), Color(0.86, 0.84, 0.76))        # lintel over the doorway
	for z in [-1.7, -0.7]:
		col(a, c + Vector3(-0.9, 1.1, z), Vector3(0.14, 2.2, 0.06), Color(0.86, 0.84, 0.76))        # door casing
	a.solid("Bathroom partition", c + Vector3(-1.575, 1.35, -0.6), Vector3(1.35, 2.5, 0.12))
	a.solid("Bathroom partition", c + Vector3(-0.9, 1.35, -1.95), Vector3(0.12, 2.5, 0.5))
	a.quad_flat(FLAT + Color(0.7, 0.78, 0.8).to_html(false), c + Vector3(-1.55, 0, -1.4), Vector2(1.3, 1.4), 0.0, 0.17)     # tiled floor
	col(a, c + Vector3(-2.0, 0.3, -1.0), Vector3(0.4, 0.34, 0.5), white)                           # toilet
	col(a, c + Vector3(-2.15, 0.62, -1.0), Vector3(0.14, 0.4, 0.4), white)
	col(a, c + Vector3(-1.55, 0.9, -0.62), Vector3(0.5, 0.1, 0.3), white)                          # basin
	col(a, c + Vector3(-1.55, 0.55, -0.68), Vector3(0.12, 0.7, 0.12), white)
	col(a, c + Vector3(-1.55, 1.5, -0.66), Vector3(0.5, 0.6, 0.02), Color(0.7, 0.85, 0.9))         # mirror
	col(a, c + Vector3(-1.9, 0.22, -2.0), Vector3(0.7, 0.1, 0.5), white)                           # shower tray
	a.light(c + Vector3(-1.5, 2.3, -1.4), Color(1.0, 0.92, 0.75), 0.5, 2.5)

# ------------------------------------------------------------------ sheds

## Roof carpentry inside a shed: tie beams across and a king post line under the ridge, so the ceiling reads as a real structure.
static func roof_frame(a, c: Vector3, h: float, rise: float, color: Color) -> void:
	for z in [-1.7, -0.6, 0.6, 1.7]:
		col(a, c + Vector3(0, h - 0.12, z), Vector3(4.5, 0.14, 0.1), color)
		col(a, c + Vector3(0, h - 0.12 + rise * 0.28, z), Vector3(0.08, rise * 0.56, 0.08), color)
	col(a, c + Vector3(0, h + rise * 0.55, 0), Vector3(0.1, 0.1, 4.4), color)

## The storage shed: a rolling door on its rails, ventilation louvres, crates, drums, pallets of stock and floor wear.
static func storage_shed(a, c: Vector3) -> void:
	var steel := Color(0.5, 0.52, 0.55)
	roof_frame(a, c, 2.8, 0.7, Color(0.36, 0.38, 0.4))
	for x in [-0.82, 0.82]:
		col(a, c + Vector3(x, 1.3, -2.46), Vector3(0.07, 2.6, 0.1), steel)                       # door guide rails
	col(a, c + Vector3(0, 2.62, -2.46), Vector3(1.8, 0.2, 0.18), steel)                         # the roll housing
	for i in range(3):                                                                           # ventilation louvres high in the back wall
		col(a, c + Vector3(1.0 + i * 0.4, 2.45, 2.22), Vector3(0.3, 0.05, 0.04), Color(0.3, 0.32, 0.34))
	# crates and drums along the back, clear of the lane
	var crate := Color(0.58, 0.44, 0.27)
	for p in [Vector3(-0.3, 0.45, 2.0), Vector3(0.35, 0.45, 2.0), Vector3(0.0, 0.95, 2.0)]:
		col(a, c + p, Vector3(0.55, 0.5, 0.45), crate)
	for p in [Vector2(-1.9, -1.85), Vector2(-1.5, -1.9), Vector2(-1.7, -1.5)]:
		col(a, c + Vector3(p.x, 0.5, p.y), Vector3(0.5, 0.7, 0.5), Color(0.3, 0.42, 0.55))      # oil drums
		col(a, c + Vector3(p.x, 0.86, p.y), Vector3(0.52, 0.04, 0.52), Color(0.2, 0.28, 0.36))
	a.solid("Shed drums", c + Vector3(-1.75, 0.5, -1.75), Vector3(0.9, 0.7, 0.8))
	a.solid("Shed crates", c + Vector3(0.0, 0.5, 2.0), Vector3(1.2, 1.0, 0.6))
	a.quad_flat(FLAT + Color(0.1, 0.1, 0.12).to_html(false), c + Vector3(0.4, 0, -0.5), Vector2(0.9, 0.6), 0.5, 0.17)       # an oil stain on the concrete

## The tool shed / workshop: roof frame, a hanging work lamp, a parts shelf with bins, a tool chest and a grinder. The workbench itself is built by main.
static func workshop(a, c: Vector3) -> void:
	roof_frame(a, c, 2.8, 0.9, Color(0.36, 0.26, 0.18))
	col(a, c + Vector3(0, 2.3, 0.3), Vector3(0.02, 0.5, 0.02), Color(0.15, 0.15, 0.17))
	col(a, c + Vector3(0, 2.05, 0.3), Vector3(0.4, 0.14, 0.4), Color(0.2, 0.32, 0.22))            # a pendant work lamp over the floor
	a.light(c + Vector3(0, 1.9, 0.3), Color(1.0, 0.9, 0.7), 0.7, 4.0)
	var bins := [Color(0.75, 0.3, 0.25), Color(0.25, 0.45, 0.7), Color(0.85, 0.7, 0.2), Color(0.3, 0.55, 0.35)]
	for k in range(4):                                                                           # coloured parts bins on the side shelving
		col(a, c + Vector3(-1.95, 0.55 + (k % 2) * 0.55, -0.1 + (k / 2) * 0.55), Vector3(0.32, 0.22, 0.4), bins[k])
	col(a, c + Vector3(1.9, 1.05, 0.3), Vector3(0.6, 0.22, 1.0), Color(0.7, 0.18, 0.15))           # tool chest lid
	col(a, c + Vector3(1.9, 0.78, -0.05), Vector3(0.02, 0.08, 0.5), Color(0.75, 0.7, 0.6))
	col(a, c + Vector3(1.9, 1.2, 0.3), Vector3(0.18, 0.1, 0.3), Color(0.35, 0.36, 0.4))            # a grinder on top
	a.quad_flat(FLAT + Color(0.1, 0.1, 0.12).to_html(false), c + Vector3(-0.6, 0, 0.9), Vector2(0.8, 0.55), 0.3, 0.17)
