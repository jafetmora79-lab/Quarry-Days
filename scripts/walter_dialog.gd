extends PanelContainer
class_name QuarryWalterDialog
## Phase 7.5: Walter talking. A short run of lines (the intro scene and every visit) shown one at a time at the bottom
## of the screen. Always skippable; the owner decides what happens when it finishes.

signal finished(skipped: bool)
signal line_changed(index: int)

var timed := false          ## cinematic mode: lines advance by themselves after their "dur" seconds
var _timer := 0.0
var _done := false

var lines: Array = []       ## [{speaker, text}]
var index := 0
var speaker_label: Label
var face: TextureRect          ## the speaker's portrait (Walter or Dr. Marsh); hidden for other speakers
var body: Label
var next_btn: Button
var skip_btn: Button

func setup(entries: Array, is_timed := false) -> void:
	lines = entries
	timed = is_timed
	name = "WalterDialog"
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(620, 0)
	add_theme_stylebox_override("panel", UiSkin.box("frame_dialog", QuarryTheme.panel_box(QuarryTheme.BG, QuarryTheme.ACCENT, 12, 4), [22, 18, 22, 18]))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	face = UiArt.portrait_rect(_face_for("WALTER"), 72)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(face)
	hb.add_child(v)
	add_child(hb)
	speaker_label = QuarryTheme.label("", 12, QuarryTheme.ACCENT, true)
	v.add_child(speaker_label)
	body = QuarryTheme.label("", QuarryTheme.DIALOG)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 0)
	v.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	next_btn = Button.new()
	next_btn.pressed.connect(advance)
	row.add_child(next_btn)
	skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(skip)
	row.add_child(skip_btn)
	_show()

## Portrait index for a speaker: the named-cast render when it exists, else the sheet's grandfather.
static func _face_for(speaker: String) -> int:
	var idx := UiArt.named_index("marsh" if speaker.contains("MARSH") else "walter")
	return idx if idx >= 0 else UiArt.GRANDFATHER

func _show() -> void:
	var l: Dictionary = lines[index]
	speaker_label.text = str(l.get("speaker", "WALTER"))
	var who := speaker_label.text.to_upper()
	face.visible = who.contains("WALT") or who.contains("MARSH")
	if face.visible:
		face.texture = UiArt.portrait(_face_for(who))
	body.text = '"%s"' % str(l.get("text", ""))
	next_btn.text = "Continue" if index < lines.size() - 1 else "Done"
	_timer = float(l.get("dur", 4.0))
	line_changed.emit(index)

func _process(delta: float) -> void:
	if not timed:
		return
	_timer -= delta
	if _timer <= 0.0:
		advance()

func advance() -> void:
	if _done:
		return
	if index >= lines.size() - 1:
		_done = true
		finished.emit(false)
		return
	index += 1
	_show()

func skip() -> void:
	if _done:
		return
	_done = true
	finished.emit(true)

## Keyboard: E / Enter / Space continue, Esc skips.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_E, KEY_ENTER, KEY_SPACE:
			advance()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			skip()
			get_viewport().set_input_as_handled()
