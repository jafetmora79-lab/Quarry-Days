extends Control
class_name QuarryLetter
## Grandpa Walt's letter: a compact sheet of aged paper in the middle of the screen, not a screen-sized popup. It unfolds (a short 0.55 s open), is read in
## dark brown ink at a normal reading size, runs over several pages instead of shrinking when it is long, and ends in Walt's hand-drawn signature.
## Display only: the game's input handler turns clicks and E into advance() and Esc into close(), so nothing behind it ever reacts to those clicks.

signal closed

const W := 500.0                                   ## the sheet's width in base (960 wide) canvas pixels
const MARGIN_X := 46.0
const FONT := 10                                   ## body size in base pixels: 13 px at 1280x720, 20 px at 1920x1080
const LINES_PER_PAGE := 10
const INK := Color(0.20, 0.12, 0.07)
const PAPER := Color(0.93, 0.86, 0.69)
const PAPER_EDGE := Color(0.80, 0.68, 0.47)

var pages: Array = []
var page := 0
var signed := true
var header_text := ""
var paper: Control
var title_l: Label
var body_l: Label
var hint_l: Label
var count_l: Label
var sig: Control
var _tween: Tween
var _edge := PackedVector2Array()
var _opening := false
var _seed := 7

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.01, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	paper = Control.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.draw.connect(_draw_paper)
	add_child(paper)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = MARGIN_X
	box.offset_right = -MARGIN_X
	box.offset_top = 38.0
	box.offset_bottom = -28.0
	box.add_theme_constant_override("separation", 10)
	paper.add_child(box)
	title_l = QuarryTheme.label("", QuarryTheme.HEAD, Color(0.4, 0.26, 0.13), true)
	title_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_l)
	body_l = QuarryTheme.label("", FONT, INK)         # (fitted: never under 15 px on screen; the page layout uses the same size)
	body_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	body_l.add_theme_constant_override("line_spacing", 6)
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body_l)
	sig = Control.new()
	sig.custom_minimum_size = Vector2(160, 50)
	sig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sig.draw.connect(_draw_signature)
	box.add_child(sig)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(foot)
	count_l = QuarryTheme.hud_label("", QuarryTheme.SMALL, Color(0.5, 0.34, 0.18))
	count_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	foot.add_child(count_l)
	hint_l = QuarryTheme.hud_label("", QuarryTheme.SMALL, Color(0.5, 0.34, 0.18))
	hint_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	hint_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(hint_l)

## Splits the text into pages that fit the sheet (about LINES_PER_PAGE lines each) at paragraph boundaries; the closing "- Grandpa Walt" line becomes the drawn signature.
static func paginate(text: String, allow_signature := true) -> Dictionary:
	var paras: Array = []
	for p in text.split("\n\n"):
		var t := String(p).strip_edges()
		if t != "":
			paras.append(t)
	var signed_by := false
	if allow_signature and not paras.is_empty() and String(paras[paras.size() - 1]).begins_with("-") and String(paras[paras.size() - 1]).to_lower().contains("walt"):
		paras.pop_back()
		signed_by = true
	var chars_per_line := int((W - MARGIN_X * 2.0) / (float(QuarryTheme.fit_size(FONT)) * 0.55))
	var out: Array = []
	var cur: Array = []
	var used := 0
	for p in paras:
		var lines := 0
		for part in String(p).split("\n"):
			lines += maxi(1, int(ceil(float(String(part).length()) / float(chars_per_line))))
		lines += 1                                      # the gap after the paragraph
		var room := LINES_PER_PAGE - (2 if signed_by else 0)
		if used + lines > room and not cur.is_empty():
			out.append("\n\n".join(cur))
			cur = []
			used = 0
		cur.append(p)
		used += lines
	if not cur.is_empty():
		out.append("\n\n".join(cur))
	if out.is_empty():
		out.append("")
	return {"pages": out, "signed": signed_by}

func open_letter(title: String, text: String, allow_signature := true) -> void:
	var r := paginate(text, allow_signature)
	pages = r["pages"]
	signed = bool(r["signed"])
	header_text = title
	page = 0
	_seed = absi(hash(text)) % 997
	_show_page(false)
	visible = true
	_layout()
	if _tween and _tween.is_valid():
		_tween.kill()
	_opening = true
	# the sheet unfolds: it opens from a thin strip, easing out a little past full height and settling, while the room dims
	paper.pivot_offset = paper.size * 0.5
	paper.scale = Vector2(0.96, 0.06)
	paper.rotation = deg_to_rad(-2.5)
	paper.modulate.a = 0.0
	(get_node("Dim") as ColorRect).modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(get_node("Dim"), "modulate:a", 1.0, 0.35)
	_tween.tween_property(paper, "modulate:a", 1.0, 0.2)
	_tween.tween_property(paper, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(paper, "rotation", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func(): _opening = false)

func _show_page(animate := true) -> void:
	title_l.text = header_text.to_upper()
	body_l.text = String(pages[page])
	var last := page >= pages.size() - 1
	sig.visible = last and signed
	count_l.text = "%d / %d" % [page + 1, pages.size()] if pages.size() > 1 else ""
	hint_l.text = "E / CLICK  CLOSE" if last else "E / CLICK  TURN THE PAGE"
	sig.queue_redraw()
	paper.queue_redraw()
	if animate:
		body_l.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(body_l, "modulate:a", 1.0, 0.18)
	else:
		body_l.modulate.a = 1.0

## Sheet size: fixed width, a height that fits the longest page (so turning the page never makes the sheet jump).
func _layout() -> void:
	var chars_per_line := int((W - MARGIN_X * 2.0) / (float(QuarryTheme.fit_size(FONT)) * 0.55))
	var most := 6
	for p in pages:
		var lines := 0
		for part in String(p).split("\n"):
			lines += maxi(1, int(ceil(float(String(part).length()) / float(chars_per_line))))
		most = maxi(most, lines)
	var line_h := float(QuarryTheme.fit_size(FONT)) * 1.45 + 6.0
	var h := 36.0 + 22.0 + 10.0 + float(most) * line_h + 8.0 + (54.0 if signed else 4.0) + 34.0
	h = clampf(h, 260.0, 500.0)
	paper.custom_minimum_size = Vector2(W, h)
	paper.size = Vector2(W, h)
	paper.offset_left = -W * 0.5
	paper.offset_right = W * 0.5
	paper.offset_top = -h * 0.5
	paper.offset_bottom = h * 0.5
	paper.pivot_offset = paper.size * 0.5
	_build_edge()
	paper.queue_redraw()

func _noise(i: int, salt: int) -> float:
	return float(absi(hash(Vector3i(i, salt, _seed))) % 1000) / 1000.0

## The sheet's outline: a rectangle whose edge wanders a few pixels, and with two softly rounded-off corners.
func _build_edge() -> void:
	_edge = PackedVector2Array()
	var w := paper.size.x
	var h := paper.size.y
	var step := 26.0
	var i := 0
	var x := 0.0
	while x < w:
		_edge.append(Vector2(x, (_noise(i, 1) - 0.5) * 4.0 + 2.0)); x += step; i += 1
	var y := 0.0
	while y < h:
		_edge.append(Vector2(w - 2.0 + (_noise(i, 2) - 0.5) * 4.0, y)); y += step; i += 1
	x = w
	while x > 0.0:
		_edge.append(Vector2(x, h - 2.0 + (_noise(i, 3) - 0.5) * 4.0)); x -= step; i += 1
	y = h
	while y > 0.0:
		_edge.append(Vector2(2.0 + (_noise(i, 4) - 0.5) * 4.0, y)); y -= step; i += 1

func _draw_paper() -> void:
	if _edge.size() < 6:
		return
	var w := paper.size.x
	var h := paper.size.y
	# drop shadow
	var sh := PackedVector2Array()
	for p in _edge:
		sh.append(p + Vector2(5, 8))
	paper.draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	# the paper: lighter in the middle, browner toward the edges (aged), drawn as a fan of triangles
	var centre := Vector2(w * 0.5, h * 0.45)
	for k in range(_edge.size()):
		var a: Vector2 = _edge[k]
		var b: Vector2 = _edge[(k + 1) % _edge.size()]
		paper.draw_polygon(PackedVector2Array([centre, a, b]), PackedColorArray([PAPER.lightened(0.03), PAPER_EDGE, PAPER_EDGE]))
	# the folds: two horizontal creases and one vertical, each a dark line with a light line beside it
	for fy in [h / 3.0, h * 2.0 / 3.0]:
		paper.draw_line(Vector2(6, fy), Vector2(w - 6, fy), Color(0.45, 0.32, 0.18, 0.3), 1.5)
		paper.draw_line(Vector2(6, fy + 1.8), Vector2(w - 6, fy + 1.8), Color(1.0, 0.96, 0.82, 0.45), 1.5)
		paper.draw_rect(Rect2(6, fy - 14, w - 12, 14), Color(0.4, 0.28, 0.14, 0.03))          # the faint shading beside a crease
	paper.draw_line(Vector2(w * 0.5, 6), Vector2(w * 0.5, h - 6), Color(0.45, 0.32, 0.18, 0.18), 1.0)
	# a curled corner (bottom right) and a couple of age spots
	paper.draw_colored_polygon(PackedVector2Array([Vector2(w - 2, h - 34), Vector2(w - 34, h - 2), Vector2(w - 2, h - 2)]), Color(0.62, 0.48, 0.28, 0.35))
	paper.draw_colored_polygon(PackedVector2Array([Vector2(w - 2, h - 34), Vector2(w - 26, h - 26), Vector2(w - 34, h - 2)]), Color(0.99, 0.94, 0.78, 0.7))
	for s in range(5):
		var sp := Vector2(30.0 + _noise(s, 9) * (w - 60.0), 24.0 + _noise(s, 10) * (h - 48.0))
		paper.draw_circle(sp, 4.0 + _noise(s, 11) * 9.0, Color(0.6, 0.45, 0.25, 0.06))
	paper.draw_polyline(_closed(_edge), Color(0.45, 0.32, 0.18, 0.55), 1.5)

func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := PackedVector2Array(p)
	c.append(p[0])
	return c

## Smooths a list of points (Catmull-Rom) so a hand-drawn stroke curves instead of showing its corners.
static func smooth(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[maxi(0, i - 1)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(pts.size() - 1, i + 2)]
		for k in range(8):
			var t := float(k) / 8.0
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[pts.size() - 1])
	return out

## Walt's signature, in a few loose pen strokes (a looping W, a-l-t, and a flourish under it), with a little "Grandpa" above.
func _draw_signature() -> void:
	var o := Vector2(8.0, 4.0)
	var ink := Color(0.16, 0.10, 0.12, 0.95)
	var strokes := [
		[Vector2(0, 8), Vector2(6, 36), Vector2(14, 12), Vector2(22, 38), Vector2(34, 2)],                                             # W
		[Vector2(36, 28), Vector2(42, 20), Vector2(47, 29), Vector2(42, 38), Vector2(37, 31), Vector2(44, 22), Vector2(49, 34), Vector2(56, 36)],   # a
		[Vector2(56, 36), Vector2(62, 22), Vector2(70, -2), Vector2(75, 6), Vector2(67, 26), Vector2(66, 38), Vector2(75, 34), Vector2(81, 30)],  # l
		[Vector2(81, 30), Vector2(87, 36), Vector2(92, 14), Vector2(95, 36), Vector2(102, 33)],                                         # t
		[Vector2(84, 20), Vector2(104, 17)],                                                                                          # the crossbar
		[Vector2(0, 46), Vector2(30, 43), Vector2(70, 47), Vector2(112, 41), Vector2(128, 36)]]                                       # the flourish under it
	for s in strokes:
		var pts: PackedVector2Array = smooth(s)
		for k in range(pts.size()):
			pts[k] += o
		sig.draw_polyline(pts, ink, 2.2, true)
	sig.draw_string(QuarryTheme.body(), Vector2(o.x + 140.0, o.y + 18.0), "Grandpa", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.28, 0.16, 0.8))

## E / a click: the next page, or closing the letter on the last one. Returns true when the letter has closed.
func advance() -> bool:
	if _opening:
		return false                                    # the sheet is still unfolding: a click is not a page turn
	if page < pages.size() - 1:
		page += 1
		_show_page(true)
		return false
	close()
	return true

## Folds the letter away (0.3 s) and tells whoever opened it.
func close(instant := false) -> void:
	if not visible:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	if instant:
		visible = false
		_opening = false
		closed.emit()
		return
	_opening = true
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(paper, "scale", Vector2(0.96, 0.06), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(paper, "modulate:a", 0.0, 0.3)
	_tween.tween_property(get_node("Dim"), "modulate:a", 0.0, 0.3)
	_tween.chain().tween_callback(func():
		visible = false
		_opening = false
		closed.emit())
