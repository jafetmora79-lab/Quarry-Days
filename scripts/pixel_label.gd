extends Label3D
class_name PixelLabel
## World text in the game's own pixel faces, drawn with crisp nearest filtering and a dark brown edge. Signs, names and pop-ups use Pixelify Sans;
## machine counters and status readouts set `readout = true` before entering the tree and use VT323 (a digital display face).
## The font is rasterised at the label's font_size, so the sign texture is already sized for the on-screen glyphs: no scaling blur.

const SIGN_FONT := preload("res://assets/fonts/qd_heading.tres")
const READOUT_FONT := preload("res://assets/fonts/qd_mono.tres")

var readout := false

func _init() -> void:
	font = SIGN_FONT
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	outline_modulate = Color(0.1, 0.07, 0.04)
	outline_size = 6
	double_sided = true

func _ready() -> void:
	if readout:
		font = READOUT_FONT
	outline_size = clampi(int(font_size / 8.0) * 2, 2, 12)
