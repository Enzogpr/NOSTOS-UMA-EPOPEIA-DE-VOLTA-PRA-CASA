shader_type canvas_item;
render_mode unshaded;

uniform float mental_mix : hint_range(0.0, 1.0) = 0.0;
uniform float focus : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * focus * 7.0;
	vec4 image = texture(TEXTURE, UV) * 0.28;
	image += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)) * 0.18;
	image += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)) * 0.18;
	image += texture(TEXTURE, UV + vec2(0.0, step_uv.y)) * 0.18;
	image += texture(TEXTURE, UV - vec2(0.0, step_uv.y)) * 0.18;
	float gray = dot(image.rgb, vec3(0.299, 0.587, 0.114));
	image.rgb = mix(image.rgb, vec3(gray) * vec3(0.67, 0.84, 1.06), focus * 0.75);
	image.rgb *= 1.0 - smoothstep(0.18, 0.72, distance(UV, vec2(0.38, 0.38))) * focus * 0.65;
	COLOR = vec4(image.rgb, image.a * (1.0 - mental_mix));
}
