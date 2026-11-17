extends RefCounted
class_name FPTools
## Per-tool hand configuration for the shared first-person rig (FPHands): where on the tool each hand closes (model space: the handle runs along +Y from the grip point),
## the axis and radius of what it grips, and which grip preset it uses. The tool decides where the hands go; the rig wraps the fingers round it.
## Keys are the tool model keys (ToolModels.key_of): the five ladder tools and every Phase 9 tool id.
##   grip fields: hand "R"/"L", at, axis (toward the working end), r (radius of the shaft), preset (see FPHands.PRESETS), node (a moving child, e.g. "Lever"), slide (travel along the shaft)

const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)

## Where the forearms come from, in camera space (below the screen edges, never through the camera).
const ANCHOR_R := Vector3(0.28, -0.62, -0.32)
const ANCHOR_L := Vector3(-0.28, -0.62, -0.32)

const GRIPS := {
	"rock_hammer": [{"hand": "R", "at": Vector3(0, 0.07, 0), "axis": Y, "r": 0.024, "preset": "one_hand_hammer"}],
	"pickaxe_worn": [{"hand": "L", "at": Vector3(0, 0.16, 0), "axis": Y, "r": 0.019, "preset": "striking", "slide": 1.0}, {"hand": "R", "at": Vector3(0, 0.37, 0), "axis": Y, "r": 0.019, "preset": "striking"}],
	"pickaxe_reinforced": [{"hand": "L", "at": Vector3(0, 0.19, 0), "axis": Y, "r": 0.02, "preset": "striking", "slide": 1.0}, {"hand": "R", "at": Vector3(0, 0.4, 0), "axis": Y, "r": 0.02, "preset": "striking"}],
	"drill": [{"hand": "R", "at": Vector3(0, 0.0, 0.05), "axis": Y, "r": 0.034, "preset": "powered"}, {"hand": "L", "at": Vector3(-0.12, 0.07, -0.12), "axis": X, "r": 0.02, "preset": "powered", "side": Vector3(0, -1, 0)}],
	"jackhammer": [{"hand": "R", "at": Vector3(0.15, 0.0, 0), "axis": X, "r": 0.03, "preset": "powered", "side": Vector3(0, -1, 0)}, {"hand": "L", "at": Vector3(-0.15, 0.0, 0), "axis": X, "r": 0.03, "preset": "powered", "side": Vector3(0, -1, 0)}],
	"pointed_chisel": [{"hand": "L", "at": Vector3(0, 0.12, 0), "axis": Y, "r": 0.013, "preset": "precision"}],
	"flat_chisel": [{"hand": "L", "at": Vector3(0, 0.12, 0), "axis": Y, "r": 0.013, "preset": "precision"}],
	"repaired_pickaxe": [{"hand": "L", "at": Vector3(0, 0.12, 0), "axis": Y, "r": 0.027, "preset": "striking", "slide": 1.0}, {"hand": "R", "at": Vector3(0, 0.36, 0), "axis": Y, "r": 0.019, "preset": "striking"}],
	"sledgehammer": [{"hand": "L", "at": Vector3(0, 0.08, 0), "axis": Y, "r": 0.031, "preset": "striking", "slide": 1.0}, {"hand": "R", "at": Vector3(0, 0.4, 0), "axis": Y, "r": 0.026, "preset": "striking"}],
	"steel_pickaxe": [{"hand": "L", "at": Vector3(0, 0.14, 0), "axis": Y, "r": 0.021, "preset": "striking", "slide": 1.0}, {"hand": "R", "at": Vector3(0, 0.4, 0), "axis": Y, "r": 0.02, "preset": "striking"}],
	"hardened_pickaxe": [{"hand": "L", "at": Vector3(0, 0.15, 0), "axis": Y, "r": 0.021, "preset": "striking", "slide": 1.0}, {"hand": "R", "at": Vector3(0, 0.42, 0), "axis": Y, "r": 0.02, "preset": "striking"}],
	"hand_splitter": [{"hand": "R", "at": Vector3(0, -0.05, 0), "axis": Y, "r": 0.031, "preset": "one_hand_hammer"}, {"hand": "L", "at": Vector3(0, 0, 0.39), "axis": Z, "r": 0.028, "preset": "striking", "node": "Lever", "side": Vector3(-1, -0.3, 0)}],
	"powered_hammer": [{"hand": "R", "at": Vector3(0, 0.0, 0.08), "axis": Y, "r": 0.034, "preset": "powered"}, {"hand": "L", "at": Vector3(-0.12, 0.12, -0.17), "axis": X, "r": 0.02, "preset": "powered", "side": Vector3(0, -1, 0)}],
	"pneumatic_chisel": [{"hand": "R", "at": Vector3(0.15, 0.04, 0), "axis": X, "r": 0.028, "preset": "powered", "side": Vector3(0, -1, 0)}, {"hand": "L", "at": Vector3(-0.15, 0.04, 0), "axis": X, "r": 0.028, "preset": "powered", "side": Vector3(0, -1, 0)}],
	"shovel": [{"hand": "R", "at": Vector3(0, 0.016, 0), "axis": X, "r": 0.016, "preset": "two_hand_shaft", "side": Vector3(0, -1, 0.2)}, {"hand": "L", "at": Vector3(0, 0.36, 0), "axis": Y, "r": 0.0185, "preset": "two_hand_shaft", "slide": 1.0}],
	"bucket": [{"hand": "R", "at": Vector3(0.203, -0.095, 0), "axis": Vector3(-0.5, 0.87, 0), "r": 0.011, "preset": "bucket_handle", "side": Vector3(1, -0.2, 0)}],       # the bail, held at its right side so the forearm clears the pail
	"ramp_plan": [{"hand": "R", "at": Vector3(0, 0.1, 0), "axis": Y, "r": 0.016, "preset": "placement"}],
}

static func grips(key: String) -> Array:
	return GRIPS.get(key, [])
