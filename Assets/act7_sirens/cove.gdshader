shader_type canvas_item;

uniform float tide_clock;
uniform float enchantment;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * vec2(576.0, 324.0));
	float bend = sin(p.y * 0.034 + p.x * 0.015 - tide_clock * 0.35);
	float swell = sin(p.x * 0.038 + p.y * 0.079 + bend * 1.2 - tide_clock * 0.94);
	float crossing = sin(p.x * 0.071 - p.y * 0.046 + sin(p.x * 0.013 + p.y * 0.007) * 1.8 + tide_clock * 0.6);
	float shallow = smoothstep(0.05, 0.85, 1.0 - abs(UV.y - 0.47) * 1.6);
	float shoal = sin(p.x * 0.011 - p.y * 0.014 + bend);
	vec3 color = mix(vec3(0.027, 0.11, 0.15), vec3(0.082, 0.29, 0.30), shallow * 0.67 + shoal * 0.13);
	color += (swell + crossing * 0.55) * vec3(0.013, 0.034, 0.034);
	float fleck = smoothstep(0.89, 1.0, swell) * smoothstep(0.28, 0.83, crossing);
	color += fleck * (0.42 + grain(floor(p / 2.0)) * 0.58) * vec3(0.082, 0.14, 0.125);
	float edge = smoothstep(0.25, 0.73, length((UV - vec2(0.5, 0.47)) * vec2(1.0, 1.18)));
	color = mix(color, color * vec3(0.69, 0.64, 0.94) + vec3(0.05, 0.0, 0.10), enchantment);
	COLOR = vec4(color * (1.0 - edge * (0.50 + enchantment * 0.35)), 1.0);
}
