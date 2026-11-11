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
var income_label: Label
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

func _panel(pos_preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var tl := _panel(Control.PRESET_TOP_LEFT)
	tl.position = Vector2(10, 10)
	tl.custom_minimum_size = Vector2(190, 0)
	var v := _vbox(tl, 0)
	time_label = QuarryTheme.label("DAY 1  08:00", 12, QuarryTheme.DIM, true)
	v.add_child(time_label)
	money_label = QuarryTheme.label("$0", 30, QuarryTheme.MONEY)
	v.add_child(money_label)
	income_label = QuarryTheme.label("", 15, QuarryTheme.GOOD)
	v.add_child(income_label)
	# ---- top-right: objective
	var tr := _panel(Control.PRESET_TOP_RIGHT)
	tr.custom_minimum_size = Vector2(310, 0)
	tr.set_anchor(SIDE_LEFT, 1.0)
	tr.offset_left = -320
	tr.offset_right = -10
	tr.offset_top = 10
	var v2 := _vbox(tr, 3)
	stage_label = QuarryTheme.label("STAGE 1", 12, QuarryTheme.ACCENT, true)
	v2.add_child(stage_label)
	objective_label = QuarryTheme.label("", 15)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(286, 0)
	v2.add_child(objective_label)
	objective_bar = _bar(v2, 7, QuarryTheme.ACCENT)
	objective_detail = QuarryTheme.label("", 15, QuarryTheme.DIM)
	objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_detail.custom_minimum_size = Vector2(286, 0)
	v2.add_child(objective_detail)
	status_label = QuarryTheme.label("", 15, QuarryTheme.INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(286, 0)
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
	var tp := PanelContainer.new()
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tp.custom_minimum_size = Vector2(200, 0)
	bottom.add_child(tp)
	var tv := _vbox(tp, 0)
	tool_label = QuarryTheme.label("ROCK HAMMER", 12, QuarryTheme.ACCENT, true)
	tv.add_child(tool_label)
	tool_pips = QuarryTheme.label("", 15, QuarryTheme.INK)
	tv.add_child(tool_pips)
	var bp := PanelContainer.new()
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bp)
	var bv := _vbox(bp, 2)
	bag_label = QuarryTheme.label("BAG 0/18", 12, QuarryTheme.ACCENT, true)
	bv.add_child(bag_label)
	bag_bar = _bar(bv, 6, QuarryTheme.GOOD)
	bag_items = QuarryTheme.label("", 15, QuarryTheme.DIM)
	bag_items.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_items.custom_minimum_size = Vector2(150, 0)
	bv.add_child(bag_items)
	# ---- prompt + message above the bottom bar
	prompt_panel = PanelContainer.new()
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.add_theme_stylebox_override("panel", QuarryTheme.panel_box(QuarryTheme.BG_SOFT, QuarryTheme.BORDER, 7, 3))
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
	prompt_label = QuarryTheme.label("", 15)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(prompt_label)
	message_label = QuarryTheme.label("", 15, QuarryTheme.ACCENT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(message_label)
	hint_label = QuarryTheme.label("WASD move  SHIFT sprint  LMB mine  E use  M manage  B build  F5 save  ESC pause", 15, Color(0.82, 0.76, 0.62))
	add_child(hint_label)
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.set_anchor(SIDE_TOP, 1.0)
	hint_label.offset_left = 12
	hint_label.offset_top = -24
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
	dura_label = QuarryTheme.label("", 15, QuarryTheme.INK)
	dura_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dura_root.add_child(dura_label)
	dura_root.modulate.a = 0.0
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
	card_title = QuarryTheme.label("", 24, Color(0.36, 0.22, 0.12), true)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(card_title)
	card_body = QuarryTheme.label("", 15, Color(0.17, 0.11, 0.06))
	card_body.add_theme_constant_override("line_spacing", 5)
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
	var l := QuarryTheme.label("+%d %s" % [n, text.to_upper()], 16, QuarryTheme.RES_COLORS.get(res, QuarryTheme.INK))
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
	var l := QuarryTheme.label(("+" if gain else "-") + QuarryTheme.money_text(amount), 15, QuarryTheme.MONEY if gain else Color(1.0, 0.33, 0.3))
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
	toast_queue.append([title, sub, kind])

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
	time_label.text = "DAY %d   %02d:%02d" % [clock / 1440 + 1, (clock / 60) % 24, clock % 60]
	while not income_log.is_empty() and _now - float(income_log[0][0]) > 60.0:
		income_log.pop_front()
	var per_min := 0
	for e in income_log:
		per_min += int(e[1])
	income_label.text = ("+%s / min" % QuarryTheme.money_text(per_min)) if per_min > 0 else "no sales yet" if st.earned <= 0 else ""
	# message fade
	message_timer = maxf(0.0, message_timer - delta)
	message_label.modulate.a = clampf(message_timer / 0.4, 0.0, 1.0)
	message_label.visible = message_timer > 0.0
	var want_prompt := 1.0 if prompt_label.text != "" or message_label.visible else 0.0
	prompt_alpha = move_toward(prompt_alpha, want_prompt, delta * 6.0)
	prompt_panel.modulate.a = prompt_alpha
	prompt_panel.visible = prompt_alpha > 0.01
	# keep the prompt just above the tool/bag bar whatever their heights
	var bar_top := bottom.get_global_rect().position.y
	prompt_panel.offset_bottom = bar_top - size.y - 6.0
	prompt_panel.offset_top = prompt_panel.offset_bottom - prompt_panel.get_combined_minimum_size().y
	hint_label.visible = tutorial
	# durability bar fade
	dura_timer = maxf(0.0, dura_timer - delta)
	dura_root.modulate.a = move_toward(dura_root.modulate.a, 1.0 if dura_timer > 0.0 else 0.0, delta * (8.0 if dura_timer > 0.0 else 3.0))
	_update_popups(delta)
	_update_toasts(delta)
	if card.visible:
		card.modulate.a = move_toward(card.modulate.a, 1.0, delta * 4.0)

func refresh_panels() -> void:
	var st: QuarryState = game.state
	var prog: QuarryProgression = game.prog
	var t := prog.tool()
	tool_label.text = str(t["title"]).to_upper()
	var pips := ""
	for i in range(prog.tools().size()):
		pips += "■" if i <= st.tool_tier else "□"
	tool_pips.text = "%s  %s" % [pips, "HOLD LMB" if prog.is_continuous() else "LMB SWING"]
	var used := st.total(st.inventory)
	var cap := st.capacity()
	bag_label.text = "BAG %d/%d" % [used, cap]
	bag_bar.value = float(used) / float(maxi(1, cap))
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
		for r in reqs:
			frac = minf(frac, float(r[1]) / maxf(0.0001, float(r[2])))
			if float(r[1]) < float(r[2]):
				detail.append("%s  (%s)" % [r[0], _amount(r)])
		objective_label.text = "Next: %s" % str(info["title"])
		objective_bar.value = clampf(frac, 0.0, 1.0)
		objective_detail.text = "\n".join(detail) if not detail.is_empty() else "Ready!"
	else:
		stage_label.text = "STAGE %d/%d  %s" % [prog.stage + 1, prog.stages().size(), str(prog.stage_info()["title"]).to_upper()]
		objective_label.text = str(prog.stage_info()["goal"])
		objective_bar.value = prog.cleared_fraction(prog.formation_ids())
		objective_detail.text = "Quarry excavated: %d%%" % int(objective_bar.value * 100.0)
	status_label.text = game.hud_status_text()

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
		toast_t = 0.0
	if toast_active == null:
		return
	toast_t += delta
	var life := 3.2 if toast_queue.is_empty() else 2.0
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
	var t := QuarryTheme.label(title.to_upper(), 12, border, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := QuarryTheme.label(sub, 15, QuarryTheme.INK)
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
