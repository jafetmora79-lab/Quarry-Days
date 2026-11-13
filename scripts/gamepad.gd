extends Node
class_name QuarryGamepad
## Gamepad support. Menus already navigate with the pad (the d-pad and left stick move the focus, A presses, B backs out); this adds the game itself:
##   on foot   left stick move, right stick look, RT mine (hold), LT alt, LB sprint, A use, X rotate, Y management, d-pad down build, START pause / back
##   driving   left stick drive, right stick spin the cab / look, RT dig / scoop, RB dump / unload, LT brake, A get out, Y recover,
##             d-pad up / down boom, d-pad left / right stick, X / LB curl the bucket, START pause
##   placing   RT or A place, X rotate, d-pad down grid, B / START cancel
## Actions the game reads through InputMap get joypad events added here; everything the game reads straight from the keyboard or the mouse (the
## management and build keys, the excavator joints, mine / dump clicks) is generated as the matching key or mouse event, the same way the touch buttons do.
## The hint bar shows pad glyphs as soon as the pad is touched, and keyboard glyphs again as soon as a key or the mouse is used.

var game
var active := false                 ## the last input came from a pad (hints show pad glyphs)
var stick := Vector2.ZERO           ## left stick, dead-zoned
var look := Vector2.ZERO            ## right stick, dead-zoned
var trig_l := 0.0
var trig_r := 0.0
var _rt_down := false
var _lt_down := false
var _held_keys := {}                ## keycode -> true while a pad button holds that key down
const DEAD := 0.2
const LOOK_RATE := 2.7              ## rad/s at full deflection (on foot)
const PITCH_RATE := 1.8
const CAB_RATE := 850.0             ## "mouse pixels"/s fed to the vehicle camera / cab at full deflection

## Pad button numbers (Godot's JOY_BUTTON_*).
const A := 0
const B := 1
const X := 2
const Y := 3
const BACK := 4
const START := 6
const LB := 9
const RB := 10
const DUP := 11
const DDOWN := 12
const DLEFT := 13
const DRIGHT := 14

func setup(main_node) -> void:
	game = main_node
	name = "Gamepad"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_input_map_events()

## Joypad events for the project's own actions (idempotent).
static func _add_input_map_events() -> void:
	var motions := {"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0], "move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0]}
	for act in motions:
		if InputMap.has_action(act) and not _has_joy(act):
			var e := InputEventJoypadMotion.new()
			e.axis = motions[act][0]
			e.axis_value = motions[act][1]
			InputMap.action_add_event(act, e)
	var buttons := {"sprint": LB, "interact": A, "rotate_machine": X, "place_machine": RB, "save_game": BACK, "ui_cancel": START}
	for act in buttons:
		if InputMap.has_action(act) and not _has_joy_button(act, int(buttons[act])):
			var e := InputEventJoypadButton.new()
			e.button_index = int(buttons[act])
			InputMap.action_add_event(act, e)

static func _has_joy(act: String) -> bool:
	for e in InputMap.action_get_events(act):
		if e is InputEventJoypadMotion:
			return true
	return false

static func _has_joy_button(act: String, idx: int) -> bool:
	for e in InputMap.action_get_events(act):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == idx:
			return true
	return false

## What the pad button means in the current situation: {"key": Key, "hold": bool} for a key, {"mouse": MouseButton, "hold": bool} for a click, or {}.
static func binding(button: int, ctx: String) -> Dictionary:
	match ctx:
		"drive":
			match button:
				Y: return {"key": KEY_R}
				DUP: return {"key": KEY_UP, "hold": true}
				DDOWN: return {"key": KEY_DOWN, "hold": true}
				DLEFT: return {"key": KEY_Z, "hold": true}
				DRIGHT: return {"key": KEY_X, "hold": true}
				X: return {"key": KEY_C, "hold": true}
				LB: return {"key": KEY_V, "hold": true}
				RB: return {"mouse": MOUSE_BUTTON_RIGHT}
		"place":
			match button:
				A: return {"mouse": MOUSE_BUTTON_LEFT}
				DDOWN: return {"key": KEY_G}
		"walk":
			match button:
				Y: return {"key": KEY_M}
				DDOWN: return {"key": KEY_B}
	return {}

## The situation the pad is used in.
func context() -> String:
	if game == null:
		return "walk"
	if game.menu != "" or (game.hud and game.hud.card_open()) or game.dialog:
		return "menu"
	if game.driving:
		return "drive"
	if game.placement or game.construction:
		return "place"
	return "walk"

func _input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		active = true
	elif (event is InputEventKey or event is InputEventMouseButton) and not event.has_meta("pad"):
		active = false
	if event is InputEventJoypadButton:
		feed_button((event as InputEventJoypadButton).button_index, (event as InputEventJoypadButton).pressed)
	elif event is InputEventJoypadMotion:
		feed_axis((event as InputEventJoypadMotion).axis, (event as InputEventJoypadMotion).axis_value)

func feed_axis(axis: int, v: float) -> void:
	match axis:
		JOY_AXIS_LEFT_X: stick.x = v
		JOY_AXIS_LEFT_Y: stick.y = v
		JOY_AXIS_RIGHT_X: look.x = v
		JOY_AXIS_RIGHT_Y: look.y = v
		JOY_AXIS_TRIGGER_LEFT: trig_l = v
		JOY_AXIS_TRIGGER_RIGHT: trig_r = v

func feed_button(button: int, pressed: bool) -> void:
	if button == START and pressed and context() == "walk":
		_key_tap(KEY_ESCAPE)             # START pauses (the ui_cancel action also carries it, for menus and cancelling)
	var b := binding(button, context())
	if b.is_empty():
		if not pressed:
			_release_held(button)
		return
	if b.has("key"):
		if bool(b.get("hold", false)):
			_key_set(int(b["key"]), pressed)
		elif pressed:
			_key_tap(int(b["key"]))
	elif b.has("mouse") and pressed:
		_mouse_tap(int(b["mouse"]))

func _release_held(_button: int) -> void:
	pass

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	var ctx := context()
	var s := stick if stick.length() > DEAD else Vector2.ZERO
	var l := look if look.length() > DEAD else Vector2.ZERO
	if ctx == "menu":
		s = Vector2.ZERO
		l = Vector2.ZERO
	# (the left stick needs nothing here: the joypad-motion events added to the move_* actions make Input.get_vector analog)
	# right stick: look on foot; spin the cab / the chase camera in a machine
	if l != Vector2.ZERO:
		if ctx == "drive" and game.driving != null:
			game.driving.rotate_camera(l * CAB_RATE * delta)
		elif game.player != null and not game.player.locked:
			game.player.rotate_y(-l.x * LOOK_RATE * delta)
			game.player.pitch = clampf(game.player.pitch - l.y * PITCH_RATE * delta, -1.42, 1.42)
	# triggers
	var rt := trig_r > 0.5 and ctx != "menu"
	if rt != _rt_down:
		_rt_down = rt
		_mouse_set(MOUSE_BUTTON_LEFT, rt)
	var lt := trig_l > 0.5 and ctx != "menu"
	if lt != _lt_down:
		_lt_down = lt
		if ctx == "drive":
			_key_set(KEY_SPACE, lt)                  # brake
		elif lt:
			_mouse_tap(MOUSE_BUTTON_RIGHT)           # alt action
	if ctx == "menu" and not _held_keys.is_empty():
		for k in _held_keys.keys():
			_key_set(int(k), false)

func _key_set(code: int, pressed: bool) -> void:
	if bool(_held_keys.get(code, false)) == pressed:
		return
	_held_keys[code] = pressed
	if not pressed:
		_held_keys.erase(code)
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.set_meta("pad", true)
	Input.parse_input_event(e)

func _key_tap(code: int) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = p
		e.set_meta("pad", true)
		Input.parse_input_event(e)

func _mouse_set(button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = get_viewport().get_visible_rect().size * 0.5
	e.global_position = e.position
	e.set_meta("touch_ok", true)
	e.set_meta("pad", true)
	Input.parse_input_event(e)

func _mouse_tap(button: int) -> void:
	_mouse_set(button, true)
	_mouse_set(button, false)

## The hint bar's key names, in pad terms.
static func pad_hints(items: Array, driving := false, placing := false) -> Array:
	var out := []
	for it in items:
		var k := str(it[0])
		var t := k
		match k:
			"W A S D": t = "L STICK"
			"SHIFT": t = "LB"
			"LEFT CLICK", "HOLD LEFT CLICK": t = "RT"
			"RIGHT CLICK": t = "RB" if driving else "LT"
			"SPACE": t = "LT"
			"E": t = "A"
			"R": t = "X" if placing else "Y"
			"G": t = "DPAD DOWN"
			"B": t = "DPAD DOWN"
			"M": t = "Y"
			"ESC": t = "START"
		out.append([t, it[1]])
	return out
