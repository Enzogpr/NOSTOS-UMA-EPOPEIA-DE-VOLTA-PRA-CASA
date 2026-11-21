shader_type canvas_item;
render_mode unshaded;

uniform sampler2D reflections : source_color, filter_linear;
uniform vec2 camera_offset;
uniform float clock;

void fragment() {
	vec2 at = UV * vec2(1152.0, 648.0) + camera_offset;
	float drift = sin(at.y * 0.085 - clock * 1.45) * 3.2 + sin(at.y * 0.041 + clock * 0.64) * 7.0;
	vec2 uv = vec2((at.x + drift) / 1180.0, at.y / 255.0 - clock * 0.012);
	uv = 1.0 - abs(mod(uv, 2.0) - 1.0);
	vec3 reflected = texture(reflections, uv).rgb;
	float small_wave = sin(at.y * 0.34 + sin(at.x * 0.012) * 2.0 - clock * 1.2);
	float broken = sin(at.x * 0.047 + sin(at.y * 0.023) * 3.0 + clock * 0.21);
	float sheen = smoothstep(0.8, 1.0, small_wave) * smoothstep(0.1, 0.9, broken);
	vec3 base = vec3(0.022, 0.079, 0.095);
	COLOR = vec4(base + reflected * vec3(0.34, 0.45, 0.47) + vec3(0.08, 0.16, 0.17) * sheen * 0.20, 1.0);
}
