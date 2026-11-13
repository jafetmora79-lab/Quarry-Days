extends Control
class_name QuarryMinimap
## The corner map: the yard, the fenced quarry with its levels (open ones filled, locked ones faint), the roads that have been built, the buildings,
## the tunnel, loose tutorial debris, machines, workers, the objective marker and the player's arrow. North is up. Redrawn a few times a second.

const BG := Color(0.07, 0.06, 0.05, 0.82)
const YARD := Color(0.42, 0.38, 0.28)
const QUARRY := Color(0.30, 0.26, 0.19)
const ROAD := Color(0.78, 0.66, 0.34)
const FENCE := Color(0.62, 0.56, 0.42)
const LEVEL_FILL := [Color(0.38, 0.33, 0.24), Color(0.34, 0.29, 0.22), Color(0.29, 0.25, 0.2), Color(0.24, 0.2, 0.17), Color(0.2, 0.17, 0.15)]
const OPEN_EDGE := Color(0.9, 0.8, 0.5)
const LOCKED_EDGE := Color(0.5, 0.45, 0.36, 0.55)

var game
var bounds := Rect2(-135.0, -112.0, 270.0, 146.0)       ## world rectangle shown (x, z), north up
var _t := 0.0
var _pulse := 0.0

func setup(main_node) -> void:
	game = main_node
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not game.blueprint:
		bounds = Rect2(-34.0, -34.0, 90.0, 70.0)          # the older layout: just the yard and its surroundings
	var w := 184.0
	custom_minimum_size = Vector2(w, roundf(w * bounds.size.y / bounds.size.x))
	size = custom_minimum_size

## World (x, z) to a point inside the control.
func to_map(x: float, z: float) -> Vector2:
	return Vector2((x - bounds.position.x) / bounds.size.x * size.x, (z - bounds.position.y) / bounds.size.y * size.y)

func rect_to_map(r: Rect2) -> Rect2:
	var a := to_map(r.position.x, r.position.y)
	var b := to_map(r.end.x, r.end.y)
	return Rect2(a, b - a)

## The pit frame (origin at the central gate, local -z north) to world.
func _local_rect(r: Array) -> Rect2:
	return Rect2(float(r[0]), float(r[1]) - 8.0, float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))

## What the map shows right now, as plain data (the drawing reads this; tests read it too).
func snapshot() -> Dictionary:
	var s := {"levels_open": 0, "levels_total": 0, "roads_built": 0, "debris": 0, "vehicles": 0, "workers": 0, "player": Vector2.ZERO, "waypoint": Vector2.INF}
	if game == null or game.prog == null:
		return s
	var prog: QuarryProgression = game.prog
	if game.blueprint:
		s["levels_total"] = maxi(0, prog.levels().size() - 1)
		for n in range(2, prog.levels().size() + 1):
			if n <= prog.quarry_level:
				s["levels_open"] += 1
			if prog.road_built(n):
				s["roads_built"] += 1
	if prog.cleanup_active():
		for id in prog.cleanup_ids():
			if not bool(prog.cleanup.get("cleared", {}).get(str(id), false)):
				s["debris"] += 1
	s["vehicles"] = game.vehicle_nodes.size()
	s["workers"] = game.worker_nodes.size()
	if game.player != null:
		var pp: Vector3 = game.driving.global_position if game.driving else game.player.global_position
		s["player"] = to_map(pp.x, pp.z)
	var wp: Dictionary = game.hud_waypoint()
	if not wp.is_empty():
		var wv: Vector3 = wp["pos"]
		s["waypoint"] = to_map(wv.x, wv.z)
	return s

func _process(delta: float) -> void:
	_t += delta
	_pulse = fposmod(_pulse + delta * 1.6, 1.0)
	if _t >= 0.12 and is_visible_in_tree():
		_t = 0.0
		queue_redraw()

func _draw() -> void:
	if game == null or game.prog == null:
		return
	var prog: QuarryProgression = game.prog
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var clip := Rect2(Vector2.ZERO, size)
	# the quarry and its levels
	if game.blueprint and game.pit_zone != null:
		var fence: Array = prog.pit_cfg().get("fence", [-126.0, -100.0, 126.0, 0.0])
		var qr := rect_to_map(_local_rect(fence))
		draw_rect(qr, QUARRY)
		for n in range(2, prog.levels().size() + 1):
			var pit: Dictionary = prog.level_def(n).get("pit", {})
			if pit.is_empty():
				continue
			var lr := rect_to_map(_local_rect(pit["rect"]))
			var open := n <= prog.quarry_level
			draw_rect(lr, LEVEL_FILL[clampi(n - 1, 0, LEVEL_FILL.size() - 1)] if open else Color(0.3, 0.26, 0.19, 0.35))
			draw_rect(lr, OPEN_EDGE if open else LOCKED_EDGE, false, 1.0)
		for n in range(2, prog.levels().size() + 1):
			if prog.road_built(n):
				for r in prog.level_def(n).get("roads", []):
					draw_rect(rect_to_map(_local_rect(r)), ROAD)
		draw_rect(qr, FENCE, false, 1.5)
	# the yard
	var hub: Rect2 = game.hub_rect()
	if hub.size != Vector2.ZERO:
		draw_rect(rect_to_map(hub), YARD)
		draw_rect(rect_to_map(hub), FENCE, false, 1.0)
	# buildings
	for bp in [game.OFFICE_POS, game.TOOLSHED_POS, game.SHED_POS, game.HOME_POS, Vector3(5.0 + game.GARAGE_DX, 0.0, 18.7)]:
		var bm := to_map(bp.x, bp.z)
		var wide := 3.4 if bp.z > 15.0 and abs(bp.x - (5.0 + game.GARAGE_DX)) < 0.1 else 2.2
		draw_rect(Rect2(bm - Vector2(wide, 1.6), Vector2(wide * 2.0, 3.2)), Color(0.7, 0.62, 0.48))
	# The workshop order terminal has a fixed amber marker; the objective marker is independent.
	var order_pos: Vector3 = game.machinery_station_position()
	var order_map := to_map(order_pos.x, order_pos.z)
	draw_rect(Rect2(order_map - Vector2(2, 2), Vector2(4, 4)), QuarryTheme.ACCENT, false, 1.0)
	# the tunnel and the way in
	if game.delivery != null:
		var gp: Vector3 = game.delivery.gate_point()
		draw_rect(Rect2(to_map(gp.x, gp.z) - Vector2(2.5, 2.0), Vector2(4.0, 4.0)), Color(0.55, 0.55, 0.6))
	# loose tutorial debris
	if prog.cleanup_active():
		for id in prog.cleanup_ids():
			if not bool(prog.cleanup.get("cleared", {}).get(str(id), false)):
				var dp := prog.cleanup_pos(str(id))
				draw_circle(to_map(dp.x, dp.y), 1.3, Color(0.45, 0.78, 0.4))
	# machines and workers
	for v in game.vehicle_nodes.values():
		if is_instance_valid(v):
			var vp := to_map(v.global_position.x, v.global_position.z)
			var mine: bool = v == game.driving
			draw_rect(Rect2(vp - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.62, 0.15) if not mine else Color(1.0, 0.95, 0.5))
	for wk in game.worker_nodes.values():
		if is_instance_valid(wk):
			draw_circle(to_map(wk.global_position.x, wk.global_position.z), 1.4, Color(0.4, 0.85, 0.95))
	# the objective marker
	var wp: Dictionary = game.hud_waypoint()
	if not wp.is_empty():
		var wv: Vector3 = wp["pos"]
		var wm := to_map(wv.x, wv.z)
		var rr := 3.0 + 6.0 * _pulse
		draw_arc(wm, rr, 0.0, TAU, 20, Color(1.0, 0.86, 0.3, 1.0 - _pulse), 1.5)
		draw_circle(wm, 2.2, Color(1.0, 0.86, 0.3))
	# the player's arrow
	if game.player != null:
		var src: Node3D = game.driving if game.driving else game.player
		var pm := to_map(src.global_position.x, src.global_position.z)
		var yaw := src.global_rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([pm + fwd * 5.0, pm - fwd * 3.0 + side * 3.0, pm - fwd * 1.5, pm - fwd * 3.0 - side * 3.0]), Color(1, 1, 1))
	draw_rect(clip, Color(0.62, 0.5, 0.3), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 12.0, 11.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.9, 0.75))

## Draws once into nothing (tests call this to be sure the drawing code runs without errors on the current state).
func _draw_test_safe() -> void:
	queue_redraw()
