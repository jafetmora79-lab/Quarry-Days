extends Control
class_name QuarryHUD
## Cozy retro-pixel HUD (Phase 5).
##   top-left : day / time, money (counts smoothly), income per minute
##   top-right: stage, current objective with progress, milestones, staff alerts, production status
##   bottom   : contextual prompt + message, equipped tool, bag capacity
##   centre   : crosshair, rock durability bar (only while mining), reward pop-ups ("+3 STONE")
##   toasts   : unlocks, sales, milestones (queued, slide in, fade out); story cards (modal)

var game
var time_label: Label
var money_label: Label
var time_icon: HudIcon
var tool_icon: HudIcon
var power_bar: ProgressBar
var power_label: Label
var hints: QuarryKeyHints
var build_plate: QuarryPlate
var build_lines: VBoxContainer
var _obj_target := 0.0
var _bag_target := 0.0
var _pow_target := 0.0
var income_label: Label
var badge_label: Label
var hint_text := "WASD move  SHIFT sprint  left click mine  E use  M manage  B build  F5 save  ESC pause"
var _income_override := ""
var minimap: QuarryMinimap
var map_plate: QuarryPlate
var loc_label: Label
var loc_root: Control
var _loc_text := ""
var menu_open := false            ## a menu is open: the plates fade out so they do not show through it
var _menu_fade := 1.0
var _loc_t := 0.0
var _loc_check := 0.0
var drive_plate: QuarryPlate
var drive_name: Label
var drive_speed_bar: ProgressBar
var drive_speed_label: Label
var drive_load_bar: ProgressBar
var drive_load_label: Label
var drive_hint: Label
var stage_label: Label
var objective_label: Label
var objective_bar: ProgressBar
var objective_detail: Label
var status_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var message_label: Label
var tool_label: Label
var tool_pips: Label
var bag_label: Label
var bag_bar: ProgressBar
var bag_items: Label
var hint_label: Label
var bottom: HBoxContainer
var dura_root: Control
var dura_bar: ProgressBar
var dura_label: Label
var popups: Control
var toast_root: Control
var card: PanelContainer
var fade_rect: ColorRect
var card_title: Label
var card_body: Label
var card_hint: Label
var card_callback: Callable

var shown_money := 0.0
var money_pulse := 0.0
var income_log: Array = []   # [time, amount]
var _now := 0.0
var message_timer := 0.0
var dura_timer := 0.0
var toast_queue: Array = []
var toast_active: Control
var toast_t := 0.0
var pop_merge := {}          # key -> [Label, count, age]
var money_merge := {}        # key -> [Label, total]
var prompt_alpha := 0.0
var tutorial := true

func setup(main_node) -> void:
	game = main_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = QuarryTheme.theme()
	_build()
	shown_money = float(game.state.money)
	if OS.has_feature("mobile") or game.touch_mode:
		get_viewport().size_changed.connect(_apply_safe_area)
		_apply_safe_area()

## Keeps the plates out of a phone's notch and rounded corners: the display's safe area, converted from window pixels to canvas units, as insets
## (left, top, right, bottom). Zero on a desktop, where the whole window is safe.
static func safe_insets(safe: Rect2i, window: Vector2i, canvas: Vector2) -> Vector4:
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var kx := canvas.x / float(window.x)
	var ky := canvas.y / float(window.y)
	return Vector4(maxf(0.0, float(safe.position.x)) * kx, maxf(0.0, float(safe.position.y)) * ky,
		maxf(0.0, float(window.x - safe.end.x)) * kx, maxf(0.0, float(window.y - safe.end.y)) * ky)

func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var ins := safe_insets(DisplayServer.get_display_safe_area(), win, get_viewport().get_visible_rect().size)
	offset_left = ins.x
	offset_top = ins.y
	offset_right = -ins.z
	offset_bottom = -ins.w

func _panel(pos_preset: int, strip := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := QuarryPlate.new(8, strip)
	add_child(p)
	p.set_anchors_preset(pos_preset)
	return p

func _vbox(parent: Control, sep := 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v

func _bar(parent: Control, h: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.max_value = 1.0
	b.step = 0.0
	b.add_theme_stylebox_override("fill", QuarryTheme.bar_box(color))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b

func _build() -> void:
	# ---- top-left: time + money
	var tl := _panel(Control.PRESET_TOP_LEFT, QuarryTheme.MONEY)
	tl.name = "TopLeftPlate"
	tl.position = Vector2(10, 10)
	tl.custom_minimum_size = Vector2(200, 0)
	tl.pivot_offset = Vector2(100, 20)
	var v := _vbox(tl, 1)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 5)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(trow)
	time_icon = HudIcon.new("sun", 13)
	trow.add_child(time_icon)
	time_label = QuarryTheme.label("DAY 1  08:00", 12, QuarryTheme.DIM, true)
	trow.add_child(time_label)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 5)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mrow)
	mrow.add_child(HudIcon.new("coin", 16))
	money_label = QuarryTheme.label("$0", QuarryTheme.HERO, QuarryTheme.MONEY, false, true)
	mrow.add_child(money_label)
	income_label = QuarryTheme.label("", QuarryTheme.BODY, QuarryTheme.GOOD)
	v.add_child(income_label)
	badge_label = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)   # deliveries waiting, unconnected belts
	badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(badge_label)
	# ---- under it: the map, with a caption for the objective marker
	map_plate = QuarryPlate.new(5, QuarryTheme.ACCENT)
	map_plate.name = "MapPlate"
	add_child(map_plate)
	map_plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_plate.position = Vector2(10, 92)
	tl.resized.connect(func(): map_plate.position.y = tl.position.y + tl.size.y + 8)
	var mv := _vbox(map_plate, 2)
	minimap = QuarryMinimap.new()
	minimap.name = "Minimap"
	mv.add_child(minimap)
	minimap.setup(game)
	# ---- top-centre: where you are (fades in on a change)
	loc_root = Control.new()
	loc_root.name = "LocationBanner"
	loc_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(loc_root)
	loc_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	loc_root.set_anchor(SIDE_LEFT, 0.5)
	loc_root.set_anchor(SIDE_RIGHT, 0.5)
	loc_root.offset_left = -200
	loc_root.offset_right = 200
	loc_root.offset_top = 8
	loc_root.offset_bottom = 36
	loc_label = QuarryTheme.label("", QuarryTheme.HEAD, QuarryTheme.ACCENT, true, false, true)
	loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loc_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loc_root.add_child(loc_label)
	loc_root.modulate.a = 0.0
	# ---- bottom-left: the machine you are driving (speed, load, what the right button does)
	drive_plate = QuarryPlate.new(7, QuarryTheme.MONEY)
	drive_plate.name = "DrivePlate"
	drive_plate.visible = false
	add_child(drive_plate)
	drive_plate.set_anchor(SIDE_LEFT, 0.0)
	drive_plate.set_anchor(SIDE_RIGHT, 0.0)
	drive_plate.set_anchor(SIDE_TOP, 1.0)
	drive_plate.set_anchor(SIDE_BOTTOM, 1.0)
	drive_plate.offset_left = 10
	drive_plate.offset_right = 226
	drive_plate.offset_bottom = -30
	drive_plate.offset_top = -128
	drive_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var dv := _vbox(drive_plate, 2)
	drive_name = QuarryTheme.label("", 12, QuarryTheme.ACCENT, true)
	dv.add_child(drive_name)
	drive_speed_bar = _bar(dv, 5, QuarryTheme.ACCENT)
	drive_speed_label = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)
	dv.add_child(drive_speed_label)
	drive_load_bar = _bar(dv, 6, QuarryTheme.GOOD)
	drive_load_label = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)
	dv.add_child(drive_load_label)
	drive_hint = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.INK)
	drive_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drive_hint.custom_minimum_size = Vector2(192, 0)
	dv.add_child(drive_hint)
	# ---- top-right: objective
	var tr := _panel(Control.PRESET_TOP_RIGHT, QuarryTheme.GOOD)
	tr.name = "ObjectivePlate"
	tr.custom_minimum_size = Vector2(250, 0)
	tr.set_anchor(SIDE_LEFT, 1.0)
	tr.offset_left = -260
	tr.offset_right = -10
	tr.offset_top = 10
	var v2 := _vbox(tr, 3)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 5)
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v2.add_child(srow)
	srow.add_child(HudIcon.new("flag", 13))
	stage_label = QuarryTheme.label("STAGE 1", 12, QuarryTheme.ACCENT, true)
	srow.add_child(stage_label)
	objective_label = QuarryTheme.label("", QuarryTheme.BODY)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(226, 0)
	v2.add_child(objective_label)
	objective_bar = _bar(v2, 7, QuarryTheme.ACCENT)
	objective_detail = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)
	objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_detail.custom_minimum_size = Vector2(226, 0)
	v2.add_child(objective_detail)
	status_label = QuarryTheme.label("", QuarryTheme.BODY, QuarryTheme.INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(226, 0)
	v2.add_child(status_label)
	# ---- bottom: tool + bag
	bottom = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.custom_minimum_size = Vector2(500, 48)
	bottom.set_anchor(SIDE_LEFT, 0.5)
	bottom.set_anchor(SIDE_RIGHT, 0.5)
	bottom.set_anchor(SIDE_TOP, 1.0)
	bottom.set_anchor(SIDE_BOTTOM, 1.0)
	bottom.offset_left = -250
	bottom.offset_right = 250
	bottom.offset_top = -76
	bottom.offset_bottom = -28
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var tp := QuarryPlate.new(8, QuarryTheme.ACCENT)
	tp.name = "ToolPlate"
	tp.custom_minimum_size = Vector2(230, 0)
	bottom.add_child(tp)
	var tv := _vbox(tp, 1)
	var tname := HBoxContainer.new()
	tname.add_theme_constant_override("separation", 5)
	tname.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(tname)
	tool_icon = HudIcon.new("hammer", 14)
	tname.add_child(tool_icon)
	tool_label = QuarryTheme.label("ROCK HAMMER", 12, QuarryTheme.ACCENT, true)
	tname.add_child(tool_label)
	power_bar = _bar(tv, 5, QuarryTheme.ACCENT)
	power_label = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)
	tv.add_child(power_label)
	tool_pips = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)
	tv.add_child(tool_pips)
	var bp := QuarryPlate.new(8, QuarryTheme.GOOD)
	bp.name = "BagPlate"
	bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bp)
	var bv := _vbox(bp, 2)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 5)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(brow)
	brow.add_child(HudIcon.new("bag", 14))
	bag_label = QuarryTheme.label("BAG 0/18", 12, QuarryTheme.ACCENT, true)
	brow.add_child(bag_label)
	bag_bar = _bar(bv, 6, QuarryTheme.GOOD)
	bag_items = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)
	bag_items.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_items.custom_minimum_size = Vector2(150, 0)
	bv.add_child(bag_items)
	# ---- prompt + message above the bottom bar
	prompt_panel = QuarryPlate.new(7)
	prompt_panel.name = "PromptPlate"
	add_child(prompt_panel)
	prompt_panel.set_anchor(SIDE_LEFT, 0.5)
	prompt_panel.set_anchor(SIDE_RIGHT, 0.5)
	prompt_panel.set_anchor(SIDE_TOP, 1.0)
	prompt_panel.set_anchor(SIDE_BOTTOM, 1.0)
	prompt_panel.offset_left = -330
	prompt_panel.offset_right = 330
	prompt_panel.offset_top = -112
	prompt_panel.offset_bottom = -64
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var pv := _vbox(prompt_panel, 1)
	prompt_label = QuarryTheme.label("", QuarryTheme.BODY)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(prompt_label)
	message_label = QuarryTheme.label("", QuarryTheme.BODY, QuarryTheme.ACCENT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(message_label)
	hint_label = QuarryTheme.label("", QuarryTheme.SMALL, Color(0.82, 0.76, 0.62))
	hint_label.visible = false
	add_child(hint_label)
	hints = QuarryKeyHints.new()
	hints.name = "KeyHints"
	add_child(hints)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hints.set_anchor(SIDE_TOP, 1.0)
	hints.offset_top = -24
	hints.offset_bottom = -4
	hints.offset_left = 10
	hints.offset_right = -10
	# ---- build mode blueprint plate (left, mid-height)
	build_plate = QuarryPlate.new(9, Color(0.45, 0.7, 1.0))
	build_plate.name = "BlueprintPlate"
	build_plate.visible = false
	add_child(build_plate)
	build_plate.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	build_plate.set_anchor(SIDE_TOP, 0.5)
	build_plate.set_anchor(SIDE_BOTTOM, 0.5)
	build_plate.offset_left = 10
	build_plate.offset_right = 250
	build_plate.offset_top = -80
	build_plate.offset_bottom = 80
	build_lines = _vbox(build_plate, 3)
	# ---- crosshair + durability
	var cross := Control.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	for r in [Rect2(-1, -6, 2, 4), Rect2(-1, 2, 2, 4), Rect2(-6, -1, 4, 2), Rect2(2, -1, 4, 2)]:
		var shadow := ColorRect.new()
		shadow.color = Color(0, 0, 0, 0.5)
		shadow.position = r.position + Vector2(1, 1)
		shadow.size = r.size
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(shadow)
		var c := ColorRect.new()
		c.color = Color(1, 0.96, 0.86, 0.9)
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(c)
	dura_root = VBoxContainer.new()
	dura_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dura_root)
	dura_root.set_anchors_preset(Control.PRESET_CENTER)
	dura_root.set_anchor(SIDE_LEFT, 0.5)
	dura_root.set_anchor(SIDE_RIGHT, 0.5)
	dura_root.set_anchor(SIDE_TOP, 0.5)
	dura_root.set_anchor(SIDE_BOTTOM, 0.5)
	dura_root.offset_left = -70
	dura_root.offset_right = 70
	dura_root.offset_top = 18
	dura_root.offset_bottom = 48
	dura_bar = _bar(dura_root, 5, QuarryTheme.ACCENT)
	dura_label = QuarryTheme.label("", QuarryTheme.BODY, QuarryTheme.INK, false, false, true)
	dura_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dura_root.add_child(dura_label)
	dura_root.modulate.a = 0.0
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.02, 0.04, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.z_index = 100
	# ---- pop-ups, toasts, story card
	popups = Control.new()
	popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(popups)
	toast_root = Control.new()
	toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(toast_root)
	card = PanelContainer.new()
	card.visible = false
	card.add_theme_stylebox_override("panel", QuarryTheme.panel_box(Color(0.93, 0.87, 0.72, 0.98), Color(0.42, 0.3, 0.18), 18, 4))
	add_child(card)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.set_anchor(SIDE_LEFT, 0.5)
	card.set_anchor(SIDE_RIGHT, 0.5)
	card.set_anchor(SIDE_TOP, 0.5)
	card.set_anchor(SIDE_BOTTOM, 0.5)
	card.offset_left = -270
	card.offset_right = 270
	card.offset_top = -225
	card.offset_bottom = 225
	var cv := _vbox(card, 8)
	card_title = QuarryTheme.label("", QuarryTheme.HEAD, Color(0.36, 0.22, 0.12), true)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(card_title)
	card_body = QuarryTheme.label("", QuarryTheme.BODY, Color(0.17, 0.11, 0.06))
	card_body.add_theme_constant_override("line_spacing", 4)
	card_body.remove_theme_color_override("font_shadow_color")
	card_body.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.custom_minimum_size = Vector2(500, 0)
	card_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(card_body)
	card_hint = QuarryTheme.label("E / CLICK  CONTINUE", 12, Color(0.5, 0.36, 0.2), true)
	card_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	card_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(card_hint)

## A short, restrained celebration when something is bought: the cash counter flashes and the top-left plate pulses once.
func purchase_flourish() -> void:
	money_pulse = 1.0
	var tl := get_node_or_null("TopLeftPlate")
	if tl:
		var tw := create_tween()
		tw.tween_property(tl, "scale", Vector2(1.04, 1.04), 0.08)
		tw.tween_property(tl, "scale", Vector2.ONE, 0.14)

# ------------------------------------------------------------------ public API

func set_prompt(text: String) -> void:
	prompt_label.text = text

func set_message(text: String, seconds := 3.0) -> void:
	message_label.text = text
	message_timer = seconds

func on_income(amount: int, source := "", anchor := Vector2.INF) -> void:
	income_log.append([_now, amount])
	money_pulse = 1.0
	popup_money(amount, anchor)

## "+3 STONE" near the crosshair. Pop-ups of the same material within a short window merge.
func popup_resource(res: String, n: int, text: String) -> void:
	var key := "res_" + res
	if pop_merge.has(key) and is_instance_valid(pop_merge[key][0]) and float(pop_merge[key][2]) < 0.45:
		var entry: Array = pop_merge[key]
		entry[1] = int(entry[1]) + n
		entry[0].text = "+%d %s" % [entry[1], text.to_upper()]
		entry[0].set_meta("age", minf(float(entry[0].get_meta("age")), 0.15))
		entry[2] = 0.0
		return
	var l := QuarryTheme.label("+%d %s" % [n, text.to_upper()], 12, QuarryTheme.RES_COLORS.get(res, QuarryTheme.INK), false, false, true)
	l.set_meta("age", 0.0)
	l.set_meta("life", 1.05)
	l.set_meta("origin", size * 0.5 + Vector2(26 + randf_range(-6, 6), -8 + randf_range(-4, 4)))
	popups.add_child(l)
	pop_merge[key] = [l, n, 0.0]

## Floating money numbers. "+$45" (green) for earnings and "-$20" (red) for purchases rise smoothly and fade over
## ~1.6 s. `anchor` is where they start (the clicked button's top centre); without one, earnings rise beside the
## cash counter. Numbers of the same sign started within 0.6 s at the same spot merge into one running total
## instead of stacking, and unrelated ones that would overlap are stacked a line apart.
const MONEY_LIFE := 1.6

func popup_money(amount: int, anchor := Vector2.INF) -> void:
	_money_popup(absi(amount), amount >= 0, anchor)

func popup_spend(amount: int, anchor := Vector2.INF) -> void:
	_money_popup(absi(amount), false, anchor)

func _money_popup(amount: int, gain: bool, anchor: Vector2) -> void:
	if amount <= 0:
		return
	var spot := anchor if anchor != Vector2.INF else Vector2(110, 96)
	var key := "%s_%d_%d" % ["in" if gain else "out", int(spot.x / 48.0), int(spot.y / 24.0)]
	if money_merge.has(key) and is_instance_valid(money_merge[key][0]) and float(money_merge[key][0].get_meta("age")) < 0.6:
		var entry: Array = money_merge[key]
		entry[1] = int(entry[1]) + amount
		var lab: Label = entry[0]
		lab.text = ("+" if gain else "-") + QuarryTheme.money_text(int(entry[1]))
		lab.set_meta("fade_start", maxf(float(lab.get_meta("fade_start")), float(lab.get_meta("age")) + 1.0)) # linger a moment longer
		return
	var l := QuarryTheme.label(("+" if gain else "-") + QuarryTheme.money_text(amount), 12, QuarryTheme.MONEY if gain else Color(1.0, 0.33, 0.3), false, true)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	popups.add_child(l)
	l.reset_size()
	var origin := spot + Vector2(-l.size.x * 0.5, -26.0)
	# keep clear of other live money numbers that start close by
	for other in popups.get_children():
		if other != l and other.has_meta("fade_start") and (other.get_meta("origin") as Vector2).distance_to(origin) < 24.0 and float(other.get_meta("age")) < 0.9:
			origin.y -= 22.0
	origin.x = clampf(origin.x, 4.0, maxf(4.0, size.x - l.size.x - 4.0))
	l.set_meta("age", 0.0)
	l.set_meta("origin", origin)
	l.set_meta("fade_start", 1.0)
	money_merge[key] = [l, amount]

## Queued notification at the top centre. kind: unlock | sale | milestone | info | warn
func toast(title: String, sub := "", kind := "info") -> void:
	# the same message is never shown twice in a row, and the queue stays short: when it is full the oldest
	# plain notices are dropped so a milestone is not stuck behind a pile of old news
	for q in toast_queue:
		if str(q[0]) == title:
			return
	if toast_active != null and str(toast_active.get_meta("title", "")) == title and toast_t < 1.5:
		return
	toast_queue.append([title, sub, kind])
	while toast_queue.size() > 4:
		var drop := -1
		for i in range(toast_queue.size()):
			if str(toast_queue[i][2]) in ["info", "sale", "warn"]:
				drop = i
				break
		toast_queue.remove_at(drop if drop >= 0 else 0)

func show_mining(text: String, fraction: float) -> void:
	dura_label.text = text
	dura_bar.value = clampf(fraction, 0.0, 1.0)
	dura_timer = 1.2

func show_card(title: String, body: String, callback := Callable()) -> void:
	card_title.text = title
	card_body.text = body
	card_callback = callback
	card.visible = true
	card.modulate.a = 0.0

## Fades the screen to black (alpha 1) or back (0), used when going to sleep.
var _fade_tween: Tween

func fade_to(alpha: float, seconds: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()                     # a newer fade replaces the one still running
	if seconds <= 0.0:
		fade_rect.color.a = alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", alpha, seconds)

func fade_alpha() -> float:
	return fade_rect.color.a

func card_open() -> bool:
	return card.visible

func close_card() -> void:
	if not card.visible:
		return
	card.visible = false
	var cb := card_callback
	card_callback = Callable()
	if cb.is_valid():
		cb.call()

# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	_now += delta
	if game == null or game.state == null:
		return
	_update_location(delta)
	_update_drive_plate()
	_menu_fade = move_toward(_menu_fade, 0.0 if menu_open else 1.0, delta * 7.0)
	for nm in ["TopLeftPlate", "MapPlate", "ObjectivePlate", "DrivePlate"]:
		var pn := get_node_or_null(nm) as CanvasItem
		if pn != null:
			pn.modulate.a = _menu_fade
	if bottom != null:
		bottom.modulate.a = _menu_fade
	hints.modulate.a = _menu_fade
	loc_root.visible = not menu_open
	var tlp := get_node_or_null("TopLeftPlate") as Control
	if tlp != null and map_plate != null:
		map_plate.position.y = tlp.position.y + tlp.size.y + 6.0       # the map always sits just under the time / money plate, whatever its height
	var st: QuarryState = game.state
	# money count-up
	var target := float(st.money)
	var diff := target - shown_money
	if absf(diff) < 1.0:
		shown_money = target
	else:
		shown_money += signf(diff) * maxf(absf(diff) * minf(1.0, delta * 7.0), minf(absf(diff), delta * 30.0))
	money_pulse = maxf(0.0, money_pulse - delta * 2.5)
	money_label.text = QuarryTheme.money_text(int(round(shown_money)))
	money_label.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 0.9), money_pulse)
	var clock := int(st.clock_minutes)
	var hr := (clock / 60) % 24
	var phase_name := "NIGHT" if hr < 5 or hr >= 21 else "DAWN" if hr < 7 else "MORNING" if hr < 12 else "AFTERNOON" if hr < 17 else "EVENING"
	time_label.text = "DAY %d   %02d:%02d   %s" % [clock / 1440 + 1, hr, clock % 60, phase_name]
	time_label.add_theme_color_override("font_color", QuarryTheme.WARN if hr >= 20 or hr < 5 else QuarryTheme.DIM)
	time_icon.set_kind("moon" if hr < 6 or hr >= 19 else "sun")
	while not income_log.is_empty() and _now - float(income_log[0][0]) > 60.0:
		income_log.pop_front()
	var per_min := 0
	for e in income_log:
		per_min += int(e[1])
	if (hr >= 20 or hr < 5) and game.prog.story["intro_seen"]:
		income_label.text = "Day ends at %02d:00 - head home to sleep" % int(game.prog.cfg.get("home", {}).get("curfew_hour", 22.0))
		income_label.add_theme_color_override("font_color", QuarryTheme.WARN)
	else:
		income_label.text = ("+%s / min" % QuarryTheme.money_text(per_min)) if per_min > 0 else "no sales yet" if st.earned <= 0 else ""
		income_label.add_theme_color_override("font_color", QuarryTheme.GOOD)
	# message fade
	message_timer = maxf(0.0, message_timer - delta)
	message_label.modulate.a = clampf(message_timer / 0.4, 0.0, 1.0)
	message_label.visible = message_timer > 0.0
	var want_prompt := 1.0 if prompt_label.text != "" or message_label.visible else 0.0
	prompt_alpha = move_toward(prompt_alpha, want_prompt, delta * 6.0)
	prompt_panel.modulate.a = prompt_alpha
	prompt_panel.visible = prompt_alpha > 0.01 and not menu_open
	# keep the prompt just above the tool/bag bar whatever their heights
	var bar_top := bottom.get_global_rect().position.y
	prompt_panel.offset_bottom = bar_top - size.y - 6.0
	prompt_panel.offset_top = prompt_panel.offset_bottom - prompt_panel.get_combined_minimum_size().y
	hints.visible = tutorial
	if tutorial:
		var hint_items: Array = game.hud_hints()
		if game.gamepad != null and game.gamepad.active:
			hint_items = QuarryGamepad.pad_hints(hint_items, game.driving != null, game.placement)
		hints.set_hints(hint_items)
	_update_build_plate(delta)
	_ease_bars(delta)
	# durability bar fade
	dura_timer = maxf(0.0, dura_timer - delta)
	dura_root.modulate.a = move_toward(dura_root.modulate.a, 1.0 if dura_timer > 0.0 else 0.0, delta * (8.0 if dura_timer > 0.0 else 3.0))
	_update_popups(delta)
	_update_toasts(delta)
	if card.visible:
		card.modulate.a = move_toward(card.modulate.a, 1.0, delta * 4.0)

## The location banner: checked a few times a second, shown for a few seconds when the place changes (never polls the world every frame).
func _update_location(delta: float) -> void:
	_loc_check -= delta
	if _loc_check <= 0.0:
		_loc_check = 0.25
		var here: String = game.hud_location()
		if here != "" and here != _loc_text:
			_loc_text = here
			loc_label.text = here
			_loc_t = 3.2
	_loc_t = maxf(0.0, _loc_t - delta)
	loc_root.modulate.a = move_toward(loc_root.modulate.a, clampf(_loc_t / 0.8, 0.0, 1.0) if _loc_t < 0.8 else 1.0, delta * 3.0)

## The vehicle plate: shown only while a machine is driven, in place of the hand tool.
func _update_drive_plate() -> void:
	var info: Dictionary = game.hud_drive_info()
	var driving: bool = not info.is_empty()
	drive_plate.visible = driving
	var tp := bottom.get_node_or_null("ToolPlate")
	if tp != null:
		tp.visible = not driving
	if not driving:
		return
	drive_name.text = str(info["name"])
	var mx := maxf(0.1, float(info["max_speed"]))
	drive_speed_bar.value = clampf(float(info["speed"]) / mx, 0.0, 1.0)
	drive_speed_label.text = "%.1f m/s   top %.1f" % [float(info["speed"]), mx]
	var cap := maxi(1, int(info["capacity"]))
	drive_load_bar.value = clampf(float(info["load"]) / float(cap), 0.0, 1.0)
	drive_load_label.text = "%s %d / %d%s" % ["BUCKET" if str(info["kind"]) in ["loader", "excavator"] else "BED", int(info["load"]), cap, ("  %s" % game.prog.display(str(info["carried"]))) if str(info["carried"]) != "" else ""]
	(drive_load_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = QuarryTheme.WARN if int(info["load"]) >= cap else QuarryTheme.GOOD
	drive_hint.text = str(info["action"]) if str(info["action"]) != "" else "WASD drive  Space brake  R recover  E exit"

func refresh_panels() -> void:
	var st: QuarryState = game.state
	var prog: QuarryProgression = game.prog
	var t := prog.tool()
	tool_label.text = str(t["title"]).to_upper()
	var top_dps := 1.0
	for ti in range(prog.tools().size()):
		top_dps = maxf(top_dps, prog.tool_dps(ti))
	_pow_target = prog.tool_dps() / top_dps
	power_label.text = "Mining power %.0f a second" % prog.tool_dps()
	tool_icon.set_kind("hammer" if st.tool_tier == 0 else "pick")
	var hard: String = ["", "Stone and coal", "Up to iron", "Up to copper", "Anything, gold too"][clampi(int(t.get("max_hardness", 1)), 0, 4)]
	tool_pips.text = "Tool %d of %d   %s" % [st.tool_tier + 1, prog.tools().size(), hard]
	var used := st.total(st.inventory)
	var cap := st.capacity()
	bag_label.text = "BAG %d/%d" % [used, cap]
	_bag_target = float(used) / float(maxi(1, cap))
	(bag_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = QuarryTheme.WARN if used >= cap else QuarryTheme.GOOD
	var items := []
	for k in QuarryState.RESOURCE_NAMES:
		if int(st.inventory[k]) > 0:
			items.append("%s %d" % [prog.display(k), int(st.inventory[k])])
	bag_items.text = "  ".join(items) if not items.is_empty() else "empty"
	# objective
	var next := prog.stage + 1
	if next < prog.stages().size():
		var info := prog.stage_info(next)
		stage_label.text = "STAGE %d/%d  %s" % [prog.stage + 1, prog.stages().size(), str(prog.stage_info()["title"]).to_upper()]
		var reqs := prog.requirement_progress(next)
		var frac := 1.0
		var detail := []
		var done_n := 0
		var more := 0
		for r in reqs:
			frac = minf(frac, float(r[1]) / maxf(0.0001, float(r[2])))
			var done_r := float(r[1]) >= float(r[2]) - 0.00001
			# compact checklist: only the first few open requirements are spelled out; finished ones are counted so progress is never a surprise
			if done_r:
				done_n += 1
			elif detail.size() < 3:
				detail.append("[ ] %s  (%s)" % [r[0], _amount(r)])
			else:
				more += 1
		if done_n > 0:
			detail.append("[x] %d done" % done_n)
		if more > 0:
			detail.append("+%d more" % more)
		objective_label.text = "Next: %s" % str(info["title"])
		_obj_target = clampf(frac, 0.0, 1.0)
		objective_detail.text = "\n".join(detail) if not detail.is_empty() else "Ready!"
	else:
		stage_label.text = "STAGE %d/%d  %s" % [prog.stage + 1, prog.stages().size(), str(prog.stage_info()["title"]).to_upper()]
		# every business stage is done: the quarry itself is the goal
		var ql: int = prog.quarry_level
		objective_label.text = "Quarry level %d: %s" % [ql, str(prog.level_def(ql).get("title", ""))]
		_obj_target = prog.level_cleared_fraction(ql) if prog.level_built(ql) else prog.cleared_fraction(prog.formation_ids())
		var nxt: Dictionary = prog.level_def(ql + 1)
		var hint := ""
		if not nxt.is_empty():
			hint = "\nNext: %s - %s" % [str(nxt.get("title", "")), ("opens at %d%% cut" % int(float(nxt.get("unlock", 0.6)) * 100.0)) if prog.level_built(ql + 1) else "being surveyed"]
		objective_detail.text = "Level cut: %d%%%s" % [int(_obj_target * 100.0), hint]
	status_label.text = game.hud_status_text()
	var badge_lines := []
	var warn := false
	for b in game.hud_badges():
		badge_lines.append(str(b[0]))
		warn = warn or bool(b[1])
	badge_label.text = "\n".join(badge_lines)
	badge_label.visible = not badge_lines.is_empty()
	badge_label.add_theme_color_override("font_color", QuarryTheme.WARN if warn else QuarryTheme.DIM)

func _amount(r: Array) -> String:
	if str(r[0]).begins_with("Earn"):
		return "%s / %s" % [QuarryTheme.money_text(int(r[1])), QuarryTheme.money_text(int(r[2]))]
	if str(r[0]).begins_with("Clear"):
		return "%d%%" % int(float(r[1]) * 100.0)
	return "%d/%d" % [int(r[1]), int(r[2])]

func _update_popups(delta: float) -> void:
	for key in pop_merge.keys():
		pop_merge[key][2] = float(pop_merge[key][2]) + delta
		if not is_instance_valid(pop_merge[key][0]):
			pop_merge.erase(key)
	for key in money_merge.keys():
		if not is_instance_valid(money_merge[key][0]):
			money_merge.erase(key)
	for l in popups.get_children():
		var age: float = float(l.get_meta("age")) + delta
		l.set_meta("age", age)
		if l.has_meta("fade_start"):
			# money numbers: constant, eased rise (position depends on age only, so merges never make it jump)
			var rise := 1.0 - pow(1.0 - clampf(age / MONEY_LIFE, 0.0, 1.0), 2.0)
			l.position = (l.get_meta("origin") as Vector2) + Vector2(0, -46.0 * rise)
			var fs: float = float(l.get_meta("fade_start"))
			l.modulate.a = clampf(age / 0.12, 0.0, 1.0) * (1.0 - clampf((age - fs) / 0.6, 0.0, 1.0))
			if age >= fs + 0.6:
				l.queue_free()
			continue
		var life: float = float(l.get_meta("life"))
		var a := clampf(age / life, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - a, 3.0)
		l.position = (l.get_meta("origin") as Vector2) + Vector2(0, -34.0 * ease)
		l.modulate.a = clampf(age / 0.08, 0.0, 1.0) * (1.0 - clampf((a - 0.6) / 0.4, 0.0, 1.0))
		if a >= 1.0:
			l.queue_free()

func _update_toasts(delta: float) -> void:
	if toast_active == null and not toast_queue.is_empty():
		var item: Array = toast_queue.pop_front()
		toast_active = _make_toast(str(item[0]), str(item[1]), str(item[2]))
		toast_active.set_meta("title", str(item[0]))
		toast_active.set_meta("kind", str(item[2]))
		toast_t = 0.0
	if toast_active == null:
		return
	toast_t += delta
	var big := str(toast_active.get_meta("kind", "")) == "milestone"
	var life := (4.8 if big else 3.2) if toast_queue.is_empty() else (3.0 if big else 2.0)   # milestones linger
	var a_in := clampf(toast_t / 0.25, 0.0, 1.0)
	var a_out := clampf((life - toast_t) / 0.35, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - a_in, 3.0)
	toast_active.modulate.a = minf(a_in, a_out)
	toast_active.position.y = lerpf(-30.0, 56.0, e)
	if toast_t >= life:
		toast_active.queue_free()
		toast_active = null

func _make_toast(title: String, sub: String, kind: String) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border: Color = {"unlock": QuarryTheme.ACCENT, "milestone": QuarryTheme.GOOD, "sale": QuarryTheme.MONEY, "warn": QuarryTheme.WARN}.get(kind, QuarryTheme.BORDER_HI)
	p.add_theme_stylebox_override("panel", QuarryTheme.panel_box(QuarryTheme.BG, border, 10, 3))
	toast_root.add_child(p)
	var v := _vbox(p, 1)
	var t := QuarryTheme.label(title.to_upper(), 16 if kind == "milestone" else 12, border, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := QuarryTheme.label(sub, QuarryTheme.BODY, QuarryTheme.INK)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if sub.length() > 52: # long subtitles wrap inside the toast instead of running off the screen
			s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			s.custom_minimum_size = Vector2(440, 0)
		v.add_child(s)
	p.reset_size()
	var w := maxf(260.0, p.get_combined_minimum_size().x)
	p.size = Vector2(w, p.get_combined_minimum_size().y)
	p.position = Vector2(size.x * 0.5 - w * 0.5, -30)
	return p


## Bars ease toward their value instead of jumping.
func _ease_bars(delta: float) -> void:
	var k := minf(1.0, delta * 8.0)
	objective_bar.value = lerpf(objective_bar.value, _obj_target, k)
	bag_bar.value = lerpf(bag_bar.value, _bag_target, k)
	power_bar.value = lerpf(power_bar.value, _pow_target, k)
	if absf(objective_bar.value - _obj_target) < 0.002:
		objective_bar.value = _obj_target

## The blueprint plate shows while placing or moving a structure and in construction mode: what, how it is turned, whether the
## ground is valid, what it costs and what it connects to.
var _build_key := ""

func _update_build_plate(delta: float) -> void:
	var info: Dictionary = game.build_info()
	var active: bool = bool(info.get("active", false))
	if active != build_plate.visible and (active or build_plate.modulate.a <= 0.02):
		build_plate.visible = active
	build_plate.modulate.a = move_toward(build_plate.modulate.a, 1.0 if active else 0.0, delta * 6.0)
	if build_plate.modulate.a <= 0.01 and not active:
		build_plate.visible = false
	if not active:
		_build_key = ""
		return
	var key := JSON.stringify(info)
	if key == _build_key:
		return
	_build_key = key
	for c in build_lines.get_children():
		build_lines.remove_child(c)
		c.queue_free()
	build_lines.add_child(QuarryTheme.label("BLUEPRINT", 12, Color(0.55, 0.78, 1.0), true))
	build_lines.add_child(QuarryTheme.label(str(info.get("title", "")), QuarryTheme.BODY, QuarryTheme.INK, false, true))
	if info.has("rotation"):
		build_lines.add_child(QuarryTheme.label("Turned %d degrees" % int(info["rotation"]), QuarryTheme.BODY, QuarryTheme.DIM))
	if info.has("grid"):
		build_lines.add_child(QuarryTheme.label("Grid snap: %s" % ("ON" if info["grid"] else "OFF"), QuarryTheme.BODY, QuarryTheme.DIM))
	if info.has("valid"):
		build_lines.add_child(QuarryTheme.label("Ground: %s" % ("VALID" if info["valid"] else "BLOCKED"), QuarryTheme.BODY, QuarryTheme.GOOD if info["valid"] else QuarryTheme.WARN, false, true))
	if info.has("price"):
		build_lines.add_child(QuarryTheme.label("Cost: %s" % (QuarryTheme.money_text(int(info["price"])) if int(info["price"]) > 0 else "already paid"), QuarryTheme.BODY, QuarryTheme.MONEY))
	if str(info.get("hint", "")) != "":
		var hl := QuarryTheme.label(str(info["hint"]).strip_edges(), QuarryTheme.SMALL, QuarryTheme.DIM)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(210, 0)
		build_lines.add_child(hl)
