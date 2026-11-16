extends RefCounted
class_name GameSettings
## The player's settings that outlive a game: effects volume, fullscreen, vertical sync. (Music volume and mute are saved by QuarryMusic in the same file.) Stored
## in user://settings.cfg and applied at start-up and whenever they change. Nothing here touches the save game.

const PATH := "user://settings.cfg"
static var sfx_volume := 0.8
static var fullscreen := false
static var vsync := true
static var loaded := false

static func load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		sfx_volume = clampf(float(cf.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
		fullscreen = bool(cf.get_value("display", "fullscreen", false))
		vsync = bool(cf.get_value("display", "vsync", true))
	loaded = true

static func save_all() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)                                        # keep the music section QuarryMusic wrote
	cf.set_value("audio", "sfx_volume", sfx_volume)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "vsync", vsync)
	cf.save(PATH)

## The effects bus: every sound effect the game plays goes through it (QuarryMain._audio, doors, rigs), so one slider sets them all.
static func ensure_sfx_bus() -> int:
	var i := AudioServer.get_bus_index("SFX")
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "SFX")
		AudioServer.set_bus_send(i, "Master")
	return i

static func apply() -> void:
	if not loaded:
		load_all()
	var i := ensure_sfx_bus()
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, sfx_volume)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

static func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply()
	save_all()

static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_all()

static func set_vsync(on: bool) -> void:
	vsync = on
	apply()
	save_all()

## The controls reference shown in Settings: [key, what it does].
const CONTROLS := [
	["W A S D", "Move"], ["SHIFT", "Sprint"], ["MOUSE", "Look"], ["LEFT CLICK", "Use the tool in hand (hold for power tools)"],
	["1 - 5", "Choose a tool on the hotbar"], ["E", "Interact / get in or out of a machine"], ["B", "Build mode (I store a machine, [ ] pick from the Build Inventory, P place)"], ["M", "Management (after your first hire)"],
	["O", "Open or close the full objectives list"], ["RIGHT CLICK", "In a machine: dump the bucket / raise the bed"], ["TAB", "Cab view in a machine"],
	["R", "Recover a stuck machine"], ["J", "Auto crew for the machine you drive"], ["F5 / F9", "Save / load"], ["ESC", "Pause"]]
