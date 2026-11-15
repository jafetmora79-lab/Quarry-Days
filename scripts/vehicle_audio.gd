extends Node3D
class_name VehicleAudio
## Engine, hydraulic and work sounds for one machine. Positional (AudioStreamPlayer3D): the player hears it from the cab when driving
## and from a distance when walking past. Sounds are synthesized by tools/qd_vehicle_sounds.py (audio/*.wav).

const DIR := "res://audio/"

var _engine: AudioStreamPlayer3D
var _hyd: AudioStreamPlayer3D
var _start: AudioStreamPlayer3D
var _stop: AudioStreamPlayer3D
var _dig: AudioStreamPlayer3D
var _dump: AudioStreamPlayer3D
var running := false
var rpm := 0.0                 # smoothed 0..1
var _gen := 0

static func _stream(file: String, loop := false) -> AudioStreamWAV:
	var s: AudioStreamWAV = load(DIR + file + ".wav")
	if s != null and loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2
	return s

func _player(file: String, db: float, loop := false) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(file, loop)
	p.volume_db = db
	p.unit_size = 7.0
	p.max_distance = 45.0
	add_child(p)
	return p

func _ready() -> void:
	_engine = _player("engine_loop", -12.0, true)
	_hyd = _player("hydraulic_loop", -80.0, true)
	_start = _player("engine_start", -6.0)
	_stop = _player("engine_stop", -8.0)
	_dig = _player("dig_scrape", -7.0)
	_dump = _player("dump_clatter", -6.0)

func start_engine() -> void:
	if running or _start == null:
		return
	running = true
	_gen += 1
	var g := _gen
	_start.play()
	await get_tree().create_timer(1.7).timeout
	if running and g == _gen:
		_engine.play()

func stop_engine() -> void:
	if not running or _stop == null:
		return
	running = false
	_gen += 1
	_engine.stop()
	_hyd.stop()
	_start.stop()
	_stop.play()

## Call every frame while the machine exists. `load01` = how hard the engine works (speed / digging), `hyd01` = how fast the joints move.
func update(delta: float, load01: float, hyd01: float) -> void:
	if _engine == null:
		return
	rpm = move_toward(rpm, clampf(load01, 0.0, 1.0), delta * 1.6)
	_engine.pitch_scale = lerpf(0.85, 1.55, rpm)
	_engine.volume_db = lerpf(-13.0, -7.0, rpm)
	if running and hyd01 > 0.04:
		if not _hyd.playing:
			_hyd.play()
		_hyd.volume_db = lerpf(_hyd.volume_db, linear_to_db(clampf(hyd01, 0.05, 1.0)) - 6.0, clampf(delta * 12.0, 0.0, 1.0))
		_hyd.pitch_scale = lerpf(0.9, 1.25, clampf(hyd01, 0.0, 1.0))
	elif _hyd.playing:
		_hyd.volume_db = lerpf(_hyd.volume_db, -60.0, clampf(delta * 10.0, 0.0, 1.0))
		if _hyd.volume_db < -50.0:
			_hyd.stop()

func dig() -> void:
	if _dig != null:
		_dig.pitch_scale = randf_range(0.92, 1.08)
		_dig.play()

func dump() -> void:
	if _dump != null:
		_dump.pitch_scale = randf_range(0.95, 1.05)
		_dump.play()
