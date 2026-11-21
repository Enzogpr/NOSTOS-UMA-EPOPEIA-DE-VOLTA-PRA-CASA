shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cave : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 torches[6];
uniform vec3 daylight = vec3(0.5, 0.35, 0.0);

void fragment() {
	vec2 pixel = UV * vec2(1152.0, 648.0);
	vec3 scene = texture(cave, SCREEN_UV).rgb;
	vec3 light = vec3(0.023, 0.030, 0.042);
	vec3 air = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		vec2 offset = pixel - torches[i].xy;
		float side = (i == 0 || i == 2 || i == 4) ? -1.0 : 1.0;
		float beam = length((offset - vec2(side * 102.0, -66.0)) / vec2(218.0, 151.0));
		float radius = length(offset / vec2(121.0, 111.0));
		float direct = 1.0 - smoothstep(0.04, 1.12, radius);
		float reflected = (1.0 - smoothstep(0.05, 1.22, beam)) * 0.41;
		light += vec3(1.23, 0.86, 0.59) * (direct * 0.64 + reflected) * torches[i].z;
		float glow = exp(-length(offset / vec2(35.0, 34.0)) * 2.45);
		air += vec3(0.30, 0.14, 0.042) * glow * torches[i].z;
	}
	vec2 outside = UV - daylight.xy;
	float opening = 1.0 - smoothstep(0.07, 0.75, length(outside * vec2(1.15, 1.15)));
	light += vec3(0.66, 0.87, 1.03) * daylight.z * opening;
	air += vec3(0.016, 0.042, 0.063) * daylight.z * pow(opening, 2.0);
	COLOR = vec4(scene * min(light, vec3(1.30, 1.10, 0.94)) + air, 1.0);
}
