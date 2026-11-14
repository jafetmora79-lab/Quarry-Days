extends Label3D
class_name PixelLabel
## World text in the game's own pixel font (Silkscreen) with crisp nearest filtering and a dark brown edge, instead of the
## smooth default font that looked like a stock overlay. A drop-in for Label3D: the size in the world stays as set; the
## font size is snapped to the font's 8 px grid so the pixels stay square.

const FONT := preload("res://assets/fonts/Silkscreen.ttf")

func _init() -> void:
	font = FONT
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	outline_modulate = Color(0.1, 0.07, 0.04)
	outline_size = 6

func _ready() -> void:
	var snapped := maxi(8, int(round(float(font_size) / 8.0)) * 8)
	if snapped != font_size:
		pixel_size *= float(font_size) / float(snapped)
		font_size = snapped
	outline_size = clampi(int(font_size / 8.0) * 2, 2, 12)
