extends RefCounted
class_name BucketView
## Helpers for the bucket item: dresses the pail in the player's hand (the tool model's "Fill" holder) so the heap shows how full the current bucket is. No numbers: the heap is the gauge.

static var _tint_mat: StandardMaterial3D

## fill: the model's Fill holder; frac 0..1 of the bucket in hand; tint the colour of what is in it.
static func dress(fill: Node3D, frac: float, tint: Color) -> void:
	if fill == null:
		return
	fill.visible = frac > 0.02
	fill.scale = Vector3(1.0, lerpf(0.12, 1.0, clampf(frac, 0.0, 1.0)), 1.0)
	fill.position.y = 0.3 - (1.0 - clampf(frac, 0.0, 1.0)) * 0.05
	var mi := fill.get_node_or_null("Mesh") as MeshInstance3D
	if mi == null:
		return
	if _tint_mat == null:
		_tint_mat = StandardMaterial3D.new()
		_tint_mat.roughness = 1.0
	_tint_mat.albedo_color = tint
	mi.material_override = _tint_mat

## The fill of the bucket in hand from the carried total: a part-full bucket, or a full one when the total is an exact multiple.
static func fraction_of(total: int, cap: int) -> float:
	if total <= 0 or cap <= 0:
		return 0.0
	var rem := total % cap
	return float(rem) / float(cap) if rem > 0 else 1.0

## How many buckets are carried (a part-full one counts).
static func count_of(total: int, cap: int) -> int:
	return 0 if total <= 0 or cap <= 0 else (total + cap - 1) / cap
