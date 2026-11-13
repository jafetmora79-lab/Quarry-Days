extends SceneTree
## Music system: which track plays where, crossfade, pause-not-restart, ducking, saved volume/mute, silence when files are missing.
## godot --headless --fixed-fps 60 -s tests/test_music.gd
var checks := 0
var failures := []
func check(c: bool, label: String) -> void:
	checks += 1
	if not c:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):
		await process_frame
func tone() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 32000
	var d := PackedByteArray()
	for i in range(32000):
		var v := int(sin(float(i) * 0.05) * 8000.0)
		d.append(v & 0xFF)
		d.append((v >> 8) & 0xFF)
	w.data = d
	return w
func run() -> void:
	var g = load("res://Main.tscn").instantiate()
	g.autosave_enabled = false
	g.title_enabled = false
	g.introductions_enabled = false
	g.curfew_enabled = false
	root.add_child(g)
	await process_frame
	for i in range(8):
		await physics_frame
	g.hud.close_card()
	var m: QuarryMusic = g.music
	check(m != null and AudioServer.get_bus_index("Music") >= 0, "a Music bus and the music manager exist")
	check(m.players.is_empty(), "with no music files in the project it stays silent (no players, no errors)")
	for key in ["menu", "play"]:
		var p := AudioStreamPlayer.new()
		p.stream = tone()
		p.bus = "Music"
		p.volume_db = -80.0
		m.add_child(p)
		m.players[key] = p
	check(m.wanted() == "play", "in the quarry the gameplay loop is wanted")
	g._open_menu("manage")
	check(m.wanted() == "menu", "the office computer wants the menu theme")
	g._close_menu()
	g._open_menu("pause")
	check(m.wanted() == "menu", "the pause menu wants the menu theme")
	g._close_menu()
	# crossfade
	m.level = {"menu": 0.0, "play": 1.0}
	g._open_menu("pause")
	await frames(30)
	var mid: float = float(m.level["play"])
	check(mid > 0.1 and mid < 0.95, "the tracks crossfade rather than cutting (play at %.2f half-way)" % mid)
	await frames(120)
	check(float(m.level["menu"]) > 0.99 and float(m.level["play"]) < 0.01, "after 1.5 s the menu theme has the floor")
	var play_p: AudioStreamPlayer = m.players["play"]
	check(play_p.stream_paused, "the faded-out track is paused so it resumes where it left off")
	g._close_menu()
	await frames(120)
	check(not play_p.stream_paused and play_p.playing, "and resumes (not restarts) when the game wants it again")
	# ducking and volume
	await frames(4)
	var before := play_p.volume_db
	m.duck()
	await frames(3)
	check(play_p.volume_db < before - 3.0, "an unlock jingle ducks the music by about 4 dB (%.1f -> %.1f)" % [before, play_p.volume_db])
	m.set_volume(0.3)
	m.set_muted(true)
	var cf := ConfigFile.new()
	check(cf.load(QuarryMusic.SETTINGS) == OK and absf(float(cf.get_value("music", "volume", 0)) - 0.3) < 0.001 and bool(cf.get_value("music", "muted", false)), "volume and mute are saved in user://settings.cfg")
	await frames(60)
	check(play_p.volume_db < -60.0, "muted is silent")
	g._open_menu("pause")
	await frames(2)
	check(g.panel.buttons.has("music_down") and g.panel.buttons.has("music_up") and g.panel.buttons.has("music_mute"), "the pause menu has music volume and mute buttons")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
