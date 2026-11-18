shader_type canvas_item;
// Colour banding + ordered dither, from MenacingMecha's godot-psx-style-demo (MIT, assets/shaders/psx/LICENSE-psx-style-demo.txt: pp_band-dither.gdshader), changed to read the screen
// texture directly so it can run as one full-screen pass over the 3D picture (under the HUD).
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D dither_tex : hint_default_white, repeat_enable, filter_nearest;
uniform float col_depth = 31.0;
uniform float dither_amount = 1.0;

void fragment() {
	vec4 base = texture(screen_tex, SCREEN_UV);
	vec2 dith_size = vec2(textureSize(dither_tex, 0));
	vec2 buf_size = vec2(textureSize(screen_tex, 0));
	vec3 dith = texture(dither_tex, SCREEN_UV * (buf_size / dith_size)).rgb - 0.5;
	COLOR = vec4(round(base.rgb * col_depth + dith * dither_amount) / col_depth, 1.0);
}
