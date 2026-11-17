extends Node3D
class_name DigAudio
## ONE entry point for every sound the ground makes. What you hit decides what you hear:
##
##   play("dig", "limestone", pos, 1.0)     a tool biting a material  -> that material's sound set (soil thud, clay squelch, gravel crunch, rock crack)
##   play("blocked", "limestone", pos, 1.0) a tool that is too weak    -> a bright metallic chink (3 variants)
##   play("pour", ...) / play("drop", ...)  material pouring / a load landing
##   play("scrape", ...)                    a bucket grinding on rock
##
## A pool of 8 AudioStreamPlayer3D, random pitch +-6 %, a per-event cooldown (data/geology.json "events") so a held button never machine-guns, volume scaled by intensity.
## Every call that gets through is appended to `log` ({event, material, stream, pos}) so tests can assert the event without hearing it.

const POOL := 8

var players: Array = []
var log: Array = []
var enabled := true
var _cool := {}                              ## event -> seconds left
var _rng := RandomNumberGenerator.new()
var _streams := {}
var _next := 0

func _ready() -> void:
	_rng.seed = 5150
	for i in range(POOL):
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 70.0
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(p)
		players.append(p)

func _process(delta: float) -> void:
	for k in _cool.keys():
		_cool[k] = maxf(0.0, float(_cool[k]) - delta)

func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := "res://audio/dig_%s.wav" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]

## Picks the sound name for an event on a material (a deterministic table, no scattered ifs). Empty when there is none.
func pick(event: String, material: String) -> String:
	var d := QuarryGeology.data()
	if event == "blocked":
		var b: Array = d["blocked_sounds"]
		return str(b[_rng.randi() % b.size()])
	if event == "scrape":
		return "scrape_metal"
	var set_id := str(QuarryGeology.material_props(material).get("sound", "soil"))
	var set: Dictionary = d["sound_sets"].get(set_id, d["sound_sets"]["soil"])
	var names: Array = set.get(event, [])
	if names.is_empty():
		return ""
	return str(names[_rng.randi() % names.size()])

## Plays (if the event is off cooldown) and returns the sound name, or "" when it was swallowed by the cooldown.
func play(event: String, material: String, pos: Vector3, intensity := 1.0) -> String:
	var ev: Dictionary = QuarryGeology.data()["events"].get(event, {})
	if float(_cool.get(event, 0.0)) > 0.0:
		return ""
	_cool[event] = float(ev.get("cooldown", 0.12))
	var name := pick(event, material)
	if name == "":
		return ""
	log.append({"event": event, "material": material, "sound": name, "pos": pos, "intensity": intensity})
	if log.size() > 200:
		log.pop_front()
	if not enabled or players.is_empty():
		return name
	var s := _stream(name)
	if s == null:
		return name
	var p: AudioStreamPlayer3D = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = s
	p.global_position = pos
	p.pitch_scale = _rng.randf_range(0.94, 1.06)
	p.volume_db = float(ev.get("volume_db", 0.0)) + linear_to_db(clampf(intensity, 0.05, 2.0))
	p.play()
	return name
