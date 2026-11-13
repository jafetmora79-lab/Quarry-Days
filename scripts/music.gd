extends Node
class_name QuarryMusic
## Background music: the menu theme (walts_hammer) over the main menu, the pause menu, the office computer, the station panels and story cards;
## the gameplay loop (quarry_shift) otherwise. Two players on a "Music" bus, crossfaded over 1.5 s, paused (not restarted) when faded out, ducked
## 4 dB for a moment when an unlock jingle plays. Volume and mute are saved in user://settings.cfg. A missing file just means silence.

const TRACKS := {"menu": "res://audio/music/walts_hammer", "play": "res://audio/music/quarry_shift"}   # .wav or .ogg
const BASE_DB := -19.0
const FADE_SECONDS := 1.5
const SETTINGS := "user://settings.cfg"

var game
var players := {}
var level := {"menu": 0.0, "play": 0.0}       ## 0 (silent) .. 1 (full) per track
var current := ""
var volume := 0.7                              ## 0..1 (music volume setting)
var muted := false
var duck_t := 0.0
var bus_index := -1

func setup(main_node) -> void:
	game = main_node
	name = "Music"
	bus_index = AudioServer.get_bus_index("Music")
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, "Music")
		AudioServer.set_bus_send(bus_index, "Master")
	_load_settings()
	for key in TRACKS:
		var stream := _load_stream(str(TRACKS[key]))
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		players[key] = p

func _load_stream(base: String) -> AudioStream:
	for ext in [".wav", ".ogg"]:
		if ResourceLoader.exists(base + ext):
			var s = load(base + ext)
			if s is AudioStreamWAV:
				var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = w.data.size() / (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if w.stereo else 1)
				return w
			if s is AudioStreamOggVorbis:
				var o := (s as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
				o.loop = true
				return o
	return null

## Which track the game wants right now.
func wanted() -> String:
	if game == null or game.player == null:
		return "menu"
	if game.menu != "" or (game.hud != null and game.hud.card_open()):
		return "menu"
	return "play"

func duck() -> void:
	duck_t = 1.2

func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_save_settings()

func set_muted(m: bool) -> void:
	muted = m
	_save_settings()

func _process(delta: float) -> void:
	current = wanted()
	duck_t = maxf(0.0, duck_t - delta)
	var step := delta / FADE_SECONDS
	for key in players:
		var p: AudioStreamPlayer = players[key]
		level[key] = move_toward(float(level[key]), 1.0 if key == current else 0.0, step)
		var lv: float = float(level[key])
		if lv <= 0.001:
			if p.playing:
				p.stream_paused = true            # paused, so the track resumes where it left off
			continue
		if not p.playing:
			p.play()
		p.stream_paused = false
		var gain := 0.0 if muted else volume
		p.volume_db = linear_to_db(maxf(0.0001, lv * gain)) + BASE_DB + (-4.0 if duck_t > 0.0 else 0.0)

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		volume = clampf(float(cf.get_value("music", "volume", volume)), 0.0, 1.0)
		muted = bool(cf.get_value("music", "muted", false))

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("music", "volume", volume)
	cf.set_value("music", "muted", muted)
	cf.save(SETTINGS)
