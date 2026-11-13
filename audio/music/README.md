# Quarry Days music

Two synthesized background loops (mono, 16-bit, 32 kHz). Both loop seamlessly: each track's ringing tail is wrapped back onto its start. They are **not wired into the game yet**.

| File | Use | Tempo / key | Length |
|---|---|---|---|
| `walts_hammer.wav` | **Menu theme**: pause menu, office/management screen, intro letter | 88 BPM, F major | 109.1 s (40 bars) |
| `quarry_shift.wav` | **Gameplay loop**: in the quarry | 94 BPM, F major / D minor | 81.7 s (32 bars) |

- **Walt's Hammer:** calm folk with a light chiptune edge: plucked guitar arpeggios, walking bass, brushed percussion, a soft square-wave melody, and a tuned anvil "ting" every 4 bars.
- **Quarry Shift:** semi-energetic lo-fi hip-hop: swung boom-bap drums, electric-piano 7th/9th chords, sub bass, a pixel hook with echo, vinyl crackle, and a light sidechain pump.

## Regenerating

The tracks are deterministic (fixed random seeds) and need only NumPy:

```
python3 tools/music/walts_hammer.py audio/music/walts_hammer.wav
python3 tools/music/quarry_shift.py audio/music/quarry_shift.wav
```

Tempo, chords, melody and the mix levels of each part are plain values near the top of each script.

## Integration notes (for whoever wires it in)

- **Looping:** set the loop mode at load, the same way `scripts/main.gd` already does for `audio/crusher_loop.wav`:
  `stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = stream.data.size() / 2` (16-bit mono → samples = bytes / 2).
  Alternatively, set loop mode Forward in each file's import settings.
- **Players and bus:** use two `AudioStreamPlayer`s on a "Music" bus. Keep music around -18 to -20 dB, under the sound effects; the mining hits and drills should cut through. Sound effects currently play at about -9 to -15 dB.
- **Switching:** crossfade over about 1.5 s: menu theme while `menu != ""` (pause, office, station panels) or while a story card is open (`hud.card_open()`); gameplay loop otherwise. Pause rather than restart each track, so it resumes where it left off.
- **Ducking:** briefly duck the music about 4 dB when the `unlock` jingle plays (stage/milestone toasts).
- **Saving:** a music volume setting (and mute) would be a nice addition to the pause menu; persist it with the save or a small `user://settings.cfg`.
- **Export:** the WAVs are about 7 MB and 5 MB. If PCK size matters, re-encode as OGG Vorbis (`AudioStreamOggVorbis`, which also has a `loop` flag).
