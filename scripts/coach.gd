extends Node
class_name QuarryCoach
## The first-visit guide. The first time the player walks through the quarry gate a short fly-over crosses the overburden from left to right (what lies on the rock and why it has to
## go first); after that a small panel walks them through the first loop, one step at a time, driven by what they really do:
##   clear -> hit a stone heap (hammer for rock, shovel for weeds) -> pick the stones up -> put them in a bucket -> carry it to the Cash Hopper -> tip it in -> done.
## Progress is kept in prog.story["coach"], so it never repeats; a save from before it existed counts as done when the site is already clean or the hopper has been used.

const FLY_SECONDS := 13.0
const GATE_Z := -9.5                    ## north of the yard fence: inside the quarry
const STEPS := ["clear", "stone", "bucket", "carry", "hopper"]

var game
var fly_cam: Camera3D
var _fly_t := -1.0
var _layer: CanvasLayer
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _caption: Label
var _skip: Label
var _panel: PanelContainer
var _p_title: Label
var _p_body: Label
var _p_key: Label
var _beacon: MeshInstance3D
var _tick := 0.0
var _lines: Array = []                  ## [t_from, t_to, text] of the fly-over
var _shown_step := ""
var _carry_seen := false
var _ui_was := true

func setup(g) -> void:
	game = g
	name = "QuarryCoach"
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	_bar_top = _bar(true)
	_bar_bot = _bar(false)
	_caption = QuarryTheme.label("", QuarryTheme.TITLE, QuarryTheme.INK, true, false, true)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -84.0
	_caption.offset_bottom = -6.0
	_caption.offset_left = 120.0
	_caption.offset_right = -120.0
	_caption.visible = false
	_layer.add_child(_caption)
	_skip = QuarryTheme.label("SPACE  skip", QuarryTheme.SMALL, QuarryTheme.DIM)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -170.0
	_skip.offset_bottom = -86.0
	_skip.offset_top = -100.0
	_skip.offset_right = -18.0
	_skip.visible = false
	_layer.add_child(_skip)
	_build_panel()

func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.03, 1.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	r.custom_minimum_size = Vector2(0, 0)
	r.size = Vector2(0, 0)
	r.visible = false
	_layer.add_child(r)
	return r

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UiSkin.box("plate_prompt", QuarryTheme.panel_box(), [14, 9, 14, 10]))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)             # under the objectives plate, never in the middle where the cards, toasts and banners are
	_panel.offset_left = 14.0
	_panel.offset_top = 124.0
	_panel.custom_minimum_size = Vector2(290, 0)
	_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_p_key = QuarryTheme.label("", QuarryTheme.SMALL, QuarryTheme.ACCENT, true)
	_p_title = QuarryTheme.label("", QuarryTheme.HEAD, QuarryTheme.INK, true)
	_p_body = QuarryTheme.label("", QuarryTheme.BODY, QuarryTheme.DIM)
	_p_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p_body.custom_minimum_size = Vector2(262, 0)
	v.add_child(_p_key)
	v.add_child(_p_title)
	v.add_child(_p_body)
	_panel.add_child(v)
	_layer.add_child(_panel)

# ------------------------------------------------------------------ state

func _data() -> Dictionary:
	if not game.prog.story.has("coach") or not game.prog.story["coach"] is Dictionary:
		game.prog.story["coach"] = {"flyover": false, "done": []}
	return game.prog.story["coach"]

func _done(step: String) -> bool:
	return step in (_data().get("done", []) as Array)

func _mark(step: String) -> void:
	var d := _data()
	if not step in d["done"]:
		(d["done"] as Array).append(step)

func finished() -> bool:
	return _done("hopper")

func flying() -> bool:
	return _fly_t >= 0.0

## Hooks from the game: "stone_hit" (a swing landed on a rubble heap), "hopper_tipped" (a bucket went into the Cash Hopper).
func event(what: String, extra = null) -> void:
	if game == null or finished():
		return
	match what:
		"stone_hit":
			if not _done("clear"):
				_mark("clear")
				var hammer := str(game.prog.tool().get("class", "")) != "digging"
				game.hud.show_card("THE RIGHT TOOL", ("Good: that is a hammer, the best tool for rock. Every heap breaks into stones that drop at your feet.\n\nKeep the shovel (1) for the weeds and loose soil. Against stone it barely scratches." if hammer else "A shovel barely dents stone. Take out the hammer (press 2): it is the best tool for rock.\n\nEvery heap breaks into stones that drop at your feet. Keep the shovel (1) for weeds and loose soil."))
		"hopper_tipped":
			_mark("clear")
			_mark("stone")
			_mark("bucket")
			_mark("carry")
			_mark("hopper")
			_panel.visible = false
			_set_beacon(false)
			game.hud.toast("THAT IS THE LOOP", "Clear the ground, collect the stone, sell it. The hopper pays as it works. The rest of the quarry is yours.", "milestone")

# ------------------------------------------------------------------ the fly-over

func _can_start_fly() -> bool:
	if game.player == null or game.driving != null or game.menu != "" or game.sleeping:
		return false
	if not bool(game.prog.story.get("intro_seen", false)) or game.opening_scene != null and is_instance_valid(game.opening_scene) and not bool(game.prog.story.get("intro_seen", false)):
		return false
	if game.est_running or game.player.locked or game._conversation_active() or game.hud.card_open():
		return false
	if not game.prog.cleanup_active() or not game.prog.filled_world():
		return false
	return game.player.global_position.z < GATE_Z and absf(game.player.global_position.x) < 30.0

func _start_fly() -> void:
	_data()["flyover"] = true
	_fly_t = 0.0
	game.player.locked = true
	fly_cam = Camera3D.new()
	fly_cam.far = 700.0
	fly_cam.fov = 62.0
	game.world.add_child(fly_cam)
	fly_cam.global_position = Vector3(-30.0, 8.0, -3.0)
	fly_cam.current = true
	for b in [_bar_top, _bar_bot]:
		b.visible = true
	_caption.visible = true
	_skip.visible = true
	_lines = [
		[0.4, 3.6, "GRANDPA WALT'S QUARRY"],
		[3.9, 8.0, "Before you can cut any rock, the ground has to be cleared. Weeds, loose earth and heaps of broken stone lie over the rock."],
		[8.3, 12.6, "The red outlines show what is left. Clear it first: then the stone below is yours."],
	]
	_panel.visible = false
	_ui_was = game.ui.visible
	game.ui.visible = false                                  # a clean picture: no HUD during the fly-over
	_show_character(true)

func _fly_process(delta: float) -> void:
	_fly_t += delta
	var k := clampf(_fly_t / FLY_SECONDS, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)                                       # eased, left to right
	var x := lerpf(-30.0, 30.0, e)
	var pos := Vector3(x, lerpf(8.5, 6.5, sin(k * PI)), lerpf(-2.0, -5.0, e))
	var look := Vector3(x + lerpf(10.0, -10.0, e), 0.4, -16.0)
	fly_cam.global_position = pos
	fly_cam.look_at(look, Vector3.UP)
	_character_looks(look)
	var bar_h := 84.0 * clampf(_fly_t / 0.6, 0.0, 1.0) * clampf((FLY_SECONDS - _fly_t) / 0.6, 0.0, 1.0)
	_bar_top.offset_bottom = bar_h
	_bar_bot.offset_top = -bar_h
	var txt := ""
	var a := 0.0
	for ln in _lines:
		if _fly_t >= float(ln[0]) and _fly_t <= float(ln[1]):
			txt = str(ln[2])
			a = clampf(minf(_fly_t - float(ln[0]), float(ln[1]) - _fly_t) / 0.5, 0.0, 1.0)
	_caption.text = txt
	_caption.modulate = Color(1, 1, 1, a)
	if _fly_t >= FLY_SECONDS or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_ESCAPE):
		_end_fly()

func _end_fly() -> void:
	_fly_t = -1.0
	if fly_cam != null and is_instance_valid(fly_cam):
		fly_cam.queue_free()
	fly_cam = null
	for b in [_bar_top, _bar_bot]:
		b.visible = false
	_caption.visible = false
	_skip.visible = false
	game.ui.visible = _ui_was
	_show_character(false)
	game.player.camera.current = true
	game.player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## During the fly-over the player is a person in the picture, not a floating shovel: the tool view is hidden and the body is drawn (head and all), its head following where the camera looks.
func _show_character(on: bool) -> void:
	var tv = game.player.tool_view
	if tv != null:
		tv.visible = (not on) and not tv.suppressed and not tv.hidden_by_vehicle
	var pb = game.player_body
	if pb != null and is_instance_valid(pb):
		pb.set_shadow_only(not on)
		pb.set_first_person(not on)
		if not on and pb.rig != null:
			pb.rig.look_yaw = 0.0
			pb.rig.look_pitch = 0.0

func _character_looks(target: Vector3) -> void:
	var pb = game.player_body
	if pb == null or not is_instance_valid(pb) or pb.rig == null:
		return
	var d: Vector3 = target - game.player.global_position
	var rel := wrapf(atan2(-d.x, -d.z) - game.player.rotation.y, -PI, PI)
	pb.rig.look_yaw = clampf(rad_to_deg(rel), -70.0, 70.0)
	pb.rig.look_pitch = clampf(rad_to_deg(atan2(d.y - 1.6, maxf(Vector2(d.x, d.z).length(), 1.0))), -20.0, 20.0)

# ------------------------------------------------------------------ the guide panel

func _current_step() -> String:
	var pb = game.placed_buckets
	var in_bucket := 0
	if pb != null and is_instance_valid(pb):
		for it in pb.items:
			in_bucket += pb.total_of(it["load"])
	var hand: int = game._buckets().total_of(game.state.hand_bucket) if game._buckets() != null else 0
	var bag: int = game.state.total(game.state.inventory)
	var stones: int = game.debris_stones.size()
	if hand > 0:
		_carry_seen = true
		return "hopper"
	if in_bucket > 0:
		return "carry"
	if bag > 0 or stones > 0:
		return "bucket" if (bag > 0) else "stone"
	if _done("clear"):
		return "stone" if game.prog.heap_total_left() > 0 else ""
	return "clear"

func _show_step(step: String) -> void:
	if step == _shown_step:
		return
	_shown_step = step
	if step == "":
		_panel.visible = false
		_set_beacon(false)
		return
	var t: Array = {
		"clear": ["STEP 1", "Clear the overburden", "Take out the HAMMER (press 2) and hit a heap of stones. Use the SHOVEL (1) on weeds. Follow the red outlines."],
		"stone": ["STEP 2", "Pick up the stones", "Look at a stone on the ground and press E to pick it up. Keep hitting the heaps with the hammer for more."],
		"bucket": ["STEP 3", "Fill a bucket", "Press 4 for the bucket and click on the ground to set it down, then press E on it to toss your stones in."],
		"carry": ["STEP 4", "Take the bucket", "Press E on the full bucket to pick it up, then carry it to the Cash Hopper in the yard (the yellow beam)."],
		"hopper": ["STEP 5", "Sell it at the Cash Hopper", "Walk up to the Cash Hopper and press E: the bucket tips in and the hopper pays you for every stone."],
	}[step]
	_p_key.text = t[0]
	_p_title.text = t[1]
	_p_body.text = t[2]
	_panel.visible = true
	_set_beacon(step == "carry" or step == "hopper")

func _set_beacon(on: bool) -> void:
	if not on:
		if _beacon != null:
			_beacon.visible = false
		return
	var idx: Array = game.business.cash_hopper_indices()
	if idx.is_empty() or not game.output_nodes.has(idx[0]):
		return
	var n: Node3D = game.output_nodes[idx[0]]
	if _beacon == null:
		_beacon = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.09
		cm.height = 9.0
		cm.radial_segments = 6
		_beacon.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.82, 0.25, 0.32)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.15)
		_beacon.material_override = m
		_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.world.add_child(_beacon)
	_beacon.global_position = n.global_position + Vector3(0, 6.0, 0)
	_beacon.visible = true

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	if _fly_t >= 0.0:
		_fly_process(delta)
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	if finished():
		return
	if not bool(_data().get("flyover", false)):
		if game.prog.cleanup_cleared_all() or bool(game.prog.story.get("hopper_intro", false)):
			_data()["flyover"] = true                       # an older save, or the site is already clean: no need for the tour
			for s in STEPS:
				_mark(s)
			return
		if DisplayServer.get_name() != "headless" and _can_start_fly():
			_start_fly()
		return
	if game.prog.cleanup_cleared_all() and not _done("hopper"):
		_mark_all()
		return
	if game.menu != "" or game.hud.card_open() or game._conversation_active() or _busy_ui():
		_panel.visible = false                                  # a card, a tip or a dialogue is up: wait, then show the step again
		_shown_step = ""
		return
	_show_step(_current_step())

## An item card (or one queued) is showing: the guide waits its turn instead of sitting on top of it.
func _busy_ui() -> bool:
	var tips = game.get("item_tips")
	return tips != null and (tips.panel != null or not tips.queue.is_empty())

func _mark_all() -> void:
	for s in STEPS:
		_mark(s)
	_panel.visible = false
	_set_beacon(false)
