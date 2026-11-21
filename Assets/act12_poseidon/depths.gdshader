shader_type canvas_item;
render_mode unshaded;

uniform float clock;
uniform float ascent;
uniform float surge;

float caustics(vec2 p) {
	float line = sin(p.x * 26.0 + p.y * 6.0 + sin(p.y * 13.0 + clock * 1.6) * 1.3);
	float cross = cos(p.x * 17.0 - p.y * 12.0 + clock);
	return pow(max(0.0, line * 0.6 + cross * 0.4), 5.0);
}

void fragment() {
	vec2 p = floor(UV * vec2(768.0, 432.0)) / vec2(768.0, 432.0);
	float top = pow(1.0 - p.y, 2.4);
	float beam = exp(-4.5 * abs(p.x - 0.5 - sin(p.y * 6.0 + clock) * 0.04));
	float rays = sin((p.x - 0.5) * (37.0 - p.y * 13.0) + clock * 0.6) * 0.5 + 0.5;
	float dapple = caustics(p + vec2(0.0, clock * -0.08 - ascent * 0.22));
	vec3 color = mix(vec3(0.011, 0.033, 0.071), vec3(0.095, 0.35, 0.40), top * beam * (0.65 + ascent * 0.34));
	color += vec3(0.12, 0.29, 0.29) * (rays * top * 0.44 + dapple * 0.28 + surge * 0.15) * beam;
	COLOR = vec4(color, 1.0);
}
