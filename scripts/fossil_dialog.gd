extends PanelContainer
class_name QuarryFossilDialog
## Phase 7.6: the choice about the fossil. Two buyers, one answer, no taking it back: picking one asks for a second,
## explicit confirmation. "Not yet" closes the panel and leaves the choice open.

signal chosen(who: String)
signal cancelled

var cfg: Dictionary = {}
var body: Label
var title: Label
var buttons: VBoxContainer
var pending := ""

func setup(fossil_cfg: Dictionary) -> void:
	cfg = fossil_cfg
	name = "FossilDialog"
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(640, 0)
	add_theme_stylebox_override("panel", QuarryTheme.panel_box(QuarryTheme.BG, QuarryTheme.ACCENT, 14, 4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	title = QuarryTheme.label("", 12, QuarryTheme.ACCENT, true)
	v.add_child(title)
	body = QuarryTheme.label("", QuarryTheme.BODY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(600, 0)
	v.add_child(body)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	v.add_child(buttons)
	_show_options()

func _clear() -> void:
	for c in buttons.get_children():
		c.queue_free()

func _add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	buttons.add_child(b)
	return b

func _show_options() -> void:
	pending = ""
	_clear()
	title.text = "WHAT WILL YOU DO WITH THE FOSSIL?"
	var txt := ""
	for who in ["collector", "scientist"]:
		var b: Dictionary = cfg["buyers"][who]
		txt += "%s - %s\n%s\n\n" % [str(b["who"]).to_upper(), QuarryTheme.money_text(int(b["price"])), str(b["pitch"])]
	body.text = txt.strip_edges()
	for who in ["collector", "scientist"]:
		var b: Dictionary = cfg["buyers"][who]
		_add_button("%s  (%s)" % [str(b["title"]), QuarryTheme.money_text(int(b["price"]))], func(): _ask(who))
	_add_button("Not yet", func(): cancelled.emit())

func _ask(who: String) -> void:
	pending = who
	_clear()
	var b: Dictionary = cfg["buyers"][who]
	title.text = "ARE YOU SURE?"
	body.text = "%s: %s for %s.\n\n%s" % [str(b["who"]), str(b["title"]).to_lower(), QuarryTheme.money_text(int(b["price"])), str(cfg.get("confirm", "This cannot be undone."))]
	_add_button("Yes, I am sure", func(): chosen.emit(who))
	_add_button("Go back", func(): _show_options())
