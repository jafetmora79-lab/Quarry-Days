shader_type spatial;
render_mode specular_disabled;

// The quarry's diggable ground. Eight materials (data/geology.json, in slot order); the mesh carries eight weights per vertex:
// COLOR = slots 0-3, UV = slots 4-5, UV2 = slots 6-7. Nearest-filtered pixel textures at THE VEIL's 64 px/m (128 px tiles = 2 m).
// Cost control for integrated graphics: a material is only sampled where its weight is above a threshold, gentle ground uses ONE flat
// projection and only steep faces (hole walls) add one side projection, so most pixels cost one or two fetches, not eighteen.

uniform sampler2D tex0 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex1 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex2 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex3 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex4 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex5 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex6 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex7 : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint0 = vec3(1.0);
uniform vec3 tint1 = vec3(1.0);
uniform vec3 tint2 = vec3(1.0);
uniform vec3 tint3 = vec3(1.0);
uniform vec3 tint4 = vec3(1.0);
uniform vec3 tint5 = vec3(1.0);
uniform vec3 tint6 = vec3(1.0);
uniform vec3 tint7 = vec3(1.0);        // per-material colour multipliers (data/geology.json "tint"): the pale limestone is warmed and darkened so it does not glare white
uniform float tiles_per_metre = 0.5;
uniform float steep_from = 0.35;     // 1 - normal.y above which a side projection is blended in (about 40 degrees)

varying vec3 world_pos;
varying vec3 world_nrm;
varying vec4 wa;
varying vec4 wb;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wa = COLOR;
	wb = vec4(UV, UV2);
}

vec3 flat_top(sampler2D t, vec3 p) {
	return texture(t, p.xz * tiles_per_metre).rgb;
}

vec3 with_side(sampler2D t, vec3 p, vec3 top, float steep) {
	if (steep <= 0.01) {
		return top;
	}
	vec2 uv = abs(world_nrm.x) > abs(world_nrm.z) ? p.zy : p.xy;
	return mix(top, texture(t, uv * tiles_per_metre).rgb, steep);
}

void fragment() {
	float steep = smoothstep(steep_from, steep_from + 0.3, 1.0 - clamp(world_nrm.y, 0.0, 1.0));
	vec3 c = vec3(0.0);
	float total = 0.0;
	if (wa.r > 0.03) { c += wa.r * tint0 * with_side(tex0, world_pos, flat_top(tex0, world_pos), steep); total += wa.r; }
	if (wa.g > 0.03) { c += wa.g * tint1 * with_side(tex1, world_pos, flat_top(tex1, world_pos), steep); total += wa.g; }
	if (wa.b > 0.03) { c += wa.b * tint2 * with_side(tex2, world_pos, flat_top(tex2, world_pos), steep); total += wa.b; }
	if (wa.a > 0.03) { c += wa.a * tint3 * with_side(tex3, world_pos, flat_top(tex3, world_pos), steep); total += wa.a; }
	if (wb.x > 0.03) { c += wb.x * tint4 * with_side(tex4, world_pos, flat_top(tex4, world_pos), steep); total += wb.x; }
	if (wb.y > 0.03) { c += wb.y * tint5 * with_side(tex5, world_pos, flat_top(tex5, world_pos), steep); total += wb.y; }
	if (wb.z > 0.03) { c += wb.z * tint6 * with_side(tex6, world_pos, flat_top(tex6, world_pos), steep); total += wb.z; }
	if (wb.w > 0.03) { c += wb.w * tint7 * with_side(tex7, world_pos, flat_top(tex7, world_pos), steep); total += wb.w; }
	ALBEDO = total > 0.0 ? c / total : vec3(0.4, 0.3, 0.2);
	ROUGHNESS = 1.0;
}
