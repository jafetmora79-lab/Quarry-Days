extends Node3D
class_name HopperPlateScreen
## The Cash Hopper's front screen (the dark plate under the funnel): a small SubViewport drawn as a quad lying on the plate.
## Unlike ScreenFace (one label) it has a layout: a title strip, a big amount line, a count bar and a footer, and it ANIMATES:
##   set_idle()      title = tier name, big line = what is going through / READY, footer = TODAY / WAITING / SPEED
##   sale(money,..)  title = "SALE  12 x LIMESTONE", the big line counts up from $0 to the amount (a `tick` signal for the coin sound), the bar fills with it
##   paid()          the amount locks, a white flash and a PAID stamp slams on, the amount blinks while the drawer is open
##   done()          THANK YOU / DONE, then back_to_idle()
## While something animates the viewport re-renders every frame; at rest it renders once per change (nothing is redrawn every frame for nothing).

signal tick                                      ## each time the counted number moves a step (the owner plays a coin tick)

## One look per upgrade tier: the interface gets nicer as the hopper levels up.
##   0 old green terminal, a smooth bar     1 amber screen, segmented bar, an LV badge    2 cyan-white screen with gold accents, a finer segmented bar, an LV badge, a bar chart of the last sales
const SKINS := [
	{"ink": Color(0.66, 1.0, 0.72), "accent": Color(1.0, 0.82, 0.30), "glass": Color(0.02, 0.07, 0.04), "bar_bg": Color(0.05, 0.16, 0.09), "segments": 0, "badge": "", "chart": false},
	{"ink": Color(1.0, 0.80, 0.38), "accent": Color(0.55, 1.0, 0.72), "glass": Color(0.07, 0.04, 0.01), "bar_bg": Color(0.18, 0.10, 0.03), "segments": 14, "badge": "LV2", "chart": false},
	{"ink": Color(0.72, 0.96, 1.0), "accent": Color(1.0, 0.84, 0.30), "glass": Color(0.01, 0.04, 0.08), "bar_bg": Color(0.04, 0.12, 0.20), "segments": 24, "badge": "LV3", "chart": true}]
const PX := Vector2i(372, 164)
var INK := Color(0.66, 1.0, 0.72)                ## the active skin's colours (set in setup)
var GOLD := Color(1.0, 0.82, 0.30)
var GLASS := Color(0.02, 0.07, 0.04)
var _skin: Dictionary
var _badge: Label
var _chart: Array = []                           ## the bar chart's bars (tier 2)
var _history: Array = []                         ## the last sales (money), newest last

var _vp: SubViewport
var _title: Label
var _big: Label
var _foot: Label
var _bar_bg: ColorRect
var _bar: ColorRect
var _stamp: Label
var _flash: ColorRect
var _quad: MeshInstance3D
var _tw: Tween
var _blink: Tween
var _shown := 0.0
var _target := 0
var _last_step := -1
var _mode := "idle"
var _idle_title := "CASH HOPPER"
var _idle_big := "READY"
var _idle_foot := ""
var _mix_text := ""
var _seg_gaps: Array = []
var _live_left := 0.0                            ## seconds the viewport keeps re-rendering every frame
var brightness := 1.0 : set = _set_brightness

func setup(size_m: Vector2, tier := 0) -> void:
	_skin = SKINS[clampi(tier, 0, SKINS.size() - 1)]
	INK = _skin["ink"]
	GOLD = _skin["accent"]
	GLASS = _skin["glass"]
	_vp = SubViewport.new()
	_vp.size = PX
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = GLASS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp.add_child(bg)
	_title = _label(Rect2(8, 4, PX.x - 200 if bool(_skin["chart"]) else (PX.x - 80 if str(_skin["badge"]) != "" else PX.x - 16), 26), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_big = _label(Rect2(8, 28, PX.x - 16, 74), 62, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_bar_bg = ColorRect.new()
	_bar_bg.color = _skin["bar_bg"]
	_bar_bg.position = Vector2(10, 104)
	_bar_bg.size = Vector2(PX.x - 20, 8)
	_vp.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = GOLD
	_bar.position = Vector2(10, 104)
	_bar.size = Vector2(0, 8)
	_vp.add_child(_bar)
	for si in range(1, int(_skin["segments"])):                          # the segmented bar: thin dark gaps over it
		var gap := ColorRect.new()
		gap.color = _skin["glass"]
		gap.position = Vector2(10.0 + (PX.x - 20.0) * float(si) / float(_skin["segments"]) - 1.0, 104)
		gap.size = Vector2(2, 8)
		_seg_gaps.append(gap)
	_foot = _label(Rect2(8, 118, PX.x - 16, 42), 17, Color(INK.r, INK.g, INK.b, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_stamp = _label(Rect2(PX.x - 150, 40, 140, 58), 40, Color(1.0, 0.95, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	_stamp.text = "PAID"
	_stamp.visible = false
	_stamp.pivot_offset = Vector2(70, 29)
	_stamp.rotation = -0.14
	for g in _seg_gaps:
		_vp.add_child(g)                                             # (above the bar fill, below the text)
	if str(_skin["badge"]) != "":
		_badge = _label(Rect2(PX.x - 62, 3, 54, 24), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_badge.text = _skin["badge"]
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.16)
		bs.border_color = GOLD
		bs.set_border_width_all(2)
		_badge.add_theme_stylebox_override("normal", bs)
	if bool(_skin["chart"]):
		for ci in range(8):                                           # a bar chart of the last eight sales, right of the title (bars grow from the baseline)
			var cb := ColorRect.new()
			cb.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
			cb.position = Vector2(PX.x - 170 + ci * 12, 27)
			cb.size = Vector2(8, 2)
			_vp.add_child(cb)
			_chart.append(cb)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(_flash)
	var scan := ColorRect.new()                                          # scanlines + vignette + glass sheen (the same layer ScreenFace puts on its screens)
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ScreenFace.SCAN_SHADER
	sm.shader = sh
	scan.material = sm
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(scan)
	_quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size_m
	_quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_quad.material_override = m
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.rotation = Vector3(0, PI, 0)                                   # the quad faces -Z, like the machine's front
	add_child(_quad)
	_show_idle()

func _label(r: Rect2, size: int, c: Color, align: int) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_override("font", QuarryTheme.hud())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(c.r * 0.35, c.g * 0.6, c.b * 0.4, 0.45))
	l.add_theme_constant_override("outline_size", 3)
	_vp.add_child(l)
	return l

func _set_brightness(b: float) -> void:
	brightness = b
	if _quad != null:
		(_quad.material_override as StandardMaterial3D).albedo_color = Color(b, b, b, 1.0)

## Keeps the viewport re-rendering every frame for `secs` (animations), then drops back to render-on-change.
func _live(secs: float) -> void:
	_live_left = maxf(_live_left, secs)
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _process(delta: float) -> void:
	if _live_left > 0.0:
		_live_left -= delta
		if _live_left <= 0.0 and _vp != null:
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE              # one last render of the final state

func _redraw() -> void:
	if _vp != null and _live_left <= 0.0:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

# ------------------------------------------------------------------ the standby page

## What the screen says between sales. The owner calls this a few times a second; it does nothing while a sale is on screen.
func set_idle(title: String, big: String, foot: String) -> void:
	if title == _idle_title and big == _idle_big and foot == _idle_foot:
		return
	_idle_title = title
	_idle_big = big
	_idle_foot = foot
	if _mode == "idle":
		_show_idle()

func _show_idle() -> void:
	_mode = "idle"
	_title.text = _idle_title
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.text = _idle_big
	_big.add_theme_font_size_override("font_size", 62 if _idle_big.length() <= 9 else 38)
	_big.add_theme_color_override("font_color", INK)
	_foot.text = _idle_foot
	_bar.size.x = 0.0
	_bar_bg.visible = false
	_stamp.visible = false
	_flash.color.a = 0.0
	_redraw()

# ------------------------------------------------------------------ a sale: count up, lock, stamp

## Starts a sale page: the number runs from `from` to `money` in `secs` seconds (quick start, slow settle).
func sale(money: int, units: int, mats: Array, secs: float, from := 0) -> void:
	_kill()
	_mode = "sale"
	_target = money
	_last_step = -1
	_shown = float(from)
	# mats: [[display name, units], ...] largest first: one material is named on the title, several are listed on the footer line
	_title.text = ("SALE   %d x %s" % [units, str((mats[0] as Array)[0]).to_upper()]) if mats.size() == 1 else "SALE   %d UNITS" % units
	var mix := []
	for m in mats:
		mix.append("%s %d" % [str(m[0]).to_upper(), int(m[1])])
	_mix_text = "   ".join(mix) if mats.size() > 1 else "COUNTING..."
	_big.add_theme_color_override("font_color", INK)
	_big.add_theme_font_size_override("font_size", 62)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_bg.visible = true
	_stamp.visible = false
	_flash.color.a = 0.0
	_foot.text = _mix_text
	_count(float(from))
	_live(secs + 0.2)
	_tw = create_tween()
	_tw.tween_method(_count, float(from), float(money), maxf(secs, 0.05)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func(): _foot.text = "TOTAL  " + QuarryTheme.money_text(_target))

func _count(v: float) -> void:
	_shown = v
	_big.text = "+" + QuarryTheme.money_text(int(round(v)))
	var span := maxf(float(_target), 1.0)
	_bar.size.x = (PX.x - 20.0) * clampf(v / span, 0.0, 1.0)
	var step := int(v / span * 12.0)                                    # a tick roughly every twelfth of the way
	if step != _last_step:
		_last_step = step
		tick.emit()

## The number on the screen right now (a sale that rides an open drawer carries on from here).
func shown_amount() -> int:
	return int(round(_shown))

## The amount locks and flashes, a PAID stamp slams onto it.
func paid(cash_text := "CASH OUT") -> void:
	_kill()
	_history.append(_target)
	if _history.size() > 8:
		_history.pop_front()
	_draw_chart()
	_mode = "paid"
	_big.text = "+" + QuarryTheme.money_text(_target)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT                 # the amount steps left and shrinks a little: the stamp lands beside it, not on it
	_big.add_theme_font_size_override("font_size", 46)
	_bar.size.x = PX.x - 20.0
	_foot.text = cash_text                                               # the bills and coins in the tray, e.g. 2x$500  1x$100  3x$20
	_stamp.visible = true
	_stamp.scale = Vector2(2.4, 2.4)
	_stamp.modulate.a = 0.0
	_live(1.4)
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(_stamp, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	_tw.tween_property(_flash, "color:a", 0.55, 0.05)
	_tw.chain().tween_property(_flash, "color:a", 0.0, 0.35)
	_blink = create_tween().set_loops(3)                                # the amount blinks gold / green while the drawer is open
	_blink.tween_callback(func(): _big.add_theme_color_override("font_color", GOLD)).set_delay(0.18)
	_blink.tween_callback(func(): _big.add_theme_color_override("font_color", INK)).set_delay(0.18)

func _draw_chart() -> void:
	if _chart.is_empty():
		return
	var top := 1.0
	for h in _history:
		top = maxf(top, float(h))
	for ci in range(_chart.size()):
		var bar := _chart[ci] as ColorRect
		var hh := 3.0
		if ci < _history.size():
			hh = 3.0 + 22.0 * float(_history[ci]) / top
		bar.size.y = hh
		bar.position.y = 27.0 - hh

func done() -> void:
	_kill()
	_mode = "done"
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.add_theme_font_size_override("font_size", 62)
	_title.text = "THANK YOU"
	_big.text = "DONE"
	_big.add_theme_color_override("font_color", INK)
	_foot.text = "TOTAL  " + QuarryTheme.money_text(_target)
	_bar.size.x = PX.x - 20.0
	_redraw()

func back_to_idle() -> void:
	_kill()
	_show_idle()

func _kill() -> void:
	for t in [_tw, _blink]:
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()
	_big.add_theme_color_override("font_color", INK)
	_stamp.visible = false
	_flash.color.a = 0.0

func is_idle() -> bool:
	return _mode == "idle"

func shown_text() -> String:
	return _big.text if _big != null else ""
