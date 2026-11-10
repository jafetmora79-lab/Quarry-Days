extends Control
## Office management interface. Mouse driven; the world is paused while it is open.
## Sized for the 960x540 base canvas, which scales cleanly to 1280x720 and 1920x1080.

const TABS := [["staff", "STAFF"], ["hire", "HIRE"], ["payroll", "PAYROLL"], ["production", "PRODUCTION"], ["milestones", "MILESTONES"]]
const INK := Color(0.93, 0.88, 0.74)
const DIM := Color(0.62, 0.58, 0.48)
const ACCENT := Color(0.95, 0.74, 0.30)
const WARN := Color(1.0, 0.45, 0.35)
const GOOD := Color(0.55, 0.85, 0.45)

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
	header = _label("", ACCENT, 14)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	var close := Button.new()
	close.text = "CLOSE [Esc]"
	close.pressed.connect(func(): game._close_menu())
	top.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(104, 0)
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
	status = _label("", GOOD, 12)
	root.add_child(status)

func _make_theme() -> Theme:
	var t := Theme.new()
	var font: Font = ThemeDB.fallback_font
	if font is FontFile:
		var pixel: FontFile = font.duplicate()
		pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		pixel.hinting = TextServer.HINTING_NONE
		pixel.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		t.default_font = pixel
	t.default_font_size = 12
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.07, 0.065, 0.055, 0.97), Color(0.62, 0.50, 0.28), 2, 10))
	t.set_stylebox("normal", "Button", _box(Color(0.16, 0.14, 0.11), Color(0.45, 0.38, 0.24), 1, 4))
	t.set_stylebox("hover", "Button", _box(Color(0.25, 0.21, 0.14), Color(0.75, 0.6, 0.3), 1, 4))
	t.set_stylebox("pressed", "Button", _box(Color(0.40, 0.30, 0.13), Color(0.95, 0.74, 0.3), 1, 4))
	t.set_stylebox("hover_pressed", "Button", _box(Color(0.40, 0.30, 0.13), Color(0.95, 0.74, 0.3), 1, 4))
	t.set_stylebox("disabled", "Button", _box(Color(0.10, 0.10, 0.09), Color(0.25, 0.23, 0.2), 1, 4))
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
	b.set_corner_radius_all(0)
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
	b.pressed.connect(action)
	return b

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	return h

func _card() -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.11, 0.10, 0.085), Color(0.30, 0.26, 0.18), 1, 6))
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
	header.text = "QUARRY OFFICE   DAY %d  %s   $%d   STAFF %d/%d" % [clock / 1440 + 1, game.fmt_time(clock), game.state.money, b.employees.size(), b.max_employees()]
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
		"milestones": _milestones(b)

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
		var title := _label("%s  -  %s   Skill %d   $%.2f/h   Training %d/3" % [e["name"], b.profession(e["profession"])["title"], e["skill"], b.wage(e), e["upgrade"]], ACCENT, 12)
		top.add_child(title)
		var task := _label(str(e["task"]), INK if b.can_work(e) else DIM, 11)
		task.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(task)
		var assign := _row()
		card.add_child(assign)
		_assignment_controls(b, e, assign)
		var line := _row()
		card.add_child(line)
		line.add_child(_label("Shift", DIM, 12, false))
		line.add_child(_button("-", func(): _say(game.ui_shift(id, int(e["shift_start"]) - 30, int(e["shift_end"])))))
		line.add_child(_label(game.fmt_time(int(e["shift_start"])), INK, 12, false))
		line.add_child(_button("+", func(): _say(game.ui_shift(id, int(e["shift_start"]) + 30, int(e["shift_end"])))))
		line.add_child(_label("to", DIM, 12, false))
		line.add_child(_button("-", func(): _say(game.ui_shift(id, int(e["shift_start"]), int(e["shift_end"]) - 30))))
		line.add_child(_label(game.fmt_time(int(e["shift_end"])), INK, 12, false))
		line.add_child(_button("+", func(): _say(game.ui_shift(id, int(e["shift_start"]), int(e["shift_end"]) + 30))))
		line.add_child(_label("(%.1f h)" % b.shift_hours(e), DIM, 11, false))
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
			card.add_child(_label("! " + str(e["warning"]), WARN, 12))

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
			row.add_child(_label("Mine:", DIM, 12, false))
			var opts := []
			for r in QuarryBusiness.MINERALS:
				opts.append([r.replace("_", " ").capitalize() + " deposits", {"resource": r}])
			row.add_child(_option(opts, a, func(v): _say(game.ui_assign(id, v))))
			row.add_child(_label("-> delivers to Storage crate", DIM, 11))
		"operator":
			row.add_child(_label("Operate:", DIM, 12, false))
			var opts := []
			for i in range(game.state.crushers.size()):
				opts.append(["Crusher #%d" % (i + 1), {"crusher": i}])
			if opts.is_empty():
				row.add_child(_label("No crusher placed yet - order one at the blue kiosk.", WARN, 11))
			else:
				row.add_child(_option(opts, a, func(v): _say(game.ui_assign(id, v))))
				var out: int = b.crusher_outputs[int(a.get("crusher", 0))] if int(a.get("crusher", 0)) < b.crusher_outputs.size() else -1
				row.add_child(_label("-> output %s" % ("to Output storage #%d" % (out + 1) if out >= 0 else "stays in crusher (place output storage at the chute)"), DIM, 11))
		"hauler":
			var srcs := [["Storage crate", {"type": "storage"}]]
			for r in QuarryBusiness.MINERALS:
				srcs.append(["Loose " + r.replace("_", " "), {"type": "deposit", "resource": r}])
			for i in range(game.state.crushers.size()):
				srcs.append(["Crusher #%d output" % (i + 1), {"type": "crusher", "index": i}])
			for i in range(b.outputs.size()):
				srcs.append(["Output storage #%d" % (i + 1), {"type": "output", "index": i}])
			var dsts := [["Storage crate", {"type": "storage"}]]
			for i in range(game.state.crushers.size()):
				dsts.append(["Crusher #%d hopper" % (i + 1), {"type": "crusher", "index": i}])
			for i in range(b.outputs.size()):
				dsts.append(["Output storage #%d" % (i + 1), {"type": "output", "index": i}])
			row.add_child(_label("From:", DIM, 12, false))
			row.add_child(_option(srcs, a.get("src", {}), func(v): _set_route(b, id, v, a.get("dst", {}), dsts)))
			row.add_child(_label("To:", DIM, 12, false))
			row.add_child(_option(dsts, a.get("dst", {}), func(v): _set_route(b, id, a.get("src", {}), v, dsts)))
			var res := b.route_resource(a.get("src", {}), a.get("dst", {}))
			row.add_child(_label(("carries " + res.replace("_", " ")) if res != "" else "invalid route", DIM if res != "" else WARN, 11))
		"clerk":
			row.add_child(_label("Works at the selling station. Choose what may be sold in PRODUCTION.", DIM, 11))

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
		row.add_child(_label("%s  -  %s   Skill %d   $%.2f/h   Hiring fee $%d" % [c["name"], prof["title"], c["skill"], c["wage"], c["hire_fee"]], INK))
		var reason := b.hire_block_reason(str(c["id"]))
		var cid := str(c["id"])
		row.add_child(_button("Hire" if reason == "" else reason, func(): _say(game.ui_hire(cid)), reason == ""))
		card.add_child(_label(_describe_profession(str(c["profession"])), DIM, 11))

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
		hist.add_child(_label("Day %d:  labour $%d (wages $%d)   clerk revenue $%d   net $%d" % [int(k) + 1, labour, d["wages"], d["revenue"], int(d["revenue"]) - labour], INK, 11))

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
	for res in ["limestone", "coal", "iron_ore", "crushed_stone"]:
		var cb := CheckBox.new()
		cb.text = "%s (stock %d)" % [res.replace("_", " ").capitalize(), b.stock(res)]
		cb.button_pressed = b.authorized[res]
		var key: String = res
		cb.toggled.connect(func(on): b.authorized[key] = on)
		row.add_child(cb)
	var st := _card()
	st.add_child(_label("STRUCTURES", ACCENT))
	st.add_child(_label("Storage crate: %d/%d  (limestone %d, coal %d, iron %d, crushed %d)" % [game.state.total(game.state.storage), game.state.storage_capacity(), game.state.storage["limestone"], game.state.storage["coal"], game.state.storage["iron_ore"], game.state.storage["crushed_stone"]], INK, 11))
	for i in range(game.state.crushers.size()):
		var c: Dictionary = game.state.crushers[i]
		st.add_child(_label("Crusher #%d: hopper %d, input %d, output %d, %s" % [i + 1, c.get("hopper", 0), c["input"], c["output"], ("running %.0fs" % float(c["remaining"])) if c["running"] else "idle"], INK, 11))
	for i in range(b.outputs.size()):
		st.add_child(_label("Output storage #%d: %d/%d crushed stone" % [i + 1, b.output_total(i), b.output_capacity()], INK, 11))
	for i in range(b.conveyors.size()):
		var link: Dictionary = b.links[i] if i < b.links.size() else {"src": {}, "dst": {}}
		st.add_child(_label("Conveyor #%d: %s -> %s, carrying %d" % [i + 1, b.describe_ep(link["src"]), b.describe_ep(link["dst"]), b.conveyors[i]["items"]], INK, 11))

# ------------------------------------------------------------------ milestones

func _milestones(b: QuarryBusiness) -> void:
	var info := [
		["first_employee", "1. FIRST EMPLOYEE", "Hire your first worker.", "Remote management with M anywhere and +5% staff productivity."],
		["mechanized", "2. MECHANIZED QUARRY", "Own a crusher and employ a machine operator.", "Conveyor belts become available at the machinery kiosk."],
		["automated", "3. AUTOMATED BUSINESS", "Complete one automated production chain: Miner -> Storage -> Hauler/Conveyor -> Crusher -> Output storage -> Sales clerk.", "Opens the east quarry expansion with new limestone, coal and iron deposits."],
	]
	for m in info:
		var card := _card()
		var done: bool = b.milestones[m[0]]
		card.add_child(_label(("[DONE] " if done else "[    ] ") + m[1], GOOD if done else ACCENT))
		card.add_child(_label(m[2], INK, 11))
		card.add_child(_label("Reward: " + m[3], DIM, 11))
		if m[0] == "automated" and not done:
			var names := {"mined": "Miner delivers ore to storage", "fed": "Limestone fed into a crusher by hauler or conveyor", "processed": "Operator completes a crushing run", "stored": "Crushed stone reaches an output storage automatically", "sold": "Clerk sells crushed stone"}
			for step in QuarryBusiness.CHAIN_STEPS:
				card.add_child(_label(("  [x] " if b.chain[step] else "  [ ] ") + names[step], GOOD if b.chain[step] else DIM, 11))
