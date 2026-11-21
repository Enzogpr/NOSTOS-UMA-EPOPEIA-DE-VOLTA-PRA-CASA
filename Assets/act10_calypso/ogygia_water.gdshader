shader_type canvas_item;

uniform sampler2D sea_art : source_color, filter_linear;
uniform float tide_clock;
uniform float passage;

vec2 reflected_repeat(vec2 point) {
	return 1.0 - abs(fract(point * 0.5) * 2.0 - 1.0);
}

void fragment() {
	vec2 pixels = floor(UV * vec2(768.0, 432.0)) / vec2(768.0, 432.0);
	float swell = sin(pixels.x * 13.1 + pixels.y * 26.0 - tide_clock * 1.83);
	float crosswind = sin(pixels.x * 26.0 - pixels.y * 12.0 + tide_clock * 0.62);
	vec2 drift = pixels * vec2(1.22, 1.75) + vec2(swell * 0.025 + tide_clock * 0.021, passage * 0.0023 + crosswind * 0.018);
	vec2 atlas = mix(vec2(0.05, 0.632), vec2(0.95, 0.992), reflected_repeat(drift));
	vec3 water = texture(sea_art, atlas).rgb;
	vec3 palette = mix(vec3(0.83, 0.94, 0.90), vec3(0.58, 0.82, 0.91), smoothstep(0.25, 1.0, pixels.y));
	float foam = smoothstep(0.69, 0.98, swell) * smoothstep(0.6, 0.99, crosswind);
	COLOR = vec4(water * palette + foam * vec3(0.043, 0.085, 0.078), 1.0);
}
