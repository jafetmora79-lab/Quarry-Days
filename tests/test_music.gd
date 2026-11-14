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
	if g.walter_dialog:
		g.walter_dialog.skip()
	g.hud.close_card()
	g._cine_tween().kill()
	g._remove_walter()
	for i in range(30):
		await physics_frame
	var m: QuarryMusic = g.music
	check(m != null and AudioServer.get_bus_index("Music") >= 0, "a Music bus and the music manager exist")
	check(m.players.size() == 2 and m.players.has("menu") and m.players.has("play"), "the real music files are connected: a player for each track")
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
	check(g.panel.buttons.has("music_vol") and g.panel.buttons.has("music_vol_mute"), "the pause menu has a music volume slider and a mute button")
	g.panel.buttons["music_vol_mute"].pressed.emit()
	await frames(2)
	check(not m.muted, "the mute button toggles the music (unmuted again)")
	m.set_muted(false)
	g._draw_menu()
	await frames(1)
	(g.panel.buttons["music_vol"] as HSlider).value = 0.4
	check(absf(m.volume - 0.4) < 0.001, "dragging the slider sets the volume")
	# ---- the real tracks are in the project and connected
	check(ResourceLoader.exists("res://audio/music/walts_hammer.wav") and ResourceLoader.exists("res://audio/music/quarry_shift.wav"), "both music files are in audio/music (walts_hammer, quarry_shift)")
	check(m.players.has("menu") and m.players.has("play") and m.players.size() == 2, "both tracks have a player, no duplicates (%d players)" % m.players.size())
	check((m.players["menu"].stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD and (m.players["play"].stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "both loop")
	# ---- the opening scene plays the menu theme, dialogue lowers the music, driving lowers it a little, and nothing restarts
	g._close_menu()
	m.set_muted(false)
	m.set_volume(0.7)
	g.est_running = true
	await frames(5)
	check(m.wanted() == "menu", "the opening shots play the menu theme")
	g.est_running = false
	await frames(5)
	check(m.wanted() == "play", "and the gameplay loop follows when control returns")
	await frames(60)
	var pos_before: float = m.players["play"].get_playback_position()
	g._open_walter_dialog([{"speaker": "GRANDPA WALTER", "text": "Hello.", "dur": 9.0}], func(_s): pass)
	await frames(90)
	check(m.context_gain < 0.6 and m.context_gain > 0.5, "the music eases down while Grandpa speaks (%.2f)" % m.context_gain)
	g.walter_dialog.skip()
	await frames(150)
	check(m.context_gain > 0.99, "and eases back up afterwards (%.2f)" % m.context_gain)
	var pos_after: float = m.players["play"].get_playback_position()
	check(m.players.size() == 2 and (pos_after >= pos_before - 0.01 or pos_before > 70.0), "the gameplay track kept playing through the dialogue (%.1f s -> %.1f s), nothing restarted or doubled" % [pos_before, pos_after])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
