shader_type canvas_item;

uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float spectral : hint_range(0.0, 1.0) = 0.0;
uniform float agitation : hint_range(0.0, 1.0) = 0.0;
uniform vec2 atlas_grid = vec2(2.0, 2.0);
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

float pixel_noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Each expression occupies one quadrant of the original, unmodified atlas.
	vec2 cell = floor(UV * atlas_grid);
	vec2 local_uv = fract(UV * atlas_grid);
	vec2 sample_uv = local_uv;
	sample_uv.x += sin(local_uv.y * 31.0 + TIME * 1.7) * spectral * agitation * 0.002;
	vec4 tex = texture(TEXTURE, (cell + clamp(sample_uv, vec2(0.001), vec2(0.999))) / atlas_grid);
	float noise = pixel_noise(floor(local_uv * 160.0));
	float threshold = local_uv.y * 0.65 + noise * 0.35;
	float dissolved = smoothstep(threshold - 0.035, threshold + 0.035, presence * 1.08) * step(0.001, presence);
	float edge = (1.0 - smoothstep(0.0, 0.08, abs(threshold - presence))) * spectral;
	vec3 light = vec3(0.46, 0.70, 1.0);
	vec3 rgb = mix(tex.rgb, tex.rgb * vec3(0.87, 0.94, 1.12), spectral * 0.45);
	rgb += light * edge * 0.40;
	rgb += light * spectral * (0.035 + sin(TIME * 2.0) * 0.012);
	float waist = 1.0 - smoothstep(0.85, 0.99, local_uv.y);
	COLOR = vec4(rgb, tex.a * dissolved * waist) * sprite_tint;
}
