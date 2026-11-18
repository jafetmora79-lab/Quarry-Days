extends CanvasLayer
class_name RetroPass
## An optional "retro colour" look over the 3D picture (Settings > Display): the colours are reduced to a few shades per channel and a fine ordered dither hides the banding, the way early
## 3D consoles did. Taken from the PSX-style demo's dither shader (assets/shaders/psx/, MIT). Level 0 = off (no pass runs at all), 1 = subtle (32 shades), 2 = strong (16 shades, the console value).
## It sits below the HUD, so the interface stays crisp, and costs one full-screen pass only while it is on.

const LEVELS := [{"name": "Off"}, {"name": "Subtle", "depth": 31.0, "dither": 1.0}, {"name": "Strong", "depth": 15.0, "dither": 1.0}]

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	name = "RetroPass"
	layer = -2                                                                   # above the 3D picture, below the interaction outline (-1) and every HUD layer
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/psx/retro_pass.gdshader")
	_mat.set_shader_parameter("dither_tex", load("res://assets/shaders/psx/psxdither.png"))
	_rect.material = _mat
	add_child(_rect)
	GameSettings.retro_node = self
	apply(GameSettings.retro)

func _exit_tree() -> void:
	if GameSettings.retro_node == self:
		GameSettings.retro_node = null

func apply(level: int) -> void:
	level = clampi(level, 0, LEVELS.size() - 1)
	_rect.visible = level > 0
	if level > 0:
		_mat.set_shader_parameter("col_depth", float(LEVELS[level]["depth"]))
		_mat.set_shader_parameter("dither_amount", float(LEVELS[level]["dither"]))
