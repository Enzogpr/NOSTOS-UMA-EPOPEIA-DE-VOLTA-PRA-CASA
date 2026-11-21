shader_type canvas_item;

uniform float travel;
uniform float tide_clock;
uniform float exit_light;

void fragment() {
	vec2 p = floor(UV * vec2(576.0, 324.0));
	p.y -= travel * 0.34;
	float bend = sin(p.x * 0.025 + p.y * 0.009);
	float ripple = sin(p.x * 0.063 + p.y * 0.126 + bend * 2.2 + tide_clock * 1.2);
	float cross_ripple = sin(p.x * 0.019 - p.y * 0.047 + tide_clock * 0.83);
	float fine = sin(p.x * 0.24 + p.y * 0.21 + bend * 2.2);
	float sheen = smoothstep(0.72, 1.0, ripple) * smoothstep(0.28, 0.92, cross_ripple);
	vec3 water = vec3(0.025, 0.095, 0.119) + (ripple * 0.19 + cross_ripple * 0.47) * vec3(0.015, 0.067, 0.071);
	water += sheen * vec3(0.054, 0.105, 0.11) * (0.72 + fine * 0.25);
	float shaft = exp(-pow((UV.x - 0.52) * 3.8, 2.0)) * (1.0 - UV.y * 0.68);
	water += exit_light * shaft * vec3(0.18, 0.31, 0.31);
	float vignette = smoothstep(0.26, 0.67, length((UV - vec2(0.50, 0.49)) * vec2(0.82, 1.10)));
	COLOR = vec4(water * (1.0 - vignette * 0.52), 1.0);
}
