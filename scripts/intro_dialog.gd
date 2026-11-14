extends PanelContainer
class_name QuarryIntroDialog
## The short, skippable first conversation with a new employee: they greet you, you confirm or change their name, they
## answer in their own way. Lines come from the worker's personality (friendly, quiet, enthusiastic, serious, humorous);
## personality only changes what they say, never their work, wages or speed.

signal finished(name_text: String, skipped: bool)

const LINES := {
	"friendly": {
		"greet": "Hey! I'm %s. Heard you're looking for another pair of hands - happy to be here!",
		"ask": "Is %s alright, or would you rather call me something else?",
		"after": "Great, %s it is. Let's get to work!"},
	"quiet": {
		"greet": "...Morning. I'm %s. The %s job, right?",
		"ask": "%s is fine. Or pick another.",
		"after": "Right. I'll get on with it."},
	"enthusiastic": {
		"greet": "Wow, so this is the quarry! I'm %s - I can't wait to see what we build here!",
		"ask": "Keep %s, or give me a better name?",
		"after": "Awesome! %s, reporting for work - and for every upgrade you buy!"},
	"serious": {
		"greet": "Good day. I'm %s. I'll take the %s work seriously.",
		"ask": "You may keep %s, or enter another name.",
		"after": "Understood, %s. I'll start at once."},
	"humorous": {
		"greet": "Hi, I'm %s. I dig the job - get it? ...I'll show myself in.",
		"ask": "%s, or something catchier? I answer to anything, including 'hey you'.",
		"after": "%s! Sounds like a name that gets promoted. Let's go!"},
}

const PLAYER_LINES := ["Welcome to the quarry.", "Glad you could come. Welcome aboard.", "Good to have you here. Welcome to the quarry."]
const JOB_LINES := {
	"friendly": "Thanks! Where do you need me?",
	"quiet": "...Where do you want me?",
	"enthusiastic": "Thanks! Okay, where do you need me? I'm ready!",
	"serious": "Understood. Where do you need me?",
	"humorous": "Thanks, boss. Point me at a rock and I'll make friends with it."}

var step := 0
var name_edit: LineEdit
var body: Label
var title: Label
var next_btn: Button
var skip_btn: Button
var suggested := ""
var personality := "friendly"
var job := "worker"

func setup(suggest: String, pers: String, job_title: String, portrait_index := -1) -> void:
	suggested = suggest
	personality = pers if LINES.has(pers) else "friendly"
	job = job_title
	name = "IntroDialog"
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(560, 0)
	add_theme_stylebox_override("panel", UiSkin.box("frame_dialog", QuarryTheme.panel_box(QuarryTheme.BG, QuarryTheme.ACCENT, 12, 4), [22, 18, 22, 18]))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if portrait_index >= 0:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var face := UiArt.portrait_rect(portrait_index, 72)
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		hb.add_child(face)
		hb.add_child(v)
		add_child(hb)
	else:
		add_child(v)
	title = QuarryTheme.label("", 12, QuarryTheme.ACCENT, true)
	v.add_child(title)
	body = QuarryTheme.label("", QuarryTheme.BODY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	v.add_child(body)
	name_edit = LineEdit.new()
	name_edit.max_length = 20
	name_edit.text = suggested
	name_edit.visible = false
	name_edit.select_all_on_focus = true
	v.add_child(name_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	next_btn = Button.new()
	next_btn.pressed.connect(_next)
	row.add_child(next_btn)
	skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(func(): finished.emit(suggested if name_edit.text.strip_edges() == "" else name_edit.text, true))
	row.add_child(skip_btn)
	_show_step()

func _show_step() -> void:
	var l: Dictionary = LINES[personality]
	var who := suggested.to_upper()
	match step:
		0:
			title.text = "%s  -  %s" % [who, job.to_upper()]
			body.text = '"%s"' % _fmt(str(l["greet"]), suggested)
			next_btn.text = "Continue"
		1:
			title.text = "YOU"
			body.text = '"%s"' % PLAYER_LINES[hash(suggested) % PLAYER_LINES.size()]
			next_btn.text = "Continue"
		2:
			title.text = who
			body.text = '"%s"' % _fmt(str(l["ask"]), suggested)
			name_edit.visible = true
			name_edit.grab_focus()
			next_btn.text = "That works"
		3:
			var chosen := name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else suggested
			title.text = chosen.to_upper()
			body.text = '"%s  %s"' % [_fmt(str(l["after"]), chosen), str(JOB_LINES.get(personality, JOB_LINES["friendly"]))]
			name_edit.visible = false
			next_btn.text = "Let's get to work"
			skip_btn.visible = false

func _fmt(line: String, who: String) -> String:
	return line % [who, job] if line.count("%s") == 2 else line % who

func _next() -> void:
	if step >= 3:
		finished.emit(name_edit.text if name_edit.text.strip_edges() != "" else suggested, false)
		return
	step += 1
	_show_step()


## Occasional one-liners a worker says while working near the player (Phase 8.3). Personality only changes the words.
const BARKS := {
	"friendly": ["Nice day for it!", "Need a hand with anything?", "This place is coming along."],
	"quiet": ["...", "Hm.", "Almost there."],
	"enthusiastic": ["I love this job!", "Look at that rock go!", "What are we building next?"],
	"serious": ["Back to work.", "Safety first.", "On schedule."],
	"humorous": ["I dig this job. Get it?", "Rock and roll.", "Don't tell the rocks I'm winning."]}

static func bark_for(pers: String, n: int) -> String:
	var lines: Array = BARKS.get(pers, BARKS["friendly"])
	return str(lines[posmod(n, lines.size())])
