extends Control
class_name QuarryTouchControls
## On-screen controls for touch devices (Godot on Android). Enabled on mobile builds and with the `--touch` user
## argument (`godot --path . -- --touch`). Left thumb: move stick. Right thumb: MINE (hold), USE (E), RUN (toggle).
## Drag anywhere else to look around. Context buttons appear when needed (PLACE / ROTATE while placing,
## ALT while driving, AUTO on a machine that can run an auto crew, SKIP while a delivery arrives). Menus keep using ordinary taps (the engine emulates mouse clicks from touch).
## Controls hide while a menu or story card is open. Positions are in the 960x540 base canvas.

var game
var player
var stick_id := -1
var stick_center := Vector2(120, 410) # updated to hug the bottom-left corner of the canvas
var stick_vec := Vector2.ZERO
var look_id := -1
var held := {}            # finger index -> button id
var run_on := false
const STICK_R := 62.0
const LOOK_SPEED := 0.0042

## id, label, canvas anchor ("r" = from right, "b" = from bottom), radius
const BUTTONS := [
	{"id": "mine", "label": "MINE", "x": -95.0, "y": -105.0, "r": 52.0},
	{"id": "use", "label": "USE", "x": -215.0, "y": -70.0, "r": 38.0},
	{"id": "run", "label": "RUN", "x": -70.0, "y": -225.0, "r": 32.0},
	{"id": "menu", "label": "MENU", "x": 38.0, "y": 150.0, "r": 28.0, "top": true},
	{"id": "manage", "label": "MGR", "x": 38.0, "y": 205.0, "r": 26.0, "top": true},
	{"id": "build", "label": "BUILD", "x": 38.0, "y": 258.0, "r": 26.0, "top": true},
	{"id": "place", "label": "PLACE", "x": -215.0, "y": -165.0, "r": 40.0, "ctx": "place"},
	{"id": "rotate", "label": "ROT", "x": -310.0, "y": -105.0, "r": 32.0, "ctx": "place"},
	{"id": "alt", "label": "ALT", "x": -215.0, "y": -165.0, "r": 40.0, "ctx": "drive"},
	{"id": "auto", "label": "AUTO", "x": -310.0, "y": -190.0, "r": 34.0, "ctx": "auto"},
	{"id": "skip", "label": "SKIP", "x": -310.0, "y": -265.0, "r": 34.0, "ctx": "skip"},
]

func setup(main_node) -> void:
	game = main_node
	player = game.player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50

## Where the top-left button column starts: just under the corner map (which the HUD sizes), so the buttons never sit on top of it.
func _top_base() -> float:
	if game != null and game.hud != null and game.hud.map_plate != null:
		return game.hud.map_plate.position.y + game.hud.map_plate.size.y + 34.0
	return 150.0

func _pos(b: Dictionary) -> Vector2:
	if b.get("top", false):
		return Vector2(float(b["x"]), _top_base() + (float(b["y"]) - 150.0)) # from the top-left corner, below the map
	return Vector2(size.x + float(b["x"]), size.y + float(b["y"]))

func _active(b: Dictionary) -> bool:
	match str(b.get("ctx", "")):
		"place": return game.placement or game.construction
		"drive": return game.driving != null
		"auto": return game.crew != null and game.crew.eligible(game.crew_candidate()) == ""      # a machine that can run an auto crew is driven or aimed at
		"skip": return game.delivery != null and not game.delivery.jobs.is_empty()                # a delivery is on its way
	return true

func _shown() -> bool:
	return game != null and game.menu == "" and not (game.hud and game.hud.card_open())

func _process(_delta: float) -> void:
	stick_center = Vector2(120.0, size.y - 130.0)
	var s := _shown()
	if s != visible:
		visible = s
		if not s:
			_release_all()
	if visible:
		queue_redraw()

func _release_all() -> void:
	stick_id = -1
	look_id = -1
	stick_vec = Vector2.ZERO
	_apply_stick()
	for id in held.keys():
		_button_up(str(held[id]))
	held.clear()

func _button_at(p: Vector2) -> String:
	for b in BUTTONS:
		if _active(b) and p.distance_to(_pos(b)) <= float(b["r"]) + 8.0:
			return str(b["id"])
	return ""

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			var bid := _button_at(p)
			if bid != "":
				held[event.index] = bid
				_button_down(bid)
				get_viewport().set_input_as_handled()
			elif p.distance_to(stick_center) < STICK_R * 1.9 and stick_id < 0:
				stick_id = event.index
				_update_stick(p)
				get_viewport().set_input_as_handled()
			elif look_id < 0 and p.x > size.x * 0.35:
				look_id = event.index
		else:
			if held.has(event.index):
				_button_up(str(held[event.index]))
				held.erase(event.index)
			if event.index == stick_id:
				stick_id = -1
				stick_vec = Vector2.ZERO
				_apply_stick()
			if event.index == look_id:
				look_id = -1
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			_update_stick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == look_id and player and not player.locked:
			player.rotate_y(-event.relative.x * LOOK_SPEED)
			player.pitch = clampf(player.pitch - event.relative.y * LOOK_SPEED, -1.42, 1.42)
			get_viewport().set_input_as_handled()

func _update_stick(p: Vector2) -> void:
	stick_vec = ((p - stick_center) / STICK_R).limit_length(1.0)
	_apply_stick()

func _apply_stick() -> void:
	var v := stick_vec
	if v.length() < 0.15:
		v = Vector2.ZERO
	_set_action("move_forward", maxf(0.0, -v.y))
	_set_action("move_back", maxf(0.0, v.y))
	_set_action("move_left", maxf(0.0, -v.x))
	_set_action("move_right", maxf(0.0, v.x))

func _set_action(a: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(a, strength)
	else:
		Input.action_release(a)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)

func _mouse(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = size * 0.5
	e.global_position = e.position
	e.set_meta("touch_ok", true) # from a touch button, not an emulated screen tap
	Input.parse_input_event(e)

func _button_down(id: String) -> void:
	match id:
		"mine":
			game.touch_mine = true
			_mouse(MOUSE_BUTTON_LEFT, true)
		"use": _key(KEY_E)
		"run":
			run_on = not run_on
			_set_action("sprint", 1.0 if run_on else 0.0)
		"menu": _key(KEY_ESCAPE)
		"manage": _key(KEY_M)
		"build": _key(KEY_B)
		"place":
			_mouse(MOUSE_BUTTON_LEFT, true)
			_mouse(MOUSE_BUTTON_LEFT, false)
		"rotate": _key(KEY_R)
		"auto": _key(KEY_J)
		"skip": _key(KEY_K)
		"alt":
			_mouse(MOUSE_BUTTON_RIGHT, true)
			_mouse(MOUSE_BUTTON_RIGHT, false)

func _button_up(id: String) -> void:
	if id == "mine":
		game.touch_mine = false
		_mouse(MOUSE_BUTTON_LEFT, false)

func _draw() -> void:
	var font := QuarryTheme.bold()
	# stick
	draw_circle(stick_center, STICK_R, Color(0.1, 0.08, 0.06, 0.38))
	draw_arc(stick_center, STICK_R, 0.0, TAU, 40, Color(0.98, 0.76, 0.34, 0.55), 2.0)
	draw_circle(stick_center + stick_vec * STICK_R * 0.8, 24.0, Color(0.98, 0.76, 0.34, 0.6))
	for b in BUTTONS:
		if not _active(b):
			continue
		var p := _pos(b)
		var down: bool = held.values().has(str(b["id"])) or (str(b["id"]) == "run" and run_on)
		draw_circle(p, float(b["r"]), Color(0.27, 0.4, 0.2, 0.7) if down else Color(0.1, 0.08, 0.06, 0.45))
		draw_arc(p, float(b["r"]), 0.0, TAU, 32, Color(0.98, 0.76, 0.34, 0.7), 2.0)
		var fs := QuarryTheme.BODY
		var w := font.get_string_size(str(b["label"]), HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, p + Vector2(-w * 0.5, fs * 0.35), str(b["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.99, 0.95, 0.84))
