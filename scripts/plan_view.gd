extends Control
class_name QuarryPlanView
## The handheld quarry plan (Q): a top-down drawing of the whole quarry that updates from the real game state. Each "ring" is one of the quarry's excavation
## contracts (the six areas): done rings are green, the ring being cut is amber, the one that opens next has a dashed edge, later rings are faint. Beside it the
## list says how far each contract is (only digging inside a ring counts toward its contract) and, separately, how much rock and soil the quarry has given overall,
## wherever it was dug. The player, the access roads and any temporary haul ramps are drawn on it. A switch turns the outlines in the 3D world on or off.

var game
var map: Control
var list_box: VBoxContainer
var detail_label: Label
var overall_label: Label
var outline_btn: Button
var _t := 0.0
const MAP_SIZE := Vector2(470, 300)

func setup(main_node) -> void:
	game = main_node
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var paper := PanelContainer.new()
	paper.name = "Paper"
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.offset_left = -430
	paper.offset_right = 430
	paper.offset_top = -250
	paper.offset_bottom = 250
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.9, 0.84, 0.66)
	st.border_color = Color(0.45, 0.32, 0.18)
	st.set_border_width_all(3)
	st.set_corner_radius_all(2)
	st.set_content_margin_all(12)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 6
	st.anti_aliasing = false
	paper.add_theme_stylebox_override("panel", st)
	add_child(paper)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	paper.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := QuarryTheme.label("QUARRY PLAN", QuarryTheme.TITLE, Color(0.32, 0.2, 0.1), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	outline_btn = Button.new()
	outline_btn.custom_minimum_size = Vector2(190, 26)
	outline_btn.focus_mode = Control.FOCUS_NONE
	outline_btn.pressed.connect(func():
		game.set_plan_outlines(not game.state.plan_outlines)
		refresh())
	head.add_child(outline_btn)
	var close := Button.new()
	close.text = "CLOSE  [Q]"
	close.custom_minimum_size = Vector2(100, 26)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): game._close_menu())
	head.add_child(close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	map = Control.new()
	map.custom_minimum_size = MAP_SIZE
	map.clip_contents = true
	map.draw.connect(_draw_map)
	body.add_child(map)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 3)
	right.add_child(list_box)
	detail_label = QuarryTheme.label("", QuarryTheme.BODY, Color(0.25, 0.16, 0.08))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_label)
	overall_label = QuarryTheme.label("", QuarryTheme.BODY, Color(0.32, 0.2, 0.1))
	overall_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(overall_label)

func open() -> void:
	visible = true
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		refresh()

# ------------------------------------------------------------------ data

## Ring state: "done", "active" (available and not finished), "next" (its requirements are being worked on) or "later".
func ring_state(id: String) -> String:
	var prog: QuarryProgression = game.prog
	if prog.area_complete(id):
		return "done"
	if prog.area_available(id):
		return "active"
	var def := prog.area_def(id)
	var req_ok := true
	for r in def.get("requires", []):
		if not (prog.area_complete(str(r)) or prog.area_available(str(r))):
			req_ok = false
	return "next" if req_ok else "later"

## The ring's footprint on the ground (world x, z): its own rectangle, or the pit of its level.
func ring_rect(def: Dictionary) -> Rect2:
	if def.has("rect"):
		var r: Array = def["rect"]
		return Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
	if game.pit_zone != null and def.has("level"):
		for lp in game.pit_zone.level_pits:
			if int(lp["n"]) == int(def["level"]):
				var rr: Rect2 = lp["rect"]
				var a: Vector3 = game.pit_zone.to_global(Vector3(rr.position.x, 0, rr.position.y))
				var b: Vector3 = game.pit_zone.to_global(Vector3(rr.end.x, 0, rr.end.y))
				return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z)))
	return Rect2()

func bounds() -> Rect2:
	var out := Rect2()
	var first := true
	for def in game.prog.area_defs():
		var r := ring_rect(def)
		if r.size == Vector2.ZERO:
			continue
		out = r if first else out.merge(r)
		first = false
	var hub: Rect2 = game.hub_rect()
	out = out.merge(hub) if not first else hub
	return out.grow(10.0)

func _to_map(p: Vector2, b: Rect2) -> Vector2:
	var s := minf(MAP_SIZE.x / b.size.x, MAP_SIZE.y / b.size.y)
	var off := (MAP_SIZE - b.size * s) * 0.5
	return off + (p - b.position) * s

func refresh() -> void:
	if game == null or game.prog == null:
		return
	var prog: QuarryProgression = game.prog
	outline_btn.text = "WORLD OUTLINES: %s" % ("ON" if game.state.plan_outlines else "OFF")
	for ch in list_box.get_children():
		list_box.remove_child(ch)
		ch.queue_free()
	var active_id := ""
	var n := 0
	for def in prog.area_defs():
		n += 1
		var id := str(def["id"])
		var stt := ring_state(id)
		var pr := prog.area_progress(id)
		var tag := {"done": "DONE", "active": "ACTIVE", "next": "NEXT", "later": "LATER"}[stt]
		var col := {"done": Color(0.2, 0.5, 0.2), "active": Color(0.62, 0.36, 0.05), "next": Color(0.35, 0.3, 0.2), "later": Color(0.5, 0.45, 0.38)}[stt]
		var line := "RING %d  %s  %s" % [n, tag, ("%d%%" % int(pr.get("pct", 0))) if stt in ["done", "active"] and not pr.is_empty() else ""]
		var l := QuarryTheme.label(line, QuarryTheme.BODY, col, stt == "active")
		list_box.add_child(l)
		if stt == "active" and active_id == "":
			active_id = id
	var lines := []
	if active_id != "":
		var def := prog.area_def(active_id)
		lines.append(str(def.get("title", active_id)))
		var pr2 := prog.area_progress(active_id)
		for pt in pr2.get("parts", []):
			lines.append("%s %s: %d / %d" % ["[x]" if int(pt["have"]) >= int(pt["need"]) else "[ ]", str(pt["label"]), int(pt["have"]), int(pt["need"])])
		lines.append("Reward on completion: %s" % QuarryTheme.money_text(int(def.get("reward", 0))))
		lines.append("Only work inside this ring counts toward it. Digging elsewhere still gives you the material.")
	else:
		lines.append("Every open ring is finished. The next one opens as the quarry grows.")
	detail_label.text = "\n".join(lines)
	var soil: int = int(game.state.soil_dumped)
	var cut := int(prog.stats.get("hand", 0)) + int(prog.stats.get("crew", 0)) + int(prog.stats.get("rigs", 0))
	overall_label.text = "Overall excavation (all rings and anywhere else): rock cut %d units, soil dumped on the spoil heap %d units.  Contract progress above counts only work inside the ring." % [cut, soil]
	map.queue_redraw()

# ------------------------------------------------------------------ drawing

func _draw_map() -> void:
	if game == null or game.prog == null:
		return
	var prog: QuarryProgression = game.prog
	map.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.82, 0.75, 0.56))
	var b := bounds()
	# faint survey grid every 20 m
	var gx := floorf(b.position.x / 20.0) * 20.0
	while gx < b.end.x:
		var a := _to_map(Vector2(gx, b.position.y), b)
		var z := _to_map(Vector2(gx, b.end.y), b)
		map.draw_line(a, z, Color(0.6, 0.5, 0.34, 0.25), 1.0)
		gx += 20.0
	var gz := floorf(b.position.y / 20.0) * 20.0
	while gz < b.end.y:
		map.draw_line(_to_map(Vector2(b.position.x, gz), b), _to_map(Vector2(b.end.x, gz), b), Color(0.6, 0.5, 0.34, 0.25), 1.0)
		gz += 20.0
	var hub: Rect2 = game.hub_rect()
	var hp := _to_map(hub.position, b)
	map.draw_rect(Rect2(hp, hub.size * minf(MAP_SIZE.x / b.size.x, MAP_SIZE.y / b.size.y)), Color(0.55, 0.5, 0.42, 0.6))
	var n := 0
	for def in prog.area_defs():
		n += 1
		var r := ring_rect(def)
		if r.size == Vector2.ZERO:
			continue
		var id := str(def["id"])
		var stt := ring_state(id)
		var p0 := _to_map(r.position, b)
		var p1 := _to_map(r.end, b)
		var rect := Rect2(p0, p1 - p0).abs()
		var fill := {"done": Color(0.35, 0.65, 0.35, 0.4), "active": Color(0.98, 0.7, 0.2, 0.5), "next": Color(0.8, 0.75, 0.6, 0.15), "later": Color(0.6, 0.55, 0.45, 0.12)}[stt]
		map.draw_rect(rect, fill)
		var edge := {"done": Color(0.2, 0.5, 0.2), "active": Color(0.75, 0.42, 0.05), "next": Color(0.4, 0.35, 0.25), "later": Color(0.55, 0.5, 0.42)}[stt]
		if stt in ["done", "active"]:
			map.draw_rect(rect, edge, false, 2.0 if stt == "active" else 1.0)
		else:
			_dashed(rect, edge)
		map.draw_string(QuarryTheme.hud(), rect.position + Vector2(4, 12), "%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, QuarryTheme.pixel_font_size(QuarryTheme.SMALL), edge.darkened(0.2))
		# the access road of a pit level: a small marker where its ramp meets the rim
		if def.has("level") and prog.road_built(int(def["level"])):
			map.draw_circle(Vector2(rect.get_center().x, rect.end.y), 3.0, Color(0.3, 0.3, 0.3))
	# temporary haul ramps: a bar with a dot at each end (the connection points)
	for rp in game.ramps_for_plan():
		var a2 := _to_map(rp["from"], b)
		var b2 := _to_map(rp["to"], b)
		map.draw_line(a2, b2, Color(0.25, 0.25, 0.28), 3.0)
		map.draw_circle(a2, 3.0, Color(0.2, 0.6, 0.3))
		map.draw_circle(b2, 3.0, Color(0.6, 0.35, 0.15))
	# the player
	var pp := _to_map(Vector2(game.player.global_position.x, game.player.global_position.z), b)
	var yaw: float = game.player.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	map.draw_colored_polygon(PackedVector2Array([pp + fwd * 7.0, pp + fwd.rotated(2.5) * 5.0, pp + fwd.rotated(-2.5) * 5.0]), Color(0.15, 0.3, 0.6))
	map.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.45, 0.32, 0.18), false, 2.0)

func _dashed(rect: Rect2, color: Color) -> void:
	var pts := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i in range(4):
		var a: Vector2 = pts[i]
		var d: Vector2 = (pts[i + 1] as Vector2) - a
		var len := d.length()
		var t := 0.0
		while t < len:
			map.draw_line(a + d.normalized() * t, a + d.normalized() * minf(len, t + 5.0), color, 1.0)
			t += 9.0
