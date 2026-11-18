extends Node
class_name QuarryItemTips
## "What is this for?" cards. The first time the player gets an item (a starter tool after the opening, a bought tool or hauling aid, a vehicle, a machine) a small card appears with a
## picture of the real 3D model, what it does and how to use it. Shown once per item (the story flag "tips" is saved), one at a time, only when nothing else is going on; E / Enter /
## Space / click closes it. Off in headless runs (the tests) unless `enabled` is set.

var game
var enabled := DisplayServer.get_name() != "headless"
var queue: Array = []
var panel: PanelContainer
var current := ""
var picture: TextureRect
var picture_key := ""

const VEHICLE_TEXT := {
	"excavator": ["Digs soil and rock out of the ground and swings it into a truck.", "Climb in with E. Mouse turns the cab, left click digs, right click tips the bucket out over a truck."],
	"loader": ["Scoops loose material and carries it to a truck, hopper or crusher.", "Drive up to a pile, scoop, drive to the truck and tip the bucket."],
	"truck": ["Hauls what the diggers load: park it beside the digger and it fills the bed, then drive it to the sell yard or the crusher.", "Keep the bed over a ramp-free road: loaded trucks are slow on slopes."],
	"bulldozer": ["Pushes soil and rubble into heaps and clears the ground in front of it.", "Drive forward with the blade down to shove loose ground where you want it."]}
const MACHINE_TEXT := {
	"crusher": ["Breaks rock into crushed stone you can sell.", "Place it near the cut and feed its hopper with a loader or by hand."],
	"hopper": ["Takes loose rock from loaders and trucks and feeds it down a belt or into a crusher.", "Tip your bucket into it."],
	"sorter": ["A manual sorting table: pick the good stone from the rubble.", "Stand at it and sort what comes in."],
	"cash_hopper": ["Another selling point: it sells whatever it is fed, one unit at a time, and can be upgraded twice.", "Place it where a belt line ends, or tip a bucket into it."],
	"output": ["Stores finished product until you sell it.", "Place it at the end of a crusher's chute."],
	"advanced_crusher": ["A bigger crusher that takes more rock and breaks it finer.", "Feed it like the small one, with a hopper in front."],
	"conveyor": ["Belts carry material between machines so nobody has to carry it by hand.", "Place pieces end to end from the hopper to the crusher and on to storage."]}

func setup(g) -> void:
	game = g
	name = "ItemTips"
	game.add_child(self)

func seen(id: String) -> bool:
	return bool(game.prog.story.get("tips", {}).get(id, false))

## Queues the card for `id` ("tool:0", "gear:shovel", "vehicle:truck", "machine:crusher", "rig:drill") unless it has been shown before.
func offer(id: String) -> void:
	if not enabled or game == null or seen(id) or queue.has(id) or current == id:
		return
	queue.append(id)

## What the card says: {title, text, how, model: {kind, ...}} for an id.
func info(id: String) -> Dictionary:
	var parts := id.split(":")
	var kind := parts[0]
	var key: String = parts[1] if parts.size() > 1 else ""
	var prog = game.prog
	match kind:
		"tool":
			var t: Dictionary = prog.tool(int(key))
			return {"title": str(t.get("title", "Tool")), "text": str(t.get("desc", "")), "how": "Left click swings it at whatever you aim at. Number keys change tools.", "model": {"kind": "tool", "tier": int(key)}}
		"gear":
			var g: Dictionary = prog.gear_def(key)
			var gk := str(g.get("kind", "tool"))
			var how := "Number keys change tools. Left click uses it."
			if key == "ramp_plan":
				how = "Aim at the floor of an excavation and face uphill: left click builds the ramp, right click takes it away."
			elif key == "shovel":
				how = "Left click digs loose ground: topsoil, soil and gravel. Rock needs a hammer or a pick."
			elif gk == "cart":
				how = "Nothing to hold: your bag simply carries more while you own it."
			elif gk == "equipment":
				how = "Keep it and your powered tools work faster."
			return {"title": str(g.get("title", key)), "text": str(g.get("desc", "")), "how": how, "model": {"kind": "ramp"} if key == "ramp_plan" else ({"kind": "gear_tool", "id": key} if gk == "tool" else {"kind": "gear", "id": key})}
		"vehicle":
			var sp: Dictionary = game.fleet.spec(key)
			var vk: String = game.fleet.kind(key)
			var vt: Array = VEHICLE_TEXT.get(vk, ["A new machine for the garage.", "Climb in with E."])
			return {"title": str(sp.get("title", key)), "text": str(vt[0]), "how": str(vt[1]), "model": {"kind": "vehicle", "type": key}}
		"machine":
			var mt: Array = MACHINE_TEXT.get(key, ["A new machine for the plant.", "Place it from the order screen or in construction mode."])
			var titles := {"crusher": "Small jaw crusher", "hopper": "Small hopper", "cash_hopper": "Cash Hopper", "sorter": "Manual sorting table", "output": "Output storage", "advanced_crusher": "Advanced crusher", "conveyor": "Conveyor"}
			return {"title": str(titles.get(key, key)), "text": str(mt[0]), "how": str(mt[1]), "model": {"kind": "machine", "id": key}}
		"companion":
			var nm := str(prog.companion().get("name", "Your dinosaur"))
			var texts := {"hatchling": ["%s, a baby ankylosaur, follows you around the quarry and sleeps on its straw bed at night." % nm, "It is too small to break rock yet. Give it a few days: its tail club grows in."],
				"juvenile": ["%s's tail club has grown in: it can smash soft rock now." % nm, "Look at exposed rock or rubble and press T: it walks up, turns its flank and swings its tail. Press T again to call it off."],
				"adult": ["%s is fully grown: its club can break hard rock and clear rubble heaps." % nm, "Same as before: look at the rock and press T. It follows the same hardness rules as your tools."]}
			var ct: Array = texts.get(key, texts["hatchling"])
			return {"title": nm, "text": str(ct[0]), "how": str(ct[1]), "model": {"kind": "companion", "stage": key}}
		"rig":
			var md: Dictionary = prog.machine(key)
			return {"title": str(md.get("title", key)), "text": "A drilling rig that cuts the rock for you at the face you set it on.", "how": "Place it on the bench and feed it while it works.", "model": {"kind": "rig", "type": key}}
	return {}

func _process(_delta: float) -> void:
	if panel != null or queue.is_empty() or not enabled or game == null:
		return
	if game.player_free_for_intro() and not game.walter_intro_running and game.walter_dialog == null:
		_show(str(queue.pop_front()))

func _build_model(m: Dictionary) -> Node3D:
	match str(m.get("kind", "")):
		"tool":
			return ToolModels.load_tool(ToolModels.key_of(int(m.get("tier", 0))))
		"gear_tool":
			return ToolModels.load_tool(str(m["id"]))
		"ramp":
			return QuarryHotbar.ramp_miniature()
		"companion":
			var dc := QuarryCompanion.new()
			dc.setup(game, str(m.get("stage", "adult")))
			dc.rotation.y = PI * 0.8
			return dc
		"gear":
			return QuarryPreview.build_model(game, {"kind": "gear", "id": str(m["id"])})
		"machine":
			var mk := str(m["id"])
			if mk.begins_with("conveyor"):
				mk = "conveyor"
			elif mk == "advanced_crusher":
				mk = "crusher"
			return QuarryPreview.build_model(game, {"kind": mk, "tier": 2 if str(m["id"]) == "advanced_crusher" else 1})
		"vehicle", "rig":
			return QuarryPreview.build_model(game, m)
	return null

func _show(id: String) -> void:
	var d := info(id)
	if d.is_empty():
		return
	current = id
	if not game.prog.story.has("tips"):
		game.prog.story["tips"] = {}
	game.prog.story["tips"][id] = true
	panel = PanelContainer.new()
	panel.name = "ItemTip"
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiSkin.box("frame_dialog", QuarryTheme.panel_box(QuarryTheme.BG, QuarryTheme.ACCENT, 12, 4), [22, 18, 22, 18]))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)
	var frame := PanelContainer.new()
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.08, 0.065, 0.05, 0.95)
	fb.border_color = Color(0.7, 0.51, 0.27, 0.9)
	fb.set_border_width_all(1)
	fb.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fb)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(150, 150)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(picture)
	hb.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var head := QuarryTheme.label("NEW  -  " + str(d["title"]).to_upper(), 12, QuarryTheme.ACCENT, true)
	v.add_child(head)
	var body := QuarryTheme.label(str(d["text"]), QuarryTheme.DIALOG)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(340, 0)
	v.add_child(body)
	var how := QuarryTheme.label(str(d["how"]), QuarryTheme.BODY, QuarryTheme.DIM)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(340, 0)
	v.add_child(how)
	var ok := Button.new()
	ok.text = "Got it  [E]"
	ok.pressed.connect(_close)
	v.add_child(ok)
	game.ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.offset_top -= 30.0
	panel.offset_bottom -= 30.0
	game.player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	picture_key = "tip:" + id
	var th: ItemThumbs = game.hud.thumbs if game.hud != null else null
	if th != null:
		if not th.ready_key.is_connected(_on_ready):
			th.ready_key.connect(_on_ready)
		var model: Dictionary = d["model"]
		var tex: Texture2D = th.get_thumb(picture_key, func(): return _build_model(model), "view" if str(model.get("kind", "")) in ["vehicle", "rig", "gear", "machine", "companion"] else "tool", 160)
		if tex != null:
			picture.texture = tex

func _on_ready(k: String) -> void:
	if k == picture_key and panel != null and is_instance_valid(panel):
		var th: ItemThumbs = game.hud.thumbs
		picture.texture = th.cache.get(k)

func _close() -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	current = ""
	game.player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_key_input(event: InputEvent) -> void:
	if panel == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_close()
		get_viewport().set_input_as_handled()
