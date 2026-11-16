extends Node
class_name QuarryOpening
## The new game's opening: the drive to the quarry in Grandpa Walt's pickup (a winding forest road, the mountain tunnel, the yard), the deed handoff, and the walk to the old
## excavator. This file holds the route geometry (also used to build the forest road and keep the forest off it) and the cinematic itself.

## The winding forest road, from the edge of the map to the tunnel's far (west) exit. y = 0 (the ground); x, z in world metres.
const ROAD := [Vector2(-197.0, 72.0), Vector2(-184.0, 66.0), Vector2(-172.0, 69.0), Vector2(-160.0, 59.0), Vector2(-152.0, 47.0), Vector2(-141.0, 42.0),
	Vector2(-132.0, 34.0), Vector2(-124.0, 27.5), Vector2(-116.5, 25.4)]

static func road_points() -> Array:
	var out := []
	for p in ROAD:
		out.append(Vector3(p.x, 0.0, p.y))
	return out

static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## The road as a smooth curve sampled about every `step` metres.
static func road_curve(step := 3.0) -> Array:
	var pts := road_points()
	var out := []
	for i in range(pts.size() - 1):
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(2, int(ceil(p1.distance_to(p2) / step)))
		for k in range(n):
			out.append(_cr(p0, p1, p2, p3, float(k) / float(n)))
	out.append(pts[pts.size() - 1])
	return out

static var _curve_cache: Array = []

## True when the point (x, z) is within `r` metres of the forest road.
static func near_road(p: Vector2, r: float) -> bool:
	if _curve_cache.is_empty():
		_curve_cache = road_curve(3.0)
	for q in _curve_cache:
		if Vector2(q.x, q.z).distance_to(p) < r:
			return true
	return false
