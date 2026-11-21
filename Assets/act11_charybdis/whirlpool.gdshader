shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float power = 0.32;
uniform float jaw_pulse = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 pixel = UV * vec2(1152.0, 648.0);
	vec2 p = (floor(pixel * 0.67) / 0.67 - vec2(576.0, 328.0)) / vec2(438.4, 230.4);
	float r = length(p);
	float a = atan(p.y, p.x);
	float arms = a * 7.0 - r * 29.0 - clock * (2.4 + power * 3.2);
	float eddies = noise(vec2(p.x * 19.0 + clock * 0.19, p.y * 23.0 - clock * 0.21));
	float swell = sin(arms + eddies * 2.55 + sin(r * 21.0 - clock * 1.7) * 0.6);
	float broken = noise(p * 58.0 + vec2(clock * 0.52, -clock * 0.35));
	float foam = smoothstep(0.68, 1.0, swell + (eddies - 0.5) * 0.49) * smoothstep(0.28, 0.76, broken);
	float spiral = (1.0 - smoothstep(0.17, 1.50, r)) * (0.35 + power * 0.65);
	float seams = sin(p.x * 27.0 + p.y * 24.0 + clock * 1.85 + eddies * 6.0) * 0.5 + 0.5;
	vec3 water = mix(vec3(0.028, 0.095, 0.14), vec3(0.15, 0.36, 0.39), eddies * 0.55 + seams * 0.28);
	water = mix(water, vec3(0.05, 0.26, 0.31), spiral * (swell * 0.26 + 0.47));
	water = mix(water, vec3(0.69, 0.87, 0.82), foam * (0.17 + power * 0.45) * smoothstep(0.08, 0.26, r));
	float throat = (0.24 + 0.05 * sin(clock * 1.8) + jaw_pulse * 0.08) * (0.45 + power * 0.55);
	float rim = exp(-pow((r - throat) * 26.0, 2.0));
	vec3 flesh = mix(vec3(0.09, 0.04, 0.088), vec3(0.38, 0.19, 0.24), eddies);
	water = mix(water, flesh, rim * power * 0.88);
	water = mix(vec3(0.012, 0.01, 0.027), water, smoothstep(throat * 0.48, throat, r));
	float shade = 1.0 - 0.56 * smoothstep(0.85, 1.83, r);
	COLOR = vec4(water * shade, 1.0);
}
