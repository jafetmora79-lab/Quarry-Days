extends Control
class_name QuarryPurchaseDialog
## Phase 8.4: the purchase window. The real model turns slowly on the left; on the right the name, the price, the numbers that
## matter, how it compares with what you own, and BUY / CANCEL. Clicking outside, Esc or CANCEL leaves without spending anything.

signal confirmed(result)
signal cancelled

var game
var offer: Dictionary = {}
var preview: QuarryPreview
var plate: QuarryPlate
var buy_btn: Button
var cancel_btn: Button
var price_label: Label
var closing := false

func setup(g, o: Dictionary) -> void:
	game = g
	offer = o
	name = "PurchaseDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	plate = QuarryPlate.new(14, QuarryTheme.ACCENT)
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(plate)
	plate.set_anchors_preset(Control.PRESET_CENTER)
	plate.custom_minimum_size = Vector2(660, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)
	# left: the turning model on a dark card
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.09, 0.07, 0.055, 0.98)
	cs.border_color = Color(0.4, 0.3, 0.2)
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(5)
	cs.anti_aliasing = true
	cs.set_content_margin_all(2)
	card.add_theme_stylebox_override("panel", cs)
	left.add_child(card)
	preview = QuarryPreview.new()
	preview.custom_minimum_size = Vector2(270, 230)
	card.add_child(preview)
	preview.setup(game, offer.get("model", {}))
	# right: the facts
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var title := QuarryTheme.label(str(offer.get("title", "")).to_upper(), QuarryTheme.HEAD, QuarryTheme.ACCENT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(300, 0)
	right.add_child(title)
	var price := int(offer.get("price", 0))
	var afford: bool = game.state.money >= price
	price_label = QuarryTheme.label("Price: %s" % QuarryTheme.money_text(price), QuarryTheme.HERO, QuarryTheme.MONEY if afford else QuarryTheme.WARN, false, true)
	right.add_child(price_label)
	right.add_child(QuarryTheme.label("You have %s" % QuarryTheme.money_text(game.state.money), QuarryTheme.SMALL, QuarryTheme.DIM))
	if int(offer.get("owned", 0)) > 0:
		right.add_child(QuarryTheme.label("You own %d" % int(offer["owned"]), QuarryTheme.SMALL, QuarryTheme.DIM))
	for s in offer.get("stats", []):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var k := QuarryTheme.label(str(s[0]) + ":", QuarryTheme.BODY, QuarryTheme.DIM)
		k.custom_minimum_size = Vector2(92, 0)
		line.add_child(k)
		var v := QuarryTheme.label(str(s[1]), QuarryTheme.BODY, QuarryTheme.INK, false, true)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size = Vector2(190, 0)
		line.add_child(v)
		right.add_child(line)
	for c in offer.get("compare", []):
		var tone := str(c[1])
		var col := QuarryTheme.GOOD if tone == "good" else (QuarryTheme.WARN if tone == "bad" else QuarryTheme.DIM)
		var cl := QuarryTheme.label(str(c[0]), QuarryTheme.BODY, col)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(290, 0)
		right.add_child(cl)
	var reason := str(offer.get("reason", ""))
	if reason != "":
		var rl := QuarryTheme.label(reason, QuarryTheme.BODY, QuarryTheme.WARN, false, true)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(290, 0)
		right.add_child(rl)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	buy_btn = Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(120, 26)
	buy_btn.disabled = reason != ""
	buy_btn.pressed.connect(_buy)
	buttons.add_child(buy_btn)
	cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(120, 26)
	cancel_btn.pressed.connect(close_cancelled)
	buttons.add_child(cancel_btn)
	modulate.a = 0.0
	plate.scale = Vector2(0.94, 0.94)
	plate.pivot_offset = plate.custom_minimum_size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(plate, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not plate.get_global_rect().has_point(event.global_position):
		close_cancelled()
		accept_event()

func _input(event: InputEvent) -> void:
	if closing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_cancelled()

func _buy() -> void:
	if closing or buy_btn.disabled:
		return
	var cb: Callable = offer.get("on_buy", Callable())
	var result = cb.call() if cb.is_valid() else null
	_finish(true, result)

func close_cancelled() -> void:
	if closing:
		return
	_finish(false, null)

func _finish(bought: bool, result) -> void:
	closing = true
	if preview:
		preview.stop()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_property(plate, "scale", Vector2(1.05, 1.05) if bought else Vector2(0.96, 0.96), 0.14)
	tw.chain().tween_callback(queue_free)
	if bought:
		confirmed.emit(result)
	else:
		cancelled.emit()
