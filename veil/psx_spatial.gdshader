shader_type spatial;
render_mode skip_vertex_transform, cull_back, diffuse_lambert, specular_disabled;
// Veil test: PSX-style vertex snap + affine texture warp + banded dither. Albedo comes from the Veil asset's own texture.
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 snap_grid = vec2(160.0, 120.0);   // virtual PS1 vertex resolution; 0 disables snapping
uniform float affine = 1.0;                    // 0 = perspective-correct, 1 = full affine warp
uniform sampler2D dither_tex : hint_default_white, repeat_enable, filter_nearest;
uniform float col_depth = 31.0;
uniform float dither_amount = 1.0;
varying vec2 v_uv;
varying float v_w;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap_grid.x > 0.0) {
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * snap_grid + 0.5) / snap_grid;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_NORMAL_MATRIX * NORMAL));
	v_w = mix(1.0, abs(clip.w), affine);
	v_uv = UV * uv_scale * v_w;
}

void fragment() {
	vec2 uv = v_uv / v_w;
	vec3 c = texture(albedo_tex, uv).rgb * tint.rgb;
	vec2 ds = vec2(textureSize(dither_tex, 0));
	vec3 d = texture(dither_tex, FRAGCOORD.xy / ds).rgb - 0.5;
	ALBEDO = round(c * col_depth + d * dither_amount * 0.5) / col_depth;
}
