shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_linear;
uniform float fatigue = 0.0;
uniform float closure = 0.0;
uniform float clock = 0.0;
void fragment() {
	vec2 px = vec2(1.0) / vec2(textureSize(screen_image, 0));
	float weight = smoothstep(0.45, 1.0, fatigue);
	vec2 shift = vec2(sin(clock * 1.1), cos(clock * 0.85)) * weight * 3.0 * px;
	vec2 at = SCREEN_UV + shift;
	vec2 radius = px * weight * 2.3;
	vec4 picture = texture(screen_image, at) * 0.4;
	picture += texture(screen_image, at + vec2(radius.x, 0.0)) * 0.15;
	picture += texture(screen_image, at - vec2(radius.x, 0.0)) * 0.15;
	picture += texture(screen_image, at + vec2(0.0, radius.y)) * 0.15;
	picture += texture(screen_image, at - vec2(0.0, radius.y)) * 0.15;
	float lid = mix(weight * weight * 0.12, 0.51, closure);
	float opening = smoothstep(lid - 0.055, lid + 0.025, UV.y) * (1.0 - smoothstep(1.0 - lid - 0.025, 1.0 - lid + 0.055, UV.y));
	float edge = smoothstep(0.22, 0.73, distance(UV, vec2(0.5, 0.48)));
	picture.rgb *= (1.0 - edge * weight * 0.33) * opening * (1.0 - closure * 0.95);
	COLOR = vec4(picture.rgb, 1.0);
}
