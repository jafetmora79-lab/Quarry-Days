extends Node
class_name QuarryAmbience
## The quiet around the quarry: a soft wind bed and a forest rustle (day), crickets (night), and the occasional bird chirping far off in the trees (day only, one at a time, not
## closer than 45 m, never in a rhythm). All sounds are synthesised once at start-up (no audio files), play on the game's effects bus (the Effects slider sets them), and sit
## well below the machines: the work stays the loudest thing in the yard. `update(delta, hour)` follows the game clock.

var game
var wind: AudioStreamPlayer
var rustle: AudioStreamPlayer
var crickets: AudioStreamPlayer
var bird: AudioStreamPlayer3D
var chirps: Array = []
var bird_timer := 9.0
var bird_count := 0
var _clock := 0.0
var _bird_end := 0.0
var day := 1.0
const RATE := 22050

func setup(g) -> void:
	game = g
	name = "Ambience"
	game.add_child(self)
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	wind = _bed(make_wind(), -27.0, bus)
	rustle = _bed(make_rustle(), -40.0, bus)
	crickets = _bed(make_crickets(), -40.0, bus)
	for k in range(5):
		chirps.append(make_chirp(100 + k * 13))
	bird = AudioStreamPlayer3D.new()
	bird.bus = bus
	bird.unit_size = 28.0
	bird.max_distance = 190.0
	bird.volume_db = -12.0
	add_child(bird)

func _bed(stream: AudioStreamWAV, db: float, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = bus
	add_child(p)
	p.play()
	return p

# ------------------------------------------------------------------ synthesis

static func _wav(data: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in range(data.size()):
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w

## Makes a buffer loop seamlessly: the last `fade` samples are blended into the first ones.
static func _seamless(raw: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := raw.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = raw[i]
	for i in range(fade):
		var k := float(i) / float(fade)
		out[i] = raw[i] * k + raw[n + i] * (1.0 - k)
	return out

## A low, breathing wind: lowpassed noise whose strength rises and falls over several seconds (8 s loop).
static func make_wind() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var secs := 8.0
	var fade := int(RATE * 0.6)
	var n := int(RATE * secs) + fade
	var raw := PackedFloat32Array()
	raw.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in range(n):
		var t := float(i) / float(RATE)
		var gust := 0.55 + 0.30 * sin(TAU * t / secs) + 0.15 * sin(TAU * 3.0 * t / secs + 1.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.035
		lp2 += (lp - lp2) * 0.2
		raw[i] = lp2 * 5.0 * gust
	return _wav(_seamless(raw, fade), true)

## The forest rustle: brighter, quieter noise with slow swells (6 s loop).
static func make_rustle() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var secs := 6.0
	var fade := int(RATE * 0.5)
	var n := int(RATE * secs) + fade
	var raw := PackedFloat32Array()
	raw.resize(n)
	var lp := 0.0
	var prev := 0.0
	for i in range(n):
		var t := float(i) / float(RATE)
		var swell := 0.5 + 0.5 * sin(TAU * 2.0 * t / secs) * sin(TAU * 3.0 * t / secs + 0.7)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.28
		var hp := lp - prev
		prev = lp * 0.9
		raw[i] = hp * 1.4 * (0.25 + swell)
	return _wav(_seamless(raw, fade), true)

## Crickets: a 4.3 kHz tone in short pulse trains, groups of pulses with gaps (3 s loop of five 0.6 s phrases).
static func make_crickets() -> AudioStreamWAV:
	var n := int(RATE * 3.0)
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(n):
		var t := float(i) / float(RATE)
		var ph := fmod(t, 0.6)
		var gate := 0.0
		if ph < 0.36:
			gate = maxf(0.0, sin(TAU * 26.0 * ph)) * (1.0 - ph / 0.5)
		var vib := 1.0 + 0.002 * sin(TAU * 7.0 * t)
		raw[i] = sin(TAU * 4300.0 * vib * t) * gate * 0.35 + sin(TAU * 4310.0 * t) * gate * 0.12
	return _wav(raw, true)

## A small bird: two to four whistled notes, each a short falling or rising sweep with a soft attack and decay. The variants differ in pitch and rhythm.
static func make_chirp(seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var notes := rng.randi_range(2, 4)
	var out := PackedFloat32Array()
	var f0 := rng.randf_range(2400.0, 3800.0)
	for k in range(notes):
		var len := rng.randf_range(0.07, 0.13)
		var sweep := rng.randf_range(-700.0, 900.0)
		var count := int(RATE * len)
		var phase := 0.0
		for i in range(count):
			var u := float(i) / float(count)
			var f := f0 + sweep * u + 120.0 * sin(TAU * 24.0 * u)
			phase += TAU * f / float(RATE)
			var env := sin(PI * u) * (1.0 - 0.3 * u)
			out.append(sin(phase) * env * 0.5)
		for i in range(int(RATE * rng.randf_range(0.05, 0.12))):
			out.append(0.0)
		f0 += rng.randf_range(-300.0, 300.0)
	return _wav(out, false)

# ------------------------------------------------------------------ following the clock

## 1 in full daylight, 0 at night (the beds and the birds follow it).
static func daylight(hour: float) -> float:
	return clampf((sin((hour - 6.0) / 24.0 * TAU) + 0.18) * 1.6, 0.0, 1.0)

## Whether a bird may sing at this hour: in daylight only (a little after sunrise to a little before sunset).
static func birds_allowed(hour: float) -> bool:
	return daylight(hour) > 0.35

func _process(delta: float) -> void:
	if game == null:
		return
	update(delta, float(game._hour()))

func update(delta: float, hour: float) -> void:
	day = daylight(hour)
	wind.volume_db = lerpf(wind.volume_db, lerpf(-33.0, -26.0, day), 1.0 - exp(-0.8 * delta))
	rustle.volume_db = lerpf(rustle.volume_db, lerpf(-60.0, -36.0, day), 1.0 - exp(-0.8 * delta))
	crickets.volume_db = lerpf(crickets.volume_db, lerpf(-34.0, -60.0, minf(1.0, day * 2.0)), 1.0 - exp(-0.8 * delta))
	_clock += delta
	bird_timer -= delta
	if bird_timer <= 0.0:
		bird_timer = randf_range(9.0, 30.0)
		if birds_allowed(hour) and game.player != null and is_instance_valid(game.player) and _clock > _bird_end:
			var a := randf() * TAU
			var d := randf_range(48.0, 95.0)
			bird.global_position = game.player.global_position + Vector3(cos(a) * d, randf_range(6.0, 14.0), sin(a) * d)
			bird.stream = chirps[randi() % chirps.size()]
			bird.pitch_scale = randf_range(0.92, 1.1)
			bird.play()
			_bird_end = _clock + (bird.stream as AudioStreamWAV).get_length() + 1.0
			bird_count += 1
