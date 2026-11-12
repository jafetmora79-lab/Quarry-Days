extends RefCounted
class_name OpeningModels
## Phase 10.1: the opening's props - the repair parts lying by the workshop, the parts fitted on Grandpa's excavator, and the natural
## starting ground (dirt patches, scrub, pebbles, boulders, half-buried limestone outcrops). Procedural MeshKit geometry, flat-shaded.

static func _inst(parent: Node3D, soup: MeshKit.Soup, mat: Material) -> MeshInstance3D:
	var mi := MeshKit.inst(parent, soup.mesh(), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## The three loose parts (lying on the ground, origin at the ground).
static func part(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Part_" + id
	var steel := MeshKit.Soup.new()
	var dark := MeshKit.Soup.new()
	var accent := MeshKit.Soup.new()
	match id:
		"battery":        # a fresh battery: black case, two terminals, a yellow strap
			MeshKit.box_into(dark, Vector3(0, 0.14, 0), Vector3(0.36, 0.26, 0.2))
			MeshKit.box_into(accent, Vector3(0, 0.28, 0), Vector3(0.38, 0.02, 0.05))
			for x in [-0.1, 0.1]:
				MeshKit.frustum_into(steel, Vector3(x, 0.27, 0.05), 0.025, 0.02, 0.05, 6)
			MeshKit.box_into(accent, Vector3(0, 0.14, 0.1), Vector3(0.2, 0.08, 0.01))
		"hose":           # a coil of hydraulic hose with brass fittings
			for k in range(5):
				var a := TAU * float(k) / 5.0
				MeshKit.box_into(dark, Vector3(cos(a) * 0.2, 0.05 + 0.04 * (k % 2), sin(a) * 0.2), Vector3(0.18, 0.06, 0.07), Vector2.ONE)
			MeshKit.frustum_into(dark, Vector3(0, 0.0, 0), 0.24, 0.24, 0.07, 10)
			MeshKit.frustum_into(dark, Vector3(0, 0.07, 0), 0.19, 0.19, 0.07, 10)
			MeshKit.box_into(accent, Vector3(0.26, 0.06, 0), Vector3(0.08, 0.07, 0.07))
			MeshKit.box_into(accent, Vector3(-0.26, 0.06, 0), Vector3(0.08, 0.07, 0.07))
		"fuel":           # a red jerry can with a spout and a handle
			MeshKit.box_into(dark, Vector3(0, 0.22, 0), Vector3(0.34, 0.44, 0.16), Vector2(0.96, 0.96))
			MeshKit.box_into(steel, Vector3(0, 0.46, 0.0), Vector3(0.18, 0.04, 0.05))
			MeshKit.frustum_into(steel, Vector3(-0.1, 0.44, 0), 0.03, 0.02, 0.1, 6)
			MeshKit.box_into(accent, Vector3(0, 0.22, 0.081), Vector3(0.2, 0.2, 0.01))
	var mats := {"dark": MeshKit.flat(Color(0.12, 0.12, 0.13)), "steel": MeshKit.mat("SteelPlate"), "accent": MeshKit.flat(Color(0.86, 0.66, 0.12))}
	if id == "fuel":
		mats["dark"] = MeshKit.flat(Color(0.72, 0.12, 0.1))
		mats["accent"] = MeshKit.flat(Color(0.9, 0.85, 0.7))
	if id == "hose":
		mats["accent"] = MeshKit.flat(Color(0.75, 0.55, 0.2))
	_inst(n, dark, mats["dark"])
	_inst(n, steel, mats["steel"])
	_inst(n, accent, mats["accent"])
	return n

## The state of the three repairs on the excavator itself (model units of VehicleModels.excavator: hood at y 1.2, z +0.45).
## A missing battery shows the empty tray and loose cables; a split hose hangs limp with an oil stain; an unfuelled tank has an open filler.
static func fitted(parent: Node3D, battery: bool, hose: bool, fuel: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "OpeningParts"
	var dark := MeshKit.Soup.new()
	var rust := MeshKit.Soup.new()
	var accent := MeshKit.Soup.new()
	var steel := MeshKit.Soup.new()
	var oil := MeshKit.Soup.new()
	if battery:
		MeshKit.box_into(dark, Vector3(0.62, 1.66, 0.45), Vector3(0.34, 0.22, 0.2))
		MeshKit.box_into(accent, Vector3(0.62, 1.78, 0.45), Vector3(0.36, 0.02, 0.05))
		for x in [0.54, 0.7]:
			MeshKit.frustum_into(steel, Vector3(x, 1.77, 0.5), 0.025, 0.02, 0.05, 6)
	else:
		MeshKit.box_into(rust, Vector3(0.62, 1.58, 0.45), Vector3(0.38, 0.06, 0.24))               # the empty tray
		for dx in [0.5, 0.74]:
			MeshKit.box_into(dark, Vector3(dx, 1.5, 0.52), Vector3(0.025, 0.2, 0.025))             # loose cables
	if hose:
		MeshKit.box_into(dark, Vector3(-0.35, 1.5, -1.05), Vector3(0.05, 0.05, 0.75))              # hose along the boom foot
	else:
		MeshKit.box_into(rust, Vector3(-0.35, 1.2, -1.1), Vector3(0.05, 0.42, 0.05))               # a limp, split hose
		MeshKit.box_into(oil, Vector3(-0.35, 0.02, -1.25), Vector3(0.7, 0.01, 0.55))               # oil on the ground
	if fuel:
		MeshKit.frustum_into(accent, Vector3(-0.62, 1.54, 0.55), 0.07, 0.07, 0.04, 8)               # filler cap, closed
	else:
		MeshKit.frustum_into(dark, Vector3(-0.62, 1.54, 0.55), 0.07, 0.04, 0.02, 8)                 # open, empty filler
	_inst(n, dark, MeshKit.flat(Color(0.1, 0.1, 0.11)))
	_inst(n, rust, MeshKit.flat(Color(0.42, 0.2, 0.12)))
	_inst(n, accent, MeshKit.flat(Color(0.86, 0.66, 0.12)))
	_inst(n, steel, MeshKit.mat("SteelPlate"))
	_inst(n, oil, MeshKit.flat(Color(0.05, 0.04, 0.03)))
	parent.add_child(n)
	return n

## The natural starting ground. `ok` is a Callable(Vector2) -> bool telling where scenery may stand (clear of the hub, paths, the hillside).
## Returns {"root": Node3D, "boulders": int, "outcrops": int, "patches": int, "scrub": int, "pebbles": int}.
static func natural_ground(world: Node3D, ok: Callable, area: Rect2, seed_value := 1010) -> Dictionary:
	var root := Node3D.new()
	root.name = "NaturalStart"
	world.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var taken: Array = []         # [centre Vector2, radius] of the solid and bushy things already placed
	var pick := func(rad: float, record: bool) -> Variant:
		for attempt in range(60):
			var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			if not ok.call(p):
				continue
			var far := true
			for t in taken:
				if (t[0] as Vector2).distance_to(p) < rad + float(t[1]) + 0.3:
					far = false
					break
			if far:
				if record:
					taken.append([p, rad])
				return p
		return null
	var counts := {"boulders": 0, "outcrops": 0, "patches": 0, "scrub": 0, "pebbles": 0}
	# natural boulders (solid) and partly buried limestone outcrops (solid, sunk into the ground)
	var bmat := MeshKit.mat("RockLimestone")
	for kind in ["boulder", "outcrop"]:
		var how_many := 9 if kind == "boulder" else 6
		for i in range(how_many):
			var c = pick.call(2.6 if kind == "outcrop" else 1.5, true)
			if c == null:
				continue
			var size := Vector3(rng.randf_range(1.1, 2.0), rng.randf_range(0.9, 1.6), rng.randf_range(1.1, 2.0)) if kind == "boulder" else Vector3(rng.randf_range(2.6, 4.2), rng.randf_range(1.4, 2.0), rng.randf_range(2.0, 3.2))
			var body := StaticBody3D.new()
			body.name = kind.capitalize()
			body.position = Vector3(c.x, 0.0, c.y)
			body.rotation.y = rng.randf_range(0.0, TAU)
			var s := MeshKit.Soup.new()
			MeshKit.rock_into(s, Vector3(0, -size.y * (0.1 if kind == "boulder" else 0.35), 0), size, 3000 + i * 7 + (0 if kind == "boulder" else 100), 4, 7)
			if kind == "outcrop":
				MeshKit.rock_into(s, Vector3(size.x * 0.45, -size.y * 0.4, size.z * 0.2), size * 0.55, 3100 + i, 3, 6)     # a second, smaller lump beside it
			_inst(body, s, bmat)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(size.x * 0.8, size.y * (0.75 if kind == "boulder" else 0.5), size.z * 0.8)
			cs.shape = box
			cs.position.y = box.size.y * 0.5 - 0.05
			body.add_child(cs)
			body.set_meta("natural", kind)
			root.add_child(body)
			counts["boulders" if kind == "boulder" else "outcrops"] += 1
	# bare dirt: irregular fans just above the ground, so the working area reads as a dug-over site
	var dirt := MeshKit.Soup.new()
	for i in range(11):
		var c = pick.call(0.0, false)
		if c == null:
			continue
		var r := rng.randf_range(3.0, 6.0)
		var n := 9
		for k in range(n):
			var a0 := TAU * float(k) / float(n)
			var a1 := TAU * float(k + 1) / float(n)
			var r0 := r * rng.randf_range(0.7, 1.15)
			var r1 := r * rng.randf_range(0.7, 1.15)
			dirt.tri(Vector3(c.x, 0.03, c.y), Vector3(c.x + cos(a1) * r1, 0.03, c.y + sin(a1) * r1), Vector3(c.x + cos(a0) * r0, 0.03, c.y + sin(a0) * r0))
		counts["patches"] += 1
	_inst(root, dirt, MeshKit.mat("ExcavatedDirt"))
	# scrub: low dark-green mounds, and tufts of dry grass
	var scrub := MeshKit.Soup.new()
	var tufts := MeshKit.Soup.new()
	for i in range(34):
		var c = pick.call(0.7, true)
		if c == null:
			continue
		MeshKit.rock_into(scrub, Vector3(c.x, 0.0, c.y), Vector3(rng.randf_range(0.6, 1.2), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.2)), 500 + i, 3, 6)
		counts["scrub"] += 1
	for i in range(60):
		var c = pick.call(0.2, false)
		if c == null:
			continue
		for b in range(3):
			var off := Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
			MeshKit.frustum_into(tufts, Vector3(c.x + off.x, 0.0, c.y + off.y), 0.07, 0.01, rng.randf_range(0.25, 0.5), 4)
	_inst(root, scrub, MeshKit.flat(Color(0.2, 0.31, 0.16)))
	_inst(root, tufts, MeshKit.flat(Color(0.5, 0.46, 0.22)))
	# small scattered rocks, one merged mesh
	var pebbles := MeshKit.Soup.new()
	for i in range(70):
		var c = pick.call(0.3, false)
		if c == null:
			continue
		var sz := rng.randf_range(0.18, 0.5)
		MeshKit.rock_into(pebbles, Vector3(c.x, -0.03, c.y), Vector3(sz * rng.randf_range(0.8, 1.4), sz * 0.6, sz * rng.randf_range(0.8, 1.4)), 900 + i, 3, 5)
		counts["pebbles"] += 1
	_inst(root, pebbles, MeshKit.mat("RockLimestone"))
	counts["root"] = root
	return counts
