extends RefCounted
class_name GearModels
## Phase 9 addendum: original low-poly models for the new tools, hauling aids and the compressor, in the same procedural
## MeshKit style as the rest of the game (flat-shaded boxes, extruded heads, frustums; shared materials, a handful of
## meshes each). Handheld tools follow the first-person convention: handle along +Y from the grip, the working head at the
## top, fore-aft along Z. Their first-person poses and the places the hands close on them are in POSE.
##   tool tier numbers >= TIER_BASE are these tools: tier = TIER_BASE + index in IDS.

const TIER_BASE := 10
const IDS := ["pointed_chisel", "flat_chisel", "repaired_pickaxe", "sledgehammer", "steel_pickaxe", "hardened_pickaxe", "hand_splitter", "powered_hammer", "pneumatic_chisel"]

const SWING := {"grip": Vector3(0.30, -0.42, -0.55), "scale": 0.8, "rest": -0.75, "yaw": 0.2, "wind": 0.1, "strike": -1.35}

## First-person poses. `power` tools run continuously (spin = "pump_y" / "pump_z" / "rotate"); the others swing: `wind` and
## `strike` are the pitch angles at the top of the back-swing and at the blow (the chisels tap with small angles, the
## sledgehammer winds up high over the shoulder, the splitter is pressed and its lever pumped).
const POSE := {
	"pointed_chisel": {"grip": Vector3(0.28, -0.40, -0.52), "scale": 1.0, "rest": -0.95, "yaw": 0.12, "wind": -0.45, "strike": -1.1, "tip": Vector3(0, 0.44, 0),
		"hands": [["R", Vector3(0, 0.05, 0)]]},
	"flat_chisel": {"grip": Vector3(0.28, -0.40, -0.52), "scale": 1.0, "rest": -0.95, "yaw": 0.12, "wind": -0.4, "strike": -1.12, "tip": Vector3(0, 0.43, 0),
		"hands": [["R", Vector3(0, 0.05, 0)]]},
	"repaired_pickaxe": {"grip": Vector3(0.30, -0.42, -0.55), "scale": 0.8, "rest": -0.75, "yaw": 0.2, "wind": 0.1, "strike": -1.35, "tip": Vector3(0, 0.5, -0.28),
		"hands": [["R", Vector3(0, 0.15, 0)], ["L", Vector3(0, 0.36, 0)]]},
	"sledgehammer": {"grip": Vector3(0.32, -0.46, -0.5), "scale": 0.82, "rest": -0.55, "yaw": 0.15, "wind": 0.75, "strike": -1.5, "tip": Vector3(0, 0.74, -0.15), "lift": 0.1,
		"hands": [["R", Vector3(0, 0.12, 0)], ["L", Vector3(0, 0.4, 0)]]},
	"steel_pickaxe": {"grip": Vector3(0.30, -0.42, -0.55), "scale": 0.78, "rest": -0.75, "yaw": 0.2, "wind": 0.1, "strike": -1.35, "tip": Vector3(0, 0.55, -0.31),
		"hands": [["R", Vector3(0, 0.14, 0)], ["L", Vector3(0, 0.4, 0)]]},
	"hardened_pickaxe": {"grip": Vector3(0.30, -0.42, -0.55), "scale": 0.76, "rest": -0.75, "yaw": 0.2, "wind": 0.12, "strike": -1.38, "tip": Vector3(0, 0.57, -0.33),
		"hands": [["R", Vector3(0, 0.15, 0)], ["L", Vector3(0, 0.42, 0)]]},
	"hand_splitter": {"grip": Vector3(0.28, -0.40, -0.5), "scale": 0.85, "rest": -0.95, "yaw": 0.1, "wind": -0.55, "strike": -1.2, "tip": Vector3(0, 0.46, -0.02), "lever": true,
		"hands": [["R", Vector3(0, 0.05, 0)], ["L", Vector3(0, 0.21, 0.24)]]},
	"powered_hammer": {"grip": Vector3(0.28, -0.32, -0.5), "scale": 0.75, "power": true, "rest_rot": Vector3(0.1, 0.2, 0.0), "tip": Vector3(0, 0.12, -0.5), "spin": "pump_z", "amp": 0.012,
		"hands": [["R", Vector3(0, 0.0, 0.08)], ["L", Vector3(-0.07, 0.14, -0.1)]]},
	"pneumatic_chisel": {"grip": Vector3(0.3, -0.14, -0.5), "scale": 0.75, "power": true, "rest_rot": Vector3(0.0, 0.3, 0.0), "model_pitch": 0.8, "tip": Vector3(0, -0.62, 0), "spin": "pump_y", "amp": 0.012,
		"hands": [["R", Vector3(0.14, 0.0, 0)], ["L", Vector3(-0.14, 0.0, 0)]]},
}

static func tier_of(id: String) -> int:
	var i := IDS.find(id)
	return TIER_BASE + i if i >= 0 else -1

static func id_of(tier: int) -> String:
	return str(IDS[tier - TIER_BASE]) if tier >= TIER_BASE and tier - TIER_BASE < IDS.size() else ""

# ------------------------------------------------------------------ a tiny builder: soups per material, one mesh each

class Builder:
	var soups := {}
	var mats := {}
	func _init() -> void:
		mats = {"steel": MeshKit.mat("SteelPlate"), "wood": MeshKit.mat(QuarryArt.M_WOOD), "dark": MeshKit.mat(QuarryArt.M_RUBBER), "rust": MeshKit.mat(QuarryArt.M_RUSTED),
			"bright": MeshKit.mat(QuarryArt.M_BRUSHED), "yellow": MeshKit.mat("PaintYellow"), "red": MeshKit.mat("PaintRed"), "orange": MeshKit.mat("PaintOrange"),
			"oldwood": MeshKit.flat(Color(0.37, 0.27, 0.18)), "blue": MeshKit.flat(Color(0.24, 0.34, 0.46)), "rope": MeshKit.flat(Color(0.62, 0.52, 0.34))}
	func s(m: String) -> MeshKit.Soup:
		if not soups.has(m):
			soups[m] = MeshKit.Soup.new()
		return soups[m]
	func box(m: String, c: Vector3, size: Vector3, taper := Vector2.ONE, xf := Transform3D.IDENTITY) -> void:
		MeshKit.box_into(s(m), c, size, taper, xf)
	func cyl(m: String, c: Vector3, r0: float, r1: float, h: float, seg := 8, xf := Transform3D.IDENTITY) -> void:
		MeshKit.frustum_into(s(m), c, r0, r1, h, seg, xf)
	func along_z(m: String, c: Vector3, r0: float, r1: float, h: float, seg := 8) -> void:
		# a cylinder lying along -Z starting at c
		MeshKit.frustum_into(s(m), Vector3.ZERO, r0, r1, h, seg, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), c))
	func along_x(m: String, c: Vector3, r: float, w: float, seg := 10) -> void:
		MeshKit.frustum_into(s(m), Vector3.ZERO, r, r, w, seg, Transform3D(Basis(Vector3(0, 0, 1), -PI / 2), c + Vector3(-w * 0.5, 0, 0)))
	func ext(m: String, prof: PackedVector2Array, width: float, at: Vector3) -> void:
		MeshKit.extrude_into(s(m), prof, width, Transform3D(Basis.IDENTITY, at))
	func finish(into: Node3D) -> void:
		MeshKit.repair(soups)
		for k in soups:
			var so: MeshKit.Soup = soups[k]
			if so.verts.size() > 0:
				var mi := MeshKit.inst(into, so.mesh(), mats[k])
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ------------------------------------------------------------------ handheld tools

static func build_tool(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Gear_" + id
	var b := Builder.new()
	match id:
		"pointed_chisel":      # slim steel shaft, taped grip, mushroomed strike end and a long pointed tip
			b.box("dark", Vector3(0, 0.05, 0), Vector3(0.042, 0.15, 0.042))
			b.cyl("steel", Vector3(0, -0.045, 0), 0.026, 0.018, 0.035, 6)
			b.box("steel", Vector3(0, 0.25, 0), Vector3(0.024, 0.26, 0.024))
			b.cyl("steel", Vector3(0, 0.37, 0), 0.015, 0.0035, 0.13, 6)
			b.cyl("steel", Vector3(0, 0.12, 0), 0.03, 0.03, 0.014, 6)          # hand guard ring
		"flat_chisel":         # wide worn blade with a bevelled cutting edge
			b.box("dark", Vector3(0, 0.05, 0), Vector3(0.05, 0.15, 0.036))
			b.cyl("steel", Vector3(0, -0.045, 0), 0.028, 0.02, 0.035, 6)
			b.box("steel", Vector3(0, 0.25, 0), Vector3(0.034, 0.24, 0.03))
			b.box("rust", Vector3(0, 0.39, 0), Vector3(0.085, 0.16, 0.022), Vector2(1.0, 0.18))
			b.box("dark", Vector3(0.035, 0.43, 0.0), Vector3(0.012, 0.02, 0.012))   # a nick in the edge
			b.box("steel", Vector3(0, 0.15, 0), Vector3(0.05, 0.02, 0.05))
		"repaired_pickaxe":    # re-handled pick: splinted handle, bands, patched head
			b.box("wood", Vector3(0, 0.22, 0), Vector3(0.036, 0.56, 0.042))
			b.box("rope", Vector3(0, 0.07, 0), Vector3(0.05, 0.14, 0.055))
			for y in [0.34, 0.43]:
				b.box("steel", Vector3(0, y, 0), Vector3(0.056, 0.032, 0.062))
			b.box("steel", Vector3(0.024, 0.27, 0), Vector3(0.012, 0.2, 0.05))     # splint plate
			for y in [0.19, 0.27, 0.35]:
				b.box("bright", Vector3(0.032, y, 0), Vector3(0.012, 0.014, 0.02))   # rivets
			b.ext("steel", PackedVector2Array([Vector2(-0.28, -0.02), Vector2(-0.03, 0.035), Vector2(0.03, 0.035), Vector2(0.28, -0.02), Vector2(0.2, -0.048), Vector2(0.0, -0.016), Vector2(-0.2, -0.048)]), 0.05, Vector3(0, 0.5, 0))
			b.box("bright", Vector3(0, 0.505, 0), Vector3(0.056, 0.05, 0.08))      # welded patch plate over the eye
		"sledgehammer":        # long thick handle, substantial rectangular head
			b.box("wood", Vector3(0, 0.3, 0), Vector3(0.046, 0.78, 0.052), Vector2(0.9, 0.9))
			b.box("dark", Vector3(0, 0.02, 0), Vector3(0.058, 0.26, 0.062))
			b.cyl("dark", Vector3(0, -0.09, 0), 0.04, 0.034, 0.05, 6)
			b.box("steel", Vector3(0, 0.74, 0), Vector3(0.12, 0.12, 0.3))
			b.box("steel", Vector3(0, 0.74, -0.15), Vector3(0.13, 0.13, 0.03))     # striking faces
			b.box("steel", Vector3(0, 0.74, 0.15), Vector3(0.13, 0.13, 0.03))
			b.box("red", Vector3(0, 0.74, -0.08), Vector3(0.126, 0.126, 0.02))      # paint bands
			b.box("red", Vector3(0, 0.74, 0.08), Vector3(0.126, 0.126, 0.02))
			b.box("steel", Vector3(0, 0.66, 0), Vector3(0.07, 0.05, 0.09))         # collar under the head
		"steel_pickaxe":       # forged curved head, ferrule, rubber grip
			b.box("wood", Vector3(0, 0.23, 0), Vector3(0.034, 0.6, 0.04))
			b.cyl("dark", Vector3(0, -0.02, 0), 0.027, 0.031, 0.26, 7)
			b.cyl("steel", Vector3(0, 0.46, 0), 0.034, 0.03, 0.06, 6)              # ferrule
			b.ext("bright", PackedVector2Array([Vector2(-0.36, -0.01), Vector2(-0.22, 0.04), Vector2(-0.04, 0.052), Vector2(0.04, 0.052), Vector2(0.22, 0.04), Vector2(0.36, -0.01),
				Vector2(0.25, -0.04), Vector2(0.0, -0.022), Vector2(-0.25, -0.04)]), 0.044, Vector3(0, 0.55, 0))
			b.box("steel", Vector3(0, 0.55, 0), Vector3(0.05, 0.07, 0.07))         # socket
		"hardened_pickaxe":    # heavy industrial head: pick one side, chisel blade the other; ergonomic composite handle
			b.cyl("dark", Vector3(0, -0.03, 0), 0.024, 0.032, 0.2, 7)               # swelling ergonomic grip
			b.box("blue", Vector3(0, 0.34, 0), Vector3(0.036, 0.46, 0.044))
			b.box("steel", Vector3(0, 0.09, 0), Vector3(0.05, 0.02, 0.06))
			b.cyl("steel", Vector3(0, -0.07, 0), 0.034, 0.03, 0.04, 6)
			b.ext("steel", PackedVector2Array([Vector2(-0.34, -0.03), Vector2(-0.12, 0.05), Vector2(0.04, 0.062), Vector2(0.14, 0.062), Vector2(0.27, 0.04), Vector2(0.28, -0.07),
				Vector2(0.14, -0.05), Vector2(0.0, -0.03), Vector2(-0.14, -0.06)]), 0.07, Vector3(0, 0.56, 0))
			b.box("red", Vector3(0, 0.56, 0.05), Vector3(0.074, 0.03, 0.05))       # painted stripe
			b.box("dark", Vector3(0, 0.58, 0.285), Vector3(0.08, 0.1, 0.02))       # rubber bumper on the blade
			b.box("bright", Vector3(0, 0.52, -0.33), Vector3(0.02, 0.02, 0.05))    # hardened tip
		"hand_splitter":       # a feather-and-wedge splitter: rubber grip, steel column, jaw block with two plates and a wedge, pumping lever
			b.cyl("dark", Vector3(0, -0.05, 0), 0.03, 0.034, 0.2, 8)               # rubber grip
			b.cyl("steel", Vector3(0, 0.15, 0), 0.05, 0.05, 0.016, 8)               # hand guard
			b.cyl("steel", Vector3(0, 0.166, 0), 0.032, 0.03, 0.25, 8)              # column
			b.box("steel", Vector3(0, 0.46, 0), Vector3(0.07, 0.09, 0.15))          # jaw block, standing on the column
			for z in [-0.083, 0.083]:
				b.box("steel", Vector3(0, 0.47, z), Vector3(0.06, 0.12, 0.016))      # the two jaw plates, flat against the block
			b.box("bright", Vector3(0, 0.575, 0), Vector3(0.035, 0.1, 0.12), Vector2(0.35, 1.0))   # the wedge, seated between the plates
			b.along_z("bright", Vector3(0, 0.47, 0.105), 0.016, 0.016, 0.21, 6)      # cross bolt through both plates and the block
			b.along_x("bright", Vector3(0.0, 0.3, 0.0), 0.018, 0.13, 6)             # pivot bolt through the column
			var lever := Node3D.new()
			lever.name = "Lever"
			lever.position = Vector3(0, 0.3, 0.0)
			n.add_child(lever)
			var lb := Builder.new()
			lb.box("orange", Vector3(0, 0.0, 0.0), Vector3(0.1, 0.06, 0.08))        # the lever's eye wraps the column
			lb.box("orange", Vector3(0, 0.0, 0.22), Vector3(0.036, 0.04, 0.4))      # arm
			lb.box("dark", Vector3(0, 0.0, 0.39), Vector3(0.05, 0.05, 0.12))        # hand grip on the arm's end
			lb.finish(lever)
			n.set_meta("lever", lever)
		"powered_hammer":      # demolition hammer: orange motor housing, vented, clamped barrel, pistol grip, top handle, cable and a chisel bit
			b.box("orange", Vector3(0, 0.12, 0.0), Vector3(0.13, 0.16, 0.3), Vector2(0.92, 0.95))   # housing
			b.box("dark", Vector3(0, 0.12, 0.165), Vector3(0.11, 0.13, 0.03))       # rubber end cap
			for z in [-0.06, -0.02, 0.02, 0.06]:
				b.box("dark", Vector3(0.067, 0.13, z), Vector3(0.012, 0.08, 0.016))  # vent slats, set into the side
				b.box("dark", Vector3(-0.067, 0.13, z), Vector3(0.012, 0.08, 0.016))
			b.box("dark", Vector3(0, 0.0, 0.07), Vector3(0.055, 0.19, 0.075), Vector2(0.9, 0.9))   # pistol grip, hanging from the housing
			b.box("steel", Vector3(0, 0.07, 0.02), Vector3(0.022, 0.05, 0.03))      # trigger in front of the grip
			b.box("dark", Vector3(0, 0.215, 0.09), Vector3(0.1, 0.036, 0.1))        # top handle
			b.along_z("steel", Vector3(0, 0.12, -0.15), 0.045, 0.045, 0.14, 8)      # barrel
			b.along_z("steel", Vector3(0, 0.12, -0.18), 0.054, 0.054, 0.035, 8)     # clamp ring round the barrel
			b.box("dark", Vector3(-0.095, 0.12, -0.17), Vector3(0.07, 0.034, 0.034))   # side grip bolted to the clamp
			MeshKit.tube_into(b.s("dark"), [Vector3(0, 0.12, 0.17), Vector3(0, 0.09, 0.21), Vector3(0, 0.03, 0.235), Vector3(0, -0.04, 0.24)], 0.014, 6)   # the cable leaves the end cap
			var ram := Node3D.new()
			ram.position = Vector3(0, 0.12, -0.32)
			n.add_child(ram)
			var rb := Builder.new()
			rb.box("bright", Vector3(0, 0, 0.0), Vector3(0.07, 0.07, 0.05))         # the hammer collar rides out of the barrel
			rb.box("steel", Vector3(0, 0, 0.06), Vector3(0.05, 0.05, 0.1))          # and back into it
			rb.box("bright", Vector3(0, 0, -0.07), Vector3(0.028, 0.028, 0.12))      # chisel bit
			rb.box("bright", Vector3(0, 0, -0.15), Vector3(0.014, 0.014, 0.04), Vector2(0.4, 0.4))
			rb.finish(ram)
			n.set_meta("spinner", ram)
		"pneumatic_chisel":    # air chisel: ribbed steel body with a colour band, T-handle, air inlet with its hose, spring retainer and the vibrating chisel
			b.cyl("steel", Vector3(0, -0.4, 0), 0.054, 0.048, 0.37, 8)             # body
			b.cyl("blue", Vector3(0, -0.27, 0), 0.058, 0.058, 0.05, 8)             # colour band
			b.cyl("steel", Vector3(0, -0.04, 0), 0.062, 0.058, 0.05, 8)            # top cap
			b.cyl("dark", Vector3(0, -0.435, 0), 0.058, 0.058, 0.035, 8)           # spring retainer at the nose
			b.cyl("bright", Vector3(0, 0.01, 0), 0.034, 0.03, 0.04, 6)             # post up into the handle
			b.box("steel", Vector3(0, 0.04, 0), Vector3(0.34, 0.04, 0.04))         # T-handle bar, sitting on the post
			for x in [-0.15, 0.15]:
				b.box("dark", Vector3(x, 0.04, 0), Vector3(0.1, 0.06, 0.06))       # rubber grips
			b.box("bright", Vector3(0.0, -0.01, 0.06), Vector3(0.04, 0.04, 0.05))  # air inlet nipple on the cap
			MeshKit.tube_into(b.s("dark"), [Vector3(0, -0.01, 0.085), Vector3(0, 0.0, 0.17), Vector3(0, -0.04, 0.26), Vector3(0, -0.14, 0.32), Vector3(0, -0.26, 0.34)], 0.017, 6)   # the air hose, one piece, from the inlet
			var chisel := Node3D.new()
			chisel.position = Vector3(0, -0.44, 0)
			n.add_child(chisel)
			var cb := Builder.new()
			cb.box("steel", Vector3(0, 0.0, 0), Vector3(0.05, 0.04, 0.05))         # collar, sliding in the retainer
			cb.box("bright", Vector3(0, -0.08, 0), Vector3(0.032, 0.14, 0.032))    # shank
			cb.box("bright", Vector3(0, -0.17, 0), Vector3(0.05, 0.05, 0.012), Vector2(0.3, 1.0))   # chisel blade
			cb.finish(chisel)
			n.set_meta("spinner", chisel)
	b.finish(n)
	return n

## The three ladder tools whose models were upgraded in Phase 9 (worn pickaxe, reinforced pickaxe, corded drill).
static func build_ladder(t: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Tool%d" % t
	var b := Builder.new()
	match t:
		1:   # worn pickaxe: weathered handle, rusty narrow head, loose wedge, frayed tape
			b.box("oldwood", Vector3(0, 0.22, 0), Vector3(0.036, 0.56, 0.042))
			b.box("dark", Vector3(0, 0.05, 0), Vector3(0.048, 0.1, 0.052))
			b.box("rope", Vector3(0, 0.38, 0.0), Vector3(0.046, 0.04, 0.05))
			b.ext("rust", PackedVector2Array([Vector2(-0.27, -0.02), Vector2(-0.03, 0.03), Vector2(0.03, 0.03), Vector2(0.27, -0.02), Vector2(0.2, -0.045), Vector2(0.0, -0.015), Vector2(-0.2, -0.045)]), 0.042, Vector3(0, 0.5, 0))
			b.box("steel", Vector3(0, 0.46, 0.0), Vector3(0.02, 0.05, 0.03))
		2:   # reinforced pickaxe: heavier painted head, steel braces down both sides of the handle
			b.box("wood", Vector3(0, 0.24, 0), Vector3(0.04, 0.6, 0.045))
			for x in [-0.026, 0.026]:
				b.box("steel", Vector3(x, 0.28, 0), Vector3(0.012, 0.5, 0.034))
			for y in [0.06, 0.2, 0.38]:
				b.box("steel", Vector3(0, y, 0), Vector3(0.062, 0.03, 0.062))
			b.ext("red", PackedVector2Array([Vector2(-0.33, -0.03), Vector2(-0.04, 0.052), Vector2(0.04, 0.052), Vector2(0.33, -0.03), Vector2(0.25, -0.07), Vector2(0.0, -0.025), Vector2(-0.25, -0.07)]), 0.075, Vector3(0, 0.55, 0))
			b.box("steel", Vector3(0, 0.52, -0.325), Vector3(0.06, 0.06, 0.07))
			b.box("steel", Vector3(0, 0.52, 0.325), Vector3(0.06, 0.06, 0.07))
		3:   # corded rock drill: motor body, pistol grip, trigger, side handle, power cord, long bit
			b.box("yellow", Vector3(0, 0.12, -0.04), Vector3(0.1, 0.13, 0.3))
			b.box("dark", Vector3(0, 0.0, 0.05), Vector3(0.07, 0.17, 0.08), Vector2(0.9, 0.9))
			b.box("steel", Vector3(0, 0.075, -0.0), Vector3(0.016, 0.035, 0.026))           # trigger
			b.box("dark", Vector3(0, 0.12, 0.14), Vector3(0.08, 0.1, 0.06))                 # rear motor cap
			b.box("steel", Vector3(0, 0.12, -0.22), Vector3(0.07, 0.07, 0.07))              # chuck
			b.box("dark", Vector3(-0.07, 0.07, -0.12), Vector3(0.1, 0.028, 0.028))          # side handle
			b.box("dark", Vector3(-0.12, 0.07, -0.12), Vector3(0.03, 0.06, 0.04))
			for p in [Vector3(0, -0.07, 0.06), Vector3(0, -0.1, 0.12), Vector3(0, -0.15, 0.2), Vector3(0, -0.22, 0.28), Vector3(0, -0.3, 0.36)]:
				b.box("dark", p, Vector3(0.022, 0.022, 0.09))                               # the power cord
			var bit := Node3D.new()
			bit.position = Vector3(0, 0.12, -0.25)
			n.add_child(bit)
			var bs := MeshKit.Soup.new()
			MeshKit.frustum_into(bs, Vector3.ZERO, 0.014, 0.004, 0.34, 5, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
			MeshKit.box_into(bs, Vector3(0, 0, -0.17), Vector3(0.03, 0.006, 0.3))            # flute (shows the rotation)
			MeshKit.inst(bit, bs.mesh(), MeshKit.mat("SteelPlate"))
			n.set_meta("spinner", bit)
	b.finish(n)
	return n

# ------------------------------------------------------------------ hauling aids and the compressor (world props)

## A small rock pile that shows what the cart carries; its scale follows how full the bag is.
static func _load_pile(parent: Node3D, pos: Vector3, size: Vector3) -> Node3D:
	var load := Node3D.new()
	load.name = "Load"
	load.position = pos
	parent.add_child(load)
	var s := MeshKit.Soup.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in range(7):
		MeshKit.rock_into(s, Vector3((rng.randf() - 0.5) * size.x * 0.6, rng.randf() * size.y * 0.5, (rng.randf() - 0.5) * size.z * 0.6), Vector3(size.x * 0.34, size.y * 0.5, size.z * 0.3), 700 + i, 3, 6)
	var mi := MeshKit.inst(load, s.mesh(), MeshKit.mat("RockLimestone"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	load.set_meta("pile", mi)
	return load

static func build_prop(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Gear_" + id
	var b := Builder.new()
	match id:
		"hand_cart":   # two big wheels, plank bed with side boards, long pull handle, prop leg
			b.box("wood", Vector3(0, 0.42, 0), Vector3(0.78, 0.07, 1.1))
			for x in [-0.37, 0.37]:
				b.box("wood", Vector3(x, 0.55, 0), Vector3(0.05, 0.22, 1.1))
			for z in [-0.53, 0.53]:
				b.box("wood", Vector3(0, 0.55, z), Vector3(0.78, 0.22, 0.05))
			for x in [-0.28, 0.28]:
				b.box("steel", Vector3(x, 0.36, 0), Vector3(0.05, 0.05, 1.12))
			b.box("steel", Vector3(0, 0.3, 0.1), Vector3(0.9, 0.04, 0.04))              # axle
			for x in [-0.46, 0.46]:
				b.along_x("dark", Vector3(x, 0.28, 0.1), 0.28, 0.07, 12)
				b.along_x("bright", Vector3(x, 0.28, 0.1), 0.07, 0.1, 8)
			for x in [-0.28, 0.28]:
				b.box("wood", Vector3(x, 0.52, -1.0), Vector3(0.04, 0.04, 0.95), Vector2(1, 1), Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3.ZERO))
			b.box("wood", Vector3(0, 0.55, -1.45), Vector3(0.64, 0.045, 0.045))          # pull bar
			b.box("steel", Vector3(0.0, 0.18, 0.55), Vector3(0.05, 0.36, 0.05))          # prop leg
			b.finish(n)
			_load_pile(n, Vector3(0, 0.46, 0), Vector3(0.66, 0.4, 0.96))
		"wheelbarrow": # single wheel, tapered tray, two handles, two legs
			b.box("steel", Vector3(0, 0.5, 0.0), Vector3(0.52, 0.3, 0.66), Vector2(1.3, 1.25))
			b.box("dark", Vector3(0, 0.36, 0.0), Vector3(0.4, 0.02, 0.56))
			b.along_x("dark", Vector3(0, 0.24, -0.62), 0.24, 0.09, 12)
			b.along_x("bright", Vector3(0, 0.24, -0.62), 0.07, 0.12, 8)
			for x in [-0.18, 0.18]:
				b.box("wood", Vector3(x, 0.42, 0.62), Vector3(0.04, 0.04, 0.95))           # handles
				b.box("dark", Vector3(x, 0.42, 1.05), Vector3(0.05, 0.05, 0.16))           # grips
				b.box("steel", Vector3(x * 0.6, 0.32, -0.45), Vector3(0.03, 0.04, 0.5))     # fork
				b.box("wood", Vector3(x * 1.2, 0.18, 0.5), Vector3(0.04, 0.4, 0.04))        # legs
			b.finish(n)
			_load_pile(n, Vector3(0, 0.62, 0), Vector3(0.6, 0.34, 0.7))
		"reinforced_wheelbarrow":   # steel tub with a rim and ribs, fat tyre, braced frame
			b.box("orange", Vector3(0, 0.52, 0.0), Vector3(0.62, 0.34, 0.78), Vector2(1.28, 1.22))
			b.box("steel", Vector3(0, 0.7, 0.0), Vector3(0.8, 0.04, 0.96))               # rolled rim
			for z in [-0.2, 0.2]:
				b.box("steel", Vector3(0, 0.5, z), Vector3(0.7, 0.04, 0.04))              # ribs
			b.box("dark", Vector3(0, 0.36, 0.0), Vector3(0.5, 0.03, 0.66))
			b.along_x("dark", Vector3(0, 0.26, -0.72), 0.27, 0.14, 12)
			b.along_x("bright", Vector3(0, 0.26, -0.72), 0.09, 0.2, 8)
			for x in [-0.2, 0.2]:
				b.box("steel", Vector3(x, 0.44, 0.65), Vector3(0.04, 0.04, 1.05))
				b.box("dark", Vector3(x, 0.44, 1.12), Vector3(0.055, 0.055, 0.2))
				b.box("steel", Vector3(x * 0.55, 0.36, -0.5), Vector3(0.035, 0.05, 0.58))
				b.box("steel", Vector3(x * 1.25, 0.18, 0.52), Vector3(0.04, 0.4, 0.04))
				b.box("steel", Vector3(x * 1.25, 0.0, 0.52), Vector3(0.1, 0.03, 0.12))    # feet plates
			b.box("steel", Vector3(0, 0.36, 0.3), Vector3(0.7, 0.03, 0.03))              # cross brace
			b.finish(n)
			_load_pile(n, Vector3(0, 0.66, 0), Vector3(0.68, 0.38, 0.8))
		"air_compressor":   # tank, motor and pump on top, gauge, hose, two wheels and a handle
			b.along_z("red", Vector3(0, 0.46, 0.45), 0.22, 0.22, 0.9, 10)
			b.box("dark", Vector3(0, 0.74, 0.0), Vector3(0.34, 0.2, 0.34))               # motor
			b.box("steel", Vector3(0, 0.74, -0.24), Vector3(0.26, 0.16, 0.14))           # pump head
			for x in [-0.07, 0.07]:
				b.box("bright", Vector3(x, 0.88, -0.24), Vector3(0.04, 0.1, 0.04))
			b.along_x("bright", Vector3(0.12, 0.6, -0.46), 0.06, 0.03, 10)                # pressure gauge
			for x in [-0.22, 0.22]:
				b.along_x("dark", Vector3(x, 0.14, 0.42), 0.14, 0.07, 10)
				b.box("steel", Vector3(x * 0.8, 0.2, -0.3), Vector3(0.04, 0.34, 0.04))   # front legs
			b.box("steel", Vector3(0, 0.86, 0.38), Vector3(0.31, 0.03, 0.03))           # carry handle, standing on the tank
			b.box("steel", Vector3(-0.14, 0.76, 0.38), Vector3(0.03, 0.2, 0.03))
			b.box("steel", Vector3(0.14, 0.76, 0.38), Vector3(0.03, 0.2, 0.03))
			MeshKit.tube_into(b.s("dark"), [Vector3(0.12, 0.62, -0.46), Vector3(0.2, 0.5, -0.52), Vector3(0.3, 0.42, -0.6), Vector3(0.38, 0.3, -0.62), Vector3(0.4, 0.2, -0.56), Vector3(0.38, 0.14, -0.46)], 0.022, 6)   # hose from the gauge port, coiled round the tank end
			b.finish(n)
	return n
