extends VBoxContainer
class_name QuarryOfferPane
## Phase 8.4 (revised): the preview pane inside a shop. You click an item in the list and its real model turns here, with the
## name, the price, the numbers that matter and how it compares with what you own; then you decide: BUY. Used by the workbench,
## the machinery orders and the office's equipment page, so every shop looks and works the same way.

signal bought(result)

var game
var preview: QuarryPreview
var holder: PanelContainer
var title_l: Label
var price_l: Label
var have_l: Label
var info: VBoxContainer
var buy_btn: Button
var offer: Dictionary = {}
var _model_key := ""
var _spec_json := ""

func setup(g) -> void:
	game = g
	add_theme_constant_override("separation", 5)
	custom_minimum_size = Vector2(290, 0)
	holder = PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.085, 0.065, 0.05, 0.98)
	cs.border_color = Color(0.42, 0.32, 0.21)
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(5)
	cs.anti_aliasing = true
	cs.set_content_margin_all(2)
	holder.add_theme_stylebox_override("panel", cs)
	holder.custom_minimum_size = Vector2(286, 226)
	add_child(holder)
	title_l = QuarryTheme.label("", QuarryTheme.HEAD, QuarryTheme.ACCENT, true)
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_l.custom_minimum_size = Vector2(280, 0)
	add_child(title_l)
	price_l = QuarryTheme.label("", QuarryTheme.HERO, QuarryTheme.MONEY, false, true)
	add_child(price_l)
	have_l = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.DIM)
	add_child(have_l)
	info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	add_child(info)
	buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 28)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.pressed.connect(func(): game.ui_click("offer_buy", _buy, buy_btn))
	add_child(buy_btn)

func _buy() -> void:
	var cb: Callable = offer.get("on_buy", Callable())
	if not cb.is_valid() or buy_btn.disabled:
		return
	var result = cb.call()
	bought.emit(result)

## Shows `o`. The model is only rebuilt when the thing being shown changes, so redrawing a menu never restarts the turntable.
func show_offer(key: String, o: Dictionary) -> void:
	offer = o
	var spec_json := JSON.stringify(o.get("model", {}))
	if preview == null or key != _model_key or spec_json != _spec_json:
		_set_preview(o.get("model", {}))
		_model_key = key
		_spec_json = spec_json
	title_l.text = str(o.get("title", "")).to_upper()
	var price := int(o.get("price", 0))
	var owned_only := bool(o.get("owned_only", false))
	price_l.text = "OWNED" if owned_only else "Price: %s" % QuarryTheme.money_text(price)
	var afford: bool = game.state.money >= price
	price_l.add_theme_color_override("font_color", QuarryTheme.GOOD if owned_only else (QuarryTheme.MONEY if afford else QuarryTheme.WARN))
	have_l.text = "You have %s" % QuarryTheme.money_text(game.state.money) + ("   You own %d" % int(o["owned"]) if int(o.get("owned", 0)) > 0 else "")
	for c in info.get_children():
		info.remove_child(c)
		c.queue_free()
	for s in o.get("stats", []):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var k := QuarryTheme.label(str(s[0]) + ":", QuarryTheme.SMALL, QuarryTheme.DIM)
		k.custom_minimum_size = Vector2(78, 0)
		line.add_child(k)
		var v := QuarryTheme.label(str(s[1]), QuarryTheme.SMALL, QuarryTheme.INK, false, true)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size = Vector2(190, 0)
		line.add_child(v)
		info.add_child(line)
	for c in o.get("compare", []):
		var tone := str(c[1])
		var cl := QuarryTheme.label(str(c[0]), QuarryTheme.SMALL, QuarryTheme.GOOD if tone == "good" else (QuarryTheme.WARN if tone == "bad" else QuarryTheme.DIM))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(276, 0)
		info.add_child(cl)
	var reason := str(o.get("reason", ""))
	if reason != "" and not owned_only:
		var rl := QuarryTheme.label(reason, QuarryTheme.SMALL, QuarryTheme.WARN, false, true)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(276, 0)
		info.add_child(rl)
	buy_btn.text = "OWNED" if owned_only else str(o.get("buy_text", "BUY  %s" % QuarryTheme.money_text(price)))
	buy_btn.disabled = reason != "" or owned_only

func _set_preview(spec: Dictionary) -> void:
	if preview:
		preview.stop()
		holder.remove_child(preview)
		preview.queue_free()
		preview = null
	preview = QuarryPreview.new()
	preview.custom_minimum_size = Vector2(280, 220)
	holder.add_child(preview)
	preview.setup(game, spec)

## The shop closed: stop rendering (the preview keeps its model but draws nothing).
func pause() -> void:
	if preview:
		preview.stop()

func resume() -> void:
	if preview and preview.viewport:
		preview.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview.set_process(true)
