extends Control
## Office management interface. Mouse driven; the world is paused while it is open.
## Sized for the 960x540 base canvas, which scales cleanly to 1280x720 and 1920x1080.

const TABS := [["staff", "WORKERS"], ["hire", "HIRE"], ["payroll", "PAYROLL"], ["production", "PRODUCTION"], ["equipment", "EQUIPMENT"], ["upgrades", "UPGRADES"], ["milestones", "MILESTONES"], ["stats", "STATS"]]
const INK := QuarryTheme.INK
const DIM := QuarryTheme.DIM
const ACCENT := QuarryTheme.ACCENT
const WARN := QuarryTheme.WARN
const GOOD := QuarryTheme.GOOD

var game
var tab := "staff"
var content: VBoxContainer
var scroll: ScrollContainer
var header: Label
var status: Label
var tab_buttons := {}
var confirm_fire := -1

func setup(main_node) -> void:
	game = main_node
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -440
	frame.offset_right = 440
	frame.offset_top = -245
	frame.offset_bottom = 245
	add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	frame.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	header = _label("", ACCENT, QuarryTheme.BODY)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	var close := Button.new()
	close.text = "CLOSE [Esc]"
	close.custom_minimum_size = Vector2(110, 28)
	close.pressed.connect(func(): game._close_menu())
	top.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(88, 0)
		b.pressed.connect(_set_tab.bind(t[0]))
		tabs.add_child(b)
		tab_buttons[t[0]] = b
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	status = _label("", GOOD, QuarryTheme.BODY)
	root.add_child(status)

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = QuarryTheme.body()
	t.default_font_size = QuarryTheme.BODY
	t.set_font("font", "Button", QuarryTheme.bold())
	t.set_font_size("font_size", "Button", QuarryTheme.BODY)
	var frame := QuarryTheme.panel_box(Color(0.13, 0.1, 0.075, 0.97), QuarryTheme.BORDER_HI, 12, 4)
	t.set_stylebox("panel", "PanelContainer", frame)
	t.set_stylebox("normal", "Button", _box(Color(0.24, 0.18, 0.12), Color(0.5, 0.37, 0.23), 2, 4))
	t.set_stylebox("hover", "Button", _box(Color(0.33, 0.25, 0.15), Color(0.72, 0.56, 0.34), 2, 4))
	t.set_stylebox("pressed", "Button", _box(Color(0.47, 0.34, 0.16), Color(0.98, 0.76, 0.34), 2, 4))
	t.set_stylebox("hover_pressed", "Button", _box(Color(0.47, 0.34, 0.16), Color(0.98, 0.76, 0.34), 2, 4))
	t.set_stylebox("disabled", "Button", _box(Color(0.15, 0.12, 0.1), Color(0.3, 0.26, 0.21), 2, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for type in ["OptionButton", "CheckBox"]:
		t.set_stylebox("normal", type, _box(Color(0.12, 0.11, 0.09), Color(0.45, 0.38, 0.24), 1, 4))
		t.set_stylebox("hover", type, _box(Color(0.22, 0.19, 0.13), Color(0.75, 0.6, 0.3), 1, 4))
		t.set_stylebox("pressed", type, _box(Color(0.30, 0.24, 0.12), Color(0.95, 0.74, 0.3), 1, 4))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", _box(Color(0.09, 0.08, 0.07), Color(0.62, 0.5, 0.28), 1, 4))
	t.set_stylebox("hover", "PopupMenu", _box(Color(0.32, 0.25, 0.12), Color(0.32, 0.25, 0.12), 0, 2))
	for type in ["Button", "OptionButton", "CheckBox", "Label", "PopupMenu"]:
		t.set_color("font_color", type, INK)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_pressed_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.40, 0.35))
	return t

func _box(bg: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(2)
	b.corner_detail = 2
	b.set_content_margin_all(margin)
	b.anti_aliasing = false
	return b

func _label(text: String, color := INK, size := 12, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(text: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): game.ui_click("mgmt_" + text, action, b)) # debounced; shows the money pop-up
	return b

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	return h

func _card() -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.19, 0.145, 0.1), Color(0.36, 0.28, 0.19), 1, 7))
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v

func _set_tab(id: String) -> void:
	tab = id
	confirm_fire = -1
	status.text = ""
	refresh()

func _say(text: String) -> void:
	refresh()
	status.text = text

func refresh() -> void:
	var b: QuarryBusiness = game.business
	var clock := int(game.state.clock_minutes)
	header.text = "GRANDPA WALT'S QUARRY  -  DAY %d  %s   %s   STAFF %d/%d   STAGE: %s" % [clock / 1440 + 1, game.fmt_time(clock), QuarryTheme.money_text(game.state.money), b.employees.size(), b.max_employees(), str(game.prog.stage_info()["title"]).to_upper()]
	for id in tab_buttons:
		tab_buttons[id].button_pressed = id == tab
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	match tab:
		"staff": _staff(b)
		"hire": _hire(b)
		"payroll": _payroll(b)
		"production": _production(b)
		"equipment": _equipment()
		"milestones": _milestones(b)
		"upgrades": _upgrades()
		"stats": _stats(b)

# ------------------------------------------------------------------ staff

func _staff(b: QuarryBusiness) -> void:
	if b.employees.is_empty():
		content.add_child(_label("No employees yet. Open HIRE to recruit your first worker. Each worker only performs their own profession.", DIM))
		return
	for e in b.employees:
		var id := int(e["id"])
		var card := _card()
		var top := _row()
		card.add_child(top)
		var title := _label("%s  -  %s   Skill %d   $%.2f/h   Training %d/3" % [e["name"], b.profession(e["profession"])["title"], e["skill"], b.wage(e), e["upgrade"]], ACCENT, QuarryTheme.BODY)
		top.add_child(title)
		var task := _label(str(e["task"]), INK if b.can_work(e) else DIM, QuarryTheme.BODY)
		task.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(task)
		var assign := _row()
		card.add_child(assign)
		_assignment_controls(b, e, assign)
		var line := _row()
		card.add_child(line)
		line.add_child(_label("Shift", DIM, QuarryTheme.BODY, false))
		line.add_child(_button("-", func(): _say(game.ui_shift(id, int(e["shift_start"]) - 30, int(e["shift_end"])))))
		line.add_child(_label(game.fmt_time(int(e["shift_start"])), INK, QuarryTheme.BODY, false))
		line.add_child(_button("+", func(): _say(game.ui_shift(id, int(e["shift_start"]) + 30, int(e["shift_end"])))))
		line.add_child(_label("to", DIM, QuarryTheme.BODY, false))
		line.add_child(_button("-", func(): _say(game.ui_shift(id, int(e["shift_start"]), int(e["shift_end"]) - 30))))
		line.add_child(_label(game.fmt_time(int(e["shift_end"])), INK, QuarryTheme.BODY, false))
		line.add_child(_button("+", func(): _say(game.ui_shift(id, int(e["shift_start"]), int(e["shift_end"]) + 30))))
		line.add_child(_label("(%.1f h)" % b.shift_hours(e), DIM, QuarryTheme.BODY, false))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(spacer)
		var up := b.upgrade_info(e)
		if up.is_empty():
			line.add_child(_button("Fully trained", func(): pass, false))
		else:
			line.add_child(_button("Train: %s $%d" % [up["name"], up["cost"]], func(): _say(game.ui_upgrade(id)), game.state.money >= int(up["cost"])))
		var fire_text := "Confirm dismiss?" if confirm_fire == id else "Dismiss"
		line.add_child(_button(fire_text, func(): _fire(id)))
		var s: Dictionary = e["stats"]
		var today: bool = int(s["day"]) == b.current_day()
		card.add_child(_label("Today: %d units  -  %.1f h worked  -  paid $%d  -  owed $%.2f   |   Total: %d units, $%d paid" % [
			int(s["units_today"]) if today else 0, (int(s["minutes_today"]) if today else 0) / 60.0, int(s["paid_today"]) if today else 0,
			float(e["owed"]), int(s["units_total"]), int(s["paid_total"])], DIM, 11))
		if str(e["warning"]) != "":
			card.add_child(_label("! " + str(e["warning"]), WARN, QuarryTheme.BODY))

func _fire(id: int) -> void:
	if confirm_fire != id:
		confirm_fire = id
		refresh()
		return
	confirm_fire = -1
	_say(game.ui_fire(id))

func _assignment_controls(b: QuarryBusiness, e: Dictionary, row: HBoxContainer) -> void:
	var id := int(e["id"])
	var a: Dictionary = e["assignment"]
	match str(e["profession"]):
		"miner":
			row.add_child(_label("Mine:", DIM, QuarryTheme.BODY, false))
			var opts := []
			for r in QuarryBusiness.MINERALS:
				opts.append([game.prog.display(r) + " deposits", {"resource": r}])
			row.add_child(_option(opts, a, func(v): _say(game.ui_assign(id, v))))
			row.add_child(_label("-> delivers to Storage crate", DIM, QuarryTheme.BODY))
		"operator":
			row.add_child(_label("Operate:", DIM, QuarryTheme.BODY, false))
			var opts := []
			for i in range(game.state.crushers.size()):
				opts.append(["Crusher #%d" % (i + 1), {"crusher": i}])
			if opts.is_empty():
				row.add_child(_label("No crusher placed yet - order one at the blue kiosk.", WARN, QuarryTheme.BODY))
			else:
				row.add_child(_option(opts, a, func(v): _say(game.ui_assign(id, v))))
				var out: int = b.crusher_outputs[int(a.get("crusher", 0))] if int(a.get("crusher", 0)) < b.crusher_outputs.size() else -1
				row.add_child(_label("-> output %s" % ("to Output storage #%d" % (out + 1) if out >= 0 else "stays in crusher (place output storage at the chute)"), DIM, QuarryTheme.BODY))
		"hauler":
			var srcs := [["Storage crate", {"type": "storage"}]]
			for r in QuarryBusiness.MINERALS:
				srcs.append(["Loose " + r.replace("_", " "), {"type": "deposit", "resource": r}])
			for i in range(game.state.crushers.size()):
				srcs.append(["Crusher #%d output" % (i + 1), {"type": "crusher", "index": i}])
			for i in range(b.outputs.size()):
				srcs.append(["Output storage #%d" % (i + 1), {"type": "output", "index": i}])
			for i in range(game.prog.rigs.size()):
				srcs.append(["%s #%d bin" % [str(game.prog.machine(str(game.prog.rigs[i]["type"]))["title"]), i + 1], {"type": "rig", "index": i}])
			var dsts := [["Storage crate", {"type": "storage"}]]
			for i in range(game.state.crushers.size()):
				dsts.append(["Crusher #%d hopper" % (i + 1), {"type": "crusher", "index": i}])
			for i in range(b.outputs.size()):
				dsts.append(["Output storage #%d" % (i + 1), {"type": "output", "index": i}])
			row.add_child(_label("From:", DIM, QuarryTheme.BODY, false))
			row.add_child(_option(srcs, a.get("src", {}), func(v): _set_route(b, id, v, a.get("dst", {}), dsts)))
			row.add_child(_label("To:", DIM, QuarryTheme.BODY, false))
			row.add_child(_option(dsts, a.get("dst", {}), func(v): _set_route(b, id, a.get("src", {}), v, dsts)))
			var res := b.route_resource(a.get("src", {}), a.get("dst", {}))
			row.add_child(_label(("carries " + res.replace("_", " ")) if res != "" else "invalid route", DIM if res != "" else WARN, QuarryTheme.BODY))
		"clerk":
			row.add_child(_label("Works at the selling station. Choose what may be sold in PRODUCTION.", DIM, QuarryTheme.BODY))

func _set_route(b: QuarryBusiness, id: int, src: Dictionary, dst: Dictionary, dsts: Array) -> void:
	if b.route_resource(src, dst) == "":
		for d in dsts:
			if b.route_resource(src, d[1]) != "":
				dst = d[1]
				break
	_say(game.ui_assign(id, {"src": src, "dst": dst}))

func _option(options: Array, current, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = true
	var selected := -1
	for i in range(options.size()):
		o.add_item(options[i][0], i)
		if JSON.stringify(options[i][1]) == JSON.stringify(current):
			selected = i
	o.select(selected)
	o.item_selected.connect(func(i): on_pick.call(options[i][1]))
	return o

# ------------------------------------------------------------------ hire

func _hire(b: QuarryBusiness) -> void:
	content.add_child(_label("Hiring fee is paid once. Wages are paid every in-game hour worked, only during each worker's shift. If the balance cannot cover wages, work stops and the wages stay owed.", DIM))
	if b.outstanding_debt > 0.0:
		content.add_child(_label("Outstanding wages to former staff: $%.2f - paid automatically when funds allow." % b.outstanding_debt, WARN))
	var list := b.available_candidates()
	if list.is_empty():
		content.add_child(_label("No candidates available.", DIM))
	for c in list:
		var card := _card()
		var row := _row()
		card.add_child(row)
		var prof: Dictionary = b.profession(c["profession"])
		row.add_child(_label("%s  -  %s   Skill %d   $%.2f/h   Hiring fee $%d" % [c["name"], prof["title"], c["skill"], float(c["wage"]) * float(b.cfg.get("wage_scale", 1.0)), b.hire_fee(c)], INK))
		var reason := b.hire_block_reason(str(c["id"]))
		var cid := str(c["id"])
		row.add_child(_button("Hire" if reason == "" else reason, func(): _say(game.ui_hire(cid)), reason == ""))
		card.add_child(_label(_describe_profession(str(c["profession"])), DIM, QuarryTheme.BODY))

func _describe_profession(p: String) -> String:
	match p:
		"miner": return "Mines an assigned mineral at its deposits, picks up the pieces and carries them to the storage crate."
		"operator": return "Runs one crusher: loads the hopper into the machine, starts and monitors it, hands output to an attached output storage."
		"hauler": return "Carries materials along a chosen route (deposit pieces, storage, crusher, output storage) with limited capacity."
		"clerk": return "Sells the materials you authorize from the storage crate and output storages at the selling station."
	return ""

# ------------------------------------------------------------------ payroll

func _payroll(b: QuarryBusiness) -> void:
	var today := b.day_stats(b.current_day())
	var card := _card()
	card.add_child(_label("TODAY (DAY %d)" % (b.current_day() + 1), ACCENT))
	card.add_child(_label("Wages paid $%d   -   Hiring fees $%d   -   Training $%d   -   Clerk revenue $%d" % [today["wages"], today.get("hire_fees", 0), today.get("upgrades", 0), today["revenue"]]))
	card.add_child(_label("Unpaid wages currently owed: $%.2f" % b.unpaid_total(), WARN if b.unpaid_total() >= 1.0 else DIM))
	var staff := _card()
	staff.add_child(_label("STAFF COSTS", ACCENT))
	if b.employees.is_empty():
		staff.add_child(_label("No staff on payroll.", DIM))
	for e in b.employees:
		var s: Dictionary = e["stats"]
		var is_today: bool = int(s["day"]) == b.current_day()
		staff.add_child(_label("%s (%s): $%.2f/h x %.1f h shift = $%.2f per day  -  paid today $%d  -  owed $%.2f%s" % [
			e["name"], b.profession(e["profession"])["title"], b.wage(e), b.shift_hours(e), b.wage(e) * b.shift_hours(e),
			int(s["paid_today"]) if is_today else 0, float(e["owed"]), "  [UNPAID - STOPPED]" if bool(e["suspended"]) else ""], WARN if bool(e["suspended"]) else INK, 11))
	var hist := _card()
	hist.add_child(_label("LAST 7 DAYS", ACCENT))
	var keys: Array = b.daily.keys()
	keys.sort_custom(func(x, y): return int(x) > int(y))
	if keys.is_empty():
		hist.add_child(_label("No business activity recorded yet.", DIM))
	for k in keys:
		var d: Dictionary = b.daily[k]
		var labour := int(d["wages"]) + int(d.get("hire_fees", 0)) + int(d.get("upgrades", 0))
		hist.add_child(_label("Day %d:  labour $%d (wages $%d)   clerk revenue $%d   net $%d" % [int(k) + 1, labour, d["wages"], d["revenue"], int(d["revenue"]) - labour], INK, QuarryTheme.BODY))

# ------------------------------------------------------------------ production

func _production(b: QuarryBusiness) -> void:
	var today := b.day_stats(b.current_day())
	var card := _card()
	card.add_child(_label("TODAY'S PRODUCTION", ACCENT))
	card.add_child(_label("Mined by staff %d   -   Hauled %d   -   Conveyed %d   -   Crushed (automated) %d   -   Sold by clerk %d" % [today["mined"], today["hauled"], today["conveyed"], today["crushed"], today["sold"]]))
	var auth := _card()
	auth.add_child(_label("SALES CLERK MAY SELL", ACCENT))
	var row := _row()
	auth.add_child(row)
	for res in QuarryState.RESOURCE_NAMES:
		var cb := CheckBox.new()
		cb.text = "%s %d" % [game.prog.display(res), b.stock(res)]
		cb.button_pressed = b.authorized[res]
		var key: String = res
		cb.toggled.connect(func(on): b.authorized[key] = on)
		row.add_child(cb)
	var st := _card()
	st.add_child(_label("STRUCTURES", ACCENT))
	var held := []
	for res in QuarryState.RESOURCE_NAMES:
		if int(game.state.storage[res]) > 0:
			held.append("%s %d" % [game.prog.display(res), int(game.state.storage[res])])
	st.add_child(_label("Storage crate: %d/%d  %s" % [game.state.total(game.state.storage), game.state.storage_capacity(), ", ".join(held)], INK, QuarryTheme.BODY))
	for i in range(game.prog.rigs.size()):
		var r: Dictionary = game.prog.rigs[i]
		st.add_child(_label("%s #%d at %s: %s, %.0f/h, bin %d/%d" % [game.prog.machine(str(r["type"]))["title"], i + 1, game.prog.fdef(str(r["formation"]))["title"], r["status"], game.prog.rig_rate_per_hour(r), game.prog.rig_bin_total(r), game.prog.rig_bin_cap(r)], INK, QuarryTheme.BODY))
	for i in range(game.state.crushers.size()):
		var c: Dictionary = game.state.crushers[i]
		st.add_child(_label("Crusher #%d: hopper %d, input %d, output %d, %s" % [i + 1, c.get("hopper", 0), c["input"], c["output"], ("running %.0fs" % float(c["remaining"])) if c["running"] else "idle"], INK, QuarryTheme.BODY))
	for i in range(b.outputs.size()):
		st.add_child(_label("Output storage #%d: %d/%d crushed stone" % [i + 1, b.output_total(i), b.output_capacity()], INK, QuarryTheme.BODY))
	for i in range(b.conveyors.size()):
		var link: Dictionary = b.links[i] if i < b.links.size() else {"src": {}, "dst": {}}
		st.add_child(_label("Conveyor #%d: %s -> %s, carrying %d" % [i + 1, b.describe_ep(link["src"]), b.describe_ep(link["dst"]), b.conveyors[i]["items"]], INK, QuarryTheme.BODY))

# ------------------------------------------------------------------ milestones

func _milestones(b: QuarryBusiness) -> void:
	var prog: QuarryProgression = game.prog
	var sc := _card()
	sc.add_child(_label("QUARRY STAGES", ACCENT))
	for i in range(prog.stages().size()):
		var st := prog.stage_info(i)
		var done := i <= prog.stage
		sc.add_child(_label("%s %d. %s  -  %s" % ["[x]" if done else "[ ]", i + 1, str(st["title"]).to_upper(), str(st["goal"])], GOOD if done else (ACCENT if i == prog.stage + 1 else DIM), QuarryTheme.BODY))
		if i == prog.stage + 1:
			for r in prog.requirement_progress(i):
				sc.add_child(_label("      %s: %s" % [r[0], "done" if float(r[1]) >= float(r[2]) else "%d / %d" % [int(r[1] if not str(r[0]).begins_with("Clear") else float(r[1]) * 100.0), int(r[2] if not str(r[0]).begins_with("Clear") else float(r[2]) * 100.0)]], DIM, QuarryTheme.BODY))
	var dc := _card()
	dc.add_child(_label("DISCOVERIES", ACCENT))
	var any := false
	for did in prog.cfg.get("story", {}).get("discoveries", {}):
		if prog.story["found"].get(did, false):
			any = true
			dc.add_child(_label("%s  %s" % [str(prog.discovery(did)["title"]), "(read)" if prog.story["read"].get(did, false) else "(waiting where the rock stood - press E on it)"], INK, QuarryTheme.BODY))
	if not any:
		dc.add_child(_label("Nothing yet. Grandpa always said the good stuff is under the rock.", DIM, QuarryTheme.BODY))
	var jc := _card()
	jc.add_child(_label("WALTER'S JOURNAL", ACCENT))
	var entries: Array = prog.journal_entries()
	if entries.is_empty():
		jc.add_child(_label("Empty. Walter will write in it as the quarry grows.", DIM, QuarryTheme.BODY))
	for je in entries:
		jc.add_child(_label(str(je["title"]).to_upper(), GOOD, QuarryTheme.BODY))
		jc.add_child(_label(str(je["text"]), INK, QuarryTheme.BODY))
	var info := [
		["first_employee", "1. FIRST EMPLOYEE", "Hire your first worker.", "Remote management with M anywhere and +5% staff productivity."],
		["mechanized", "2. MECHANIZED QUARRY", "Own a crusher and employ a machine operator.", "Conveyor belts at the machinery kiosk and the Front Loader in EQUIPMENT."],
		["automated", "3. AUTOMATED BUSINESS", "Run an automated production chain: Miner -> Storage -> Hauler/Conveyor -> Crusher -> Output storage -> Sales clerk, until the clerk has sold %d crushed stone." % b.sales_goal(), "Opens the east quarry expansion (new deposits, rubble piles and building space) and the Dump Truck."],
	]
	for m in info:
		var card := _card()
		var done: bool = b.milestones[m[0]]
		card.add_child(_label(("[DONE] " if done else "[    ] ") + m[1], GOOD if done else ACCENT))
		card.add_child(_label(m[2], INK, QuarryTheme.BODY))
		card.add_child(_label("Reward: " + m[3], DIM, QuarryTheme.BODY))
		if m[0] == "automated" and not done:
			var names := {"mined": "Miner delivers ore to storage", "fed": "Limestone fed into a crusher by hauler or conveyor", "processed": "Operator completes a crushing run", "stored": "Crushed stone reaches an output storage automatically", "sold": "Clerk sells crushed stone"}
			for step in QuarryBusiness.CHAIN_STEPS:
				card.add_child(_label(("  [x] " if b.chain[step] else "  [ ] ") + names[step], GOOD if b.chain[step] else DIM, QuarryTheme.BODY))
			var sold_ok := b.auto_crushed_sold >= b.sales_goal()
			card.add_child(_label(("  [x] " if sold_ok else "  [ ] ") + "Clerk sales of crushed stone: %d / %d" % [mini(b.auto_crushed_sold, b.sales_goal()), b.sales_goal()], GOOD if sold_ok else DIM, QuarryTheme.BODY))

# ------------------------------------------------------------------ equipment (Phase 3)

func _equipment() -> void:
	var f: QuarryFleet = game.fleet
	content.add_child(_label("Heavy machinery is delivered to the equipment parking bays south of the yard. Walk up and press E to drive.", DIM))
	for type in QuarryFleet.TYPES:
		var spec: Dictionary = f.spec(type)
		var card := _card()
		var row := _row()
		card.add_child(row)
		var owned := 0
		for v in f.vehicles:
			if str(v["type"]) == type:
				owned += 1
		row.add_child(_label("%s   $%d   %s" % [spec["title"], spec["price"], ("owned: %d" % owned) if owned > 0 else ""], ACCENT))
		var reason: String = f.buy_block_reason(type)
		var t: String = type
		row.add_child(_button("Buy" if reason == "" else reason, func(): _say(game.ui_buy_vehicle(t)), reason == ""))
		var desc := "Scoops rubble piles and loose rock; dumps into the storage crate, crusher hoppers, output storage or a truck." if type == "loader" else "Hauls large loads from the loader to the storage crate, crusher hoppers or output storage. Bed tips to unload."
		card.add_child(_label(desc, DIM, QuarryTheme.BODY))
		for v in f.vehicles:
			if str(v["type"]) == type:
				var cargo := ""
				for k in v["cargo"]:
					cargo += " %s %d" % [str(k).replace("_", " "), v["cargo"][k]]
				card.add_child(_label("  #%d  load %d/%d%s   top speed %.1f m/s   acceleration %.1f m/s2" % [v["id"], f.cargo_total(v), f.capacity(v), cargo, f.max_speed(v), f.accel(v)], INK, QuarryTheme.BODY))
	var up := _card()
	up.add_child(_label("EQUIPMENT UPGRADES", ACCENT))
	for key in ["bucket", "cargo", "engine"]:
		var u: Dictionary = f.cfg["upgrades"][key]
		var row := _row()
		up.add_child(row)
		row.add_child(_label("%s ($%d): %s" % [u["title"], u["cost"], u["effect"]], INK, QuarryTheme.BODY))
		var reason: String = f.upgrade_block_reason(key)
		var k: String = key
		row.add_child(_button("Install" if reason == "" else reason, func(): _say(game.ui_vehicle_upgrade(k)), reason == ""))
	var piles := _card()
	piles.add_child(_label("RUBBLE PILES (regrow 1 unit every %d in-game minutes, max %d)" % [int(f.cfg["pile_regen_minutes"]), int(f.cfg["pile_max"])], ACCENT))
	for id in f.piles:
		if f.pile_active(id):
			piles.add_child(_label("%s: %d" % [f.cfg["piles"][id]["title"], f.piles[id]["amount"]], INK, QuarryTheme.BODY))
		else:
			piles.add_child(_label("%s: opens with the east expansion" % f.cfg["piles"][id]["title"], DIM, QuarryTheme.BODY))

# ------------------------------------------------------------------ Phase 5: upgrades and statistics

func _upgrades() -> void:
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	var tc := _card()
	tc.add_child(_label("MINING TOOLS", ACCENT))
	for i in range(prog.tools().size()):
		var t: Dictionary = prog.tools()[i]
		var row := _row()
		tc.add_child(row)
		var owned := i <= st.tool_tier
		row.add_child(_label("%s %s  -  %s" % ["[x]" if owned else "[ ]", str(t["title"]), str(t.get("desc", ""))], GOOD if i == st.tool_tier else (INK if owned else DIM), QuarryTheme.BODY))
		if i == st.tool_tier + 1:
			row.add_child(_button("Buy $%d  (+%d%%)" % [int(t["cost"]), prog.tool_gain_percent(st.tool_tier, i)], func(): game.buy_next_tool(); _say("Tool upgraded" if st.tool_tier >= i else "Need $%d" % int(t["cost"])), st.money >= int(t["cost"])))
	var uc := _card()
	uc.add_child(_label("PERSONAL UPGRADES", ACCENT))
	for key in game.UPGRADE_MENU:
		var info: Dictionary = prog.cfg.get("player_upgrades", {}).get(key, {})
		var row := _row()
		uc.add_child(row)
		row.add_child(_label("%s  -  %s" % [str(info.get("title", key)), str(info.get("effect", ""))], INK if not st.upgrades[key] else GOOD, QuarryTheme.BODY))
		var k: String = key
		if not st.upgrades[key]:
			row.add_child(_button("Buy $%d" % int(st.config["upgrades"][key]), func(): game.buy_player_upgrade(k); _say(""), st.money >= int(st.config["upgrades"][key])))
	var rc := _card()
	rc.add_child(_label("MINING MACHINES (order at the blue kiosk)", ACCENT))
	if prog.rigs.is_empty():
		rc.add_child(_label("No rigs yet. Drilling rigs unlock at the %s stage." % prog.feature_stage_title("drill_rig"), DIM, QuarryTheme.BODY))
	for i in range(prog.rigs.size()):
		var r: Dictionary = prog.rigs[i]
		var row := _row()
		rc.add_child(row)
		row.add_child(_label("%s #%d  Lv %d  @ %s  -  %s" % [prog.machine(str(r["type"]))["title"], i + 1, int(r["level"]) + 1, prog.fdef(str(r["formation"]))["title"], r["status"]], INK, QuarryTheme.BODY))
		var up := prog.rig_upgrade_info(r)
		var rr := r
		if not up.is_empty():
			row.add_child(_button("Upgrade $%d" % int(up["cost"]), func(): _say(str(up["effect"]) if prog.upgrade_rig(rr) else "Need $%d" % int(up["cost"])), st.money >= int(up["cost"])))
		row.add_child(_button("Turn off" if bool(r["on"]) else "Turn on", func(): rr["on"] = not bool(rr["on"]); _say("")))
	var ec := _card()
	ec.add_child(_label("DEEP EXCAVATION", ACCENT))
	if prog.level_unlocked >= 2:
		ec.add_child(_label("The lower level is open: copper vein and gold seam, reached by the ramp.", GOOD, QuarryTheme.BODY))
	else:
		var why := prog.permit_block_reason()
		var row := _row()
		ec.add_child(row)
		row.add_child(_label("Excavation permit: dig a 3.5 m lower level into the pit floor.", INK, QuarryTheme.BODY))
		row.add_child(_button("Buy $%d" % prog.permit_cost() if why == "" else why, func(): game.buy_permit(); _say("The lower level is open!"), why == ""))

func _stats(b: QuarryBusiness) -> void:
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	var c := _card()
	c.add_child(_label("BUSINESS", ACCENT))
	var vehicles: int = game.fleet.vehicles.size()
	c.add_child(_label("Lifetime sales %s   -   cash %s   -   day %d" % [QuarryTheme.money_text(st.earned), QuarryTheme.money_text(st.money), int(st.clock_minutes) / 1440 + 1], INK, QuarryTheme.BODY))
	c.add_child(_label("Staff %d   -   crushers %d   -   rigs %d   -   vehicles %d   -   tool: %s" % [b.employees.size(), st.crushers.size(), prog.rigs.size(), vehicles, prog.tool()["title"]], INK, QuarryTheme.BODY))
	var m := _card()
	m.add_child(_label("ROCK MINED (units)", ACCENT))
	m.add_child(_label("By hand %d   -   by staff %d   -   by rigs %d   -   chunks broken off %d" % [int(prog.stats["hand"]), int(prog.stats["crew"]), int(prog.stats["rigs"]), int(prog.stats["chunks"])], INK, QuarryTheme.BODY))
	var f := _card()
	f.add_child(_label("FORMATIONS", ACCENT))
	for id in prog.formation_ids():
		if not st.deposits.has(id):
			f.add_child(_label("%s  -  lower level (locked)" % prog.fdef(id)["title"], DIM, QuarryTheme.BODY))
			continue
		var left := prog.units_left(id)
		var total := prog.max_units(id)
		var frac := 1.0 - float(left) / float(maxi(1, total))
		var bar := ""
		for k in range(20):
			bar += "|" if float(k) / 20.0 < frac else "."
		f.add_child(_label("%-16s [%s] %3d%% excavated   %d / %d %s left" % [prog.fdef(id)["title"], bar, int(frac * 100.0), left, total, prog.display(str(prog.fdef(id)["resource"]))], GOOD if left <= 0 else INK, QuarryTheme.BODY))
