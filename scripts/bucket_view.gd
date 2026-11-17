extends Node3D
class_name BucketView
## The player's buckets, in view at the lower left of the screen. The Blender pail you start with is held in the left hand and shows how full it is (a heap of what you dug rising
## out of it); every other FULL bucket you carry stands behind it, up to four drawn (any number can be carried). No numbers: the heap is the gauge.
##   update_view(total_units, bucket_capacity, resource_colour, visible_now)

const SPARE_SPOTS := [Vector3(-0.2, -0.04, -0.07), Vector3(0.18, -0.03, -0.1), Vector3(-0.38, -0.02, -0.12), Vector3(0.34, -0.01, -0.13)]

var held: Dictionary = {}                 ## {"root", "fill"}
var spares: Array = []                    ## [{"root", "fill"}]
var _tint := Color(0.4, 0.28, 0.18)
var _tint_mat: StandardMaterial3D

func _ready() -> void:
	name = "BucketView"
	position = Vector3(-0.36, -0.40, -0.62)
	rotation_degrees = Vector3(4.0, 14.0, 0.0)
	held = _make(1.0)
	for k in range(SPARE_SPOTS.size()):
		var sp := _make(0.9)
		(sp["root"] as Node3D).position = SPARE_SPOTS[k]
		(sp["root"] as Node3D).visible = false
		spares.append(sp)
		_set_fill(sp, 1.0)
	_tint_mat = StandardMaterial3D.new()
	_tint_mat.roughness = 1.0
	_tint_mat.albedo_color = _tint
	_set_fill(held, 0.0)

func _make(scale_f: float) -> Dictionary:
	var a: Dictionary = WorldModels.animal("bucket")
	if a.is_empty():
		var box := MeshInstance3D.new()                     # (the model is missing: a plain pail so the game still works)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.17
		cm.height = 0.34
		box.mesh = cm
		box.position.y = 0.17
		var holder := Node3D.new()
		holder.add_child(box)
		add_child(holder)
		return {"root": holder, "fill": null}
	var root: Node3D = a["root"]
	root.scale = Vector3.ONE * scale_f
	add_child(root)
	var fill: Node3D = (a["parts"] as Dictionary).get("Fill")
	return {"root": root, "fill": fill}

func _set_fill(b: Dictionary, frac: float) -> void:
	var f: Node3D = b.get("fill")
	if f == null:
		return
	f.visible = frac > 0.02
	f.scale = Vector3(1.0, lerpf(0.12, 1.0, clampf(frac, 0.0, 1.0)), 1.0)
	f.position.y = 0.3 - (1.0 - clampf(frac, 0.0, 1.0)) * 0.05
	var mi := f.get_node_or_null("Mesh") as MeshInstance3D
	if mi != null and _tint_mat != null:
		mi.material_override = _tint_mat

## Drives the picture from the carried amount.
func update_view(total: int, cap: int, tint: Color, show_it: bool) -> void:
	visible = show_it
	if not show_it or cap <= 0:
		return
	if _tint_mat != null and _tint != tint:
		_tint = tint
		_tint_mat.albedo_color = tint
	var full := total / cap
	var rem := total % cap
	var frac := 0.0
	var spare_n := 0
	if total > 0:
		if rem > 0:
			frac = float(rem) / float(cap)
			spare_n = full
		else:
			frac = 1.0
			spare_n = full - 1
	_set_fill(held, frac)
	for k in range(spares.size()):
		(spares[k]["root"] as Node3D).visible = k < spare_n
	for k in range(spares.size()):
		if k < spare_n:
			_set_fill(spares[k], 1.0)

## How many buckets are carried (a part-full one counts).
static func count_of(total: int, cap: int) -> int:
	return 0 if total <= 0 or cap <= 0 else (total + cap - 1) / cap
