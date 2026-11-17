shader_type spatial;
render_mode specular_disabled;

// Deformable quarry ground (prototype). Vertex colour R = rock fraction (0 dirt .. 1 rock).
// Triplanar, nearest-filtered pixel textures at THE VEIL's 64 px/m density (128 px tiles = 2 m).

uniform sampler2D dirt_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tiles_per_metre = 0.5;

varying vec3 world_pos;
varying vec3 world_nrm;
varying float rock_amount;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	rock_amount = COLOR.r;
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 w) {
	vec3 x = texture(tex, p.zy * tiles_per_metre).rgb;
	vec3 y = texture(tex, p.xz * tiles_per_metre).rgb;
	vec3 z = texture(tex, p.xy * tiles_per_metre).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 w = pow(abs(world_nrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 d = triplanar(dirt_tex, world_pos, w);
	vec3 r = triplanar(rock_tex, world_pos, w);
	float m = smoothstep(0.25, 0.75, rock_amount);
	ALBEDO = mix(d, r, m);
	ROUGHNESS = 1.0;
}
